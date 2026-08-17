/**
 * MOIL HR App — Local FTP Outbound Sync Agent
 * Run this INSIDE the MOIL company LAN network.
 * Install: npm install mysql2 basic-ftp xlsx
 * Run:     node local_ftp_sync_agent.js
 * Cron:    (every 5 min) node /path/to/local_ftp_sync_agent.js
 */

const mysql = require('mysql2/promise');
const ftp = require('basic-ftp');
const xlsx = require('xlsx');
const fs = require('fs');
const path = require('path');

const DB_CONFIG = {
  host: '147.93.109.38', port: 3306,
  user: 'u156958239_moil_hr_app',
  password: '6Fw|hF#qOv?',
  database: 'u156958239_moil_hr_app',
  connectTimeout: 30000
};

const FTP_CONFIG = { host: '172.16.1.51', port: 21, user: 'ftpuser2', password: 'Ftppo16$', secure: false };
const FTP_OUTBOUND_DIR = '/HR_App/Outbound';
const LOCAL_TEMP_DIR = path.join(__dirname, 'tmp_outbound');

async function runLocalFtpSync() {
  if (!fs.existsSync(LOCAL_TEMP_DIR)) fs.mkdirSync(LOCAL_TEMP_DIR, { recursive: true });
  let db = null;
  const ftpClient = new ftp.Client();
  ftpClient.ftp.verbose = false;
  try {
    db = await mysql.createConnection(DB_CONFIG);
    console.log('[DB] Connected to Hostinger DB');
    const [pending] = await db.execute('SELECT * FROM app_outbound_changes WHERE is_synced = 0 ORDER BY id ASC LIMIT 200');
    if (pending.length === 0) { console.log('[DB] All records synced. Nothing to upload.'); return; }
    console.log('[DB] Found ' + pending.length + ' pending outbound records...');
    await ftpClient.access(FTP_CONFIG);
    console.log('[FTP] Connected to ' + FTP_CONFIG.host);
    const syncedIds = [];
    for (const record of pending) {
      const ts = Date.now();
      const base = 'outbound_' + record.table_name + '_' + record.action_type + '_' + record.record_id + '_' + ts;
      let row = {};
      try { row = typeof record.row_data === 'string' ? JSON.parse(record.row_data || '{}') : (record.row_data || {}); } catch (_) {}
      const payload = { id: record.id, table: record.table_name, record_id: record.record_id, action: record.action_type, data: row, created_at: record.created_at };
      const jf = base + '.json', jp = path.join(LOCAL_TEMP_DIR, jf);
      fs.writeFileSync(jp, JSON.stringify(payload, null, 2));
      try { await ftpClient.uploadFrom(jp, FTP_OUTBOUND_DIR + '/' + jf); console.log('[FTP] JSON uploaded:', jf); } catch (e) { console.error('[FTP] JSON failed:', e.message); }
      const cf = base + '.csv', cp = path.join(LOCAL_TEMP_DIR, cf);
      try {
        const ws = xlsx.utils.json_to_sheet([row]);
        const csvContent = xlsx.utils.sheet_to_csv(ws);
        fs.writeFileSync(cp, csvContent, 'utf8');
        await ftpClient.uploadFrom(cp, FTP_OUTBOUND_DIR + '/' + cf);
        console.log('[FTP] CSV uploaded:', cf);
      } catch (e) { console.error('[FTP] CSV failed:', e.message); }
      syncedIds.push(record.id);
      try { fs.unlinkSync(jp); fs.unlinkSync(cp); } catch (_) {}
    }
    if (syncedIds.length > 0) {
      await db.execute('UPDATE app_outbound_changes SET is_synced=1, synced_at=NOW() WHERE id IN (' + syncedIds.map(() => '?').join(',') + ')', syncedIds);
      console.log('[DB] Marked ' + syncedIds.length + ' records as synced in Hostinger DB');
    }
    console.log('DONE! Synced ' + syncedIds.length + ' records.');
  } catch (err) { console.error('ERROR:', err.message); } finally {
    if (db) await db.end().catch(() => {});
    ftpClient.close();
  }
}
runLocalFtpSync().catch(console.error);
