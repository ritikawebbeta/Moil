// src/services/ftp_sync_service.js
const fs = require('fs');
const path = require('path');
const ftp = require('basic-ftp');
const xlsx = require('xlsx');
const { pool } = require('../config/db');

// Environment variables with fallbacks
const FTP_HOST = process.env.FTP_HOST || '172.16.1.51';
const FTP_PORT = parseInt(process.env.FTP_PORT || '21', 10);
const FTP_USER = process.env.FTP_USER || 'ftpuser2';
const FTP_PASS = process.env.FTP_PASSWORD || 'Ftppo16$';
const FTP_INBOUND_DIR = process.env.FTP_INBOUND_DIR || '/HR_App/Inbound';
const FTP_OUTBOUND_DIR = process.env.FTP_OUTBOUND_DIR || '/HR_App/Outbound';

/**
 * Utility: Convert Excel date numbers/strings into YYYY-MM-DD
 */
function excelDateToDateString(val) {
  if (val === null || val === undefined || val === '') return null;
  const str = String(val).trim();
  if (str === '' || str.toUpperCase() === 'NULL' || str === '0000-00-00' || str === '00.00.0000') return null;

  // Numeric Excel serial date code
  if (/^\d{4,5}(\.\d+)?$/.test(str)) {
    const num = parseFloat(str);
    if (num > 1000) {
      const d = new Date(Math.round((num - 25569) * 86400 * 1000));
      if (!isNaN(d.getTime())) {
        const yyyy = d.getUTCFullYear();
        const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
        const dd = String(d.getUTCDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
      }
    }
  }

  // Format: DD.MM.YYYY
  if (/^\d{2}\.\d{2}\.\d{4}$/.test(str)) {
    const p = str.split('.');
    return `${p[2]}-${p[1]}-${p[0]}`;
  }

  // Format: DD-MM-YYYY
  if (/^\d{2}-\d{2}-\d{4}$/.test(str)) {
    const p = str.split('-');
    return `${p[2]}-${p[1]}-${p[0]}`;
  }

  return str;
}

/**
 * Utility: Match incoming file headers or filename to MySQL table name
 */
function detectTableFromHeaders(headers, fileName) {
  const kStr = (headers || []).join(' ').toLowerCase();

  if (kStr.includes('cname') || kStr.includes('act_doj_on_promt_dt') || kStr.includes('cname_first') || kStr.includes('act_dob_dt') || kStr.includes('employee_number')) {
    return 'manpower';
  }
  if (kStr.includes('absence_quota_type') || kStr.includes('quota_number') || (kStr.includes('personnel_number') && kStr.includes('deduction_from'))) {
    return 'leave_quota';
  }
  if (kStr.includes('att_abs_days') && kStr.includes('calendar_days') && kStr.includes('lock_indicator') && !kStr.includes('id_of_request_item')) {
    return 'absence';
  }
  if (kStr.includes('nomination_percentage') || kStr.includes('nominee_name') || kStr.includes('nominee_relation')) {
    return 'it0591_nomination';
  }
  if (kStr.includes('family_member') || kStr.includes("child's_address") || kStr.includes('family')) {
    return 'it0021_family_member';
  }
  if (kStr.includes('id_of_request_item') || (kStr.includes('infotype_operation') && kStr.includes('full_day'))) {
    return 'ptreq_attabsdata_leave_apply_1';
  }
  if (kStr.includes('document_identification') || kStr.includes('document_version') || kStr.includes('document_category')) {
    return 'ptreq_header_leave_approved_1';
  }
  if (kStr.includes('employment_percentage') || kStr.includes('working_hours') || kStr.includes('planned_working_time')) {
    return 'planned_working_time';
  }
  if (kStr.includes('compensation') || kStr.includes('comp_quota') || (fileName || '').toUpperCase().includes('IT0416')) {
    return 'time_quota_compensation_infotype';
  }
  if (kStr.includes('beginning_date_of_trip_segment') || kStr.includes('trip_destination') || kStr.includes('reason_for_trip')) {
    return 'travel';
  }
  if (kStr.includes('holiday_date') || kStr.includes('holiday_description') || kStr.includes('holiday')) {
    return 'zhcm_opt_holiday';
  }
  if (kStr.includes('reporting_officer') || kStr.includes('reporting_officer_1')) {
    return 'zhcm_lr_t_agents_03072026';
  }

  const fnUpper = (fileName || '').toUpperCase();
  if (fnUpper.includes('MANPOWER')) return 'manpower';
  if (fnUpper.includes('LEAVE_QUOTA')) return 'leave_quota';
  if (fnUpper.includes('ABSENCE')) return 'absence';
  if (fnUpper.includes('NOMINATION')) return 'it0591_nomination';
  if (fnUpper.includes('FAMILY')) return 'it0021_family_member';
  if (fnUpper.includes('LEAVE_APPLY')) return 'ptreq_attabsdata_leave_apply_1';
  if (fnUpper.includes('LEAVE_APPROVED')) return 'ptreq_header_leave_approved_1';
  if (fnUpper.includes('HOLIDAY')) return 'zhcm_opt_holiday';
  if (fnUpper.includes('AGENTS')) return 'zhcm_lr_t_agents_03072026';
  if (fnUpper.includes('PLANNED')) return 'planned_working_time';
  if (fnUpper.includes('TRAVEL')) return 'travel';

  return null;
}

/**
 * Upsert parsed file records into MySQL database table
 * Insert new records & update existing modified records without duplicates
 */
async function importRowsToDatabase(tableName, rows, fileName) {
  if (!Array.isArray(rows) || rows.length === 0) return { inserted: 0, updated: 0 };

  const conn = await pool.getConnection();
  try {
    // 1. Fetch valid table columns
    const [tableColsRows] = await conn.query(`SHOW COLUMNS FROM \`${tableName}\``);
    const validColsSet = new Set(tableColsRows.map(c => c.Field.toLowerCase()));

    let insertedCount = 0;
    let updatedCount = 0;

    for (const rowObj of rows) {
      const rawKeys = Object.keys(rowObj).filter(k => k && rowObj[k] !== undefined);
      if (rawKeys.length === 0) continue;

      const validKeys = [];
      const validVals = [];

      for (const k of rawKeys) {
        let cleanK = k.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_').replace(/^_+|_+$/g, '');
        if (validColsSet.has(cleanK)) {
          validKeys.push(cleanK);
          let val = rowObj[k];
          if (cleanK.includes('date') || cleanK.includes('dob') || cleanK.includes('dt') || cleanK.includes('from') || cleanK.includes('to') || cleanK.includes('dosl') || cleanK.includes('dopp') || cleanK.includes('doj')) {
            val = excelDateToDateString(val);
          }
          validVals.push(val);
        }
      }

      if (validKeys.length === 0) continue;

      const cols = validKeys.map(k => `\`${k}\``).join(', ');
      const placeholders = validKeys.map(() => '?').join(', ');
      const updateAssigns = validKeys.map(k => `\`${k}\` = VALUES(\`${k}\`)`).join(', ');

      const sql = `INSERT INTO \`${tableName}\` (${cols}) VALUES (${placeholders}) ON DUPLICATE KEY UPDATE ${updateAssigns}`;
      const [res] = await conn.query(sql, validVals);

      if (res.affectedRows === 1) insertedCount++;
      else if (res.affectedRows === 2) updatedCount++;
    }

    console.log(`[DB Sync] ${fileName} -> ${tableName}: Inserted ${insertedCount}, Updated ${updatedCount}`);
    return { inserted: insertedCount, updated: updatedCount };
  } finally {
    conn.release();
  }
}

/**
 * Parse local data file (.xlsx, .csv, .json)
 */
function parseDataFile(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.json') {
    const raw = fs.readFileSync(filePath, 'utf8');
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [parsed];
  } else if (ext === '.xlsx' || ext === '.xls' || ext === '.csv') {
    const wb = xlsx.readFile(filePath);
    let bestSheet = wb.Sheets[wb.SheetNames[0]];
    let maxRows = 0;
    for (const sName of wb.SheetNames) {
      const s = wb.Sheets[sName];
      const r = xlsx.utils.sheet_to_json(s);
      if (r.length > maxRows) {
        maxRows = r.length;
        bestSheet = s;
      }
    }
    return xlsx.utils.sheet_to_json(bestSheet);
  }
  return [];
}

/**
 * Core FTP Sync Runner
 */
async function runFtpSync() {
  console.log(`\n[FTP Sync] Starting synchronization process... [${new Date().toISOString()}]`);
  const localInboundDir = path.join(__dirname, '../../tmp_ftp_inbound');
  const localOutboundDir = path.join(__dirname, '../../outbound');

  if (!fs.existsSync(localInboundDir)) fs.mkdirSync(localInboundDir, { recursive: true });
  if (!fs.existsSync(localOutboundDir)) fs.mkdirSync(localOutboundDir, { recursive: true });

  const client = new ftp.Client();
  client.ftp.verbose = false;

  try {
    // Connect to FTP
    await client.access({
      host: FTP_HOST,
      port: FTP_PORT,
      user: FTP_USER,
      password: FTP_PASS,
      secure: false
    });
    console.log(`[FTP Sync] Connected successfully to FTP server ${FTP_HOST}:${FTP_PORT} as ${FTP_USER}`);

    // Ensure registry table exists
    await pool.query(`
      CREATE TABLE IF NOT EXISTS inbound_sync_registry (
        id INT AUTO_INCREMENT PRIMARY KEY,
        file_name VARCHAR(255) UNIQUE,
        file_size BIGINT,
        last_modified VARCHAR(100),
        processed_at DATETIME
      )
    `);

    // Step 1: Fetch latest files from FTP Inbound (/HR_App/Inbound)
    let inboundFiles = [];
    try {
      inboundFiles = await client.list(FTP_INBOUND_DIR);
    } catch (e) {
      console.warn(`[FTP Sync] Could not list ${FTP_INBOUND_DIR}: ${e.message}`);
    }

    for (const file of inboundFiles) {
      if (file.isDirectory) continue;

      const lastModStr = file.modifiedAt ? file.modifiedAt.toISOString() : (file.rawModifiedAt || '');

      // Check if file is already processed and unchanged
      const [regRows] = await pool.query(
        'SELECT * FROM inbound_sync_registry WHERE file_name = ? AND file_size = ? AND last_modified = ?',
        [file.name, file.size, lastModStr]
      );

      if (regRows.length > 0) {
        console.log(`[FTP Sync] Skipping unchanged inbound file: ${file.name}`);
        continue;
      }

      console.log(`[FTP Sync] Processing updated inbound file: ${file.name} (${file.size} bytes)`);

      const remoteFilePath = `${FTP_INBOUND_DIR}/${file.name}`;
      const localFilePath = path.join(localInboundDir, file.name);

      // Download file from FTP Inbound
      console.log(`[FTP Sync] Downloading Inbound file: ${file.name}`);
      await client.downloadTo(localFilePath, remoteFilePath);

      // Step 2: Store copy of Inbound file to FTP Outbound (/HR_App/Outbound)
      const remoteOutboundCopyPath = `${FTP_OUTBOUND_DIR}/${file.name}`;
      console.log(`[FTP Sync] Storing copy of ${file.name} to FTP Outbound folder...`);
      await client.uploadFrom(localFilePath, remoteOutboundCopyPath);

      // Step 3: Import parsed data from FTP Inbound into Database
      const rows = parseDataFile(localFilePath);
      if (rows.length > 0) {
        const sampleKeys = Object.keys(rows[0]);
        const tableName = detectTableFromHeaders(sampleKeys, file.name);
        if (tableName) {
          await importRowsToDatabase(tableName, rows, file.name);
        } else {
          console.log(`[FTP Sync] Skipping unmapped file: ${file.name}`);
        }
      }

      // Update registry
      await pool.query(`
        INSERT INTO inbound_sync_registry (file_name, file_size, last_modified, processed_at)
        VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE file_size = VALUES(file_size), last_modified = VALUES(last_modified), processed_at = NOW()
      `, [file.name, file.size, lastModStr]);
    }

    // Ensure app_outbound_changes table exists
    await pool.query(`
      CREATE TABLE IF NOT EXISTS app_outbound_changes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        table_name VARCHAR(100),
        record_id VARCHAR(100),
        action_type VARCHAR(50),
        changed_columns TEXT,
        row_data TEXT,
        is_synced TINYINT(1) DEFAULT 0,
        synced_at DATETIME,
        created_at DATETIME
      )
    `);

    // Step 4 & 5: Sync local App Outbound changes to FTP Outbound & DB
    const [pendingOutbound] = await pool.query('SELECT * FROM app_outbound_changes WHERE is_synced = 0 ORDER BY id ASC LIMIT 500');
    if (pendingOutbound.length > 0) {
      console.log(`[FTP Sync] Processing ${pendingOutbound.length} pending app outbound changes...`);
      const syncedIds = [];

      for (const change of pendingOutbound) {
        const timestamp = Date.now();
        const baseFileName = `outbound_${change.table_name}_${change.action_type}_${change.record_id}_${timestamp}`;
        const parsedRowData = typeof change.row_data === 'string' ? JSON.parse(change.row_data || '{}') : (change.row_data || {});

        const fileNameXlsx = `${baseFileName}.xlsx`;
        const localXlsxPath = path.join(localOutboundDir, fileNameXlsx);
        const wb = xlsx.utils.book_new();
        const ws = xlsx.utils.json_to_sheet([parsedRowData]);
        xlsx.utils.book_append_sheet(wb, ws, 'Sheet1');
        const excelBuffer = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
        fs.writeFileSync(localXlsxPath, excelBuffer);

        const remotePath = `${FTP_OUTBOUND_DIR}/${fileNameXlsx}`;
        let xlsxUploaded = false;

        // Retry loop for FTP upload with remote size verification
        for (let attempt = 1; attempt <= 3; attempt++) {
          try {
            await client.uploadFrom(localXlsxPath, remotePath);
            
            // Remote verification: verify the file exists on remote FTP and size > 0
            const remoteSize = await client.size(remotePath).catch(() => 0);
            if (remoteSize > 0) {
              xlsxUploaded = true;
              console.log(`[FTP Sync Upload Verified] ${fileNameXlsx} (${remoteSize} bytes on remote FTP)`);
              break;
            }
          } catch (e) {
            console.warn(`[FTP Sync Attempt ${attempt}/3 Failed] Uploading ${fileNameXlsx}: ${e.message}`);
            if (attempt < 3) await new Promise(r => setTimeout(r, attempt * 1000));
          }
        }

        if (xlsxUploaded) {
          syncedIds.push(change.id);
        }
      }

      if (syncedIds.length > 0) {
        await pool.query('UPDATE app_outbound_changes SET is_synced = 1, synced_at = NOW() WHERE id IN (?)', [syncedIds]);
        console.log(`[FTP Sync] Marked ${syncedIds.length} app outbound records as synced in DB.`);
      }
    }

    console.log(`[FTP Sync] Synchronization process completed successfully.`);
  } catch (err) {
    console.error(`[FTP Sync Error] ${err.message}`);
  } finally {
    client.close();
  }
}

module.exports = {
  runFtpSync,
  importRowsToDatabase,
  detectTableFromHeaders
};
