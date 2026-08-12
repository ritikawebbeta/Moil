// src/services/payslip_service.js
const fs = require('fs');
const path = require('path');
const ftp = require('basic-ftp');
const { pool } = require('../config/db');

const PAYSLIP_DIR = path.join(__dirname, '../../uploads/payslips');
const PUBLIC_PAYSLIP_DIR = '/home/u156958239/domains/acubeai.com/public_html/test/moil_hr_app/uploads/payslips';

// Month mapping
const MONTH_NAMES = {
  '01': 'January', '1': 'January',
  '02': 'February', '2': 'February',
  '03': 'March', '3': 'March',
  '04': 'April', '4': 'April',
  '05': 'May', '5': 'May',
  '06': 'June', '6': 'June',
  '07': 'July', '7': 'July',
  '08': 'August', '8': 'August',
  '09': 'September', '9': 'September',
  '10': 'October',
  '11': 'November',
  '12': 'December'
};

/**
 * Ensure payslips directory exists
 */
function ensurePayslipDir() {
  if (!fs.existsSync(PAYSLIP_DIR)) {
    fs.mkdirSync(PAYSLIP_DIR, { recursive: true });
  }
  if (fs.existsSync('/home/u156958239/domains/acubeai.com/public_html/test/moil_hr_app') && !fs.existsSync(PUBLIC_PAYSLIP_DIR)) {
    try { fs.mkdirSync(PUBLIC_PAYSLIP_DIR, { recursive: true }); } catch (_) {}
  }
}

/**
 * Clean employee ID by removing leading zeroes
 */
function cleanEmpId(id) {
  if (!id) return '';
  return id.toString().trim().replace(/^0+/, '');
}

/**
 * Parse payslip filename pattern: {empNo}_{month}_{year}.pdf
 * Example: 4428_05_2026.pdf -> { empNo: '4428', month: '05', year: '2026' }
 */
function parsePayslipFileName(fileName) {
  const match = fileName.match(/^(\d+)[_\-](\d{1,2})[_\-](\d{4})\.(pdf|PDF)$/);
  if (!match) return null;

  const rawEmpId = match[1];
  const empId = cleanEmpId(rawEmpId);
  const monthStr = match[2].padStart(2, '0');
  const yearStr = match[3];
  const monthName = MONTH_NAMES[monthStr] || `Month ${monthStr}`;

  return {
    fileName,
    employeeId: empId,
    month: monthStr,
    year: yearStr,
    monthName,
    formattedPeriod: `${monthName} ${yearStr}`
  };
}

/**
 * Purge payslips older than the 3 most recent months for a given employee
 */
async function purgeOldPayslips(employeeId) {
  try {
    const cleanId = cleanEmpId(employeeId);
    if (!cleanId) return;

    const [rows] = await pool.execute(
      `SELECT id, file_name, employee_id FROM payslips WHERE employee_id = ? ORDER BY CAST(year AS UNSIGNED) DESC, CAST(month AS UNSIGNED) DESC`,
      [cleanId]
    );

    if (rows.length > 3) {
      const toDelete = rows.slice(3);
      for (const row of toDelete) {
        const localPath = path.join(PAYSLIP_DIR, row.file_name);
        const pubPath = path.join(PUBLIC_PAYSLIP_DIR, row.file_name);
        
        try { if (fs.existsSync(localPath)) fs.unlinkSync(localPath); } catch (_) {}
        try { if (fs.existsSync(pubPath)) fs.unlinkSync(pubPath); } catch (_) {}

        await pool.execute(`DELETE FROM payslips WHERE id = ?`, [row.id]);
        console.log(`[Payslip Purge] Purged old payslip ${row.file_name} for employee ${row.employee_id}`);
      }
    }
  } catch (err) {
    console.error('[Payslip Purge Error]', err.message);
  }
}

/**
 * Sync a single parsed payslip into the MySQL database `payslips` table
 */
async function syncPayslipToDb(parsedFile, localFilePath) {
  try {
    const stats = fs.existsSync(localFilePath) ? fs.statSync(localFilePath) : { size: 0 };

    // Also sync copy to public static directory for Nginx PDF viewer
    if (fs.existsSync(PUBLIC_PAYSLIP_DIR)) {
      try {
        const pubFile = path.join(PUBLIC_PAYSLIP_DIR, parsedFile.fileName);
        fs.copyFileSync(localFilePath, pubFile);
      } catch (_) {}
    }

    const sql = `
      INSERT INTO payslips (employee_id, file_name, month, year, period_name, file_path, file_size)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        month = VALUES(month),
        year = VALUES(year),
        period_name = VALUES(period_name),
        file_path = VALUES(file_path),
        file_size = VALUES(file_size),
        updated_at = NOW()
    `;
    await pool.execute(sql, [
      parsedFile.employeeId,
      parsedFile.fileName,
      parsedFile.month,
      parsedFile.year,
      parsedFile.formattedPeriod,
      localFilePath,
      stats.size
    ]);

    // Auto-purge older files
    await purgeOldPayslips(parsedFile.employeeId);
  } catch (err) {
    console.error(`[Payslip DB Sync Error] Failed for ${parsedFile.fileName}:`, err.message);
  }
}

/**
 * Get all available payslips for a given employee ID from MySQL database `payslips` table
 */
async function getPayslipsForEmployee(employeeId, baseUrl = '') {
  ensurePayslipDir();
  const targetId = employeeId ? cleanEmpId(employeeId) : null;

  // Sync any local files into MySQL `payslips` table
  if (fs.existsSync(PAYSLIP_DIR)) {
    const files = fs.readdirSync(PAYSLIP_DIR);
    for (const file of files) {
      const parsed = parsePayslipFileName(file);
      if (parsed) {
        const localPath = path.join(PAYSLIP_DIR, file);
        await syncPayslipToDb(parsed, localPath);
      }
    }
  }

  // Query records from database `payslips` table
  try {
    const publicBase = baseUrl ? baseUrl.replace(/\/$/, '') : 'https://acubeai.com/test/moil_hr_app';
    let rows;
    if (targetId && targetId !== 'all') {
      [rows] = await pool.execute(
        `SELECT * FROM payslips WHERE employee_id = ? ORDER BY year DESC, month DESC`,
        [targetId]
      );
    } else {
      [rows] = await pool.execute(
        `SELECT * FROM payslips ORDER BY year DESC, month DESC`
      );
    }

    return rows.map(r => ({
      fileName: r.file_name,
      employeeId: r.employee_id,
      month: r.month,
      year: r.year,
      monthName: MONTH_NAMES[r.month] || `Month ${r.month}`,
      formattedPeriod: r.period_name,
      downloadUrl: `${publicBase}/uploads/payslips/${r.file_name}`,
      status: 'Available'
    }));
  } catch (err) {
    console.error('[Get Payslips DB Error]', err.message);
    return [];
  }
}

/**
 * Sync payslips from FTP server (/HR_App/Payslip) to local uploads/payslips folder and database
 */
async function syncPayslipsFromFtp() {
  ensurePayslipDir();
  const client = new ftp.Client();
  client.ftp.verbose = false;
  let downloadedCount = 0;

  try {
    const host = process.env.FTP_HOST || '172.16.1.51';
    const port = parseInt(process.env.FTP_PORT || '21', 10);
    const user = process.env.FTP_USER || 'ftpuser2';
    const password = process.env.FTP_PASSWORD || 'Ftppo16$';

    await client.access({ host, port, user, password, secure: false });
    console.log('[Payslip FTP Sync] Connected to FTP server:', host);

    const list = await client.list('/HR_App/Payslip');
    const empPayslipsMap = {};

    for (const file of list) {
      if (file.isFile && file.name.match(/\.(pdf|PDF)$/i)) {
        const parsed = parsePayslipFileName(file.name);
        if (parsed) {
          if (!empPayslipsMap[parsed.employeeId]) {
            empPayslipsMap[parsed.employeeId] = [];
          }
          empPayslipsMap[parsed.employeeId].push({ file, parsed });
        }
      }
    }

    for (const employeeId of Object.keys(empPayslipsMap)) {
      const items = empPayslipsMap[employeeId];
      items.sort((a, b) => {
        const yA = parseInt(a.parsed.year);
        const yB = parseInt(b.parsed.year);
        if (yA !== yB) return yB - yA;
        return parseInt(b.parsed.month) - parseInt(a.parsed.month);
      });

      const activeItems = items.slice(0, 3);
      const purgedItems = items.slice(3);

      for (const item of activeItems) {
        const localFilePath = path.join(PAYSLIP_DIR, item.file.name);
        if (!fs.existsSync(localFilePath) || fs.statSync(localFilePath).size !== item.file.size) {
          console.log(`[Payslip FTP Sync] Downloading ${item.file.name}...`);
          await client.downloadTo(localFilePath, `/HR_App/Payslip/${item.file.name}`);
          downloadedCount++;
        }
        await syncPayslipToDb(item.parsed, localFilePath);
      }

      for (const item of purgedItems) {
        const localFilePath = path.join(PAYSLIP_DIR, item.file.name);
        const pubFilePath = path.join(PUBLIC_PAYSLIP_DIR, item.file.name);

        try { if (fs.existsSync(localFilePath)) fs.unlinkSync(localFilePath); } catch (_) {}
        try { if (fs.existsSync(pubFilePath)) fs.unlinkSync(pubFilePath); } catch (_) {}

        await pool.execute('DELETE FROM payslips WHERE employee_id = ? AND file_name = ?', [employeeId, item.file.name]);
      }
    }
    console.log(`[Payslip FTP Sync] Completed! Synced ${downloadedCount} new/updated payslip PDFs.`);
  } catch (err) {
    console.error('[Payslip FTP Sync Error]', err.message);
  } finally {
    client.close();
  }

  return downloadedCount;
}

module.exports = {
  getPayslipsForEmployee,
  syncPayslipsFromFtp,
  parsePayslipFileName,
  PAYSLIP_DIR
};
