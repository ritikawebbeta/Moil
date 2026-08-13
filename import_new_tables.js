const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');
const mysql = require('mysql2/promise');

const tmpDir = path.join(__dirname, 'tmp_ftp_scan');

function excelDateToDateString(val) {
  if (val === null || val === undefined || val === '') return null;
  const str = String(val).trim();
  if (str === '' || str.toUpperCase() === 'NULL' || str === '0000-00-00' || str === '00.00.0000') return null;

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

function cleanColName(name) {
  let c = name.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_').replace(/^_+|_+$/g, '');
  if (!c) c = 'col';
  if (/^\d/.test(c)) c = 'col_' + c;
  return c;
}

async function createAndImportNewTables() {
  const conn = await mysql.createConnection({
    host: '127.0.0.1', port: 3306,
    user: 'root', password: '',
    database: 'u156958239_moil_hr_app'
  });

  const targets = [
    { file: 'PTREQ_HEADER_Leave_Approved.XLSX', table: 'ptreq_header_leave_approved_1' },
    { file: 'PTREQ_ITEMS-Request Items.XLSX', table: 'ptreq_items' }
  ];

  for (const t of targets) {
    const filePath = path.join(tmpDir, t.file);
    if (!fs.existsSync(filePath)) {
      console.log(`Skipping ${t.file}: File not found in ${tmpDir}`);
      continue;
    }

    console.log(`\n==================================================`);
    console.log(`Processing ${t.file} -> Table '${t.table}'...`);
    console.log(`==================================================`);

    const wb = xlsx.readFile(filePath);
    let rows = [];
    for (const sName of wb.SheetNames) {
      const sRows = xlsx.utils.sheet_to_json(wb.Sheets[sName]);
      if (sRows.length > rows.length) rows = sRows;
    }

    if (rows.length === 0) {
      console.log(`No data rows in ${t.file}`);
      continue;
    }

    const rawHeaders = Object.keys(rows[0]);
    const colMap = {};
    const cleanCols = [];
    const usedColNames = new Set();

    for (const h of rawHeaders) {
      let c = cleanColName(h);
      let idx = 1;
      let originalC = c;
      while (usedColNames.has(c)) {
        c = `${originalC}_${idx++}`;
      }
      usedColNames.add(c);
      colMap[h] = c;
      cleanCols.push(c);
    }

    // 1. Create table dynamically if not exists
    console.log(`Creating table \`${t.table}\` with ${cleanCols.length} columns...`);
    await conn.query(`DROP TABLE IF EXISTS \`${t.table}\``);

    const colDefs = cleanCols.map((c) => `\`${c}\` TEXT`);

    const createSql = `CREATE TABLE \`${t.table}\` (
      \`row_id\` INT AUTO_INCREMENT PRIMARY KEY,
      ${colDefs.join(',\n      ')}
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;`;

    await conn.query(createSql);
    console.log(`Table \`${t.table}\` created successfully!`);

    // 2. Batch insert rows
    const colsSql = cleanCols.map(c => `\`${c}\``).join(', ');
    const placeholders = cleanCols.map(() => '?').join(', ');
    const insertSql = `INSERT INTO \`${t.table}\` (${colsSql}) VALUES (${placeholders})`;

    const BATCH_SIZE = 500;
    let inserted = 0;

    for (let i = 0; i < rows.length; i += BATCH_SIZE) {
      const chunk = rows.slice(i, i + BATCH_SIZE);
      for (const rowObj of chunk) {
        const vals = rawHeaders.map(h => {
          let val = rowObj[h];
          const cleanK = colMap[h];
          if (cleanK && (cleanK.includes('date') || cleanK.includes('dob') || cleanK.includes('dt'))) {
            val = excelDateToDateString(val);
          }
          return val !== undefined && val !== null ? String(val) : null;
        });
        await conn.query(insertSql, vals);
        inserted++;
      }
      console.log(`  Inserted ${inserted}/${rows.length} rows...`);
    }

    console.log(`✅ ${t.table}: Total ${inserted} rows imported.`);
  }

  await conn.end();
  console.log('\n==================================================');
  console.log('✅ ALL NEW TABLES CREATED AND DATA IMPORTED SUCCESSFULLY!');
  console.log('==================================================');
}

createAndImportNewTables().catch(err => console.error('Error:', err));
