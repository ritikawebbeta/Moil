const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const authenticateToken = require('../middleware/auth');
const { pool } = require('../config/db');
const {
  sendLeaveAppliedSms,
  sendLeaveApprovedSms,
  sendLeaveRejectedSms,
  sendLeaveEncashAppliedSms,
  sendLeaveEncashApprovedSms,
  sendLeaveEncashRejectedSms
} = require('../utils/smsService');

async function getEmployeeMobile(employeeId) {
  // FOR TESTING: Hardcoded test mobile number requested by user
  const defaultPhone = '9689941705';
  return defaultPhone;

  /* =========================================================================
   * FUTURE PRODUCTION USE: Uncomment this block to automatically fetch 
   * the employee's actual mobile number from the manpower MySQL database.
   * =========================================================================
  if (!employeeId || employeeId === '0' || employeeId === 'N/A') return defaultPhone;
  try {
    const [rows] = await pool.query(
      'SELECT mobile_number FROM manpower WHERE employee_number = ? OR CAST(employee_number AS UNSIGNED) = ? LIMIT 1',
      [employeeId, employeeId]
    );
    if (rows.length > 0 && rows[0].mobile_number) {
      const mob = String(rows[0].mobile_number).trim().replace(/[^\d]/g, '');
      if (mob.length >= 10) return mob.slice(-10);
    }
  } catch (e) {
    console.error('[getEmployeeMobile Error]', e.message);
  }
  return defaultPhone;
  */
}

// Helper to format dates consistently (DD-MM-YYYY)
function formatDate(date) {
  if (!date) return 'N/A';
  const str = String(date).trim();
  if (str === 'N/A' || str === 'NULL' || str === '0000-00-00' || str === '00.00.0000' || str.startsWith('1899') || str.startsWith('0000') || str.includes('1899')) return 'N/A';

  if (/^\d{2}\.\d{2}\.\d{4}$/.test(str)) return str;
  if (/^\d{2}-\d{2}-\d{4}$/.test(str)) return str;

  if (/^\d{4}[-/]\d{2}[-/]\d{2}/.test(str)) {
    const parts = str.split('T')[0].split(/[-/]/);
    if (parts[0] === '0000' || parts[0] === '1899' || parseInt(parts[0]) <= 1900) return 'N/A';
    return `${parts[2]}-${parts[1]}-${parts[0]}`;
  }

  const d = new Date(date);
  if (isNaN(d.getTime()) || d.getFullYear() <= 1900) return 'N/A';
  const day = d.getDate().toString().padStart(2, '0');
  const month = (d.getMonth() + 1).toString().padStart(2, '0');
  const year = d.getFullYear();
  return `${day}-${month}-${year}`;
}

// Helper to format dates for DB query/inserts (YYYY-MM-DD HH:mm:ss)
function formatDbDateTime(date) {
  if (!date) return null;
  const d = new Date(date);
  if (isNaN(d.getTime())) return null;
  const yyyy = d.getFullYear();
  const mm = (d.getMonth() + 1).toString().padStart(2, '0');
  const dd = d.getDate().toString().padStart(2, '0');
  const hh = d.getHours().toString().padStart(2, '0');
  const min = d.getMinutes().toString().padStart(2, '0');
  const ss = d.getSeconds().toString().padStart(2, '0');
  return `${yyyy}-${mm}-${dd} ${hh}:${min}:${ss}`;
}

/**
 * Format any date input to dd.mm.yyyy format for DB storage
 */
function formatDateDdMmYyyy(dateInput) {
  if (!dateInput) return '';
  const str = String(dateInput).trim();

  // If already DD.MM.YYYY
  if (/^\d{2}\.\d{2}\.\d{4}$/.test(str)) return str;

  // If YYYY-MM-DD or YYYY/MM/DD
  if (/^\d{4}[-/]\d{2}[-/]\d{2}/.test(str)) {
    const cleanDate = str.split('T')[0].split(' ')[0];
    const parts = cleanDate.split(/[-/]/);
    return `${parts[2]}.${parts[1]}.${parts[0]}`;
  }

  // If DD-MM-YYYY or DD/MM/YYYY
  if (/^\d{2}[-/]\d{2}[-/]\d{4}/.test(str)) {
    const cleanDate = str.split('T')[0].split(' ')[0];
    const parts = cleanDate.split(/[-/]/);
    return `${parts[0]}.${parts[1]}.${parts[2]}`;
  }

  const d = new Date(dateInput);
  if (isNaN(d.getTime())) return str;
  const day = String(d.getDate()).padStart(2, '0');
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const year = d.getFullYear();
  return `${day}.${month}.${year}`;
}

/**
 * Format any date input to YYYY-MM-DD ISO format for frontend calendar parsing
 */
function formatIsoDate(dateInput) {
  if (!dateInput) return null;
  const str = String(dateInput).trim();
  if (str === 'N/A' || str === 'NULL' || str === '0000-00-00' || str === '00.00.0000') return null;

  if (/^\d{2}[\.\-]\d{2}[\.\-]\d{4}$/.test(str)) {
    const parts = str.split(/[\.\-]/);
    return `${parts[2]}-${parts[1]}-${parts[0]}`;
  }
  if (/^\d{4}[-/]\d{2}[-/]\d{2}/.test(str)) {
    return str.split('T')[0].split(' ')[0];
  }
  const d = new Date(dateInput);
  if (isNaN(d.getTime())) return null;
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Calculate actual number of days between start and end date inclusive
 */
function calculateDays(startDateStr, endDateStr, isHalfDay = false) {
  if (isHalfDay) return 0.5;
  if (!startDateStr || !endDateStr) return 1.0;

  try {
    let d1, d2;
    const s1 = String(startDateStr).split('T')[0].split(' ')[0];
    const s2 = String(endDateStr).split('T')[0].split(' ')[0];

    if (s1.includes('.')) {
      const p = s1.split('.');
      d1 = new Date(p[2], p[1] - 1, p[0]);
    } else {
      d1 = new Date(s1);
    }

    if (s2.includes('.')) {
      const p = s2.split('.');
      d2 = new Date(p[2], p[1] - 1, p[0]);
    } else {
      d2 = new Date(s2);
    }

    if (isNaN(d1.getTime()) || isNaN(d2.getTime())) return 1.0;

    const diffTime = Math.abs(d2 - d1);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
    return diffDays > 0 ? diffDays : 1.0;
  } catch (_) {
    return 1.0;
  }
}

// Generate random 32-char uppercase hex string (for UUIDs / GUIDs)
function generateHexId() {
  return crypto.randomBytes(16).toString('hex').toUpperCase();
}

async function logApproval(managerId, requestType, requestId, applicantId, action, remarks) {
  try {
    const cleanApplicantId = applicantId.toString().trim().replace(/^0+/, '');
    const [empRows] = await pool.query('SELECT employee_name FROM manpower WHERE CAST(employee_number AS UNSIGNED) = CAST(? AS UNSIGNED) LIMIT 1', [cleanApplicantId]);
    const applicantName = empRows.length > 0 ? empRows[0].employee_name : 'Unknown';

    const query = `
      INSERT INTO approval_history (manager_id, request_type, request_id, applicant_id, applicant_name, action, remarks)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `;
    await pool.query(query, [managerId, requestType, requestId, cleanApplicantId, applicantName, action, remarks]);
  } catch (error) {
    console.error('[logApproval Error]', error.message);
  }
}

async function createNotification(employeeId, title, message, type) {
  try {
    if (!employeeId) return;
    const cleanEmpId = employeeId.toString().trim().replace(/^0+/, '') || employeeId.toString().trim();
    const query = `
      INSERT INTO notifications (employee_id, title, message, type)
      VALUES (?, ?, ?, ?)
    `;
    await pool.query(query, [cleanEmpId, title, message, type || 'General']);
  } catch (error) {
    console.error('[createNotification Error]', error.message);
  }
}

async function getEmployeeName(employeeId) {
  if (!employeeId || employeeId === '0' || employeeId === 'N/A') return '';
  try {
    const [rows] = await pool.query(
      'SELECT employee_name FROM manpower WHERE employee_number = ? OR CAST(employee_number AS UNSIGNED) = ? LIMIT 1',
      [employeeId, employeeId]
    );
    if (rows.length > 0 && rows[0].employee_name) {
      return rows[0].employee_name;
    }
  } catch (e) {}
  return `Employee #${employeeId}`;
}

// Subarea text to code mapping for Holiday Calendar
function getSubareaCodes(subareaText) {
  const clean = (subareaText || '').toString().trim().toLowerCase();
  
  if (clean.includes('head office') || clean.includes('nagpur')) {
    return { area: 'MOMH', subarea: 'HONG' };
  } else if (clean.includes('balaghat')) {
    return { area: 'MOMH', subarea: 'MHBL' };
  } else if (clean.includes('chikla')) {
    return { area: 'MOMH', subarea: 'MHCH' };
  } else if (clean.includes('dongri')) {
    return { area: 'MOMH', subarea: 'MHDB' };
  } else if (clean.includes('gumgaon')) {
    return { area: 'MOMH', subarea: 'MHGM' };
  } else if (clean.includes('kandri')) {
    return { area: 'MOMH', subarea: 'MHKD' };
  } else if (clean.includes('munsar')) {
    return { area: 'MOMH', subarea: 'MHMS' };
  } else if (clean.includes('beldongri')) {
    return { area: 'MOMH', subarea: 'MHMS' };
  } else if (clean.includes('ukwa')) {
    return { area: 'MOMP', subarea: 'MPSP' };
  } else if (clean.includes('tirodi')) {
    return { area: 'MOMP', subarea: 'MPTD' };
  }
  
  return { area: 'MOMH', subarea: 'HONG' };
}

// Map database row to standard employee model
function mapEmployeeRow(row) {
  const serviceHistory = [];
  const apptDt = formatDate(row.date_of_appointment);
  const promDt = formatDate(row.act_doj_on_promt_dt || row.latest_promotion_dt || row.dosl);
  const payscaleStr = row.payscale ? row.payscale.toString().trim() : (row.basic_pay ? `Rs. ${parseFloat(row.basic_pay).toLocaleString('en-IN')}` : 'N/A');
  const locStr = row.personnel_subarea_text || 'Head Office Nag';
  const desigStr = row.position_name || 'Employee';
  const gradeStr = row.employee_subgroup_text || row.employee_subgroup || 'E5';

  if (apptDt && apptDt !== 'N/A') {
    serviceHistory.push({
      date: apptDt,
      action: 'Appointment',
      reason: row.hire_action_reason || 'New Position',
      designation: desigStr,
      grade: gradeStr,
      location: locStr,
      from: apptDt,
      to: (promDt && promDt !== 'N/A') ? promDt : 'Till Date',
      payscale: payscaleStr
    });
  }

  if (promDt && promDt !== 'N/A' && promDt !== apptDt) {
    serviceHistory.push({
      date: promDt,
      action: 'Promotion',
      reason: 'Regular Promotion',
      designation: desigStr,
      grade: gradeStr,
      location: locStr,
      from: promDt,
      to: 'Till Date',
      payscale: payscaleStr
    });
  }

  return {
    id: row.employee_number.toString(),
    employeeId: row.employee_number.toString(),
    employee_number: row.employee_number,
    name: row.employee_name,
    fatherSpouseName: row.family_members_father || row.family_members_spouse || 'N/A',
    designation: row.position_name || 'Employee',
    department: row.department || 'N/A',
    presentGrade: row.employee_subgroup_text || row.employee_subgroup || 'N/A',
    dateOfBirth: formatDate(row.date_of_birth),
    joinDate: formatDate(row.date_of_appointment),
    qualification: row.qualification ? row.qualification.toString().trim() : 'N/A',
    lastPromotionDate: formatDate(row.act_doj_on_promt_dt || row.latest_promotion_dt || row.dopp),
    appointmentType: row.hire_action_reason || 'Regular',
    category: row.caste || 'GEN',
    bloodGroup: row.blood_group || 'O+',
    gender: (row.gender || '').toString().trim() === '2' ? 'Female' : ((row.gender || '').toString().trim() === '1' ? 'Male' : (row.gender || 'Male')),
    maritalStatus: row.marital_status || 'Single',
    basicSalary: parseFloat(row.basic_pay || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 }),
    presentPlaceOfPosting: row.personnel_subarea_text || 'Head Office',
    presentPostingDate: formatDate(row.dopp || row.act_doj_on_promt_dt),
    retirementDate: formatDate(row.date_of_retirement),
    email: (row.email_id || row.email || '').toString().trim() || 'N/A',
    uanNo: (row.uan || row.uan_number || '').toString().trim() || 'N/A',
    mobile: row.mobile_number || 'N/A',
    mobileNumber: row.mobile_number || 'N/A',
    pan_number: row.pan_number || 'N/A',
    aadhaarNo: row.aadhar_number || 'N/A',
    pranNo: (row.praan_no && row.praan_no.toString().trim() !== '' && row.praan_no.toString().trim().toUpperCase() !== 'NULL') ? row.praan_no.toString().trim() : 'N/A',
    pfNo: (row.employee_pf_number && row.employee_pf_number.toString().trim() !== '' && row.employee_pf_number.toString().trim().toUpperCase() !== 'NULL') ? row.employee_pf_number.toString().trim() : 'N/A',
    pensionNo: (row.employee_pension_number && row.employee_pension_number.toString().trim() !== '' && row.employee_pension_number.toString().trim().toUpperCase() !== 'NULL') ? row.employee_pension_number.toString().trim() : 'N/A',
    presentPostingDate: formatDate(row.dopp || row.act_doj_on_promt_dt),
    dopp: formatDate(row.dopp || row.act_doj_on_promt_dt),
    reportingOfficer: (row.reporting_officer || '0').toString(),
    reportingOfficer1: (row.reporting_officer_1 || '0').toString(),
    reportingOfficerName: row.reporting_officer_name || '',
    reportingOfficer1Name: row.reporting_officer_1_name || '',
    permanentAddress: row.permanent_address || 'N/A',
    temporaryAddress: row.temporary_address || 'N/A',
    currentAddress: row.emergency_address || 'N/A',
    employee_group: row.employee_group || 'N/A',
    employee_subgroup: row.employment_status || 'N/A',
    dopp: formatDate(row.dopp),
    nominees: [],
    serviceHistory,
    familyMembers: []
  };
}

/**
 * @route   GET /api/health
 */
router.get('/health', async (req, res) => {
  try {
    const startTime = Date.now();
    const [rows] = await pool.query('SELECT 1 + 1 AS solution');
    const responseTimeMs = Date.now() - startTime;
    
    res.json({
      status: 'UP',
      database: {
        status: 'CONNECTED',
        responseTimeMs,
        check: rows[0].solution === 2 ? 'OK' : 'FAIL'
      },
      timestamp: new Date()
    });
  } catch (error) {
    res.status(500).json({
      status: 'DOWN',
      database: {
        status: 'DISCONNECTED',
        error: error.message
      },
      timestamp: new Date()
    });
  }
});

/**
 * @route   GET /api/pending-outbound
 * @desc    Returns all unsynced modified rows & columns for Outbound FTP export
 */
router.get('/pending-outbound', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM app_outbound_changes WHERE is_synced = 0 ORDER BY id ASC LIMIT 500');
    const parsed = rows.map(r => ({
      id: r.id,
      table_name: r.table_name,
      record_id: r.record_id,
      action_type: r.action_type,
      changed_columns: typeof r.changed_columns === 'string' ? JSON.parse(r.changed_columns || '{}') : r.changed_columns,
      row_data: typeof r.row_data === 'string' ? JSON.parse(r.row_data || '{}') : r.row_data,
      created_at: r.created_at
    }));
    res.json(parsed);
  } catch (err) {
    console.error('[Pending Outbound Error]', err.message);
    res.status(500).json({ error: 'Failed to fetch pending outbound changes' });
  }
});

/**
 * @route   POST /api/mark-outbound-synced
 * @desc    Marks processed change IDs as synced
 */
router.post('/mark-outbound-synced', async (req, res) => {
  try {
    const { ids } = req.body;
    if (Array.isArray(ids) && ids.length > 0) {
      await pool.query('UPDATE app_outbound_changes SET is_synced = 1, synced_at = NOW() WHERE id IN (?)', [ids]);
    }
    res.json({ success: true, count: ids ? ids.length : 0 });
  } catch (err) {
    console.error('[Mark Outbound Synced Error]', err.message);
    res.status(500).json({ error: 'Failed to mark outbound changes as synced' });
  }
});

/**
 * Detect table name based on column header fingerprints (so files can be renamed freely!)
 */
function detectTableFromHeaders(keys, fileName) {
  const kStr = keys.map(k => String(k).toLowerCase()).join(' ');

  // 1. Manpower
  if (kStr.includes('cname') || kStr.includes('act_doj_on_promt_dt') || kStr.includes('date_of_appointment') || kStr.includes('date_of_retirement') || (kStr.includes('personnel number') && kStr.includes('name'))) {
    return 'manpower';
  }
  // 2. Family Member
  if (kStr.includes('family member') || kStr.includes('child\'s address') || kStr.includes('aadhar card') || kStr.includes('post-retirement medical benefit') || kStr.includes('rel/child')) {
    return 'it0021_family_member';
  }
  // 3. Nomination
  if (kStr.includes('nominee') || kStr.includes('share_percentage') || kStr.includes('guardian_name') || kStr.includes('serial_number_of_family_member') || kStr.includes('nomination')) {
    return 'it0591_nomination';
  }
  // 4. Leave Quota
  if (kStr.includes('absence_quota_type') || kStr.includes('quota_number') || kStr.includes('quota_deduction') || kStr.includes('deduction_from') || kStr.includes('quota type')) {
    return 'leave_quota';
  }
  // 5. Absence
  if (kStr.includes('att_abs_days') || kStr.includes('absence_hours') || kStr.includes('payroll_days') || kStr.includes('absence type')) {
    return 'absence';
  }
  // 6. Leave Apply Items
  if (kStr.includes('id_of_request_item') || kStr.includes('infotype_operation')) {
    return 'ptreq_attabsdata_leave_apply_1';
  }
  // 7. Leave Header Approved
  if (kStr.includes('document_identification') || kStr.includes('document_status') || kStr.includes('id_of_request_item_list')) {
    return 'ptreq_header_leave_approved_1';
  }
  // 8. Planned Working Time
  if (kStr.includes('work schedule rule') || kStr.includes('time mgmt status') || kStr.includes('monthly working hrs') || kStr.includes('daily working hours')) {
    return 'planned_working_time';
  }
  // 9. Time Quota Compensation
  if (kStr.includes('compensation') || kStr.includes('comp_quota') || kStr.includes('time quota') || fnUpper.includes('COMPENSATION') || fnUpper.includes('IT0416')) {
    return 'time_quota_compensation_infotype';
  }
  // 10. Travel
  if (kStr.includes('beginning_date_of_trip_segment') || kStr.includes('trip_destination') || kStr.includes('reason_for_trip') || kStr.includes('trip')) {
    return 'travel';
  }
  // 11. Holiday
  if (kStr.includes('holiday_date') || kStr.includes('holiday_description') || kStr.includes('holiday_title') || kStr.includes('holiday')) {
    return 'zhcm_opt_holiday';
  }
  // 12. Reporting Officers (Agents)
  if (kStr.includes('reporting_officer') || kStr.includes('reporting_officer_1')) {
    return 'zhcm_lr_t_agents_03072026';
  }

  // Fallback to filename keywords if header match is inconclusive
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
 * @route   POST /api/inbound-sync-db
 * @desc    Upserts parsed rows from FTP Inbound files into MySQL DB tables
 */
router.post('/inbound-sync-db', async (req, res) => {
  try {
    const { fileName, rows } = req.body;
    if (!fileName || !Array.isArray(rows) || rows.length === 0) {
      return res.status(400).json({ error: 'fileName and non-empty rows array are required' });
    }

    const sampleRowKeys = rows.length > 0 ? Object.keys(rows[0]) : [];
    let tableName = detectTableFromHeaders(sampleRowKeys, fileName);

    if (!tableName) {
      return res.json({ message: `Skipping unmapped file ${fileName} (Headers did not match any known table fingerprint)`, processed: 0 });
    }

    let successCount = 0;
    const conn = await pool.getConnection();

    try {
      for (const rowObj of rows) {
        const keys = Object.keys(rowObj).filter(k => k && rowObj[k] !== undefined);
        if (keys.length === 0) continue;

        const cols = keys.map(k => `\`${k.trim().toLowerCase()}\``).join(', ');
        const placeholders = keys.map(() => '?').join(', ');
        const updateAssigns = keys.map(k => `\`${k.trim().toLowerCase()}\` = VALUES(\`${k.trim().toLowerCase()}\`)`).join(', ');
        const vals = keys.map(k => rowObj[k]);

        const sql = `INSERT INTO \`${tableName}\` (${cols}) VALUES (${placeholders}) ON DUPLICATE KEY UPDATE ${updateAssigns}`;
        await conn.query(sql, vals);
        successCount++;
      }
    } finally {
      conn.release();
    }

    console.log(`[Inbound DB Sync] Successfully upserted ${successCount} rows into ${tableName} from ${fileName}`);
    res.json({ success: true, table: tableName, count: successCount });
  } catch (err) {
    console.error('[Inbound DB Sync Error]', err.message);
    res.status(500).json({ error: 'Failed to sync inbound rows to DB', message: err.message });
  }
});

/**
 * @route   POST /api/login & POST /api/auth/login
 */
router.post(['/login', '/auth/login'], async (req, res) => {
  const employee_number = req.body.employee_number || req.body.employee_id || req.body.employeeId;
  const password = req.body.password;

  if (!employee_number || !password) {
    return res.status(400).json({ error: 'Employee number and password are required' });
  }

  try {
    // 1. Fetch employee details from manpower (flexible number matching)
    const empQuery = `SELECT * FROM manpower WHERE employee_number = ? OR CAST(employee_number AS UNSIGNED) = CAST(? AS UNSIGNED) LIMIT 1`;
    const [empRows] = await pool.query(empQuery, [employee_number, employee_number]);
    
    if (empRows.length === 0) {
      return res.status(401).json({ error: 'Invalid Employee Number or Password' });
    }
    
    const employee = empRows[0];

    // 2. Fetch designation directly from manpower table position_name
    const designation = employee.position_name || 'Employee';

    // 3. Fetch agent info for reporting officers from zhcm_lr_t_agents_03072026
    const agentQuery = `
      SELECT reporting_officer, reporting_officer_1 
      FROM zhcm_lr_t_agents_03072026 
      WHERE personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = ? LIMIT 1
    `;
    const [agentRows] = await pool.query(agentQuery, [employee_number, employee_number]);
    
    let reportingOfficer = '0';
    let reportingOfficer1 = '0';
    
    if (agentRows.length > 0) {
      reportingOfficer = agentRows[0].reporting_officer || '0';
      reportingOfficer1 = agentRows[0].reporting_officer_1 || '0';
    }

    // 4. Fetch custom password from user_accounts
    const credQuery = `SELECT password FROM user_accounts WHERE employee_number = ? OR CAST(employee_number AS UNSIGNED) = CAST(? AS UNSIGNED) LIMIT 1`;
    const [credRows] = await pool.query(credQuery, [employee_number, employee_number]);
    
    let isPasswordValid = false;
    let hasCustomPassword = false;

    if (credRows.length > 0) {
      isPasswordValid = credRows[0].password === password;
      hasCustomPassword = true;
    } else {
      if (employee.pan_number) {
        isPasswordValid = employee.pan_number.toString().trim().toUpperCase() === password.toString().trim().toUpperCase();
      }
    }

    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid Employee Number or Password' });
    }

    // 5. Fetch reporting officer names from manpower
    let reportingOfficerName = '';
    let reportingOfficer1Name = '';

    if (reportingOfficer !== '0' && reportingOfficer !== 'N/A') {
      const [roRows] = await pool.query('SELECT employee_name FROM manpower WHERE employee_number = ? LIMIT 1', [reportingOfficer]);
      if (roRows.length > 0) reportingOfficerName = roRows[0].employee_name;
    }
    if (reportingOfficer1 !== '0' && reportingOfficer1 !== 'N/A') {
      const [ro1Rows] = await pool.query('SELECT employee_name FROM manpower WHERE employee_number = ? LIMIT 1', [reportingOfficer1]);
      if (ro1Rows.length > 0) reportingOfficer1Name = ro1Rows[0].employee_name;
    }

    const mustChangePassword = !hasCustomPassword;

    // 6. Sign JWT token
    const tokenSecret = process.env.JWT_SECRET || 'fallback_secret';
    const token = jwt.sign({
      employee_number: employee.employee_number,
      employee_name: employee.employee_name,
      department: employee.department,
      position: designation
    }, tokenSecret, { expiresIn: '24h' });

    res.json({
      message: 'Login successful',
      token,
      must_change_password: mustChangePassword,
      employee: {
        id: employee.employee_number.toString(),
        employee_number: employee.employee_number,
        name: employee.employee_name,
        status: employee.employment_status,
        group: employee.employee_group,
        subgroup: employee.employee_subgroup_text,
        department: employee.department,
        position: designation,
        gender: employee.gender,
        email: employee.email_id,
        mobile: employee.mobile_number,
        pan_number: employee.pan_number,
        has_custom_password: hasCustomPassword,
        must_change_password: mustChangePassword,
        reporting_officer: reportingOfficer,
        reporting_officer_1: reportingOfficer1,
        reporting_officer_name: reportingOfficerName,
        reporting_officer_1_name: reportingOfficer1Name
      }
    });

  } catch (error) {
    console.error('[Login Error]', error.message);
    res.status(500).json({ error: 'Authentication failed', message: error.message });
  }
});

/**
 * @route   POST /api/change-password
 */
router.post('/change-password', authenticateToken, async (req, res) => {
  const { new_password } = req.body;
  const employeeId = req.user.employee_number;

  if (!new_password) {
    return res.status(400).json({ error: 'New password is required' });
  }

  try {
    const query = `
      INSERT INTO user_accounts (employee_number, password, updated_at) 
      VALUES (?, ?, NOW()) 
      ON DUPLICATE KEY UPDATE password = ?, updated_at = NOW()
    `;
    await pool.query(query, [employeeId, new_password, new_password]);
    res.json({ message: 'Password changed successfully' });
  } catch (error) {
    console.error('[Change Password Error]', error.message);
    res.status(500).json({ error: 'Failed to update password', message: error.message });
  }
});

/**
 * @route   GET /api/profile
 */
router.get('/profile', authenticateToken, async (req, res) => {
  const employeeId = req.query.employee_id || req.user.employee_number;
  try {
    const query = `
      SELECT 
        m.*, 
        m.employee_pension_number AS employee_pension_number,
        a.reporting_officer, 
        a.reporting_officer_1, 
        ro.employee_name AS reporting_officer_name,
        ro1.employee_name AS reporting_officer_1_name
      FROM manpower m 
      LEFT JOIN zhcm_lr_t_agents_03072026 a ON m.employee_number = a.personnel_number
      LEFT JOIN manpower ro ON a.reporting_officer = ro.employee_number
      LEFT JOIN manpower ro1 ON a.reporting_officer_1 = ro1.employee_number
      WHERE m.employee_number = ? LIMIT 1
    `;
    const [rows] = await pool.query(query, [employeeId]);
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Profile not found' });
    }

    const profileData = mapEmployeeRow(rows[0]);

    // Fetch family members from it0021_family_member
    const [familyRows] = await pool.query(
      'SELECT * FROM it0021_family_member WHERE personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = ?', 
      [employeeId, employeeId]
    );
    const familyMap = new Map();
    familyRows.forEach(f => {
      let fullName = `${f.first_name || ''} ${f.middle_name || ''} ${f.last_name || ''}`.trim();
      fullName = Array.from(new Set(fullName.split(/\s+/))).join(' ');
      if (!fullName || fullName === 'NULL' || fullName === 'N/A') return;

      if (!familyMap.has(fullName)) {
        let relation = 'Other';
        const cleanRel = (f.family_member || '').toString().trim();
        if (cleanRel === '1') relation = 'Spouse';
        else if (cleanRel === '2') relation = 'Child';
        else if (cleanRel === '11') relation = 'Father';
        else if (cleanRel === '12') relation = 'Mother';

        let genderStr = 'N/A';
        const cleanGender = (f.gender || '').toString().trim();
        if (cleanGender === '1') genderStr = 'Male';
        else if (cleanGender === '2') genderStr = 'Female';
        else if (f.gender) genderStr = f.gender;

        let age = 'N/A';
        if (f.date_of_birth) {
          const dobStr = String(f.date_of_birth).trim();
          let dobDate;
          if (dobStr.includes('.')) {
            const p = dobStr.split('.');
            if (p.length === 3) dobDate = new Date(p[2], parseInt(p[1]) - 1, p[0]);
          } else {
            dobDate = new Date(dobStr);
          }
          if (dobDate && !isNaN(dobDate.getTime())) {
            const today = new Date();
            let calculatedAge = today.getFullYear() - dobDate.getFullYear();
            const monthDiff = today.getMonth() - dobDate.getMonth();
            if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < dobDate.getDate())) {
              calculatedAge--;
            }
            age = calculatedAge > 0 ? calculatedAge.toString() : '0';
          }
        }

        familyMap.set(fullName, {
          name: fullName,
          relation,
          dob: formatDate(f.date_of_birth),
          age,
          gender: genderStr
        });
      }
    });
    profileData.familyMembers = Array.from(familyMap.values());

    // Fetch nominations from it0591_nomination
    const [nomineeRows] = await pool.query(
      'SELECT * FROM it0591_nomination WHERE personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = ? GROUP BY benefit_type, name_of_nominee', 
      [employeeId, employeeId]
    );
    const nominees = [];
    nomineeRows.forEach(n => {
      let benefitType = 'Other';
      const typeCode = (n.benefit_type || '').toString().trim().toUpperCase();
      if (typeCode === 'BNGR') benefitType = 'Gratuity';
      else if (typeCode === 'BNPF') benefitType = 'PF';
      else if (typeCode === 'BNPN') benefitType = 'Pension';
      else if (typeCode === 'BNBF') benefitType = 'FB';

      // Suffixes for nominee columns in table: empty, _1, _2, _3, _4
      const suffixes = ['', '_1', '_2', '_3', '_4'];
      suffixes.forEach(s => {
        const nomineeName = n[`name_of_nominee${s}`];
        if (nomineeName && nomineeName.toString().trim() !== '' && nomineeName.toString().trim() !== 'NULL') {
          nominees.push({
            benefit: benefitType,
            name: nomineeName.toString().trim(),
            relation: n[`relationship_with_employee${s}`] || 'N/A',
            dob: formatDate(n[`date_of_birth_of_nominee${s}`]) || 'N/A',
            percentage: n[`percentage_of_share${s}`] ? parseFloat(n[`percentage_of_share${s}`]) : 0
          });
        }
      });
    });
    profileData.nominees = nominees;

    res.json(profileData);
  } catch (error) {
    console.error('[Get Profile Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch employee profile', message: error.message });
  }
});

/**
 * @route   POST /api/profile/update
 */
router.post('/profile/update', authenticateToken, async (req, res) => {
  const { mobile, email } = req.body;
  const employeeId = req.user.employee_number;

  try {
    await pool.query('UPDATE manpower SET mobile_number = ?, email_id = ? WHERE employee_number = ?', [mobile, email, employeeId]);
    res.json({ message: 'Profile updated successfully' });
  } catch (error) {
    console.error('[Update Profile Error]', error.message);
    res.status(500).json({ error: 'Failed to update profile', message: error.message });
  }
});

/**
 * @route   POST /api/tours/delete
 */
router.post('/tours/delete', authenticateToken, async (req, res) => {
  const { tour_id } = req.body;
  const employeeId = req.user.employee_number;
  try {
    await pool.query(
      'DELETE FROM travel WHERE id = ? AND (personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = ?)',
      [tour_id, employeeId, employeeId]
    );
    res.json({ message: 'Tour deleted successfully' });
  } catch (error) {
    console.error('[Delete Tour Error]', error.message);
    res.status(500).json({ error: 'Failed to delete tour', message: error.message });
  }
});

/**
 * @route   GET /api/leaves
 */
router.get('/leaves', authenticateToken, async (req, res) => {
  const employeeId = req.query.employee_id || req.user.employee_number;
  try {
    const query = `
      SELECT 
        a.*, 
        h.document_status, 
        h.last_changed_by,
        ro.employee_name AS processor_name,
        ro1.employee_name AS processor1_name
      FROM ptreq_attabsdata_leave_apply_1 a
      LEFT JOIN ptreq_header_leave_approved_1 h ON a.id_of_request_item = h.document_identification
      LEFT JOIN zhcm_lr_t_agents_03072026 ag ON CAST(a.personnel_number AS UNSIGNED) = CAST(ag.personnel_number AS UNSIGNED)
      LEFT JOIN manpower ro ON CAST(ag.reporting_officer AS UNSIGNED) = ro.employee_number
      LEFT JOIN manpower ro1 ON CAST(ag.reporting_officer_1 AS UNSIGNED) = ro1.employee_number
      WHERE a.personnel_number = ? OR CAST(a.personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED)
      GROUP BY a.id_of_request_item
      ORDER BY a.start_date DESC
    `;
    const [rows] = await pool.query(query, [employeeId, employeeId]);
    const leaves = rows.map(row => {
      let status = 'Approved';
      if (row.document_status === 'SENT') status = 'Pending L1';
      else if (row.document_status === 'SENT_L2') status = 'Pending L2';
      else if (row.document_status === 'REJECTED') status = 'Rejected';
      else if (row.document_status === 'APPROVED' || row.document_status === 'POSTED') status = 'Approved';

      let leaveType = 'Earned leave';
      if (row.sub_type === '1001') leaveType = 'Casual Leave';
      else if (row.sub_type === '1002') leaveType = 'HPL';
      else if (row.sub_type === '1003') leaveType = 'CHPL';
      else if (row.sub_type === '1010') leaveType = 'Optional Leave';
      else if (row.sub_type === '2000' || row.sub_type === '2008') leaveType = 'Special Leave';

      const formatIso = (dateVal) => {
        if (!dateVal) return null;
        const str = String(dateVal).trim();
        if (str.includes('.')) {
          const p = str.split('.');
          if (p.length === 3) {
            const d = new Date(p[2], parseInt(p[1]) - 1, p[0]);
            return isNaN(d.getTime()) ? null : d.toISOString();
          }
        }
        try {
          const d = new Date(dateVal);
          return isNaN(d.getTime()) ? null : d.toISOString();
        } catch (_) {
          return null;
        }
      };

      const startIso = formatIso(row.start_date);
      const endIso = formatIso(row.end_date);

      const computedDays = row.att_abs_days ? parseFloat(row.att_abs_days) : calculateDays(row.start_date, row.end_date);

      return {
        id: row.id_of_request_item,
        employeeId: row.personnel_number ? row.personnel_number.toString() : employeeId.toString(),
        leaveType,
        startDate: startIso,
        startTime: row.start_time || '00:00:00',
        endDate: endIso,
        endTime: row.end_time || '00:00:00',
        duration: `${computedDays} Day(s)`,
        used: `${computedDays} Day(s)`,
        status,
        appliedOn: startIso,
        approvedOn: status === 'Approved' ? endIso : null,
        reason: 'Personal affairs',
        processor: row.processor_name || '-',
        processor1: row.processor1_name || '-'
      };
    });
    res.json(leaves);
  } catch (error) {
    console.error('[Get Leaves Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch leaves list', message: error.message });
  }
});

/**
 * @route   GET /api/employee-leave-details/:empId
 * @desc    Returns employee name + all leave quota details from DB
 */
router.get('/employee-leave-details/:empId', authenticateToken, async (req, res) => {
  const empId = req.params.empId;
  try {
    // 1. Get employee name from manpower
    const [empRows] = await pool.query(
      'SELECT employee_number, employee_name FROM manpower WHERE employee_number = ? OR CAST(employee_number AS UNSIGNED) = CAST(? AS UNSIGNED) LIMIT 1',
      [empId, empId]
    );
    const employeeName = empRows.length > 0 ? empRows[0].employee_name : null;

    // 2. Get all leave quotas from leave_quota
    const [quotaRows] = await pool.query(
      'SELECT sub_type, absence_quota_type, quota_number, quota_deduction, deduction_from, deduction_to, start_date, end_date FROM leave_quota WHERE personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED) GROUP BY sub_type',
      [empId, empId]
    );

    const leaveDetails = quotaRows.map(row => {
      const ent = parseFloat(row.quota_number || 0);
      const taken = parseFloat(row.quota_deduction || 0);
      const bal = ent - taken;

      let leaveType = 'Other';
      const sub = (row.sub_type || '').toString().trim();
      if (sub === '01') leaveType = 'Earned Leave';
      else if (sub === '02') leaveType = 'Casual Leave';
      else if (sub === '03') leaveType = 'HPL';
      else if (sub === '05') leaveType = 'Optional Holiday';

      return {
        leaveType,
        subType: sub,
        entitlement: ent,
        taken,
        balance: bal,
        deductionFrom: row.deduction_from || row.start_date,
        deductionTo: row.deduction_to || row.end_date
      };
    });

    // 3. Get reporting officers
    const [agentRows] = await pool.query(
      'SELECT reporting_officer, reporting_officer_1 FROM zhcm_lr_t_agents_03072026 WHERE personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED) LIMIT 1',
      [empId, empId]
    );

    let reportingOfficer = null;
    let reportingOfficer1 = null;
    if (agentRows.length > 0) {
      const ro = (agentRows[0].reporting_officer || '').toString().trim();
      const ro1 = (agentRows[0].reporting_officer_1 || '').toString().trim();
      if (ro && ro !== '0' && ro !== 'N/A') {
        const [roName] = await pool.query('SELECT employee_name FROM manpower WHERE employee_number = ? LIMIT 1', [ro]);
        reportingOfficer = { id: ro, name: roName.length > 0 ? roName[0].employee_name : ro };
      }
      if (ro1 && ro1 !== '0' && ro1 !== 'N/A') {
        const [ro1Name] = await pool.query('SELECT employee_name FROM manpower WHERE employee_number = ? LIMIT 1', [ro1]);
        reportingOfficer1 = { id: ro1, name: ro1Name.length > 0 ? ro1Name[0].employee_name : ro1 };
      }
    }

    const earnedLeave = leaveDetails.find(l => l.subType === '01');

    res.json({
      employeeNumber: empId,
      employeeName: employeeName || `Employee ${empId}`,
      earnedLeaveBalance: earnedLeave ? earnedLeave.balance : 0.0,
      earnedLeaveEntitlement: earnedLeave ? earnedLeave.entitlement : 0.0,
      earnedLeaveTaken: earnedLeave ? earnedLeave.taken : 0.0,
      leaveDetails,
      reportingOfficer,
      reportingOfficer1
    });
  } catch (error) {
    console.error('[Get Employee Leave Details Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch employee leave details', message: error.message });
  }
});

/**
 * @route   GET /api/leave-balances
 */
router.get('/leave-balances', authenticateToken, async (req, res) => {
  const employeeId = req.query.employee_id || req.user.employee_number;
  try {
    const [rows] = await pool.query('SELECT * FROM leave_quota WHERE personnel_number = ? GROUP BY sub_type', [employeeId]);
    const balances = rows.map(row => {
      const ent = parseFloat(row.quota_number || 0);
      const taken = parseFloat(row.quota_deduction || 0);
      const bal = ent - taken;
      
      let leaveType = 'Other';
      let typeId = row.absence_quota_type;
      
      const sub = (row.sub_type || '').toString().trim();
      if (sub === '01') {
        leaveType = 'Earned leave';
        typeId = '1000';
      } else if (sub === '02') {
        leaveType = 'Casual Leave';
        typeId = '1001';
      } else if (sub === '03') {
        leaveType = 'HPL';
        typeId = '1002';
      } else if (sub === '05') {
        leaveType = 'Optional Holiday';
        typeId = '1010';
      }

      return {
        timeAccount: leaveType,
        typeId: typeId,
        entitlementMinusPlanned: bal,
        entitlement: ent,
        taken,
        planned: 0.0,
        deductionFrom: row.deduction_from || row.start_date,
        deductionTo: row.deduction_to || row.end_date
      };
    });
    res.json(balances);
  } catch (error) {
    console.error('[Get Leave Balances Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch leave balances', message: error.message });
  }
});

/**
 * @route   POST /api/leaves and POST /api/leaves/apply
 */
router.post(['/leaves', '/leaves/apply'], authenticateToken, async (req, res) => {
  const leave_type = req.body.leave_type || req.body.leaveType;
  const start_date = req.body.start_date || req.body.startDate;
  const end_date = req.body.end_date || req.body.endDate;
  const start_time = req.body.start_time || req.body.beginTime;
  const end_time = req.body.end_time || req.body.endTime;
  const duration = req.body.duration;
  const reason = req.body.reason || req.body.note;

  const employeeId = req.user.employee_number;

  try {
    // 1. Verify that reporting officers exist
    const agentQuery = `
      SELECT reporting_officer, reporting_officer_1 
      FROM zhcm_lr_t_agents_03072026 
      WHERE personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = ? LIMIT 1
    `;
    const [agentRows] = await pool.query(agentQuery, [employeeId, employeeId]);
    
    let ro = '0';
    let ro1 = '0';
    if (agentRows.length > 0) {
      ro = (agentRows[0].reporting_officer || '0').toString().trim();
      ro1 = (agentRows[0].reporting_officer_1 || '0').toString().trim();
    }

    if ((ro === '0' || ro === 'N/A' || !ro) && (ro1 === '0' || ro1 === 'N/A' || !ro1)) {
      return res.status(400).json({ error: 'Missing reporting officers. Please connect to HR office.' });
    }

    // 2. Determine Subtype code
    let subType = '1000'; // EL
    if (leave_type === 'Casual Leave') subType = '1001';
    else if (leave_type === 'HPL') subType = '1002';
    else if (leave_type === 'CHPL') subType = '1003';
    else if (leave_type === 'Optional Leave') subType = '1010';

    const reqItemId = generateHexId();
    const conn = await pool.getConnection();
    await conn.beginTransaction();

    try {
      // Calculate leave days count dynamically
      const formattedStartDate = formatDateDdMmYyyy(start_date);
      const formattedEndDate = formatDateDdMmYyyy(end_date);
      const daysCount = calculateDays(formattedStartDate, formattedEndDate, duration === 'Half-Day');
      const startDateTimeStr = `${formattedStartDate} 00:00:00`;
      const endDateTimeStr = `${formattedEndDate} 00:00:00`;

      // HPL / CHPL can have custom times. Others have 00:00:00.
      const beginTimeStr = (subType === '1002' || subType === '1003') ? (start_time || '09:00:00') : '00:00:00';
      const endTimeStr = (subType === '1002' || subType === '1003') ? (end_time || '17:30:00') : '00:00:00';

      // Insert into ptreq_attabsdata_leave_apply_1
      const applyQuery = `
        INSERT INTO ptreq_attabsdata_leave_apply_1 (
          id_of_request_item, infotype_operation, infotype, start_time, end_time, absence_hours, 
          personnel_number, sub_type, start_date, end_date, att_abs_days, calendar_days, full_day, payroll_days, payroll_hours, lock_indicator
        ) VALUES (?, 'INS', '2001', ?, ?, '8.00', ?, ?, ?, ?, ?, ?, 'X', ?, '8.00', 'P')
      `;
      await conn.query(applyQuery, [
        reqItemId, beginTimeStr, endTimeStr, employeeId, subType, formattedStartDate, formattedEndDate, daysCount, daysCount, daysCount
      ]);

      // Insert into ptreq_header_leave_approved_1
      const [maxIdRows] = await conn.query('SELECT MAX(CAST(id AS UNSIGNED)) AS max_id FROM ptreq_header_leave_approved_1');
      const nextId = (maxIdRows[0].max_id || 4800000) + 1;

      const headerQuery = `
        INSERT INTO ptreq_header_leave_approved_1 (
          document_identification, document_version, document_category, document_status, 
          guid, guid_1, guid_2, guid_3, guid_4, guid_5, guid_6, guid_7, 
          id_of_request_item_list, last_changed_by, time_stamp, time_zone, id
        ) VALUES (?, '2', 'ABSREQ', 'SENT', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 'INDIA', ?)
      `;
      const randomGuid = generateHexId();
      await conn.query(headerQuery, [
        reqItemId, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, reqItemId, employeeId, nextId
      ]);

      // Sync into old absence table to prevent layout breakages
      const absenceQuery = `
        INSERT INTO absence (personnel_number, sub_type, start_date, end_date, start_time, end_time, att_abs_days, lock_indicator, changed_on, changed_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'P', NOW(), 'HR_app')
      `;
      await conn.query(absenceQuery, [
        employeeId, subType === '1000' ? '1' : (subType === '1001' ? '2' : '3'), formattedStartDate, formattedEndDate, beginTimeStr, endTimeStr, daysCount
      ]);

      await conn.commit();

      // Record Outbound Delta Changes for FTP Sync
      await recordOutboundChange(
        'PTREQ_ATTABSDATA_Leave_Apply',
        reqItemId,
        'INSERT',
        { personnel_number: employeeId, sub_type: subType, start_date: formattedStartDate, end_date: formattedEndDate, reason: reason },
        { id_of_request_item: reqItemId, personnel_number: employeeId, sub_type: subType, start_date: formattedStartDate, end_date: formattedEndDate, lock_indicator: 'P' }
      );
      await recordOutboundChange(
        'PTREQ_HEADER_Leave_Approved',
        reqItemId,
        'INSERT',
        { document_identification: reqItemId, document_status: 'SENT', last_changed_by: employeeId },
        { document_identification: reqItemId, document_status: 'SENT', last_changed_by: employeeId }
      );

      // Trigger notifications for applicant, RO, and RO1
      const applicantName = await getEmployeeName(employeeId);
      const datesText = `${start_date.toString().split('T')[0]} to ${end_date.toString().split('T')[0]}`;

      // 1. Applicant notification
      await createNotification(
        employeeId,
        'Leave Application Submitted',
        `Your ${leave_type} application (${datesText}) has been submitted successfully for approval.`,
        'Leave'
      );

      // 2. Reporting Officer (L1) notification
      if (ro && ro !== '0' && ro !== 'N/A') {
        await createNotification(
          ro,
          'New Leave Request',
          `${applicantName} (${employeeId}) applied for ${leave_type} (${datesText}).`,
          'Leave'
        );
      }

      // 3. Reporting Officer 1 (L2) notification
      if (ro1 && ro1 !== '0' && ro1 !== 'N/A' && ro1 !== ro) {
        await createNotification(
          ro1,
          'New Leave Request',
          `${applicantName} (${employeeId}) applied for ${leave_type} (${datesText}).`,
          'Leave'
        );
      }

      // 4. Trigger ZHR_LEAVE_SEND SMS notification to RO & RO1
      try {
        if (ro && ro !== '0' && ro !== 'N/A') {
          const roMobile = await getEmployeeMobile(ro);
          sendLeaveAppliedSms({
            mobileNumber: roMobile,
            applicantName: applicantName,
            leaveType: leave_type,
            startDate: start_date,
            endDate: end_date
          }).catch(err => console.error('[SMS Applied L1 Error]', err.message));
        }
        if (ro1 && ro1 !== '0' && ro1 !== 'N/A' && ro1 !== ro) {
          const ro1Mobile = await getEmployeeMobile(ro1);
          sendLeaveAppliedSms({
            mobileNumber: ro1Mobile,
            applicantName: applicantName,
            leaveType: leave_type,
            startDate: start_date,
            endDate: end_date
          }).catch(err => console.error('[SMS Applied L2 Error]', err.message));
        }
      } catch (smsErr) {
        console.error('[SMS Leave Applied Error]', smsErr.message);
      }

      res.status(201).json({ message: 'Leave application submitted successfully', leaveId: reqItemId });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (error) {
    console.error('[Apply Leave Error]', error.message);
    res.status(500).json({ error: 'Failed to apply for leave', message: error.message });
  }
});

/**
 * @route   GET /api/leaves/pending-approvals
 */
router.get('/leaves/pending-approvals', authenticateToken, async (req, res) => {
  const managerId = req.user.employee_number;
  try {
    // A manager sees a request if they are L1 and status is SENT, OR if they are L2 and status is SENT_L2
    const query = `
      SELECT a.*, h.document_status, m.employee_name AS applicant_name, 
             ag.reporting_officer, ag.reporting_officer_1
      FROM ptreq_attabsdata_leave_apply_1 a
      JOIN ptreq_header_leave_approved_1 h ON a.id_of_request_item = h.document_identification
      JOIN manpower m ON CAST(a.personnel_number AS UNSIGNED) = CAST(m.employee_number AS UNSIGNED)
      JOIN zhcm_lr_t_agents_03072026 ag ON CAST(a.personnel_number AS UNSIGNED) = CAST(ag.personnel_number AS UNSIGNED)
      WHERE 
        (h.document_status = 'SENT' AND CAST(ag.reporting_officer AS UNSIGNED) = CAST(? AS UNSIGNED))
        OR
        (h.document_status = 'SENT_L2' AND CAST(ag.reporting_officer_1 AS UNSIGNED) = CAST(? AS UNSIGNED))
      ORDER BY a.start_date DESC
    `;
    const [rows] = await pool.query(query, [managerId, managerId]);
    const pending = rows.map(row => {
      let leaveType = 'Earned leave';
      if (row.sub_type === '1001') leaveType = 'Casual Leave';
      else if (row.sub_type === '1002') leaveType = 'HPL';
      else if (row.sub_type === '1003') leaveType = 'CHPL';
      else if (row.sub_type === '1010') leaveType = 'Optional Leave';

      return {
        id: row.id_of_request_item,
        employeeId: `${row.personnel_number} (${row.applicant_name})`,
        leaveType,
        startDate: row.start_date,
        startTime: row.start_time || '00:00:00',
        endDate: row.end_date,
        endTime: row.end_time || '00:00:00',
        duration: `${row.att_abs_days || 1} Day(s)`,
        status: row.document_status === 'SENT' ? 'Pending L1' : 'Pending L2',
        appliedOn: row.start_date,
        reason: 'Personal Emergency',
        processor: 'Manager'
      };
    });
    res.json(pending);
  } catch (error) {
    console.error('[Get Leave Approvals Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch pending leave approvals', message: error.message });
  }
});

/**
 * @route   POST /api/leaves/approve
 */
router.post('/leaves/approve', authenticateToken, async (req, res) => {
  const { leave_id, remarks } = req.body;
  const managerId = req.user.employee_number;

  try {
    const headerQuery = `SELECT * FROM ptreq_header_leave_approved_1 WHERE document_identification = ? LIMIT 1`;
    const [headers] = await pool.query(headerQuery, [leave_id]);
    if (headers.length === 0) {
      return res.status(404).json({ error: 'Leave request not found' });
    }

    const requestHeader = headers[0];
    const applicantId = requestHeader.last_changed_by;

    // Get reporting officers of applicant
    const agentQuery = `SELECT reporting_officer, reporting_officer_1 FROM zhcm_lr_t_agents_03072026 WHERE personnel_number = ? LIMIT 1`;
    const [agents] = await pool.query(agentQuery, [applicantId]);
    if (agents.length === 0) {
      return res.status(400).json({ error: 'Applicant agent mapping not found' });
    }

    const { reporting_officer: l1, reporting_officer_1: l2 } = agents[0];
    let nextStatus = 'APPROVED';

    if (requestHeader.document_status === 'SENT' && l1 == managerId) {
      // Approved by L1. Advance to L2 if L2 exists, else fully approve.
      if (l2 && l2 !== '0' && l2 !== 'N/A') {
        nextStatus = 'SENT_L2';
      } else {
        nextStatus = 'APPROVED';
      }
    } else if (requestHeader.document_status === 'SENT_L2' && l2 == managerId) {
      // Approved by L2. Fully approve.
      nextStatus = 'APPROVED';
    } else {
      return res.status(403).json({ error: 'You are not the designated approver for this request stage' });
    }

    // Update status in header table
    await pool.query('UPDATE ptreq_header_leave_approved_1 SET document_status = ? WHERE document_identification = ?', [nextStatus, leave_id]);

    // Sync state to old absence table
    const lockIndicator = nextStatus === 'SENT_L2' ? 'P2' : (nextStatus === 'APPROVED' ? null : 'P');
    await pool.query(
      'UPDATE absence SET lock_indicator = ? WHERE personnel_number = ? AND start_date = (SELECT start_date FROM ptreq_attabsdata_leave_apply_1 WHERE id_of_request_item = ?)',
      [lockIndicator, applicantId, leave_id]
    );

    await logApproval(managerId, 'Leave', leave_id, applicantId, 'Approved', remarks);

    // Record Outbound Delta Change for FTP Outbound Sync
    await recordOutboundChange(
      'PTREQ_HEADER_Leave_Approved',
      leave_id,
      'UPDATE',
      { document_status: nextStatus, last_changed_by: managerId, remarks: remarks || '' },
      { document_identification: leave_id, document_status: nextStatus, last_changed_by: managerId }
    );

    const managerName = await getEmployeeName(managerId);
    const applicantName = await getEmployeeName(applicantId);

    if (nextStatus === 'APPROVED') {
      await createNotification(
        applicantId,
        'Leave Request Approved',
        `Your leave request has been approved by ${managerName}.${remarks ? ' Remarks: ' + remarks : ''}`,
        'Leave'
      );
      if (l1 && l1 !== '0' && l1 !== 'N/A' && l1 != managerId) {
        await createNotification(
          l1,
          'Leave Request Approved',
          `Leave request for ${applicantName} has been approved by ${managerName}.`,
          'Leave'
        );
      }
    } else if (nextStatus === 'SENT_L2') {
      await createNotification(
        applicantId,
        'Leave Request L1 Approved',
        `Your leave request has been approved by L1 (${managerName}) and is pending L2 approval.`,
        'Leave'
      );
      if (l2 && l2 !== '0' && l2 !== 'N/A') {
        await createNotification(
          l2,
          'Pending Leave Approval',
          `Leave request for ${applicantName} (approved by L1 ${managerName}) is pending your approval.`,
          'Leave'
        );
      }
    }

    // Trigger ZHR_LEAVE_APPROVE2 SMS to applicant
    try {
      const [leaveRows] = await pool.query(
        'SELECT sub_type, start_date, end_date FROM ptreq_attabsdata_leave_apply_1 WHERE id_of_request_item = ? LIMIT 1',
        [leave_id]
      );
      if (leaveRows.length > 0) {
        const lRow = leaveRows[0];
        let leaveTypeStr = 'Earned Leave';
        if (lRow.sub_type === '1001') leaveTypeStr = 'Casual Leave';
        else if (lRow.sub_type === '1002') leaveTypeStr = 'HPL';
        else if (lRow.sub_type === '1003') leaveTypeStr = 'CHPL';
        else if (lRow.sub_type === '1010') leaveTypeStr = 'Optional Leave';

        const applicantMobile = await getEmployeeMobile(applicantId);
        sendLeaveApprovedSms({
          mobileNumber: applicantMobile,
          approverName: managerName,
          leaveType: leaveTypeStr,
          startDate: lRow.start_date,
          endDate: lRow.end_date
        }).catch(err => console.error('[SMS Approve Error]', err.message));
      }
    } catch (smsErr) {
      console.error('[SMS Leave Approve Error]', smsErr.message);
    }

    res.json({ message: 'Leave request approved successfully', status: nextStatus });
  } catch (error) {
    console.error('[Approve Leave Error]', error.message);
    res.status(500).json({ error: 'Failed to approve leave', message: error.message });
  }
});

/**
 * @route   POST /api/leaves/reject
 */
router.post('/leaves/reject', authenticateToken, async (req, res) => {
  const { leave_id, remarks } = req.body;
  const managerId = req.user.employee_number;

  try {
    const headerQuery = `SELECT * FROM ptreq_header_leave_approved_1 WHERE document_identification = ? LIMIT 1`;
    const [headers] = await pool.query(headerQuery, [leave_id]);
    if (headers.length === 0) {
      return res.status(404).json({ error: 'Leave request not found' });
    }

    const requestHeader = headers[0];
    const applicantId = requestHeader.last_changed_by;

    // Get reporting officers of applicant
    const agentQuery = `SELECT reporting_officer, reporting_officer_1 FROM zhcm_lr_t_agents_03072026 WHERE personnel_number = ? LIMIT 1`;
    const [agents] = await pool.query(agentQuery, [applicantId]);
    if (agents.length === 0) {
      return res.status(400).json({ error: 'Applicant agent mapping not found' });
    }

    const { reporting_officer: l1, reporting_officer_1: l2 } = agents[0];
    if (l1 == managerId || l2 == managerId) {
      await pool.query('UPDATE ptreq_header_leave_approved_1 SET document_status = "REJECTED" WHERE document_identification = ?', [leave_id]);
      await pool.query(
        'UPDATE absence SET lock_indicator = "R" WHERE personnel_number = ? AND start_date = (SELECT start_date FROM ptreq_attabsdata_leave_apply_1 WHERE id_of_request_item = ?)',
        [applicantId, leave_id]
      );
      await logApproval(managerId, 'Leave', leave_id, applicantId, 'Rejected', remarks);

      const managerName = await getEmployeeName(managerId);
      const applicantName = await getEmployeeName(applicantId);

      await createNotification(
        applicantId,
        'Leave Request Rejected',
        `Your leave request has been rejected by ${managerName}.${remarks ? ' Remarks: ' + remarks : ''}`,
        'Leave'
      );

      if (l1 && l1 !== '0' && l1 !== 'N/A' && l1 != managerId) {
        await createNotification(
          l1,
          'Leave Request Rejected',
          `Leave request for ${applicantName} has been rejected by ${managerName}.`,
          'Leave'
        );
      }
      if (l2 && l2 !== '0' && l2 !== 'N/A' && l2 != managerId && l2 != l1) {
        await createNotification(
          l2,
          'Leave Request Rejected',
          `Leave request for ${applicantName} has been rejected by ${managerName}.`,
          'Leave'
        );
      }

      // Trigger ZHR_LEAVE_REJECT1 / ZHR_LEAVE_REJECT2 SMS to applicant
      try {
        const [leaveRows] = await pool.query(
          'SELECT sub_type, start_date, end_date FROM ptreq_attabsdata_leave_apply_1 WHERE id_of_request_item = ? LIMIT 1',
          [leave_id]
        );
        if (leaveRows.length > 0) {
          const lRow = leaveRows[0];
          let leaveTypeStr = 'Earned Leave';
          if (lRow.sub_type === '1001') leaveTypeStr = 'Casual Leave';
          else if (lRow.sub_type === '1002') leaveTypeStr = 'HPL';
          else if (lRow.sub_type === '1003') leaveTypeStr = 'CHPL';
          else if (lRow.sub_type === '1010') leaveTypeStr = 'Optional Leave';

          const applicantMobile = await getEmployeeMobile(applicantId);
          const rejectStage = (requestHeader.document_status === 'SENT_L2' || l2 == managerId) ? 2 : 1;
          sendLeaveRejectedSms({
            mobileNumber: applicantMobile,
            approverName: managerName,
            leaveType: leaveTypeStr,
            startDate: lRow.start_date,
            endDate: lRow.end_date,
            stage: rejectStage
          }).catch(err => console.error('[SMS Reject Error]', err.message));
        }
      } catch (smsErr) {
        console.error('[SMS Leave Reject Error]', smsErr.message);
      }

      res.json({ message: 'Leave request rejected successfully' });
    } else {
      res.status(403).json({ error: 'You are not designated to reject this request' });
    }
  } catch (error) {
    console.error('[Reject Leave Error]', error.message);
    res.status(500).json({ error: 'Failed to reject leave', message: error.message });
  }
});

/**
 * @route   GET /api/tours
 */
router.get('/tours', authenticateToken, async (req, res) => {
  const employeeId = req.query.employee_id || req.user.employee_number;
  try {
    const query = `
      SELECT 
        tr.*, 
        ag.reporting_officer, 
        ag.reporting_officer_1,
        ro.employee_name AS reporting_officer_name,
        ro1.employee_name AS reporting_officer_1_name
      FROM travel tr
      LEFT JOIN zhcm_lr_t_agents_03072026 ag ON CAST(tr.personnel_number AS UNSIGNED) = CAST(ag.personnel_number AS UNSIGNED)
      LEFT JOIN manpower ro ON CAST(ag.reporting_officer AS UNSIGNED) = CAST(ro.employee_number AS UNSIGNED)
      LEFT JOIN manpower ro1 ON CAST(ag.reporting_officer_1 AS UNSIGNED) = CAST(ro1.employee_number AS UNSIGNED)
      WHERE tr.personnel_number = ? OR CAST(tr.personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED)
      ORDER BY tr.beginning_date_of_trip_segment DESC
    `;
    const [rows] = await pool.query(query, [employeeId, employeeId]);
    const tours = rows.map(row => {
      let status = 'Approved';
      if (row.planning_status === '0') status = 'Draft';
      else if (row.planning_status === '1') status = 'Pending L1';
      else if (row.planning_status === '11') status = 'Pending L2';
      else if (row.planning_status === '3') status = 'Rejected';

      let activityType = 'Official Tour';
      const rawAct = (row.trip_activity_type || '').toString().trim().toUpperCase();
      if (rawAct === 'B') {
        activityType = 'Official Tour';
      } else if (rawAct && rawAct !== 'NULL') {
        activityType = rawAct;
      }

      return {
        id: row.id.toString(),
        employeeId: row.personnel_number.toString(),
        destination: row.trip_destination || 'N/A',
        startDate: formatIsoDate(row.beginning_date_of_trip_segment) || row.beginning_date_of_trip_segment,
        endDate: formatIsoDate(row.end_date_of_trip_segment) || row.end_date_of_trip_segment,
        travelPurpose: row.reason_for_trip || 'Official Work',
        transportMode: row.depart_res_workplace || 'Train',
        tourType: activityType,
        status,
        appliedOn: row.changed_on || row.beginning_date_of_trip_segment,
        approvedOn: row.planning_status === '2' ? row.changed_on : null,
        reportingOfficer: (row.reporting_officer || '').toString(),
        reportingOfficerName: row.reporting_officer_name || '',
        reportingOfficer1: (row.reporting_officer_1 || '').toString(),
        reportingOfficer1Name: row.reporting_officer_1_name || ''
      };
    });
    res.json(tours);
  } catch (error) {
    console.error('[Get Tours Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch tours list', message: error.message });
  }
});

/**
 * @route   POST /api/tours/apply
 */
router.post('/tours/apply', authenticateToken, async (req, res) => {
  const { tour_id, id, destination, start_date, end_date, purpose, transport_mode, tour_type, status } = req.body;
  const employeeId = req.user.employee_number;

  try {
    // Verify that reporting officers exist
    const agentQuery = `
      SELECT reporting_officer, reporting_officer_1 
      FROM zhcm_lr_t_agents_03072026 
      WHERE personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = ? LIMIT 1
    `;
    const [agentRows] = await pool.query(agentQuery, [employeeId, employeeId]);
    
    let ro = '0';
    let ro1 = '0';
    if (agentRows.length > 0) {
      ro = (agentRows[0].reporting_officer || '0').toString().trim();
      ro1 = (agentRows[0].reporting_officer_1 || '0').toString().trim();
    }

    if ((ro === '0' || ro === 'N/A' || !ro) && (ro1 === '0' || ro1 === 'N/A' || !ro1)) {
      return res.status(400).json({ error: 'Missing reporting officers. Please connect to HR office.' });
    }

    const formattedStartDate = formatIsoDate(start_date) || start_date;
    const formattedEndDate = formatIsoDate(end_date) || end_date;

    const isDraft = status === 'Draft';
    const newPlanningStatus = isDraft ? '0' : '1'; // '0' = Draft, '1' = Pending L1

    const targetTourId = tour_id || id;
    let existingId = null;

    if (targetTourId) {
      const [checkRows] = await pool.query(
        'SELECT id FROM travel WHERE id = ? AND (personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = ?) LIMIT 1',
        [targetTourId, employeeId, employeeId]
      );
      if (checkRows.length > 0) {
        existingId = checkRows[0].id;
      }
    }

    // If no explicit ID match, check if there is an existing Draft record for this employee
    if (!existingId) {
      const [draftRows] = await pool.query(
        'SELECT id FROM travel WHERE (personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = ?) AND planning_status = "0" ORDER BY id DESC LIMIT 1',
        [employeeId, employeeId]
      );
      if (draftRows.length > 0) {
        existingId = draftRows[0].id;
      }
    }

    let recordId;
    if (existingId) {
      // UPDATE EXISTING DRAFT / TRIP RECORD TO PENDING (OR DRAFT) TO PREVENT DUPLICATES!
      const updateQuery = `
        UPDATE travel 
        SET 
          trip_destination = ?, 
          beginning_date_of_trip_segment = ?, 
          end_date_of_trip_segment = ?, 
          reason_for_trip = ?, 
          depart_res_workplace = ?, 
          trip_activity_type = ?, 
          planning_status = ?, 
          changed_on = NOW(), 
          changed_by = 'HR_app'
        WHERE id = ?
      `;
      await pool.query(updateQuery, [destination, formattedStartDate, formattedEndDate, purpose, transport_mode, tour_type, newPlanningStatus, existingId]);
      recordId = existingId;

      await recordOutboundChange(
        'travel',
        recordId,
        'UPDATE',
        { personnel_number: employeeId, trip_destination: destination, beginning_date_of_trip_segment: formattedStartDate, end_date_of_trip_segment: formattedEndDate, reason_for_trip: purpose, planning_status: newPlanningStatus },
        { id: recordId, personnel_number: employeeId, trip_destination: destination }
      );
    } else {
      // INSERT NEW RECORD ONLY IF NO PREVIOUS DRAFT / MATCHING TRIP RECORD EXISTS
      const insertQuery = `
        INSERT INTO travel (personnel_number, trip_destination, beginning_date_of_trip_segment, end_date_of_trip_segment, reason_for_trip, depart_res_workplace, trip_activity_type, planning_status, changed_on, changed_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), 'HR_app')
      `;
      const [result] = await pool.query(insertQuery, [employeeId, destination, formattedStartDate, formattedEndDate, purpose, transport_mode, tour_type, newPlanningStatus]);
      recordId = result.insertId;

      await recordOutboundChange(
        'travel',
        recordId,
        'INSERT',
        { personnel_number: employeeId, trip_destination: destination, beginning_date_of_trip_segment: formattedStartDate, end_date_of_trip_segment: formattedEndDate, reason_for_trip: purpose, planning_status: newPlanningStatus },
        { id: recordId, personnel_number: employeeId, trip_destination: destination }
      );
    }

    // Trigger notifications for applicant, RO, and RO1
    const applicantName = await getEmployeeName(employeeId);
    const datesText = `${formattedStartDate} to ${formattedEndDate}`;

    // 1. Applicant notification
    await createNotification(
      employeeId,
      'Tour Application Submitted',
      `Your tour application to ${destination || 'destination'} (${datesText}) has been submitted successfully for approval.`,
      'Tour'
    );

    // 2. Reporting Officer (L1) notification
    if (ro && ro !== '0' && ro !== 'N/A') {
      await createNotification(
        ro,
        'New Tour Request',
        `${applicantName} (${employeeId}) applied for Tour to ${destination || 'destination'} (${datesText}).`,
        'Tour'
      );
    }

    // 3. Reporting Officer 1 (L2) notification
    if (ro1 && ro1 !== '0' && ro1 !== 'N/A' && ro1 !== ro) {
      await createNotification(
        ro1,
        'New Tour Request',
        `${applicantName} (${employeeId}) applied for Tour to ${destination || 'destination'} (${datesText}).`,
        'Tour'
      );
    }

    res.status(201).json({ message: 'Tour request submitted successfully', tourId: recordId });
  } catch (error) {
    console.error('[Apply Tour Error]', error.message);
    res.status(500).json({ error: 'Failed to apply for tour', message: error.message });
  }
});

/**
 * @route   GET /api/tours/pending-approvals
 */
router.get('/tours/pending-approvals', authenticateToken, async (req, res) => {
  const managerId = req.user.employee_number;
  try {
    const query = `
      SELECT 
        tr.*, 
        m.employee_name AS applicant_name, 
        ag.designation,
        ag.reporting_officer, 
        ag.reporting_officer_1,
        ro.employee_name AS reporting_officer_name,
        ro1.employee_name AS reporting_officer_1_name
      FROM travel tr
      JOIN manpower m ON CAST(tr.personnel_number AS UNSIGNED) = CAST(m.employee_number AS UNSIGNED)
      JOIN zhcm_lr_t_agents_03072026 ag ON CAST(tr.personnel_number AS UNSIGNED) = CAST(ag.personnel_number AS UNSIGNED)
      LEFT JOIN manpower ro ON CAST(ag.reporting_officer AS UNSIGNED) = CAST(ro.employee_number AS UNSIGNED)
      LEFT JOIN manpower ro1 ON CAST(ag.reporting_officer_1 AS UNSIGNED) = CAST(ro1.employee_number AS UNSIGNED)
      WHERE 
        (tr.planning_status = '1' AND CAST(ag.reporting_officer AS UNSIGNED) = CAST(? AS UNSIGNED))
        OR
        (tr.planning_status = '11' AND CAST(ag.reporting_officer_1 AS UNSIGNED) = CAST(? AS UNSIGNED))
      ORDER BY tr.beginning_date_of_trip_segment DESC
    `;
    const [rows] = await pool.query(query, [managerId, managerId]);
    const approvals = rows.map(row => {
      let status = row.planning_status === '1' ? 'Pending L1' : 'Pending L2';
      let activityType = 'Official Tour';
      const rawAct = (row.trip_activity_type || '').toString().trim().toUpperCase();
      if (rawAct === 'B') {
        activityType = 'Official Tour';
      } else if (rawAct && rawAct !== 'NULL') {
        activityType = rawAct;
      }

      return {
        id: row.id.toString(),
        employeeId: `${row.personnel_number} (${row.applicant_name})`,
        tourType: activityType,
        destination: row.trip_destination || 'N/A',
        startDate: formatIsoDate(row.beginning_date_of_trip_segment) || row.beginning_date_of_trip_segment,
        endDate: formatIsoDate(row.end_date_of_trip_segment) || row.end_date_of_trip_segment,
        travelPurpose: row.reason_for_trip || 'Official Visit',
        transportMode: row.depart_res_workplace || 'Train',
        processor: 'Manager',
        status,
        remarks: row.reason_for_trip,
        appliedOn: row.changed_on || row.beginning_date_of_trip_segment,
        reportingOfficer: (row.reporting_officer || '').toString(),
        reportingOfficerName: row.reporting_officer_name || '',
        reportingOfficer1: (row.reporting_officer_1 || '').toString(),
        reportingOfficer1Name: row.reporting_officer_1_name || ''
      };
    });
    res.json(approvals);
  } catch (error) {
    console.error('[Get Tour Approvals Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch pending tour approvals', message: error.message });
  }
});

/**
 * @route   POST /api/tours/approve
 */
router.post('/tours/approve', authenticateToken, async (req, res) => {
  const { tour_id, remarks } = req.body;
  const managerId = req.user.employee_number;

  try {
    const selectQuery = `
      SELECT tr.*, ag.reporting_officer, ag.reporting_officer_1
      FROM travel tr
      JOIN zhcm_lr_t_agents_03072026 ag ON tr.personnel_number = ag.personnel_number
      WHERE tr.id = ? LIMIT 1
    `;
    const [rows] = await pool.query(selectQuery, [tour_id]);
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Tour request not found' });
    }

    const tour = rows[0];
    let nextStatus = '';

    if (tour.planning_status === '1' && tour.reporting_officer == managerId) {
      if (tour.reporting_officer_1 && tour.reporting_officer_1 !== '0' && tour.reporting_officer_1 !== 'N/A') {
        nextStatus = '11'; // L2 pending
      } else {
        nextStatus = '2'; // Fully approved
      }
    } else if (tour.planning_status === '11' && tour.reporting_officer_1 == managerId) {
      nextStatus = '2'; // Fully approved
    } else {
      return res.status(403).json({ error: 'You are not designated to approve this tour stage' });
    }

    const updateQuery = `
      UPDATE travel SET planning_status = ?, changed_on = NOW(), changed_by = 'HR_app' WHERE id = ?
    `;
    await pool.query(updateQuery, [nextStatus, tour_id]);
    await logApproval(managerId, 'Tour', tour_id, tour.personnel_number, 'Approved', remarks);

    const managerName = await getEmployeeName(managerId);
    const applicantName = await getEmployeeName(tour.personnel_number);

    if (nextStatus === '2') {
      await createNotification(
        tour.personnel_number,
        'Tour Request Approved',
        `Your tour request to ${tour.trip_destination || 'destination'} has been approved by ${managerName}.${remarks ? ' Remarks: ' + remarks : ''}`,
        'Tour'
      );
      if (tour.reporting_officer && tour.reporting_officer !== '0' && tour.reporting_officer != managerId) {
        await createNotification(
          tour.reporting_officer,
          'Tour Request Approved',
          `Tour request to ${tour.trip_destination || 'destination'} for ${applicantName} has been approved by ${managerName}.`,
          'Tour'
        );
      }
    } else if (nextStatus === '11') {
      await createNotification(
        tour.personnel_number,
        'Tour Request L1 Approved',
        `Your tour request to ${tour.trip_destination || 'destination'} has been approved by L1 (${managerName}) and is pending L2 approval.`,
        'Tour'
      );
      if (tour.reporting_officer_1 && tour.reporting_officer_1 !== '0') {
        await createNotification(
          tour.reporting_officer_1,
          'Pending Tour Approval',
          `Tour request to ${tour.trip_destination || 'destination'} for ${applicantName} (approved by L1 ${managerName}) is pending your approval.`,
          'Tour'
        );
      }
    }

    res.json({ message: 'Tour request approved successfully', status: nextStatus });
  } catch (error) {
    console.error('[Approve Tour Error]', error.message);
    res.status(500).json({ error: 'Failed to approve tour', message: error.message });
  }
});

/**
 * @route   POST /api/tours/reject
 */
router.post('/tours/reject', authenticateToken, async (req, res) => {
  const { tour_id, remarks } = req.body;
  const managerId = req.user.employee_number;

  try {
    const selectQuery = `
      SELECT tr.*, ag.reporting_officer, ag.reporting_officer_1
      FROM travel tr
      JOIN zhcm_lr_t_agents_03072026 ag ON tr.personnel_number = ag.personnel_number
      WHERE tr.id = ? LIMIT 1
    `;
    const [rows] = await pool.query(selectQuery, [tour_id]);
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Tour request not found' });
    }

    const tour = rows[0];
    if (tour.reporting_officer == managerId || tour.reporting_officer_1 == managerId) {
      const updateQuery = `
        UPDATE travel SET planning_status = '3', changed_on = NOW(), changed_by = 'HR_app' WHERE id = ?
      `;
      await pool.query(updateQuery, [tour_id]);
      await logApproval(managerId, 'Tour', tour_id, tour.personnel_number, 'Rejected', remarks);

      const managerName = await getEmployeeName(managerId);
      const applicantName = await getEmployeeName(tour.personnel_number);

      await createNotification(
        tour.personnel_number,
        'Tour Request Rejected',
        `Your tour request to ${tour.trip_destination || 'destination'} has been rejected by ${managerName}.${remarks ? ' Remarks: ' + remarks : ''}`,
        'Tour'
      );

      if (tour.reporting_officer && tour.reporting_officer !== '0' && tour.reporting_officer != managerId) {
        await createNotification(
          tour.reporting_officer,
          'Tour Request Rejected',
          `Tour request to ${tour.trip_destination || 'destination'} for ${applicantName} was rejected by ${managerName}.`,
          'Tour'
        );
      }
      if (tour.reporting_officer_1 && tour.reporting_officer_1 !== '0' && tour.reporting_officer_1 != managerId && tour.reporting_officer_1 != tour.reporting_officer) {
        await createNotification(
          tour.reporting_officer_1,
          'Tour Request Rejected',
          `Tour request to ${tour.trip_destination || 'destination'} for ${applicantName} was rejected by ${managerName}.`,
          'Tour'
        );
      }

      res.json({ message: 'Tour request rejected successfully' });
    } else {
      res.status(403).json({ error: 'You are not designated to reject this tour request' });
    }
  } catch (error) {
    console.error('[Reject Tour Error]', error.message);
    res.status(500).json({ error: 'Failed to reject tour', message: error.message });
  }
});

/**
 * @route   GET /api/approvals/history
 */
router.get('/approvals/history', authenticateToken, async (req, res) => {
  const managerId = req.user.employee_number;
  try {
    const query = `
      SELECT * FROM approval_history 
      WHERE manager_id = ? 
      ORDER BY action_date DESC
    `;
    const [rows] = await pool.query(query, [managerId]);
    const historyList = rows.map(row => ({
      id: row.id,
      managerId: row.manager_id,
      requestType: row.request_type,
      requestId: row.request_id,
      applicantId: row.applicant_id,
      applicantName: row.applicant_name,
      action: row.action,
      remarks: row.remarks || '',
      actionDate: row.action_date
    }));
    res.json(historyList);
  } catch (error) {
    console.error('[Get Approval History Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch approval history list', message: error.message });
  }
});

/**
 * @route   GET /api/holidays
 */
router.get('/holidays', authenticateToken, async (req, res) => {
  const employeeId = req.user.employee_number;
  try {
    // 1. Get employee subarea text from manpower
    const empQuery = 'SELECT personnel_subarea_text FROM manpower WHERE employee_number = ? LIMIT 1';
    const [empRows] = await pool.query(empQuery, [employeeId]);
    if (empRows.length === 0) {
      return res.status(404).json({ error: 'Employee not found' });
    }

    // 2. Resolve subarea and area code mapping
    const codes = getSubareaCodes(empRows[0].personnel_subarea_text);

    // 3. Query zhcm_opt_holiday filtered by area and subarea
    const [holidayRows] = await pool.query(
      'SELECT * FROM zhcm_opt_holiday WHERE personnel_area = ? AND personnel_subarea = ? ORDER BY optional_holiday_date ASC',
      [codes.area, codes.subarea]
    );

    const publicHolidays = [
      // 2025 Public Holidays
      { id: 'pub2025_1', name: 'Republic Day', date: '2025-01-26 00:00:00', type: 'Mandatory' },
      { id: 'pub2025_2', name: 'Holi', date: '2025-03-14 00:00:00', type: 'Mandatory' },
      { id: 'pub2025_3', name: 'Dr. Babasaheb Ambedkar Jayanti', date: '2025-04-14 00:00:00', type: 'Mandatory' },
      { id: 'pub2025_4', name: 'Independence Day', date: '2025-08-15 00:00:00', type: 'Mandatory' },
      { id: 'pub2025_5', name: 'Narbodh/Pola', date: '2025-08-24 00:00:00', type: 'Mandatory' },
      { id: 'pub2025_6', name: 'Mahatma Gandhi Jayanti', date: '2025-10-02 00:00:00', type: 'Mandatory' },
      { id: 'pub2025_7', name: 'Diwali', date: '2025-10-20 00:00:00', type: 'Mandatory' },
      { id: 'pub2025_8', name: 'Diwali', date: '2025-10-21 00:00:00', type: 'Mandatory' },

      // 2026 Public Holidays
      { id: 'pub2026_1', name: 'Republic Day', date: '2026-01-26 00:00:00', type: 'Mandatory' },
      { id: 'pub2026_2', name: 'Holi', date: '2026-03-03 00:00:00', type: 'Mandatory' },
      { id: 'pub2026_3', name: 'Dr. Babasaheb Ambedkar Jayanti', date: '2026-04-14 00:00:00', type: 'Mandatory' },
      { id: 'pub2026_4', name: 'Independence Day', date: '2026-08-15 00:00:00', type: 'Mandatory' },
      { id: 'pub2026_5', name: 'Narbodh/Pola', date: '2026-09-12 00:00:00', type: 'Mandatory' },
      { id: 'pub2026_6', name: 'Mahatma Gandhi Jayanti', date: '2026-10-02 00:00:00', type: 'Mandatory' },
      { id: 'pub2026_7', name: 'Diwali', date: '2026-11-08 00:00:00', type: 'Mandatory' },
      { id: 'pub2026_8', name: 'Diwali', date: '2026-11-09 00:00:00', type: 'Mandatory' }
    ];

    const optionalHolidays = holidayRows.map(row => ({
      id: row.id.toString(),
      name: row.description || 'Optional Holiday',
      date: row.optional_holiday_date,
      type: 'Optional'
    }));

    res.json([...publicHolidays, ...optionalHolidays]);
  } catch (error) {
    console.error('[Get Holidays Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch holidays list', message: error.message });
  }
});

/**
 * @route   GET /api/notifications
 */
router.get('/notifications', authenticateToken, async (req, res) => {
  const employeeId = req.user.employee_number;
  try {
    const [rows] = await pool.query(
      'SELECT * FROM notifications WHERE employee_id = ? OR CAST(employee_id AS UNSIGNED) = CAST(? AS UNSIGNED) ORDER BY created_at DESC',
      [employeeId, employeeId]
    );
    const list = rows.map(row => ({
      id: row.id.toString(),
      title: row.title,
      message: row.message,
      type: row.type || 'General',
      isRead: !!row.is_read,
      createdAt: row.created_at
    }));
    res.json(list);
  } catch (error) {
    console.error('[Get Notifications Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch notifications', message: error.message });
  }
});

/**
 * @route   POST /api/notifications/read
 */
router.post('/notifications/read', authenticateToken, async (req, res) => {
  const employeeId = req.user.employee_number;
  const notifId = req.body && req.body.id;
  try {
    if (notifId) {
      await pool.query(
        'UPDATE notifications SET is_read = TRUE WHERE id = ?',
        [notifId]
      );
    } else {
      await pool.query(
        'UPDATE notifications SET is_read = TRUE WHERE employee_id = ? OR CAST(employee_id AS UNSIGNED) = CAST(? AS UNSIGNED)',
        [employeeId, employeeId]
      );
    }
    res.json({ message: 'Notifications marked as read' });
  } catch (error) {
    console.error('[Mark Notifications Read Error]', error.message);
    res.status(500).json({ error: 'Failed to mark notifications as read', message: error.message });
  }
});

/**
 * @route   GET /api/employees
 */
router.get('/employees', authenticateToken, async (req, res) => {
  const managerId = req.user.employee_number;
  try {
    const cleanManagerId = managerId ? managerId.toString().trim().replace(/^0+/, '') : '';
    let query;
    let params;

    // EVERY Reporting Officer (including Top Executive 16194) sees ONLY employees who work under them
    query = `
      SELECT 
        m.*, 
        a.reporting_officer, 
        a.reporting_officer_1, 
        ro.employee_name AS reporting_officer_name,
        ro1.employee_name AS reporting_officer_1_name
      FROM manpower m 
      JOIN zhcm_lr_t_agents_03072026 a ON CAST(m.employee_number AS UNSIGNED) = CAST(a.personnel_number AS UNSIGNED)
      LEFT JOIN manpower ro ON CAST(a.reporting_officer AS UNSIGNED) = CAST(ro.employee_number AS UNSIGNED)
      LEFT JOIN manpower ro1 ON CAST(a.reporting_officer_1 AS UNSIGNED) = CAST(ro1.employee_number AS UNSIGNED)
      WHERE CAST(a.reporting_officer AS UNSIGNED) = CAST(? AS UNSIGNED) 
         OR CAST(a.reporting_officer_1 AS UNSIGNED) = CAST(? AS UNSIGNED)
      GROUP BY m.employee_number
      ORDER BY CAST(m.employee_number AS UNSIGNED) ASC
    `;
    params = [cleanManagerId, cleanManagerId];

    const [rows] = await pool.query(query, params);

    if (rows.length === 0) {
      return res.json([]);
    }

    // Extract clean personnel numbers for bulk fetching family & nomination details
    const empNumbers = rows
      .map(r => (r.employee_number || '').toString().trim().replace(/^0+/, ''))
      .filter(Boolean);

    // Fetch family & nominee details ONLY if count <= 100 or include_details=true
    const includeDetails = req.query.include_details === 'true' || empNumbers.length <= 100;

    const familyMap = new Map();
    const nomineeMap = new Map();

    if (includeDetails && empNumbers.length > 0) {
      // Fetch family members from it0021_family_member
      try {
        const placeholders = empNumbers.map(() => '?').join(',');
        const [famRows] = await pool.query(
          `SELECT personnel_number, full_name, first_name, middle_name, last_name, family_member, sub_type, date_of_birth, gender, aadhar_card FROM it0021_family_member WHERE CAST(personnel_number AS UNSIGNED) IN (${placeholders})`,
          empNumbers
        );
        famRows.forEach(f => {
          const pNo = (f.personnel_number || '').toString().trim().replace(/^0+/, '');
          if (!familyMap.has(pNo)) familyMap.set(pNo, []);
          familyMap.get(pNo).push({
            name: f.full_name || [f.first_name, f.middle_name, f.last_name].filter(Boolean).join(' ') || 'N/A',
            relation: f.family_member || f.sub_type || 'Family Member',
            dob: formatDate(f.date_of_birth),
            gender: f.gender === '1' ? 'Male' : (f.gender === '2' ? 'Female' : (f.gender || 'N/A')),
            aadhar: f.aadhar_card || 'N/A'
          });
        });
      } catch (famErr) {
        console.error('[Family Fetch Error]', famErr.message);
      }

      // Fetch nominations from it0591_nomination
      try {
        const placeholders = empNumbers.map(() => '?').join(',');
        const [nomRows] = await pool.query(
          `SELECT personnel_number, benefit_type, name_of_nominee, relationship_with_employee, percentage_of_share, address_of_nominee, date_of_birth_of_nominee, name_of_nominee_1, relationship_with_employee_1, percentage_of_share_1, address_of_nominee_1, date_of_birth_of_nominee_1, name_of_nominee_2, relationship_with_employee_2, percentage_of_share_2, address_of_nominee_2, date_of_birth_of_nominee_2 FROM it0591_nomination WHERE CAST(personnel_number AS UNSIGNED) IN (${placeholders})`,
          empNumbers
        );
        nomRows.forEach(n => {
          const pNo = (n.personnel_number || '').toString().trim().replace(/^0+/, '');
          if (!nomineeMap.has(pNo)) nomineeMap.set(pNo, []);
          
          if (n.name_of_nominee) {
            nomineeMap.get(pNo).push({
              name: n.name_of_nominee,
              relation: n.relationship_with_employee || 'N/A',
              share: n.percentage_of_share || '100%',
              benefitType: n.benefit_type || 'Nomination',
              address: n.address_of_nominee || 'N/A',
              dob: formatDate(n.date_of_birth_of_nominee)
            });
          }
          if (n.name_of_nominee_1) {
            nomineeMap.get(pNo).push({
              name: n.name_of_nominee_1,
              relation: n.relationship_with_employee_1 || 'N/A',
              share: n.percentage_of_share_1 || 'N/A',
              benefitType: n.benefit_type || 'Nomination',
              address: n.address_of_nominee_1 || 'N/A',
              dob: formatDate(n.date_of_birth_of_nominee_1)
            });
          }
          if (n.name_of_nominee_2) {
            nomineeMap.get(pNo).push({
              name: n.name_of_nominee_2,
              relation: n.relationship_with_employee_2 || 'N/A',
              share: n.percentage_of_share_2 || 'N/A',
              benefitType: n.benefit_type || 'Nomination',
              address: n.address_of_nominee_2 || 'N/A',
              dob: formatDate(n.date_of_birth_of_nominee_2)
            });
          }
        });
      } catch (nomErr) {
        console.error('[Nominee Fetch Error]', nomErr.message);
      }
    }

    // Guaranteed deduplication by employee_number and inject family/nominee data
    const seenMap = new Map();
    rows.forEach(row => {
      const empNo = (row.employee_number || '').toString().trim();
      const cleanEmpNo = empNo.replace(/^0+/, '');
      if (empNo && !seenMap.has(cleanEmpNo)) {
        const empObject = mapEmployeeRow(row);
        empObject.familyMembers = familyMap.get(cleanEmpNo) || [];
        empObject.nominees = nomineeMap.get(cleanEmpNo) || [];
        seenMap.set(cleanEmpNo, empObject);
      }
    });

    res.json(Array.from(seenMap.values()));
  } catch (error) {
    console.error('[Get Employees Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch employees list', message: error.message });
  }
});

/**
 * @route   POST /api/leave-encashment
 */
router.post('/leave-encashment', authenticateToken, async (req, res) => {
  const { employee_id, days, year } = req.body;
  const loggedInId = req.user.employee_number;
  const cleanEmpId = employee_id.toString().trim().replace(/^0+/, '');

  try {
    // 1. Validation: Only self or respective reporting officer can encash
    const agentQuery = `SELECT reporting_officer, reporting_officer_1 FROM zhcm_lr_t_agents_03072026 WHERE personnel_number = ? LIMIT 1`;
    const [agents] = await pool.query(agentQuery, [cleanEmpId]);
    if (agents.length === 0) {
      return res.status(400).json({ error: 'Applicant agent mapping not found' });
    }

    const { reporting_officer: l1, reporting_officer_1: l2 } = agents[0];
    if (cleanEmpId != loggedInId && l1 != loggedInId && l2 != loggedInId) {
      return res.status(403).json({ error: 'Unauthorized. Only self or the designated reporting officer can submit leave encashment.' });
    }

    // 2. Encashment rule: Max 50% of available Earned Leave quota
    const [quotaRows] = await pool.query(
      `SELECT * FROM leave_quota WHERE personnel_number = ? AND (absence_quota_type = '1' OR sub_type = '01') ORDER BY deduction_to DESC LIMIT 1`,
      [cleanEmpId]
    );

    if (quotaRows.length === 0) {
      return res.status(400).json({ error: 'No Earned Leave quota balance found for this employee' });
    }

    const balance = parseFloat(quotaRows[0].quota_number || 0) - parseFloat(quotaRows[0].quota_deduction || 0);
    const maxAllowed = Math.floor(balance * 0.5);
    const requestedDays = parseInt(days, 10);

    if (requestedDays > maxAllowed) {
      return res.status(400).json({ 
        error: `Not eligible: You can only encash up to 50% of your total balance (Max: ${maxAllowed} days).` 
      });
    }

    // 3. Encashment rule: Cap requested days to 30
    const finalDays = Math.min(requestedDays, 30);

    const docNumber = '303' + Math.floor(100000000 + Math.random() * 900000000).toString();
    const insertQuery = `
      INSERT INTO time_quota_compensation_infotype (
        personnel_number, sub_type, start_date, end_date, comp_quota_number, 
        quota_type, time_quota_compensation_method, changed_by, changed_on, infotype_record_no, logical_system, document_number
      ) VALUES (?, '1000', NOW(), NOW(), ?, 'A', '1000', 'HR_app', NOW(), '0', 'PECCLNT100', ?)
    `;
    const [result] = await pool.query(insertQuery, [cleanEmpId, finalDays, docNumber]);

    // Trigger ZHR_LEAVE_ENCASH_SEND SMS to Reporting Officer
    try {
      const applicantName = await getEmployeeName(cleanEmpId);
      const roMobile = await getEmployeeMobile(l1);
      sendLeaveEncashAppliedSms({
        mobileNumber: roMobile,
        applicantName: applicantName,
        days: finalDays
      }).catch(err => console.error('[SMS Encash Applied Error]', err.message));
    } catch (smsErr) {
      console.error('[SMS Leave Encash Applied Error]', smsErr.message);
    }

    res.status(201).json({
      message: 'Leave encashment request processed successfully',
      id: result.insertId,
      docNumber,
      appliedDays: finalDays
    });
  } catch (error) {
    console.error('[Leave Encashment Error]', error.message);
    res.status(500).json({ error: 'Failed to process leave encashment', message: error.message });
  }
});

/**
 * @route   GET /api/leaves/team-calendar
 */
router.get('/leaves/team-calendar', authenticateToken, async (req, res) => {
  const managerId = req.user.employee_number;
  try {
    // 1. Fetch team members (subordinates)
    const teamQuery = `
      SELECT m.employee_number, m.employee_name
      FROM manpower m
      JOIN zhcm_lr_t_agents_03072026 a ON m.employee_number = CAST(a.personnel_number AS UNSIGNED)
      WHERE a.reporting_officer = ? OR a.reporting_officer_1 = ?
    `;
    const [subordinates] = await pool.query(teamQuery, [managerId, managerId]);

    const result = [];
    for (const sub of subordinates) {
      // 2. Fetch leaves for this team member
      const leavesQuery = `
        SELECT a.start_date, a.end_date, a.sub_type, h.document_status
        FROM ptreq_attabsdata_leave_apply_1 a
        JOIN ptreq_header_leave_approved_1 h ON a.id_of_request_item = h.document_identification
        WHERE a.personnel_number = ? AND h.document_status IN ('APPROVED', 'POSTED', 'SENT', 'SENT_L2')
      `;
      const [leaves] = await pool.query(leavesQuery, [sub.employee_number]);

      const formattedLeaves = leaves.map(l => {
        let leaveType = 'Earned leave';
        if (l.sub_type === '1001') leaveType = 'Casual Leave';
        else if (l.sub_type === '1002') leaveType = 'HPL';
        else if (l.sub_type === '1003') leaveType = 'CHPL';
        else if (l.sub_type === '1010') leaveType = 'Optional Leave';

        return {
          startDate: l.start_date,
          endDate: l.end_date,
          leaveType
        };
      });

      result.push({
        employee_number: sub.employee_number,
        name: sub.employee_name,
        leaves: formattedLeaves
      });
    }

    res.json(result);
  } catch (error) {
    console.error('[Get Team Calendar Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch team calendar details', message: error.message });
  }
});

/**
 * @route   GET /api/tours/team-calendar
 */
router.get('/tours/team-calendar', authenticateToken, async (req, res) => {
  const managerId = req.user.employee_number;
  const cleanManagerId = managerId ? managerId.toString().trim().replace(/^0+/, '') : '';
  try {
    const teamQuery = `
      SELECT DISTINCT m.employee_number, m.employee_name
      FROM manpower m
      LEFT JOIN zhcm_lr_t_agents_03072026 a ON CAST(m.employee_number AS UNSIGNED) = CAST(a.personnel_number AS UNSIGNED)
      LEFT JOIN travel tr ON CAST(m.employee_number AS UNSIGNED) = CAST(tr.personnel_number AS UNSIGNED)
      WHERE CAST(a.reporting_officer AS UNSIGNED) = CAST(? AS UNSIGNED) 
         OR CAST(a.reporting_officer_1 AS UNSIGNED) = CAST(? AS UNSIGNED)
         OR CAST(m.employee_number AS UNSIGNED) = CAST(? AS UNSIGNED)
         OR CAST(tr.personnel_number AS UNSIGNED) IN (
            SELECT DISTINCT CAST(t.personnel_number AS UNSIGNED) 
            FROM travel t
            JOIN zhcm_lr_t_agents_03072026 ag ON CAST(t.personnel_number AS UNSIGNED) = CAST(ag.personnel_number AS UNSIGNED)
            WHERE CAST(ag.reporting_officer AS UNSIGNED) = CAST(? AS UNSIGNED)
               OR CAST(ag.reporting_officer_1 AS UNSIGNED) = CAST(? AS UNSIGNED)
         )
      ORDER BY CAST(m.employee_number AS UNSIGNED) ASC
    `;
    const [subordinates] = await pool.query(teamQuery, [cleanManagerId, cleanManagerId, cleanManagerId, cleanManagerId, cleanManagerId]);

    const result = [];
    for (const sub of subordinates) {
      const cleanSubEmpNo = sub.employee_number ? sub.employee_number.toString().trim().replace(/^0+/, '') : '';

      const toursQuery = `
        SELECT * FROM travel 
        WHERE (personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED) OR personnel_number = ?)
          AND (planning_status IN ('1', '2', '11', 'APPROVED', 'Approved') OR planning_status LIKE '2%')
        ORDER BY beginning_date_of_trip_segment DESC
      `;
      const [tours] = await pool.query(toursQuery, [cleanSubEmpNo, cleanSubEmpNo, sub.employee_number]);

      const formattedTours = tours.map(row => {
        let activityType = 'Official Tour';
        const rawAct = (row.trip_activity_type || '').toString().trim().toUpperCase();
        if (rawAct === 'B') {
          activityType = 'Official Tour';
        } else if (rawAct && rawAct !== 'NULL') {
          activityType = rawAct;
        }

        let status = 'Approved';
        const rawStatus = (row.planning_status || '').toString().trim();
        if (rawStatus === '1') status = 'Pending L1';
        else if (rawStatus === '11') status = 'Pending L2';
        else status = 'Approved';

        const startDateIso = formatIsoDate(row.beginning_date_of_trip_segment);
        const endDateIso = formatIsoDate(row.end_date_of_trip_segment);

        return {
          startDate: startDateIso || row.beginning_date_of_trip_segment,
          endDate: endDateIso || row.end_date_of_trip_segment,
          destination: row.trip_destination || 'N/A',
          travelPurpose: row.reason_for_trip || 'Official Work',
          tourType: activityType,
          status
        };
      });

      result.push({
        employee_number: sub.employee_number,
        name: sub.employee_name,
        tours: formattedTours
      });
    }

    res.json(result);
  } catch (error) {
    console.error('[Get Tours Team Calendar Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch team calendar tours', message: error.message });
  }
});

/**
 * Helper to record outbound modifications (delta tracking & file export for FTP Outbound folder)
 */
async function recordOutboundChange(tableName, recordId, actionType, changedColumns, rowData) {
  try {
    // 1. Database delta tracking
    await pool.query(
      'INSERT INTO app_outbound_changes (table_name, record_id, action_type, changed_columns, row_data) VALUES (?, ?, ?, ?, ?)',
      [tableName, String(recordId), actionType, JSON.stringify(changedColumns || {}), JSON.stringify(rowData || {})]
    );

    // 2. Save changed data file into local FTP Outbound folder
    const outboundDir = path.join(__dirname, '../../outbound');
    if (!fs.existsSync(outboundDir)) {
      fs.mkdirSync(outboundDir, { recursive: true });
    }
    const fileName = `${tableName}_${actionType}_${recordId}_${Date.now()}.json`;
    const filePath = path.join(outboundDir, fileName);
    const filePayload = {
      timestamp: new Date().toISOString(),
      table_name: tableName,
      record_id: recordId,
      action_type: actionType,
      changed_columns: changedColumns || {},
      row_data: rowData || {}
    };
    fs.writeFileSync(filePath, JSON.stringify(filePayload, null, 2), 'utf8');
    console.log(`[FTP Outbound File Created] ${filePath}`);
  } catch (err) {
    console.error('[Record Outbound Change Error]', err.message);
  }
}

/**
 * @route   GET /api/pending-outbound
 * @desc    Returns all unsynced modified rows & columns for Outbound FTP export
 */
router.get('/pending-outbound', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM app_outbound_changes WHERE is_synced = 0 ORDER BY id ASC LIMIT 500');
    const parsed = rows.map(r => ({
      id: r.id,
      table_name: r.table_name,
      record_id: r.record_id,
      action_type: r.action_type,
      changed_columns: typeof r.changed_columns === 'string' ? JSON.parse(r.changed_columns || '{}') : r.changed_columns,
      row_data: typeof r.row_data === 'string' ? JSON.parse(r.row_data || '{}') : r.row_data,
      created_at: r.created_at
    }));
    res.json(parsed);
  } catch (err) {
    console.error('[Pending Outbound Error]', err.message);
    res.status(500).json({ error: 'Failed to fetch pending outbound changes' });
  }
});

/**
 * @route   POST /api/mark-outbound-synced
 * @desc    Marks processed change IDs as synced
 */
router.post('/mark-outbound-synced', async (req, res) => {
  try {
    const { ids } = req.body;
    if (Array.isArray(ids) && ids.length > 0) {
      await pool.query('UPDATE app_outbound_changes SET is_synced = 1, synced_at = NOW() WHERE id IN (?)', [ids]);
    }
    res.json({ success: true, count: ids ? ids.length : 0 });
  } catch (err) {
    console.error('[Mark Outbound Synced Error]', err.message);
    res.status(500).json({ error: 'Failed to mark outbound changes as synced' });
/**
 * @route   ALL /api/trigger-ftp-sync
 * @desc    Triggers automated FTP Inbound/Outbound sync & DB upserts
 */
router.all('/trigger-ftp-sync', async (req, res) => {
  try {
    const { runFtpSync } = require('../services/ftp_sync_service');
    // Run sync in background or await
    runFtpSync().catch(err => console.error('[Background FTP Sync Error]', err));
    res.json({ success: true, message: 'FTP Inbound/Outbound synchronization triggered successfully' });
  } catch (err) {
    console.error('[Trigger FTP Sync Error]', err.message);
    res.status(500).json({ error: 'Failed to trigger FTP sync', details: err.message });
  }
});

module.exports = router;
