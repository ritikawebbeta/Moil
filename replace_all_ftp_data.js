const ftp = require('basic-ftp');
const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');
const mysql = require('mysql2/promise');

const FTP_HOST = process.env.FTP_HOST || '172.16.1.51';
const FTP_PORT = parseInt(process.env.FTP_PORT || '21', 10);
const FTP_USER = process.env.FTP_USER || 'ftpuser2';
const FTP_PASS = process.env.FTP_PASSWORD || 'Ftppo16$';
const FTP_INBOUND_DIR = '/HR_App/Inbound';

const tmpDir = path.join(__dirname, 'tmp_ftp_full_sync');
if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir, { recursive: true });

function isExplicitDateColumn(colName) {
  const c = colName.toLowerCase();
  if (c.includes('type') || c.includes('by') || c.includes('id') || c.includes('number') || c.includes('amount') || c.includes('count') || c.includes('code') || c.includes('rule')) {
    return false;
  }
  return c.includes('date') || c.includes('dob') || c === 'changed_on' || c.endsWith('_dt') || c.includes('doj') || c.includes('dosl') || c.includes('dopp');
}

function excelDateToDateString(val) {
  if (val === null || val === undefined || val === '') return null;
  const str = String(val).trim();
  if (str === '' || str.toUpperCase() === 'NULL' || str === '0000-00-00' || str === '00.00.0000') return null;

  // Only convert numbers if they are valid Excel serial dates between 1950 and 2100 (Serial 18264 to 73050)
  if (/^\d{4,5}(\.\d+)?$/.test(str)) {
    const num = parseFloat(str);
    if (num >= 18264 && num <= 73050) { // 18264 = 1950-01-01, 73050 = 2099-12-31
      const d = new Date(Math.round((num - 25569) * 86400 * 1000));
      if (!isNaN(d.getTime())) {
        const yyyy = d.getUTCFullYear();
        if (yyyy >= 1950 && yyyy <= 2100) {
          const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
          const dd = String(d.getUTCDate()).padStart(2, '0');
          return `${yyyy}-${mm}-${dd}`;
        }
      }
    }
  }
  if (/^\d{2}\.\d{2}\.\d{4}$/.test(str)) {
    const p = str.split('.');
    return `${p[2]}-${p[1]}-${p[0]}`;
  }
  if (/^\d{2}-\d{2}-\d{4}$/.test(str)) {
    const p = str.split('-');
    return `${p[2]}-${p[1]}-${p[0]}`;
  }
  return str;
}

function detectTableFromFileName(fileName, headers) {
  const kStr = (headers || []).join(' ').toLowerCase();
  const fnUpper = (fileName || '').toUpperCase();

  if (fnUpper.includes('MANPOWER')) return 'manpower';
  if (fnUpper.includes('LEAVE_QUOTA')) return 'leave_quota';
  if (fnUpper.includes('ABSENCE') && !fnUpper.includes('PTREQ')) return 'absence';
  if (fnUpper.includes('NOMINATION')) return 'it0591_nomination';
  if (fnUpper.includes('FAMILY')) return 'it0021_family_member';
  if (fnUpper.includes('LEAVE_APPLY') || fnUpper.includes('ATTABSDATA')) return 'ptreq_attabsdata_leave_apply_1';
  if (fnUpper.includes('LEAVE_APPROVED') || fnUpper.includes('PTREQ_HEADER')) return 'ptreq_header_leave_approved_1';
  if (fnUpper.includes('REQUEST ITEMS') || fnUpper.includes('PTREQ_ITEMS')) return 'ptreq_items';
  if (fnUpper.includes('HOLIDAY')) return 'zhcm_opt_holiday';
  if (fnUpper.includes('AGENTS') || fnUpper.includes('APPROVERS')) return 'zhcm_lr_t_agents_03072026';
  if (fnUpper.includes('PLANNED')) return 'planned_working_time';
  if (fnUpper.includes('TRAVEL') || fnUpper.includes('FTPT_REQ')) return 'travel';
  if (fnUpper.includes('COMPENSATION') || fnUpper.includes('IT0416')) return 'time_quota_compensation_infotype';

  if (kStr.includes('cname') || kStr.includes('act_doj_on_promt_dt')) return 'manpower';
  if (kStr.includes('absence_quota_type') || kStr.includes('quota_number')) return 'leave_quota';

  return null;
}

function mapExcelHeaderToTableColumn(excelHeader, tableColsSet, tableColsArray) {
  const raw = String(excelHeader).trim();
  const lower = raw.toLowerCase();

  if (tableColsSet.has(raw)) return raw;
  if (tableColsSet.has(lower)) return lower;

  if (lower.includes('att') && lower.includes('abs') && lower.includes('day')) {
    if (tableColsSet.has('att__abs__days')) return 'att__abs__days';
  }
  if (lower.includes('prev') && lower.includes('day') && lower.includes('indicator')) {
    if (tableColsSet.has('prev__day_indicator')) return 'prev__day_indicator';
  }
  if (lower.includes('desc') && lower.includes('illness')) {
    if (lower.endsWith('1') && tableColsSet.has('desc__of_illness_1')) return 'desc__of_illness_1';
    if (tableColsSet.has('desc__of_illness')) return 'desc__of_illness';
  }
  if (lower.includes('ind') && lower.includes('repeated') && lower.includes('illness')) {
    if (tableColsSet.has('ind__for_repeated_illness')) return 'ind__for_repeated_illness';
  }
  if (lower.includes('cost') && lower.includes('assign')) {
    if (tableColsSet.has('reference_fields_exist__cost_assign')) return 'reference_fields_exist__cost_assign';
  }
  if (lower.includes('conf') && lower.includes('fields') && lower.includes('exist')) {
    if (tableColsSet.has('conf__fields_exist')) return 'conf__fields_exist';
  }

  const norm = lower.replace(/[^a-z0-9_]/g, '_').replace(/^_+|_+$/g, '').replace(/__+/g, '_');
  for (const col of tableColsArray) {
    const colNorm = col.toLowerCase().replace(/__+/g, '_');
    if (norm === colNorm) return col;
  }

  return null;
}

async function runFullFtpDataReplacement() {
  console.log('🚀 Step 1: Connecting to FTP to download all 14 latest inbound files...');
  const client = new ftp.Client(30000);
  client.ftp.verbose = false;

  await client.access({
    host: FTP_HOST, port: FTP_PORT,
    user: FTP_USER, password: FTP_PASS, secure: false
  });
  console.log('✅ Connected to FTP successfully!');

  const inboundFiles = await client.list(FTP_INBOUND_DIR);
  console.log(`Found ${inboundFiles.length} files in ${FTP_INBOUND_DIR}.\n`);

  for (const file of inboundFiles) {
    if (file.isDirectory) continue;
    const localPath = path.join(tmpDir, file.name);
    console.log(`📥 Downloading: ${file.name} (${file.size} bytes)...`);
    try {
      await client.downloadTo(localPath, `${FTP_INBOUND_DIR}/${file.name}`);
    } catch (e) {
      console.log(`❌ Error downloading ${file.name}: ${e.message}`);
    }
  }
  client.close();

  console.log('\n🚀 Step 2: Connecting to MySQL database...');
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || '127.0.0.1',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'u156958239_moil_hr_app'
  });
  console.log('✅ Connected to MySQL DB.\n');

  const files = fs.readdirSync(tmpDir).filter(f => f.endsWith('.XLSX') || f.endsWith('.xlsx') || f.endsWith('.csv') || f.endsWith('.json'));
  const summary = [];

  for (const fname of files) {
    const fpath = path.join(tmpDir, fname);
    const stat = fs.statSync(fpath);
    if (stat.size === 0) continue;

    let rows = [];
    try {
      const wb = xlsx.readFile(fpath);
      for (const sName of wb.SheetNames) {
        const sheetRows = xlsx.utils.sheet_to_json(wb.Sheets[sName]);
        if (sheetRows.length > rows.length) rows = sheetRows;
      }
    } catch (e) {
      console.log(`❌ Error parsing spreadsheet ${fname}: ${e.message}`);
      continue;
    }

    if (rows.length === 0) continue;

    const rawHeaders = Object.keys(rows[0]);
    const targetTable = detectTableFromFileName(fname, rawHeaders);
    if (!targetTable) continue;

    let tableColsArray = [];
    try {
      const [colRows] = await conn.query(`SHOW COLUMNS FROM \`${targetTable}\``);
      tableColsArray = colRows.map(c => c.Field);
    } catch (e) {}

    const tableColsSet = new Set(tableColsArray);
    const headerToColMap = {};
    const validTargetCols = [];

    for (const h of rawHeaders) {
      const matchedCol = mapExcelHeaderToTableColumn(h, tableColsSet, tableColsArray);
      if (matchedCol) {
        headerToColMap[h] = matchedCol;
        if (!validTargetCols.includes(matchedCol)) {
          validTargetCols.push(matchedCol);
        }
      }
    }

    console.log(`==================================================`);
    console.log(`Replacing table '${targetTable}' data with fresh rows from '${fname}' (${rows.length} rows, ${validTargetCols.length} columns)... `);
    console.log(`==================================================`);

    try {
      await conn.query(`TRUNCATE TABLE \`${targetTable}\``);
    } catch (e) {
      await conn.query(`DELETE FROM \`${targetTable}\``);
    }

    const colsSql = validTargetCols.map(c => `\`${c}\``).join(', ');
    const BATCH_SIZE = 300;
    let inserted = 0;

    for (let i = 0; i < rows.length; i += BATCH_SIZE) {
      const chunk = rows.slice(i, i + BATCH_SIZE);
      const valueTuples = [];
      const flatParams = [];

      for (const rowObj of chunk) {
        const rowVals = validTargetCols.map(colName => {
          const rawH = rawHeaders.find(h => headerToColMap[h] === colName);
          let val = rawH ? rowObj[rawH] : null;

          if (val !== undefined && val !== null && isExplicitDateColumn(colName)) {
            val = excelDateToDateString(val);
          }
          return val !== undefined && val !== null ? String(val) : null;
        });

        flatParams.push(...rowVals);
        valueTuples.push(`(${validTargetCols.map(() => '?').join(', ')})`);
      }

      const bulkInsertSql = `INSERT INTO \`${targetTable}\` (${colsSql}) VALUES ${valueTuples.join(', ')}`;
      await conn.query(bulkInsertSql, flatParams);
      inserted += chunk.length;
    }

    console.log(`✅ Table '${targetTable}' replaced with ${inserted} fresh rows into exact columns.\n`);
    summary.push({ file: fname, table: targetTable, rows: inserted, cols: validTargetCols.length });
  }

  await conn.end();

  console.log('==================================================');
  console.log('🎉 EXACT DATA REPLACEMENT COMPLETE! SUMMARY REPORT:');
  console.log('==================================================');
  summary.forEach((s, i) => {
    console.log(`${(i + 1).toString().padStart(2)}. Table: ${s.table.padEnd(35)} | Rows: ${s.rows.toString().padStart(7)} | Columns: ${s.cols} (Source: ${s.file})`);
  });
}

runFullFtpDataReplacement().catch(err => console.error('Data Replacement Error:', err));
