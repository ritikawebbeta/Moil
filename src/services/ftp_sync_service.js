// src/services/ftp_sync_service.js
const fs = require('fs');
const path = require('path');
const ftp = require('basic-ftp');
const xlsx = require('xlsx');
const { pool } = require('../config/db');

// Local uploads paths acting as local FTP replacement on Hostinger
const UPLOADS_DIR = fs.existsSync('/home/u156958239/domains/acubeai.com/public_html/test/moil_hr_app/uploads')
  ? '/home/u156958239/domains/acubeai.com/public_html/test/moil_hr_app/uploads'
  : path.join(__dirname, '../../uploads');

const UPLOADS_INBOUND_DIR = path.join(UPLOADS_DIR, 'Inbound');
const UPLOADS_OUTBOUND_DIR = path.join(UPLOADS_DIR, 'Outbound');

// Formatting helper: formats database changes into the exact column layouts/names of the Inbound SAP files
function formatOutboundRow(change) {
  const cc = change.changed_columns ? (typeof change.changed_columns === 'string' ? JSON.parse(change.changed_columns || '{}') : change.changed_columns) : {};
  const rd = change.row_data ? (typeof change.row_data === 'string' ? JSON.parse(change.row_data || '{}') : change.row_data) : {};
  
  function dateToExcelSerial(dateStr) {
    if (!dateStr) return '';
    const parts = dateStr.split('.');
    if (parts.length === 3) {
      const d = new Date(parts[2], parts[1] - 1, parts[0]);
      return Math.floor((d - new Date(1899, 11, 30)) / 86400000);
    }
    const iso = new Date(dateStr);
    if (!isNaN(iso)) return Math.floor((iso - new Date(1899, 11, 30)) / 86400000);
    return dateStr;
  }

  const tableNameUpper = (change.table_name || '').toUpperCase();

  if (tableNameUpper === 'PTREQ_ATTABSDATA_LEAVE_APPLY' || tableNameUpper === 'PTREQ_ATTABSDATA_LEAVE_APPLY_1') {
    const startDate = cc.start_date || rd.start_date || '';
    const endDate   = cc.end_date   || rd.end_date   || '';
    const days      = parseFloat(cc.days_count || rd.att__abs__days || rd.calendar_days || '1');
    const hours     = days * 8.5;
    return {
      'ID of Request Item':       change.record_id,
      'Infotype operation':       change.action_type === 'INSERT' ? 'INS' : 'MOD',
      'Infotype':                 '2001',
      'Start time':               0,
      'End time':                 0,
      'Absence hours':            hours,
      'Personnel number':         cc.personnel_number || rd.personnel_number || '',
      'Sub Type':                 cc.sub_type         || rd.sub_type         || '1000',
      'Object ID':                '',
      'Lock indicator':           rd.lock_indicator   || 'P',
      'End Date':                 dateToExcelSerial(endDate),
      'Start Date':               dateToExcelSerial(startDate),
      'Infotype record no.':      '0',
      'Customer Field':           '',
      'Customer Field_1':         '',
      'Customer Field_2':         '',
      'Customer Field_3':         '',
      'Customer Field_4':         '',
      'Customer Field_5':         '',
      'Customer Field_6':         '',
      'Customer Field_7':         '',
      'Customer Field_8':         '',
      'Customer Field_9':         '',
      'Prev. day indicator':      '',
      'Att./abs. days':           days,
      'Calendar days':            days,
      'Set hours':                '',
      'Full-day':                 'X',
      'Payroll days':             days,
      'Payroll hours':            hours,
      'Desc. of illness':         '',
      'Desc. of illness_1':       '',
      'Days credited':            0,
      'End of continued pay':     '',
      'End of sick pay':          '',
      'Certified start':          '',
      'Confirmed on':             '',
      'Subs.sickness ind.':       0,
      'Ind. for repeated illness':0,
    };
  }
  
  if (tableNameUpper === 'PTREQ_HEADER_LEAVE_APPROVED' || tableNameUpper === 'PTREQ_HEADER_LEAVE_APPROVED_1') {
    const now = new Date();
    const excelTs = (now - new Date(1899, 11, 30)) / 86400000;
    const status  = cc.document_status || rd.document_status || 'SENT';
    const guid    = cc.document_identification || change.record_id || '';
    return {
      'Document Identification':    change.record_id,
      'Document Version':           1,
      'Document Category':          'ABSREQ',
      'Document Status':            status,
      'GUID':                       guid,
      'GUID_1':                     guid,
      'GUID_2':                     guid,
      'GUID_3':                     guid,
      'GUID_4':                     guid,
      'GUID_5':                     guid,
      'GUID_6':                     guid,
      'GUID_7':                     guid,
      'ID of Request Item List':    cc.req_item_list_id || rd.req_item_list_id || change.record_id,
      'Last Changed By':            cc.last_changed_by || rd.last_changed_by || '',
      'Time Stamp':                 excelTs,
      'Time Zone':                  'INDIA',
      'ID':                         cc.personnel_number || rd.personnel_number || cc.last_changed_by || '',
    };
  }

  if (tableNameUpper === 'TRAVEL') {
    return {
      'Personnel Number':           cc.personnel_number || rd.personnel_number || '',
      'Trip Number':                cc.trip_number      || rd.trip_number      || change.record_id,
      'Plan/Request Indicator':     rd.plan_request_indicator || 'R',
      'Trip Destination':           cc.trip_destination || rd.trip_destination || '',
      'Country Key':                rd.country_key      || 'IN',
      'Reason for Trip':            cc.reason_for_trip  || rd.reason_for_trip  || '',
      'Beginning Date':             dateToExcelSerial(cc.beginning_date_of_trip_segment || rd.beginning_date_of_trip_segment || ''),
      'End Date':                   dateToExcelSerial(cc.end_date_of_trip_segment       || rd.end_date_of_trip_segment       || ''),
      'Planning Status':            rd.planning_status  || '1',
      'Changed By':                 cc.changed_by       || rd.changed_by       || '',
      'Created By':                 rd.created_by       || '',
      'Approved By':                rd.approved_by      || '',
    };
  }

  // Fallback
  return rd;
}

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
 * Sync Employee Photos from FTP folders to DB & Local uploads
 */
async function syncPhotosFromFtp(client) {
  try {
    // Ensure employee_photos table exists
    await pool.query(`
      CREATE TABLE IF NOT EXISTS employee_photos (
        id INT AUTO_INCREMENT PRIMARY KEY,
        employee_number VARCHAR(50) UNIQUE,
        file_name VARCHAR(255),
        file_size BIGINT,
        photo_url VARCHAR(500),
        last_updated DATETIME
      )
    `);

    // Ensure photo target directories exist
    const localPhotoDir = path.join(__dirname, '../../uploads/profiles/Photo');
    const publicPhotoDir = '/home/u156958239/domains/acubeai.com/public_html/test/moil_hr_app/uploads/profiles/Photo';
    if (!fs.existsSync(localPhotoDir)) fs.mkdirSync(localPhotoDir, { recursive: true });
    if (!fs.existsSync(publicPhotoDir) && fs.existsSync('/home/u156958239/domains/acubeai.com/public_html/test/moil_hr_app/uploads')) {
      try { fs.mkdirSync(publicPhotoDir, { recursive: true }); } catch (_) {}
    }

    // Candidate FTP directories containing employee photos
    const photoFtpDirs = [
      '/HR_App/Inbound/Photo',
      '/HR_App/Inbound/Profiles',
      '/HR_App/Photo',
      '/HR_App/Inbound'
    ];

    for (const ftpDir of photoFtpDirs) {
      let files = [];
      try {
        files = await client.list(ftpDir);
      } catch (_) {
        continue;
      }

      for (const file of files) {
        if (file.isDirectory) continue;
        const ext = path.extname(file.name).toLowerCase();
        if (!['.jpg', '.jpeg', '.png'].includes(ext)) continue;

        console.log(`[FTP Photo Sync] Found photo on FTP (${ftpDir}): ${file.name} (${file.size} bytes)`);

        const remotePath = `${ftpDir}/${file.name}`;
        const localPath = path.join(localPhotoDir, file.name);

        try {
          await client.downloadTo(localPath, remotePath);

          // Copy to public web path if available
          if (fs.existsSync(path.dirname(publicPhotoDir))) {
            try {
              const publicPath = path.join(publicPhotoDir, file.name);
              fs.copyFileSync(localPath, publicPath);
            } catch (_) {}
          }

          // Parse employee ID from file name (e.g. 4428.jpg -> 4428, 00004428_self.png -> 4428)
          const cleanEmpNo = file.name.split('.')[0].split('_')[0].trim().replace(/^0+/, '');
          if (cleanEmpNo) {
            const photoUrl = `https://acubeai.com/test/moil_hr_app/api/profile-photo/${cleanEmpNo}`;
            await pool.query(`
              INSERT INTO employee_photos (employee_number, file_name, file_size, photo_url, last_updated)
              VALUES (?, ?, ?, ?, NOW())
              ON DUPLICATE KEY UPDATE file_name = VALUES(file_name), file_size = VALUES(file_size), photo_url = VALUES(photo_url), last_updated = NOW()
            `, [cleanEmpNo, file.name, file.size, photoUrl]);

            // Also attempt to update manpower table if photo_url column exists
            try {
              await pool.query('UPDATE manpower SET photo_url = ? WHERE employee_number = ? OR CAST(employee_number AS UNSIGNED) = CAST(? AS UNSIGNED)', [photoUrl, cleanEmpNo, cleanEmpNo]);
            } catch (_) {}
          }
        } catch (e) {
          console.warn(`[FTP Photo Sync] Failed to download photo ${file.name}: ${e.message}`);
        }
      }
    }
  } catch (err) {
    console.warn(`[FTP Photo Sync Warn] ${err.message}`);
  }
}

/**
 * Utility: Map MySQL table name to clean outbound filename (case-insensitive)
 */
function getOutboundFileName(tableName) {
  const upper = (tableName || '').toUpperCase();
  if (upper === 'PTREQ_ATTABSDATA_LEAVE_APPLY' || upper === 'PTREQ_ATTABSDATA_LEAVE_APPLY_1') {
    return 'PTREQ_ATTABSDATA_Leave_Apply.csv';
  }
  if (upper === 'PTREQ_HEADER_LEAVE_APPROVED' || upper === 'PTREQ_HEADER_LEAVE_APPROVED_1') {
    return 'PTREQ_HEADER_Leave_Approved.csv';
  }
  if (upper === 'TRAVEL') {
    return "Travel From April'26 to till date.csv";
  }
  return `${upper}.csv`;
}

/**
 * Core FTP Sync Runner
 */
async function runFtpSync() {
  console.log(`\n[Local Upload Sync] Starting synchronization process... [${new Date().toISOString()}]`);
  
  if (!fs.existsSync(UPLOADS_INBOUND_DIR)) fs.mkdirSync(UPLOADS_INBOUND_DIR, { recursive: true });
  if (!fs.existsSync(UPLOADS_OUTBOUND_DIR)) fs.mkdirSync(UPLOADS_OUTBOUND_DIR, { recursive: true });

  try {
    // Step 0: Sync Photos from Inbound/Photo if they exist
    const localPhotoDir = path.join(__dirname, '../../uploads/profiles/Photo');
    const publicPhotoDir = path.join(UPLOADS_DIR, 'profiles/Photo');
    if (!fs.existsSync(localPhotoDir)) fs.mkdirSync(localPhotoDir, { recursive: true });
    if (!fs.existsSync(publicPhotoDir)) {
      try { fs.mkdirSync(publicPhotoDir, { recursive: true }); } catch (_) {}
    }

    const sourcePhotoDir = path.join(UPLOADS_INBOUND_DIR, 'Photo');
    if (fs.existsSync(sourcePhotoDir)) {
      const photos = fs.readdirSync(sourcePhotoDir);
      for (const photo of photos) {
        const ext = path.extname(photo).toLowerCase();
        if (!['.jpg', '.jpeg', '.png'].includes(ext)) continue;
        const srcPath = path.join(sourcePhotoDir, photo);
        const destPath = path.join(localPhotoDir, photo);
        const publicPath = path.join(publicPhotoDir, photo);
        try {
          fs.copyFileSync(srcPath, destPath);
          fs.copyFileSync(srcPath, publicPath);

          const cleanEmpNo = photo.split('.')[0].split('_')[0].trim().replace(/^0+/, '');
          if (cleanEmpNo) {
            const photoUrl = `https://acubeai.com/test/moil_hr_app/api/profile-photo/${cleanEmpNo}`;
            await pool.query(`
              INSERT INTO employee_photos (employee_number, file_name, file_size, photo_url, last_updated)
              VALUES (?, ?, ?, ?, NOW())
              ON DUPLICATE KEY UPDATE file_name = VALUES(file_name), file_size = VALUES(file_size), photo_url = VALUES(photo_url), last_updated = NOW()
            `, [cleanEmpNo, photo, fs.statSync(srcPath).size, photoUrl]);

            try {
              await pool.query('UPDATE manpower SET photo_url = ? WHERE employee_number = ? OR CAST(employee_number AS UNSIGNED) = CAST(? AS UNSIGNED)', [photoUrl, cleanEmpNo, cleanEmpNo]);
            } catch (_) {}
          }
        } catch (photoErr) {
          console.warn(`[Photo Sync Error] ${photoErr.message}`);
        }
      }
    }

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

    // Step 1: List files in local Inbound directory
    const inboundFiles = fs.readdirSync(UPLOADS_INBOUND_DIR);
    for (const filename of inboundFiles) {
      const fullInboundPath = path.join(UPLOADS_INBOUND_DIR, filename);
      const stat = fs.statSync(fullInboundPath);
      if (stat.isDirectory()) continue;

      const lastModStr = stat.mtime.toISOString();

      // Check if file is already processed and unchanged
      const [regRows] = await pool.query(
        'SELECT * FROM inbound_sync_registry WHERE file_name = ? AND file_size = ? AND last_modified = ?',
        [filename, stat.size, lastModStr]
      );

      if (regRows.length > 0) {
        continue;
      }

      console.log(`[Upload Sync] Processing updated inbound file: ${filename} (${stat.size} bytes)`);

      // Step 2: Store copy of Inbound file to Outbound folder
      const destOutboundPath = path.join(UPLOADS_OUTBOUND_DIR, filename);
      console.log(`[Upload Sync] Storing copy of ${filename} to Outbound folder...`);
      try {
        fs.copyFileSync(fullInboundPath, destOutboundPath);
      } catch (cpErr) {
        console.warn(`[Upload Sync Copy Error] ${cpErr.message}`);
      }

      // Step 3: Import parsed data from Inbound into Database
      const rows = parseDataFile(fullInboundPath);
      if (rows.length > 0) {
        const sampleKeys = Object.keys(rows[0]);
        const tableName = detectTableFromHeaders(sampleKeys, filename);
        if (tableName) {
          await importRowsToDatabase(tableName, rows, filename);
        } else {
          console.log(`[Upload Sync] Skipping unmapped file: ${filename}`);
        }
      }

      // Update registry
      await pool.query(`
        INSERT INTO inbound_sync_registry (file_name, file_size, last_modified, processed_at)
        VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE file_size = VALUES(file_size), last_modified = VALUES(last_modified), processed_at = NOW()
      `, [filename, stat.size, lastModStr]);
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

    // Step 4 & 5: Sync local App Outbound changes to Outbound & DB
    const [pendingOutbound] = await pool.query('SELECT * FROM app_outbound_changes WHERE is_synced = 0 ORDER BY id ASC LIMIT 500');
    if (pendingOutbound.length > 0) {
      console.log(`[Upload Sync] Processing ${pendingOutbound.length} pending app outbound changes...`);
      const syncedIds = [];

      // Group changes by their target file name
      const groups = {};
      for (const change of pendingOutbound) {
        const fileName = getOutboundFileName(change.table_name);
        if (!groups[fileName]) {
          groups[fileName] = {
            fileName,
            changes: []
          };
        }
        groups[fileName].changes.push(change);
      }

      // Process each file group
      for (const group of Object.values(groups)) {
        const destOutboundPath = path.join(UPLOADS_OUTBOUND_DIR, group.fileName);
        
        try {
          let existingRows = [];
          if (fs.existsSync(destOutboundPath)) {
            try {
              const wb = xlsx.readFile(destOutboundPath);
              const ws = wb.Sheets[wb.SheetNames[0]];
              existingRows = xlsx.utils.sheet_to_json(ws, { defval: "" });
            } catch (readErr) {
              console.warn(`[Upload Sync] Failed to read existing outbound file ${group.fileName}, starting fresh:`, readErr.message);
            }
          }

          // Format and append all changes for this file
          for (const change of group.changes) {
            const formattedDataObj = formatOutboundRow(change);
            existingRows.push(formattedDataObj);
            syncedIds.push(change.id);
          }

          // Write all rows back to the file
          const ws = xlsx.utils.json_to_sheet(existingRows);
          const csvContent = xlsx.utils.sheet_to_csv(ws);
          fs.writeFileSync(destOutboundPath, csvContent, 'utf8');
          console.log(`[Upload Sync] Appended ${group.changes.length} rows to outbound: ${group.fileName}`);
        } catch (err) {
          console.error(`[Upload Sync Group File Error] Failed to write to ${group.fileName}: ${err.message}`);
        }
      }

      if (syncedIds.length > 0) {
        await pool.query('UPDATE app_outbound_changes SET is_synced = 1, synced_at = NOW() WHERE id IN (?)', [syncedIds]);
        console.log(`[Upload Sync] Marked ${syncedIds.length} app outbound records as synced in DB.`);
      }
    }

    console.log(`[Upload Sync] Synchronization process completed successfully.`);
  } catch (err) {
    console.error(`[Upload Sync Error] ${err.message}`);
  }

  /*
  // ─── ORIGINAL FTP SYNC LOGIC (COMMENTED OUT FOR FUTURE LAN REVERT) ───
  //
  // const client = new ftp.Client();
  // client.ftp.verbose = false;
  // try {
  //   await client.access({
  //     host: FTP_HOST,
  //     port: FTP_PORT,
  //     user: FTP_USER,
  //     password: FTP_PASS,
  //     secure: false
  //   });
  //   await syncPhotosFromFtp(client);
  //   let inboundFiles = await client.list(FTP_INBOUND_DIR);
  //   for (const file of inboundFiles) {
  //     if (file.isDirectory) continue;
  //     const lastModStr = file.modifiedAt ? file.modifiedAt.toISOString() : (file.rawModifiedAt || '');
  //     const [regRows] = await pool.query('SELECT * FROM inbound_sync_registry WHERE file_name = ? AND file_size = ? AND last_modified = ?', [file.name, file.size, lastModStr]);
  //     if (regRows.length > 0) continue;
  //     const localFilePath = path.join(localInboundDir, file.name);
  //     await client.downloadTo(localFilePath, `${FTP_INBOUND_DIR}/${file.name}`);
  //     await client.uploadFrom(localFilePath, `${FTP_OUTBOUND_DIR}/${file.name}`);
  //     const rows = parseDataFile(localFilePath);
  //     if (rows.length > 0) {
  //       const sampleKeys = Object.keys(rows[0]);
  //       const tableName = detectTableFromHeaders(sampleKeys, file.name);
  //       if (tableName) await importRowsToDatabase(tableName, rows, file.name);
  //     }
  //     await pool.query('INSERT INTO inbound_sync_registry (file_name, file_size, last_modified, processed_at) VALUES (?, ?, ?, NOW()) ON DUPLICATE KEY UPDATE file_size = VALUES(file_size), last_modified = VALUES(last_modified), processed_at = NOW()', [file.name, file.size, lastModStr]);
  //   }
  //   const [pendingOutbound] = await pool.query('SELECT * FROM app_outbound_changes WHERE is_synced = 0 ORDER BY id ASC LIMIT 500');
  //   if (pendingOutbound.length > 0) {
  //     const syncedIds = [];
  //     for (const change of pendingOutbound) {
  //       const baseFileName = `outbound_${change.table_name}_${change.action_type}_${change.record_id}_${Date.now()}`;
  //       const formattedDataObj = formatOutboundRow(change);
  //       const fileNameXlsx = `${baseFileName}.xlsx`;
  //       const localXlsxPath = path.join(localOutboundDir, fileNameXlsx);
  //       const wb = xlsx.utils.book_new();
  //       const ws = xlsx.utils.json_to_sheet([formattedDataObj]);
  //       xlsx.utils.book_append_sheet(wb, ws, 'Sheet1');
  //       fs.writeFileSync(localXlsxPath, xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' }));
  //       await client.uploadFrom(localXlsxPath, `${FTP_OUTBOUND_DIR}/${fileNameXlsx}`);
  //       syncedIds.push(change.id);
  //     }
  //     if (syncedIds.length > 0) await pool.query('UPDATE app_outbound_changes SET is_synced = 1, synced_at = NOW() WHERE id IN (?)', [syncedIds]);
  //   }
  // } catch (err) {
  //   console.error(`[FTP Sync Error] ${err.message}`);
  // } finally {
  //   client.close();
  // }
  */
}

module.exports = {
  runFtpSync,
  importRowsToDatabase,
  detectTableFromHeaders
};
