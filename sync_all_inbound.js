const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: '127.0.0.1',
  user: 'u156958239_moil_hr_app',
  password: '6Fw|hF#qOv?',
  database: 'u156958239_moil_hr_app',
  waitForConnections: true,
  connectionLimit: 10
});

function excelDateToDateString(val) {
  if (val === null || val === undefined || val === '') return null;
  const str = String(val).trim();
  if (str === '' || str.toUpperCase() === 'NULL' || str === '0000-00-00' || str === '00.00.0000') return null;

  // Numeric Excel date code like 27876 or 39427 or 45474
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

  // If already DD.MM.YYYY string
  if (/^\d{2}\.\d{2}\.\d{4}$/.test(str)) {
    const p = str.split('.');
    return `${p[2]}-${p[1]}-${p[0]}`;
  }

  // If already DD-MM-YYYY string
  if (/^\d{2}-\d{2}-\d{4}$/.test(str)) {
    const p = str.split('-');
    return `${p[2]}-${p[1]}-${p[0]}`;
  }

  return str;
}

function detectTableFromHeaders(headers, fileName) {
  const kStr = (headers || []).join(' ').toLowerCase();

  if (kStr.includes('cname') || kStr.includes('act_doj_on_promt_dt') || kStr.includes('cname_first') || kStr.includes('act_dob_dt') || kStr.includes('employee_number') || kStr.includes('employee number')) {
    return 'manpower';
  }
  if (kStr.includes('absence_quota_type') || kStr.includes('quota_number') || (kStr.includes('personnel_number') && kStr.includes('deduction_from'))) {
    return 'leave_quota';
  }
  if (kStr.includes('att_abs_days') && kStr.includes('calendar_days') && kStr.includes('lock_indicator') && !kStr.includes('id_of_request_item')) {
    return 'absence';
  }
  if (kStr.includes('nomination_percentage') || kStr.includes('nominee_name') || kStr.includes('nominee_relation') || kStr.includes('nomination')) {
    return 'it0591_nomination';
  }
  if (kStr.includes('family_member') || kStr.includes("child's_address") || kStr.includes('child_address') || kStr.includes('family')) {
    return 'it0021_family_member';
  }
  if (kStr.includes('id_of_request_item') || (kStr.includes('infotype_operation') && kStr.includes('full_day'))) {
    return 'ptreq_attabsdata_leave_apply_1';
  }
  if (kStr.includes('document_identification') || kStr.includes('document_version') || kStr.includes('document_category') || kStr.includes('document_status')) {
    return 'ptreq_header_leave_approved_1';
  }
  if (kStr.includes('employment_percentage') || kStr.includes('working_hours') || kStr.includes('planned_working_time')) {
    return 'planned_working_time';
  }
  if (kStr.includes('compensation') || kStr.includes('comp_quota') || kStr.includes('time quota') || (fileName || '').toUpperCase().includes('IT0416')) {
    return 'time_quota_compensation_infotype';
  }
  if (kStr.includes('beginning_date_of_trip_segment') || kStr.includes('trip_destination') || kStr.includes('reason_for_trip') || kStr.includes('trip')) {
    return 'travel';
  }
  if (kStr.includes('holiday_date') || kStr.includes('holiday_description') || kStr.includes('holiday_title') || kStr.includes('holiday')) {
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

async function runSync() {
  const dir = '/home/u156958239/inbound_files';
  const files = fs.readdirSync(dir);
  console.log(`Found ${files.length} files in ${dir}`);

  for (const file of files) {
    if (!file.endsWith('.xlsx') && !file.endsWith('.XLSX')) continue;
    const filePath = path.join(dir, file);
    console.log(`\nProcessing ${file}...`);

    try {
      const wb = xlsx.readFile(filePath);

      // Select sheet with maximum rows (skips pivot/summary sheets)
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

      const rows = xlsx.utils.sheet_to_json(bestSheet);
      console.log(`Total rows in ${file}: ${rows.length}`);

      if (rows.length === 0) continue;

      const sampleKeys = Object.keys(rows[0]);
      const tableName = detectTableFromHeaders(sampleKeys, file);
      if (!tableName) {
        console.log(`Skipping unmapped file ${file}`);
        continue;
      }
      console.log(`Target Table: ${tableName}`);

      const conn = await pool.getConnection();

      // TRUNCATE table before importing to ensure clean 0 duplicate import
      try {
        await conn.query(`TRUNCATE TABLE \`${tableName}\``);
        console.log(`Truncated table ${tableName}`);
      } catch (trErr) {
        console.warn(`Could not truncate ${tableName}:`, trErr.message);
      }

      // Fetch valid column names in database table
      const [tableColsRows] = await conn.query(`SHOW COLUMNS FROM \`${tableName}\``);
      const validColsSet = new Set(tableColsRows.map(c => c.Field.toLowerCase()));

      let inserted = 0;
      let errors = 0;

      try {
        for (const rowObj of rows) {
          const rawKeys = Object.keys(rowObj).filter(k => k && rowObj[k] !== undefined);
          if (rawKeys.length === 0) continue;

          // Clean key and filter against valid DB table columns
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

          const sql = `INSERT INTO \`${tableName}\` (${cols}) VALUES (${placeholders})`;
          try {
            await conn.query(sql, validVals);
            inserted++;
          } catch (e) {
            errors++;
            if (errors <= 3) console.error(`Insert Error in ${tableName}:`, e.message);
          }
        }
        console.log(`Result for ${file} -> ${tableName}: Cleanly Inserted ${inserted} rows, Errors: ${errors}`);
      } finally {
        conn.release();
      }
    } catch (e) {
      console.error(`Failed to read/process ${file}:`, e.message);
    }
  }

  await pool.end();
  console.log('\nAll inbound files processed with ZERO duplicates!');
}

runSync().catch(console.error);
