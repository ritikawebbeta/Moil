const ftp = require('basic-ftp');
const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');

const FTP_HOST = '172.16.1.51';
const FTP_PORT = 21;
const FTP_USER = 'ftpuser2';
const FTP_PASS = '';
const FTP_INBOUND_DIR = '/HR_App/Inbound';
const FTP_OUTBOUND_DIR = '/HR_App/Outbound';

const tmpDir = path.join(__dirname, 'tmp_ftp_scan');
if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir, { recursive: true });

async function run() {
  const client = new ftp.Client();
  client.ftp.verbose = false;

  try {
    await client.access({
      host: FTP_HOST,
      port: FTP_PORT,
      user: FTP_USER,
      password: FTP_PASS,
      secure: false
    });
    console.log(`Connected to FTP ${FTP_HOST}:${FTP_PORT}\n`);

    // List Inbound files
    console.log('='.repeat(80));
    console.log('INBOUND FILES (/HR_App/Inbound)');
    console.log('='.repeat(80));
    
    let inboundFiles = [];
    try {
      inboundFiles = await client.list(FTP_INBOUND_DIR);
    } catch (e) {
      console.log('Could not list Inbound:', e.message);
    }

    if (inboundFiles.length === 0) {
      console.log('  (empty - no files)\n');
    }

    for (const file of inboundFiles) {
      if (file.isDirectory) {
        console.log(`  [DIR] ${file.name}`);
        continue;
      }
      
      console.log(`\n--- FILE: ${file.name} ---`);
      console.log(`  Size: ${file.size} bytes | Modified: ${file.modifiedAt || file.rawModifiedAt}`);
      
      // Download and parse to get columns
      const localPath = path.join(tmpDir, file.name);
      try {
        await client.downloadTo(localPath, `${FTP_INBOUND_DIR}/${file.name}`);
        
        const ext = path.extname(file.name).toLowerCase();
        let rows = [];
        
        if (ext === '.json') {
          const raw = fs.readFileSync(localPath, 'utf8');
          const parsed = JSON.parse(raw);
          rows = Array.isArray(parsed) ? parsed : [parsed];
        } else if (['.xlsx', '.xls', '.csv'].includes(ext)) {
          const wb = xlsx.readFile(localPath);
          for (const sName of wb.SheetNames) {
            const s = wb.Sheets[sName];
            const sheetRows = xlsx.utils.sheet_to_json(s);
            console.log(`  Sheet: "${sName}" | Rows: ${sheetRows.length}`);
            if (sheetRows.length > rows.length) rows = sheetRows;
          }
        }

        if (rows.length > 0) {
          const columns = Object.keys(rows[0]);
          console.log(`  Total Rows: ${rows.length}`);
          console.log(`  Total Columns: ${columns.length}`);
          console.log(`  Columns:`);
          columns.forEach((col, i) => {
            const sampleVal = rows[0][col];
            console.log(`    ${(i + 1).toString().padStart(3)}. ${col} (sample: ${JSON.stringify(sampleVal).substring(0, 50)})`);
          });
        } else {
          console.log(`  (no data rows)`);
        }
      } catch (e) {
        console.log(`  Error parsing: ${e.message}`);
      }
    }

    // List Outbound files
    console.log('\n' + '='.repeat(80));
    console.log('OUTBOUND FILES (/HR_App/Outbound)');
    console.log('='.repeat(80));
    
    let outboundFiles = [];
    try {
      outboundFiles = await client.list(FTP_OUTBOUND_DIR);
    } catch (e) {
      console.log('Could not list Outbound:', e.message);
    }

    if (outboundFiles.length === 0) {
      console.log('  (empty - no files)\n');
    }

    for (const file of outboundFiles) {
      if (file.isDirectory) {
        console.log(`  [DIR] ${file.name}`);
        continue;
      }
      
      console.log(`\n--- FILE: ${file.name} ---`);
      console.log(`  Size: ${file.size} bytes | Modified: ${file.modifiedAt || file.rawModifiedAt}`);

      const localPath = path.join(tmpDir, 'out_' + file.name);
      try {
        await client.downloadTo(localPath, `${FTP_OUTBOUND_DIR}/${file.name}`);
        
        const ext = path.extname(file.name).toLowerCase();
        let rows = [];

        if (ext === '.json') {
          const raw = fs.readFileSync(localPath, 'utf8');
          const parsed = JSON.parse(raw);
          rows = Array.isArray(parsed) ? parsed : [parsed];
        } else if (['.xlsx', '.xls', '.csv'].includes(ext)) {
          const wb = xlsx.readFile(localPath);
          for (const sName of wb.SheetNames) {
            const s = wb.Sheets[sName];
            const sheetRows = xlsx.utils.sheet_to_json(s);
            console.log(`  Sheet: "${sName}" | Rows: ${sheetRows.length}`);
            if (sheetRows.length > rows.length) rows = sheetRows;
          }
        }

        if (rows.length > 0) {
          const columns = Object.keys(rows[0]);
          console.log(`  Total Rows: ${rows.length}`);
          console.log(`  Total Columns: ${columns.length}`);
          console.log(`  Columns:`);
          columns.forEach((col, i) => {
            const sampleVal = rows[0][col];
            console.log(`    ${(i + 1).toString().padStart(3)}. ${col} (sample: ${JSON.stringify(sampleVal).substring(0, 50)})`);
          });
        } else {
          console.log(`  (no data rows)`);
        }
      } catch (e) {
        console.log(`  Error parsing: ${e.message}`);
      }
    }

    // Also list root directories
    console.log('\n' + '='.repeat(80));
    console.log('ROOT DIRECTORIES');
    console.log('='.repeat(80));
    try {
      const rootFiles = await client.list('/HR_App');
      for (const f of rootFiles) {
        console.log(`  ${f.isDirectory ? '[DIR]' : '[FILE]'} ${f.name} (${f.size} bytes)`);
      }
    } catch (e) {
      console.log('Could not list /HR_App:', e.message);
    }

  } catch (err) {
    console.error('FTP Error:', err.message);
  } finally {
    client.close();
  }
}

run();
