#!/usr/bin/env node
/**
 * MOIL HR App — FTP Bridge Service
 * ─────────────────────────────────────────────────────────────
 * Runs on LOCAL machine (your Mac/PC on the same LAN as FTP).
 * 
 * Every 30 seconds:
 *   1. Polls Hostinger API for pending outbound records
 *   2. Converts each record to JSON + XLSX
 *   3. Pushes files to internal FTP /HR_App/Outbound/
 *   4. Marks records as synced on Hostinger
 *
 * Usage:
 *   cd "/Users/apple/Flutter WB Project/Moil_backend"
 *   node ftp_bridge_service.js
 *
 * Run as background daemon (auto-restart):
 *   nohup node ftp_bridge_service.js >> ftp_bridge.log 2>&1 &
 * ─────────────────────────────────────────────────────────────
 */

const https = require('https');
const ftp = require('basic-ftp');
const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

// ─── Configuration ────────────────────────────────────────────
const CONFIG = {
  // Hostinger API
  apiBase:     'acubeai.com',
  apiPath:     '/test/moil_hr_app/api',

  // Internal FTP (LAN)
  ftpHost:     '172.16.1.51',
  ftpPort:     21,
  ftpUser:     'ftpuser2',
  ftpPassword: 'Ftppo16$',
  ftpInbound:  '/HR_App/Inbound',
  ftpOutbound: '/HR_App/Outbound',

  // Polling interval (milliseconds)
  interval:    30000,   // 30 seconds

  // Local temp dir for files before FTP push (auto-cleaned)
  tmpDir:      path.join(__dirname, 'tmp_bridge'),

  // Local archive dir — keeps permanent copies of all uploaded files on Mac
  archiveDir:  path.join(__dirname, 'outbound_archive'),
};

// ─── Helpers ──────────────────────────────────────────────────
function httpsRequest(method, hostname, path, body) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const opts = {
      hostname,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(postData ? { 'Content-Length': Buffer.byteLength(postData) } : {}),
      },
    };
    const req = https.request(opts, (res) => {
      let data = '';
      res.on('data', d => (data += d));
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch (e) { resolve(data); }
      });
    });
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

function timestamp() {
  return new Date().toISOString().replace('T', ' ').substring(0, 19);
}

function log(msg) {
  const line = `[${timestamp()}] ${msg}`;
  console.log(line);
}

function buildFilename(record) {
  return `outbound_${record.table_name}_${record.action_type}_${record.record_id}_${Date.now()}`;
}

function saveJson(record, filePath) {
  fs.writeFileSync(filePath, JSON.stringify(record, null, 2), 'utf8');
}

// Convert SAP date string "DD.MM.YYYY" to Excel serial number (same as inbound)
function dateToExcelSerial(dateStr) {
  if (!dateStr) return '';
  // Handle "DD.MM.YYYY" format
  const parts = dateStr.split('.');
  if (parts.length === 3) {
    const d = new Date(parts[2], parts[1] - 1, parts[0]);
    // Excel serial: days since 1900-01-01 (+1 for Excel's leap year bug)
    return Math.floor((d - new Date(1899, 11, 30)) / 86400000);
  }
  // Handle ISO "YYYY-MM-DD" format
  const iso = new Date(dateStr);
  if (!isNaN(iso)) return Math.floor((iso - new Date(1899, 11, 30)) / 86400000);
  return dateStr;
}

function saveCsv(record, filePath) {
  const cc = record.changed_columns || {};
  const rd = record.row_data || {};
  let rows = [];

  if (record.table_name === 'PTREQ_ATTABSDATA_Leave_Apply') {
    // Exact column match with inbound PTREQ_ATTABSDATA_Leave_Apply.XLSX
    const startDate = cc.start_date || rd.start_date || '';
    const endDate   = cc.end_date   || rd.end_date   || '';
    const days      = parseFloat(cc.days_count || rd.att__abs__days || '1');
    const hours     = days * 8.5;
    rows = [{
      'ID of Request Item':       record.record_id,
      'Infotype operation':       record.action_type === 'INSERT' ? 'INS' : 'MOD',
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
    }];

  } else if (record.table_name === 'PTREQ_HEADER_Leave_Approved') {
    // Exact column match with inbound PTREQ_HEADER_Leave_Approved.XLSX
    const now = new Date();
    const excelTs = (now - new Date(1899, 11, 30)) / 86400000;
    const status  = cc.document_status || rd.document_status || 'SENT';
    const guid    = cc.document_identification || record.record_id || '';
    rows = [{
      'Document Identification':    record.record_id,
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
      'ID of Request Item List':    cc.req_item_list_id || rd.req_item_list_id || record.record_id,
      'Last Changed By':            cc.last_changed_by || rd.last_changed_by || '',
      'Time Stamp':                 excelTs,
      'Time Zone':                  'INDIA',
      'ID':                         cc.personnel_number || rd.personnel_number || cc.last_changed_by || '',
    }];

  } else if (record.table_name === 'travel') {
    // Match inbound FTPT_REQ_HEAD-Travel request.XLSX structure
    rows = [{
      'Personnel Number':           cc.personnel_number || rd.personnel_number || '',
      'Trip Number':                cc.trip_number      || rd.trip_number      || record.record_id,
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
    }];

  } else {
    // Generic fallback — key/value layout
    const allData = Object.assign({}, cc, rd);
    rows = [allData];
  }

  const ws = XLSX.utils.json_to_sheet(rows);
  const csvContent = XLSX.utils.sheet_to_csv(ws);
  fs.writeFileSync(filePath, csvContent, 'utf8');
}


// ─── Core sync cycle ──────────────────────────────────────────
let isSyncing = false;  // Lock to prevent concurrent duplicate uploads

async function syncCycle() {
  if (isSyncing) {
    log('⏳ Previous sync still running — skipping this interval.');
    return;
  }
  isSyncing = true;
  try {
    await doSync();
    await doInboundSync();
  } catch (err) {
    log(`❌ Sync cycle error: ${err.message}`);
  } finally {
    isSyncing = false;
  }
}

async function doSync() {
  // 1. Fetch pending records from Hostinger
  let pending;
  try {
    pending = await httpsRequest('GET', CONFIG.apiBase, `${CONFIG.apiPath}/pending-outbound`);
  } catch (err) {
    log(`❌ API fetch error: ${err.message}`);
    return;
  }

  if (!Array.isArray(pending) || pending.length === 0) {
    log('✅ No pending outbound records.');
    return;
  }

  log(`📋 Found ${pending.length} pending outbound record(s). Syncing...`);

  // Ensure temp + archive dirs exist
  if (!fs.existsSync(CONFIG.tmpDir)) fs.mkdirSync(CONFIG.tmpDir, { recursive: true });
  if (!fs.existsSync(CONFIG.archiveDir)) fs.mkdirSync(CONFIG.archiveDir, { recursive: true });

  // 2. Connect to FTP
  const client = new ftp.Client();
  client.ftp.verbose = false;
  client.ftp.timeout = 120000; // 2 minutes timeout for large file sync
  const syncedIds = [];

  try {
    await client.access({
      host:     CONFIG.ftpHost,
      port:     CONFIG.ftpPort,
      user:     CONFIG.ftpUser,
      password: CONFIG.ftpPassword,
      secure:   false,
    });
    log(`🔗 FTP Connected: ${CONFIG.ftpHost}`);

    // Ensure outbound folder exists
    try { await client.ensureDir(CONFIG.ftpOutbound); } catch (_) {}

    for (const record of pending) {
      const baseName  = buildFilename(record);
      const jsonPath  = path.join(CONFIG.tmpDir, `${baseName}.json`);
      const csvPath   = path.join(CONFIG.tmpDir, `${baseName}.csv`);

      // 3. Write JSON + CSV locally
      saveJson(record, jsonPath);
      saveCsv(record, csvPath);

      // 4. Upload both files to FTP
      try {
        await client.uploadFrom(jsonPath, `${CONFIG.ftpOutbound}/${baseName}.json`);
        await client.uploadFrom(csvPath, `${CONFIG.ftpOutbound}/${baseName}.csv`);
        log(`  ✅ Uploaded: ${baseName} (${record.table_name})`);
        syncedIds.push(record.id);

        // Archive copies locally on Mac
        fs.copyFileSync(jsonPath, path.join(CONFIG.archiveDir, `${baseName}.json`));
        fs.copyFileSync(csvPath, path.join(CONFIG.archiveDir, `${baseName}.csv`));
        log(`  📁 Archived locally: outbound_archive/${baseName}.json`);
      } catch (uploadErr) {
        log(`  ❌ Upload failed for ${record.record_id}: ${uploadErr.message}`);
      }

      // Cleanup temp files
      try { fs.unlinkSync(jsonPath); } catch (_) {}
      try { fs.unlinkSync(csvPath); } catch (_) {}
    }
  } catch (ftpErr) {
    log(`❌ FTP Error: ${ftpErr.message}`);
  } finally {
    client.close();
  }

  // 5. Mark synced on Hostinger
  if (syncedIds.length > 0) {
    try {
      const result = await httpsRequest('POST', CONFIG.apiBase, `${CONFIG.apiPath}/mark-outbound-synced`, { ids: syncedIds });
      log(`📌 Marked ${syncedIds.length} record(s) as synced on Hostinger. Response: ${JSON.stringify(result)}`);
    } catch (err) {
      log(`⚠️  Could not mark synced: ${err.message}`);
    }
  }

  log(`🎉 Sync complete. ${syncedIds.length}/${pending.length} records pushed to FTP.`);
}

function parseInboundFile(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.json') {
    const raw = fs.readFileSync(filePath, 'utf8');
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [parsed];
  } else if (ext === '.xlsx' || ext === '.xls' || ext === '.csv') {
    const wb = XLSX.readFile(filePath);
    let bestSheet = wb.Sheets[wb.SheetNames[0]];
    let maxRows = 0;
    for (const sName of wb.SheetNames) {
      const s = wb.Sheets[sName];
      const r = XLSX.utils.sheet_to_json(s);
      if (r.length > maxRows) {
        maxRows = r.length;
        bestSheet = s;
      }
    }
    return XLSX.utils.sheet_to_json(bestSheet);
  }
  return [];
}

async function doInboundSync() {
  log('📡 Starting Inbound Sync (FTP -> Hostinger)...');

  // 1. Fetch already processed inbound files registry from Hostinger
  let registered;
  try {
    registered = await httpsRequest('GET', CONFIG.apiBase, `${CONFIG.apiPath}/inbound-registry`);
  } catch (err) {
    log(`❌ Inbound Registry fetch error: ${err.message}`);
    return;
  }

  if (!Array.isArray(registered)) {
    log('⚠️  Invalid response from inbound registry endpoint.');
    return;
  }

  const registeredMap = {};
  registered.forEach(r => {
    registeredMap[r.file_name] = r;
  });

  // 2. Connect to FTP
  const client = new ftp.Client();
  client.ftp.verbose = false;
  client.ftp.timeout = 120000; // 2 minutes timeout for large file sync

  try {
    await client.access({
      host:     CONFIG.ftpHost,
      port:     CONFIG.ftpPort,
      user:     CONFIG.ftpUser,
      password: CONFIG.ftpPassword,
      secure:   false,
    });

    let inboundFiles = [];
    try {
      inboundFiles = await client.list(CONFIG.ftpInbound);
    } catch (e) {
      log(`⚠️  Could not list FTP Inbound directory: ${e.message}`);
      return;
    }

    const filesToSync = inboundFiles.filter(f => !f.isDirectory);
    log(`📋 Found ${filesToSync.length} file(s) in FTP Inbound folder.`);

    for (const file of filesToSync) {
      const lastModStr = file.modifiedAt ? file.modifiedAt.toISOString() : (file.rawModifiedAt || '');
      const match = registeredMap[file.name];

      // Check if file is unchanged
      if (match && String(match.file_size) === String(file.size) && match.last_modified === lastModStr) {
        // Skip unchanged file
        continue;
      }

      log(`🔄 Processing new/updated inbound file: ${file.name} (${file.size} bytes)`);

      const localPath = path.join(CONFIG.tmpDir, file.name);
      if (!fs.existsSync(CONFIG.tmpDir)) fs.mkdirSync(CONFIG.tmpDir, { recursive: true });

      // Download file locally to Mac
      await client.downloadTo(localPath, `${CONFIG.ftpInbound}/${file.name}`);

      // Parse file
      let rows = [];
      try {
        rows = parseInboundFile(localPath);
      } catch (parseErr) {
        log(`  ❌ Failed to parse ${file.name}: ${parseErr.message}`);
        try { fs.unlinkSync(localPath); } catch (_) {}
        continue;
      }

      if (rows.length === 0) {
        log(`  ⚠️  File ${file.name} is empty or invalid.`);
        try { fs.unlinkSync(localPath); } catch (_) {}
        continue;
      }

      log(`  📦 Parsed ${rows.length} rows. Uploading to Hostinger in chunks...`);

      // Upload in chunks of 300 to avoid payload limit / timeout
      const chunkSize = 300;
      let totalSuccess = 0;
      let failed = false;

      for (let i = 0; i < rows.length; i += chunkSize) {
        const chunk = rows.slice(i, i + chunkSize);
        try {
          const res = await httpsRequest('POST', CONFIG.apiBase, `${CONFIG.apiPath}/inbound-sync-db`, {
            fileName: file.name,
            rows: chunk
          });
          if (res && res.success) {
            totalSuccess += res.count;
          } else {
            log(`  ❌ Chunk upload failed: ${JSON.stringify(res)}`);
            failed = true;
            break;
          }
        } catch (postErr) {
          log(`  ❌ HTTP error during chunk upload: ${postErr.message}`);
          failed = true;
          break;
        }
      }

      if (!failed) {
        log(`  ✅ Synced all ${totalSuccess} rows to Hostinger database!`);

        // Mark as synced on Hostinger
        try {
          await httpsRequest('POST', CONFIG.apiBase, `${CONFIG.apiPath}/inbound-registry`, {
            file_name: file.name,
            file_size: file.size,
            last_modified: lastModStr
          });
          log(`  📌 Updated registry for ${file.name}`);
        } catch (regErr) {
          log(`  ⚠️  Could not update registry for ${file.name}: ${regErr.message}`);
        }
      }

      // Cleanup local temp file
      try { fs.unlinkSync(localPath); } catch (_) {}
    }
  } catch (ftpErr) {
    log(`❌ FTP Inbound Error: ${ftpErr.message}`);
  } finally {
    client.close();
  }
}

// ─── Startup ──────────────────────────────────────────────────
log('═══════════════════════════════════════════════════');
log('  MOIL HR App — FTP Bridge Service  STARTED');
log(`  Polling every ${CONFIG.interval / 1000}s`);
log(`  FTP: ${CONFIG.ftpHost}:${CONFIG.ftpPort}`);
log(`  API: https://${CONFIG.apiBase}${CONFIG.apiPath}`);
log(`  Archive: ${CONFIG.archiveDir}`);
log('═══════════════════════════════════════════════════');

// Run immediately, then every interval
syncCycle();
setInterval(syncCycle, CONFIG.interval);

