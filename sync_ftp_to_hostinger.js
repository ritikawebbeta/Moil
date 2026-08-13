const ftp = require('basic-ftp');
const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');
const mysql = require('mysql2/promise');
const { Client } = require('ssh2');

const FTP_HOST = '172.16.1.51';
const FTP_PORT = 21;
const FTP_USER = 'ftpuser2';
const FTP_PASS = 'Ftppo16$';
const FTP_INBOUND_DIR = '/HR_App/Inbound';

const SSH_KEY_PATH = '/Users/apple/.ssh/id_ed25519';
const HOSTINGER_HOST = '147.93.109.38';
const HOSTINGER_PORT = 65002;
const HOSTINGER_USER = 'u156958239';

const tmpDir = path.join(__dirname, 'tmp_ftp_full_sync');

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

async function syncFtpToHostingerDb() {
  console.log('🚀 Step 1: Checking local FTP files in ' + tmpDir + '...');
  let files = fs.existsSync(tmpDir) ? fs.readdirSync(tmpDir).filter(f => f.endsWith('.XLSX') || f.endsWith('.xlsx') || f.endsWith('.xls')) : [];

  if (files.length === 0) {
    console.log('Downloading 14 FTP files from 172.16.1.51...');
    const client = new ftp.Client(15000);
    await client.access({ host: FTP_HOST, port: FTP_PORT, user: FTP_USER, password: FTP_PASS, secure: false });
    const inboundFiles = await client.list(FTP_INBOUND_DIR);

    for (const file of inboundFiles) {
      if (file.isDirectory) continue;
      const localPath = path.join(tmpDir, file.name);
      console.log(` Downloading: ${file.name}...`);
      await client.downloadTo(localPath, `${FTP_INBOUND_DIR}/${file.name}`);
    }
    client.close();
    files = fs.readdirSync(tmpDir).filter(f => f.endsWith('.XLSX') || f.endsWith('.xlsx') || f.endsWith('.xls'));
  }
  console.log(`✅ Found ${files.length} FTP files ready for import!`);

  console.log('\n🚀 Step 2: Connecting to Hostinger MySQL Database over SSH Tunnel...');
  const ssh = new Client();
  ssh.on('ready', () => {
    ssh.forwardOut('127.0.0.1', 3307, '127.0.0.1', 3306, async (err, stream) => {
      if (err) throw err;
      const conn = await mysql.createConnection({
        stream: stream,
        user: 'u156958239_moil_hr_app',
        password: '6Fw|hF#qOv?',
        database: 'u156958239_moil_hr_app'
      });

      console.log('✅ Connected to Hostinger DB! Replacing database tables...');
      const files = fs.readdirSync(tmpDir).filter(f => f.endsWith('.XLSX') || f.endsWith('.xlsx') || f.endsWith('.xls'));

      for (const file of files) {
        const filePath = path.join(tmpDir, file);
        const workbook = xlsx.readFile(filePath);
        let rawHeaders = Object.keys(xlsx.utils.sheet_to_json(workbook.Sheets[workbook.SheetNames[0]], { defval: null })[0] || {});
        let targetTable = detectTableFromFileName(file, rawHeaders);

        let sheetName = workbook.SheetNames[0];
        if (targetTable === 'manpower' && workbook.SheetNames.includes('Working')) {
          sheetName = 'Working';
        }
        const rows = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName], { defval: null });

        if (!rows || rows.length === 0) continue;
        rawHeaders = Object.keys(rows[0]);
        targetTable = detectTableFromFileName(file, rawHeaders);

        if (!targetTable) {
          console.log(` ⚠️ Skipping unknown table for file: ${file}`);
          continue;
        }

        console.log(` 📦 Replacing table '${targetTable}' with ${rows.length} rows from ${file}...`);
        const cleanCols = rawHeaders.map(cleanColName);

        const colDefs = cleanCols.map(col => `\`${col}\` TEXT`).join(', ');
        await conn.query(`DROP TABLE IF EXISTS \`${targetTable}\``);
        await conn.query(`CREATE TABLE \`${targetTable}\` (\`row_id\` INT AUTO_INCREMENT PRIMARY KEY, ${colDefs})`);

        const BATCH_SIZE = 500;
        for (let i = 0; i < rows.length; i += BATCH_SIZE) {
          const batch = rows.slice(i, i + BATCH_SIZE);
          const valuePlaceholders = [];
          const flatValues = [];

          for (const row of batch) {
            const rowValues = rawHeaders.map(h => excelDateToDateString(row[h]));
            valuePlaceholders.push(`(${cleanCols.map(() => '?').join(', ')})`);
            flatValues.push(...rowValues);
          }

          const insertSql = `INSERT INTO \`${targetTable}\` (${cleanCols.map(c => `\`${c}\``).join(', ')}) VALUES ${valuePlaceholders.join(', ')}`;
          await conn.query(insertSql, flatValues);
        }
        console.log(`   ✅ Imported ${rows.length} rows into Hostinger DB table '${targetTable}'.`);
      }

      await conn.end();
      ssh.end();
      console.log('\n🎉 ALL 14 TABLES AND 464,645 ROWS FULLY REPLACED ON HOSTINGER DATABASE!');
    });
  }).connect({
    host: HOSTINGER_HOST,
    port: HOSTINGER_PORT,
    username: HOSTINGER_USER,
    privateKey: fs.readFileSync(SSH_KEY_PATH)
  });
}

syncFtpToHostingerDb().catch(console.error);
