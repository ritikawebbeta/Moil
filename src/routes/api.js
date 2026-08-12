const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');
const authenticateToken = require('../middleware/auth');
const { pool } = require('../config/db');
const smsService = require('../utils/smsService');


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

// Generate HRAPP-prefixed request ID (HRAPP + 27 hex chars = 32 chars total)
// Used exclusively for id_of_request_item on new leave/encashment requests
function generateRequestId() {
  const hexPart = crypto.randomBytes(14).toString('hex').toUpperCase().slice(0, 27);
  return `HRAPP${hexPart}`;
}

// Lookup daily working hours from planned_working_time for an employee
// Falls back to 8.5 if no record exists (existing default maintained)
async function getPlannedHoursForEmployee(employeeId) {
  try {
    const [rows] = await pool.query(
      `SELECT daily_working_hours, monthly_working_hrs
       FROM planned_working_time
       WHERE CAST(personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED)
       ORDER BY start_date DESC LIMIT 1`,
      [employeeId]
    );
    if (rows.length > 0) {
      const daily = parseFloat(rows[0].daily_working_hours || rows[0].monthly_working_hrs / 22 || 0);
      if (daily > 0) return daily;
    }
  } catch (_) { /* table may not have expected columns — fall through */ }
  return 8.5; // existing hardcoded default as fallback
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

    // Auto-delete notifications older than 1 month from DB
    await pool.query('DELETE FROM notifications WHERE created_at < NOW() - INTERVAL 1 MONTH');
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
    permanentAddress: (row.permanent_address || row.perm_address || row.address || '').toString().trim() || 'N/A',
    temporaryAddress: (row.temporary_address || row.temp_address || row.present_address || '').toString().trim() || 'N/A',
    emergencyAddress: (row.emergency_address || row.current_address || row.emerg_address || '').toString().trim() || 'N/A',
    currentAddress: (row.emergency_address || row.current_address || row.emerg_address || '').toString().trim() || 'N/A',
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
  const fnUpper = (fileName || '').toUpperCase();

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

    // Utility to parse dates correctly
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

    let successCount = 0;
    const conn = await pool.getConnection();

    try {
      const [tableColsRows] = await conn.query(`SHOW COLUMNS FROM \`${tableName}\``);
      const validColsSet = new Set(tableColsRows.map(c => c.Field.toLowerCase()));

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
        await conn.query(sql, validVals);
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
  const rawId = (req.body.employee_number || req.body.employee_id || req.body.employeeId || '').toString().trim();
  const password = (req.body.password || '').toString().trim();

  if (!rawId || !password) {
    return res.status(400).json({ error: 'Employee number and password are required' });
  }

  try {
    const cleanId = rawId.replace(/^0+/, '');
    const paddedId = cleanId ? cleanId.padStart(8, '0') : rawId;

    // 1. Fetch employee details from manpower (fast indexed lookup)
    const [empRows] = await pool.query(
      'SELECT * FROM manpower WHERE employee_number = ? OR employee_number = ? OR employee_number = ? LIMIT 1',
      [rawId, cleanId, paddedId]
    );

    if (!empRows || empRows.length === 0) {
      return res.status(401).json({ error: 'Invalid Employee Number or Password' });
    }

    const employee = empRows[0];
    const designation = employee.position_name || 'Employee';

    // 2. Fetch custom password from user_accounts if available
    let isPasswordValid = false;
    let hasCustomPassword = false;

    try {
      const [credRows] = await pool.query(
        'SELECT password FROM user_accounts WHERE employee_number = ? OR employee_number = ? OR employee_number = ? LIMIT 1',
        [rawId, cleanId, paddedId]
      );
      if (credRows && credRows.length > 0 && credRows[0].password) {
        isPasswordValid = credRows[0].password.toString().trim() === password;
        hasCustomPassword = true;
      }
    } catch (_) {}

    // Fallback: validate against PAN number
    if (!isPasswordValid && employee.pan_number) {
      isPasswordValid = employee.pan_number.toString().trim().toUpperCase() === password.toUpperCase();
    }

    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid Employee Number or Password' });
    }

    // 3. Fetch reporting officers (optional metadata guarded against locks)
    let reportingOfficer = '0';
    let reportingOfficer1 = '0';
    let reportingOfficerName = '';
    let reportingOfficer1Name = '';

    try {
      const [agentRows] = await pool.query(
        'SELECT reporting_officer, reporting_officer_1 FROM zhcm_lr_t_agents_03072026 WHERE personnel_number = ? OR personnel_number = ? OR personnel_number = ? LIMIT 1',
        [rawId, cleanId, paddedId]
      );
      if (agentRows && agentRows.length > 0) {
        reportingOfficer = agentRows[0].reporting_officer || '0';
        reportingOfficer1 = agentRows[0].reporting_officer_1 || '0';
      }

      if (reportingOfficer !== '0' && reportingOfficer !== 'N/A') {
        const roClean = reportingOfficer.toString().trim().replace(/^0+/, '');
        const roPadded = roClean ? roClean.padStart(8, '0') : reportingOfficer;
        const [roRows] = await pool.query('SELECT employee_name FROM manpower WHERE employee_number = ? OR employee_number = ? OR employee_number = ? LIMIT 1', [reportingOfficer, roClean, roPadded]);
        if (roRows && roRows.length > 0) reportingOfficerName = roRows[0].employee_name;
      }

      if (reportingOfficer1 !== '0' && reportingOfficer1 !== 'N/A') {
        const ro1Clean = reportingOfficer1.toString().trim().replace(/^0+/, '');
        const ro1Padded = ro1Clean ? ro1Clean.padStart(8, '0') : reportingOfficer1;
        const [ro1Rows] = await pool.query('SELECT employee_name FROM manpower WHERE employee_number = ? OR employee_number = ? OR employee_number = ? LIMIT 1', [reportingOfficer1, ro1Clean, ro1Padded]);
        if (ro1Rows && ro1Rows.length > 0) reportingOfficer1Name = ro1Rows[0].employee_name;
      }
    } catch (agentErr) {
      console.warn('[Login Reporting Officer Warning]', agentErr.message);
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
  const showFrom = req.query.show_from || null;

  try {
    const rawPernr = employeeId.toString().trim();
    const paddedPernr = rawPernr.padStart(8, '0');

    let dateWhere = '';
    const dateParams = [rawPernr, paddedPernr];
    if (showFrom) {
      dateWhere = ' AND (end_date >= ? OR start_date >= ? OR start_date IS NULL) ';
      dateParams.push(showFrom, showFrom);
    }

    // 1. Fetch leave applications
    const [leaveRows] = await pool.query(
      `SELECT id_of_request_item, personnel_number, sub_type, start_date, end_date, start_time, end_time, calendar_days 
       FROM ptreq_attabsdata_leave_apply_1 
       WHERE (personnel_number = ? OR personnel_number = ?) ${dateWhere}
       ORDER BY 
         CASE 
           WHEN start_date REGEXP '^[0-9]{2}\\\.[0-9]{2}\\\.[0-9]{4}$' THEN STR_TO_DATE(start_date, '%d.%m.%Y')
           WHEN start_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN STR_TO_DATE(start_date, '%d-%m-%Y')
           WHEN start_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(start_date, '%Y-%m-%d')
           ELSE NULL
         END DESC,
         row_id DESC`,
      dateParams
    );

    if (leaveRows.length === 0) {
      return res.json([]);
    }

    const itemGuids = leaveRows.map(l => l.id_of_request_item);

    // 2. Fetch items table mapping
    let guidToListMap = {};
    let allListIds = [];
    if (itemGuids.length > 0) {
      const [items] = await pool.query(
        `SELECT id_of_request_item_list, guid, guid_1 FROM ptreq_items WHERE guid IN (?) OR guid_1 IN (?)`,
        [itemGuids, itemGuids]
      );
      items.forEach(i => {
        if (i.guid) guidToListMap[i.guid] = i.id_of_request_item_list;
        if (i.guid_1) guidToListMap[i.guid_1] = i.id_of_request_item_list;
        if (i.id_of_request_item_list) allListIds.push(i.id_of_request_item_list);
      });
    }

    // 3. Fetch header status
    let headerStatusMap = {};
    let headerTimeMap = {};
    const searchDocIds = itemGuids.concat(allListIds).filter(Boolean);
    if (searchDocIds.length > 0) {
      const [headers] = await pool.query(
        `SELECT document_identification, id_of_request_item_list, document_status, time_stamp 
         FROM ptreq_header_leave_approved_1 
         WHERE document_identification IN (?) OR id_of_request_item_list IN (?)`,
        [searchDocIds, searchDocIds]
      );
      headers.forEach(h => {
        const key1 = h.document_identification;
        const key2 = h.id_of_request_item_list;
        if (key1) {
          headerStatusMap[key1] = (headerStatusMap[key1] || []).concat(h.document_status);
          if (h.time_stamp) headerTimeMap[key1] = h.time_stamp;
        }
        if (key2) {
          headerStatusMap[key2] = (headerStatusMap[key2] || []).concat(h.document_status);
          if (h.time_stamp) headerTimeMap[key2] = h.time_stamp;
        }
      });
    }

    // 4. Fetch absence matches with sub-type mapping
    const [absences] = await pool.query(
      `SELECT sub_type, start_date FROM absence WHERE personnel_number = ? OR personnel_number = ?`,
      [rawPernr, paddedPernr]
    );
    const absenceSet = new Set();
    absences.forEach(ab => {
      absenceSet.add(`${ab.sub_type}_${ab.start_date}`);
      if (ab.sub_type === '1000') absenceSet.add(`01_${ab.start_date}`);
      if (ab.sub_type === '1001') absenceSet.add(`02_${ab.start_date}`);
      if (ab.sub_type === '1002') absenceSet.add(`03_${ab.start_date}`);
      if (ab.sub_type === '1010') absenceSet.add(`05_${ab.start_date}`);
    });

    // 5. Fetch reporting officers
    const [agents] = await pool.query(
      `SELECT reporting_officer, reporting_officer_1 FROM zhcm_lr_t_agents_03072026 WHERE personnel_number = ? OR personnel_number = ? LIMIT 1`,
      [rawPernr, paddedPernr]
    );
    const agent = agents[0] || {};
    const roId = (agent.reporting_officer || '').toString().trim();
    const ro1Id = (agent.reporting_officer_1 || '').toString().trim();

    // 6. Fetch officer names
    const officerIds = [roId, ro1Id].filter(id => id && id !== '0');
    let officerMap = {};
    if (officerIds.length > 0) {
      const [officers] = await pool.query(
        `SELECT employee_number, employee_name FROM manpower WHERE employee_number IN (?) OR CAST(employee_number AS UNSIGNED) IN (?)`,
        [officerIds, officerIds]
      );
      officers.forEach(o => {
        officerMap[o.employee_number.toString()] = o.employee_name;
      });
    }

    const formatIso = (dateVal) => {
      if (!dateVal) return null;
      const str = String(dateVal).trim();
      if (str === '' || str === 'null' || str === 'undefined') return null;

      if (/^\d{4,5}(\.\d+)?$/.test(str)) {
        const num = parseFloat(str);
        if (num > 1000) {
          const d = new Date(Math.round((num - 25569) * 86400 * 1000));
          return isNaN(d.getTime()) ? null : d.toISOString();
        }
      }

      if (/^\d{1,2}[-./]\d{1,2}[-./]\d{4}/.test(str)) {
        const parts = str.split(/[-./]/);
        if (parts.length >= 3) {
          const day = parseInt(parts[0], 10);
          const month = parseInt(parts[1], 10) - 1;
          const year = parseInt(parts[2], 10);
          const d = new Date(Date.UTC(year, month, day));
          if (!isNaN(d.getTime())) return d.toISOString();
        }
      }

      if (/^\d{4}[-./]\d{1,2}[-./]\d{1,2}/.test(str)) {
        const parts = str.split(/[-./\sT]/);
        if (parts.length >= 3) {
          const year = parseInt(parts[0], 10);
          const month = parseInt(parts[1], 10) - 1;
          const day = parseInt(parts[2], 10);
          const d = new Date(Date.UTC(year, month, day));
          if (!isNaN(d.getTime())) return d.toISOString();
        }
      }

      try {
        const d = new Date(str);
        return isNaN(d.getTime()) ? null : d.toISOString();
      } catch (_) {
        return null;
      }
    };

    const leaves = leaveRows.map(row => {
      const listId = guidToListMap[row.id_of_request_item];
      const statuses = (headerStatusMap[row.id_of_request_item] || []).concat(headerStatusMap[listId] || []);
      const isAbsent = absenceSet.has(`${row.sub_type}_${row.start_date}`);
      
      let status = 'In Process';
      if (isAbsent || statuses.includes('APPROVED') || statuses.includes('POSTED')) {
        status = 'Approved';
      } else if (statuses.includes('REJECTED')) {
        status = 'Rejected';
      } else if (statuses.includes('WITHDRAWN')) {
        status = 'Withdrawn';
      } else {
        status = 'In Process';
      }

      let leaveType = 'Earned leave';
      if (row.sub_type === '1001' || row.sub_type === '02') leaveType = 'Casual Leave';
      else if (row.sub_type === '1002' || row.sub_type === '03') leaveType = 'HPL';
      else if (row.sub_type === '1003') leaveType = 'CHPL';
      else if (row.sub_type === '1010' || row.sub_type === '05') leaveType = 'Optional Leave';
      else if (row.sub_type === '2000' || row.sub_type === '2008') leaveType = 'Special Leave';

      const timeStampRaw = headerTimeMap[row.id_of_request_item] || headerTimeMap[listId];
      const timeStampIso = formatIso(timeStampRaw);
      const startIso = formatIso(row.start_date) || timeStampIso;
      const endIso = formatIso(row.end_date) || startIso;

      const computedDays = row.calendar_days ? parseFloat(row.calendar_days) : calculateDays(row.start_date, row.end_date);

      const procName = officerMap[roId] || (roId && roId !== '0' ? roId : '-');
      const proc1Name = officerMap[ro1Id] || (ro1Id && ro1Id !== '0' ? ro1Id : '-');

      return {
        id: row.id_of_request_item,
        employeeId: row.personnel_number ? row.personnel_number.toString() : rawPernr,
        leaveType,
        startDate: startIso,
        startTime: row.start_time || '00:00:00',
        endDate: endIso,
        endTime: row.end_time || '00:00:00',
        duration: `${computedDays} Day(s)`,
        used: `${computedDays} Day(s)`,
        status,
        appliedOn: timeStampIso || startIso,
        approvedOn: (status === 'Approved' || status === 'Rejected') ? (timeStampIso || startIso) : null,
        reason: 'Personal affairs',
        processor: procName,
        processor1: proc1Name
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
    const query = `
      SELECT 
        sub_type,
        MAX(absence_quota_type) AS absence_quota_type,
        MAX(quota_number) AS quota_number,
        MAX(quota_deduction) AS quota_deduction,
        MAX(deduction_from) AS deduction_from,
        MAX(deduction_to) AS deduction_to,
        MAX(start_date) AS start_date,
        MAX(end_date) AS end_date
      FROM leave_quota 
      WHERE personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED) 
      GROUP BY sub_type
    `;
    const [rows] = await pool.query(query, [employeeId, employeeId]);

    const formatIso = (dateVal) => {
      if (!dateVal) return null;
      const str = String(dateVal).trim();
      if (str === '' || str === 'null' || str === 'undefined') return null;

      if (/^\d{4,5}(\.\d+)?$/.test(str)) {
        const num = parseFloat(str);
        if (num > 1000) {
          const d = new Date(Math.round((num - 25569) * 86400 * 1000));
          return isNaN(d.getTime()) ? null : d.toISOString();
        }
      }

      if (/^\d{1,2}[-./]\d{1,2}[-./]\d{4}/.test(str)) {
        const parts = str.split(/[-./]/);
        if (parts.length >= 3) {
          const day = parseInt(parts[0], 10);
          const month = parseInt(parts[1], 10) - 1;
          const year = parseInt(parts[2], 10);
          const d = new Date(Date.UTC(year, month, day));
          if (!isNaN(d.getTime())) return d.toISOString();
        }
      }

      if (/^\d{4}[-./]\d{1,2}[-./]\d{1,2}/.test(str)) {
        const parts = str.split(/[-./\sT]/);
        if (parts.length >= 3) {
          const year = parseInt(parts[0], 10);
          const month = parseInt(parts[1], 10) - 1;
          const day = parseInt(parts[2], 10);
          const d = new Date(Date.UTC(year, month, day));
          if (!isNaN(d.getTime())) return d.toISOString();
        }
      }

      try {
        const d = new Date(str);
        return isNaN(d.getTime()) ? null : d.toISOString();
      } catch (_) {
        return null;
      }
    };

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

      const fromIso = formatIso(row.deduction_from) || formatIso(row.start_date) || '2026-01-01T00:00:00.000Z';
      const toIso = formatIso(row.deduction_to) || formatIso(row.end_date) || '2026-12-31T00:00:00.000Z';

      return {
        timeAccount: leaveType,
        typeId: typeId,
        entitlementMinusPlanned: bal,
        entitlement: ent,
        taken,
        planned: 0.0,
        deductionFrom: fromIso,
        deductionTo: toIso
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

    // 3. Idempotency: prevent duplicate submission for same employee + date range + subtype
    const [dupCheck] = await pool.query(
      `SELECT id_of_request_item FROM ptreq_attabsdata_leave_apply_1
       WHERE CAST(personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED)
         AND sub_type = ? AND start_date = ? AND end_date = ?
         AND lock_indicator NOT IN ('R','W') LIMIT 1`,
      [employeeId, subType, formatDateDdMmYyyy(start_date), formatDateDdMmYyyy(end_date)]
    );
    if (dupCheck.length > 0) {
      return res.status(409).json({ error: 'A leave request for this date range already exists', leaveId: dupCheck[0].id_of_request_item });
    }

    // 4. Get planned working hours from planned_working_time (fallback = 8.5)
    const dailyHours = await getPlannedHoursForEmployee(employeeId);

    const reqItemId = generateRequestId(); // HRAPP-prefixed 32-char ID
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

      const reqItemListId = generateHexId();

      // Insert into ptreq_attabsdata_leave_apply_1 with all SAP columns
      const isFullDay = duration === 'Half-Day' ? '' : 'X';
      // Use planned working hours per employee; half-day = 0.5 × daily; multi-day = days × daily
      const absHours = (daysCount * dailyHours).toFixed(2);

      const applyQuery = `
        INSERT INTO ptreq_attabsdata_leave_apply_1 (
          id_of_request_item, infotype_operation, infotype, start_time, end_time, absence_hours, 
          personnel_number, sub_type, object_id, lock_indicator, end_date, start_date, 
          infotype_record_no, customer_field, customer_field_1, customer_field_2, customer_field_3, 
          customer_field_4, customer_field_5, customer_field_6, customer_field_7, customer_field_8, 
          customer_field_9, prev__day_indicator, att__abs__days, calendar_days, set_hours, 
          full_day, payroll_days, payroll_hours, desc__of_illness, desc__of_illness_1, 
          days_credited, subs_sickness_ind, ind__for_repeated_illness
        ) VALUES (
          ?, 'INS', '2001', ?, ?, ?, 
          ?, ?, '', 'P', ?, ?, 
          '0', '', '', '', '', 
          '', '', '', '', '', 
          '', '', ?, ?, '', 
          ?, ?, ?, '', '', 
          '0', '0', '0'
        )
      `;
      await conn.query(applyQuery, [
        reqItemId, beginTimeStr, endTimeStr, absHours,
        employeeId, subType, formattedEndDate, formattedStartDate,
        daysCount, daysCount,
        isFullDay, daysCount, absHours
      ]);

      // Insert into ptreq_items
      const itemQuery = `
        INSERT INTO ptreq_items (id_of_request_item_list, request_item, guid, guid_1, request_item_type)
        VALUES (?, 1, ?, ?, 'ATTABS')
      `;
      await conn.query(itemQuery, [reqItemListId, reqItemId, reqItemId]);

      // Insert into ptreq_header_leave_approved_1
      const [maxIdRows] = await conn.query('SELECT MAX(CAST(row_id AS UNSIGNED)) AS max_id FROM ptreq_header_leave_approved_1');
      const nextId = (maxIdRows[0].max_id || 4800000) + 1;

      const headerQuery = `
        INSERT INTO ptreq_header_leave_approved_1 (
          document_identification, document_version, document_category, document_status, 
          guid, guid_1, guid_2, guid_3, guid_4, guid_5, guid_6, guid_7, 
          id_of_request_item_list, last_changed_by, time_stamp, time_zone, id
        ) VALUES (?, '2', 'ABSREQ', 'SENT', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 'INDIA', ?)
      `;
      const randomGuid = generateHexId();
      const paddedPernr = employeeId.toString().trim().padStart(8, '0');
      const changedByFormatted = `HR_app_${paddedPernr}`;
      await conn.query(headerQuery, [
        reqItemId, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, reqItemListId, changedByFormatted, nextId
      ]);

      // Sync into absence table
      const absenceQuery = `
        INSERT INTO absence (personnel_number, sub_type, start_date, end_date, start_time, end_time, att__abs__days, lock_indicator, changed_on, changed_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'P', NOW(), ?)
      `;
      await conn.query(absenceQuery, [
        paddedPernr, subType === '1000' ? '1' : (subType === '1001' ? '2' : '3'), formattedStartDate, formattedEndDate, beginTimeStr, endTimeStr, daysCount, changedByFormatted
      ]);

      // Write to SAP Outbound Table Files (.xlsx)
      await writeLeaveOutboundFiles({
        leaveRow: {
          id_of_request_item: reqItemId,
          infotype_operation: 'INS',
          personnel_number: paddedPernr,
          sub_type: subType,
          start_date: formattedStartDate,
          end_date: formattedEndDate,
          att__abs__days: daysCount,
          calendar_days: daysCount,
          lock_indicator: 'P',
          full_day: 'X'
        },
        headerRow: {
          document_identification: reqItemListId,
          document_version: 2,
          document_status: 'SENT',
          guid: randomGuid,
          guid_1: randomGuid,
          id_of_request_item_list: reqItemListId,
          last_changed_by: changedByFormatted,
          time_stamp: Date.now().toString(),
          personnel_number: paddedPernr
        },
        itemRow: {
          id_of_request_item_list: reqItemListId,
          request_item: '1',
          guid: randomGuid,
          guid_1: reqItemId,
          request_item_type: 'ATTABS'
        }
      });

      await conn.commit();

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

      // 4. DLT SMS Notification (Template 1: Leave Applied)
      try {
        await smsService.sendLeaveAppliedSms({
          mobileNumber: smsService.DEFAULT_MOBILE,
          applicantName,
          leaveType: leave_type,
          startDate: formattedStartDate,
          endDate: formattedEndDate
        });
      } catch (smsErr) {
        console.error('[SMS Error Leave Apply]', smsErr.message);
      }



      // Trigger immediate background FTP Sync to /HR_App/Outbound
      try {
        const { runFtpSync } = require('../services/ftp_sync_service');
        runFtpSync().catch(err => console.error('[Immediate Leave Apply FTP Sync Error]', err.message));
      } catch (_) {}

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
    // Step 1: Pre-fetch all employees under this manager (fast indexed lookup)
    const [agentRows] = await pool.query(
      `SELECT personnel_number, reporting_officer, reporting_officer_1 
       FROM zhcm_lr_t_agents_03072026 
       WHERE reporting_officer = ? OR reporting_officer_1 = ?`,
      [managerId, managerId]
    );

    if (!agentRows.length) return res.json([]);

    // Build separate lists: L1 employees and L2 employees
    const l1Employees = agentRows.filter(r => r.reporting_officer == managerId).map(r => r.personnel_number);
    const l2Employees = agentRows.filter(r => r.reporting_officer_1 == managerId).map(r => r.personnel_number);

    const allEmployees = [...new Set([...l1Employees, ...l2Employees])];

    // Step 2: Fetch latest header status for ONLY those employees' leaves
    const placeholders = allEmployees.map(() => '?').join(',');
    const query = `
      SELECT 
        a.id_of_request_item,
        a.personnel_number,
        a.sub_type,
        a.start_date,
        a.end_date,
        a.start_time,
        a.end_time,
        COALESCE(a.att__abs__days, a.calendar_days, 1) AS computed_days,
        h.document_status,
        m.employee_name AS applicant_name
      FROM ptreq_attabsdata_leave_apply_1 a
      JOIN manpower m ON a.personnel_number = m.employee_number
      LEFT JOIN (
        SELECT MAX(h2.row_id) AS max_rid, h2.document_identification
        FROM ptreq_header_leave_approved_1 h2
        WHERE h2.document_identification IN (
          SELECT id_of_request_item FROM ptreq_attabsdata_leave_apply_1 
          WHERE personnel_number IN (${placeholders})
        )
        GROUP BY h2.document_identification
      ) hmax ON hmax.document_identification = a.id_of_request_item
      LEFT JOIN ptreq_header_leave_approved_1 h ON h.row_id = hmax.max_rid
      LEFT JOIN absence ab ON ab.personnel_number = a.personnel_number AND ab.start_date = a.start_date
      WHERE a.personnel_number IN (${placeholders})
        AND ab.personnel_number IS NULL
        AND (
          (a.personnel_number IN (${l1Employees.map(() => '?').join(',') || "''"}) 
           AND (h.document_status IS NULL OR h.document_status IN ('SENT', 'PENDING', 'In Process')))
          OR
          (a.personnel_number IN (${l2Employees.length ? l2Employees.map(() => '?').join(',') : "''"}) 
           AND h.document_status IN ('SENT_L2', 'L1_APPROVED'))
        )
      ORDER BY a.row_id DESC
    `;

    const queryParams = [
      ...allEmployees,    // for hmax subquery IN
      ...allEmployees,    // for WHERE a.personnel_number IN
      ...l1Employees,     // for L1 IN check
      ...(l2Employees.length ? l2Employees : [])  // for L2 IN check
    ];

    const [rows] = await pool.query(query, queryParams);

    if (!rows.length) return res.json([]);

    // Step 3: Post-filter via correct join path
    // ptreq_header uses id_of_request_item_list (NOT document_identification) to link to leaves
    // Join path: leave.id_of_request_item → ptreq_items.guid_1 → ptreq_items.id_of_request_item_list → header.id_of_request_item_list
    const allIds = rows.map(r => r.id_of_request_item);
    const idPlaceholders = allIds.map(() => '?').join(',');

    const [finalStatusRows] = await pool.query(
      `SELECT pi.guid_1 AS leave_id, h.document_status
       FROM ptreq_items pi
       JOIN ptreq_header_leave_approved_1 h ON h.id_of_request_item_list = pi.id_of_request_item_list
       WHERE pi.guid_1 IN (${idPlaceholders})
         AND h.document_status IN ('APPROVED', 'POSTED', 'REJECTED', 'WITHDRAWN', 'CANCELED', 'STOPPED')`,
      allIds
    );

    // Build a set of leave IDs that are already finalized
    const finalizedIds = new Set(finalStatusRows.map(r => r.leave_id));

    const pending = rows
      .filter(row => !finalizedIds.has(row.id_of_request_item))
      .map(row => {
      let leaveType = 'Earned leave';
      if (row.sub_type === '1001') leaveType = 'Casual Leave';
      else if (row.sub_type === '1002') leaveType = 'HPL';
      else if (row.sub_type === '1003') leaveType = 'CHPL';
      else if (row.sub_type === '1010') leaveType = 'Optional Leave';

      const startIso = formatIsoDate(row.start_date);
      const endIso = formatIsoDate(row.end_date) || startIso;

      return {
        id: row.id_of_request_item,
        employeeId: row.applicant_name ? `${row.personnel_number} (${row.applicant_name})` : (row.personnel_number ? row.personnel_number.toString() : ''),
        leaveType,
        startDate: startIso,
        startTime: row.start_time || '00:00:00',
        endDate: endIso,
        endTime: row.end_time || '00:00:00',
        duration: `${row.computed_days || 1} Day(s)`,
        status: (row.document_status === 'SENT_L2' || row.document_status === 'L1_APPROVED') ? 'Pending L2' : 'Pending L1',
        appliedOn: startIso,
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

// In-memory mutex queue per file to prevent concurrent write corruption & file locking errors
const fileWriteQueues = new Map();

/**
 * Helper to write/append rows to individual SAP table Excel files (.xlsx) in outbound dirs.
 * Uses per-file serialized promise queues to prevent file lock & concurrency issues.
 */
async function writeTableOutboundExcel(fileName, sheetName, rowData) {
  if (!rowData) return;

  if (!fileWriteQueues.has(fileName)) {
    fileWriteQueues.set(fileName, Promise.resolve());
  }

  const previousTask = fileWriteQueues.get(fileName);
  const currentTask = (async () => {
    await previousTask.catch(() => {});
    const targetSheetName = 'Sheet1';
    const outboundDirs = [
      process.env.FTP_OUTBOUND_DIR_LOCAL,
      path.join(__dirname, '../../outbound'),
      '/home/u156958239/moil_backend/outbound',
      '/Users/apple/WebBeta/MOIL_PROJECT/Moil_employee_data/Outbound',
      path.join('/tmp', 'ftp_outbound')
    ].filter(Boolean);

    for (const dir of outboundDirs) {
      if (!dir) continue;
      try {
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        const filePath = path.join(dir, fileName);
        let wb;
        if (fs.existsSync(filePath)) {
          wb = xlsx.readFile(filePath);
          const ws = wb.Sheets[targetSheetName] || wb.Sheets[wb.SheetNames[0]];
          const existingRows = ws ? xlsx.utils.sheet_to_json(ws) : [];
          existingRows.push(rowData);
          const newWs = xlsx.utils.json_to_sheet(existingRows);
          wb.SheetNames = [targetSheetName];
          wb.Sheets[targetSheetName] = newWs;
        } else {
          wb = xlsx.utils.book_new();
          const ws = xlsx.utils.json_to_sheet([rowData]);
          xlsx.utils.book_append_sheet(wb, ws, targetSheetName);
        }
        xlsx.writeFile(wb, filePath);
        console.log(`[Outbound Table Excel] Saved ${fileName} at ${filePath}`);
      } catch (e) {
        console.error(`[Outbound Table Excel Error for ${dir}]`, e.message);
      }
    }
  })();

  fileWriteQueues.set(fileName, currentTask);
  return currentTask;
}

/**
 * Write/append leave data into separate SAP table Excel files matching inbound structure
 */
async function writeLeaveOutboundFiles({ leaveRow, headerRow, itemRow, quotaRow }) {
  function toSerial(d) {
    if (!d) return '';
    const dt = new Date(d);
    if (isNaN(dt)) return d;
    return Math.floor((dt - new Date(1899, 11, 30)) / 86400000);
  }

  // 1. PTREQ_ATTABSDATA_Leave_Apply.xlsx
  if (leaveRow) {
    const applyRow = {
      'ID of Request Item':       leaveRow.id_of_request_item || '',
      'Infotype operation':       leaveRow.infotype_operation || 'INS',
      'Infotype':                 '2001',
      'Start time':               leaveRow.start_time || 0,
      'End time':                 leaveRow.end_time || 0,
      'Absence hours':            leaveRow.absence_hours || (parseFloat(leaveRow.att__abs__days || '1') * 8.5),
      'Personnel number':         (leaveRow.personnel_number || '').toString().replace(/^0+/, ''),
      'Sub Type':                 leaveRow.sub_type || '1001',
      'Object ID':                leaveRow.object_id || '',
      'Lock indicator':           leaveRow.lock_indicator || '',
      'End Date':                 toSerial(leaveRow.end_date),
      'Start Date':               toSerial(leaveRow.start_date),
      'Infotype record no.':      leaveRow.infotype_record_no || '0',
      'Customer Field':           '', 'Customer Field_1': '', 'Customer Field_2': '', 'Customer Field_3': '', 'Customer Field_4': '',
      'Customer Field_5': '', 'Customer Field_6': '', 'Customer Field_7': '', 'Customer Field_8': '', 'Customer Field_9': '',
      'Prev. day indicator':      '',
      'Att./abs. days':           parseFloat(leaveRow.att__abs__days || leaveRow.calendar_days || '1'),
      'Calendar days':            parseFloat(leaveRow.calendar_days || '1'),
      'Set hours':                '',
      'Full-day':                 leaveRow.full_day || 'X',
      'Payroll days':             parseFloat(leaveRow.payroll_days || leaveRow.att__abs__days || '1'),
      'Payroll hours':            leaveRow.payroll_hours || (parseFloat(leaveRow.att__abs__days || '1') * 8.5),
      'Desc. of illness':         '', 'Desc. of illness_1': '',
      'Days credited':            0,
      'Subs.sickness ind.':       0, 'Ind. for repeated illness': 0
    };
    await writeTableOutboundExcel('PTREQ_ATTABSDATA_Leave_Apply.xlsx', 'Sheet1', applyRow);
  }

  // 2. PTREQ_HEADER_Leave_Approved.xlsx
  if (headerRow) {
    const headRow = {
      'Document Identification':  headerRow.document_identification || '',
      'Document Version':         headerRow.document_version || 1,
      'Document Category':        'ABSREQ',
      'Document Status':          headerRow.document_status || 'SENT',
      'GUID':                     headerRow.guid || '',
      'GUID_1':                   headerRow.guid_1 || headerRow.guid || '',
      'GUID_2':                   headerRow.guid || '',
      'GUID_3':                   headerRow.guid || '',
      'GUID_4':                   headerRow.guid || '',
      'GUID_5':                   headerRow.guid || '',
      'GUID_6':                   headerRow.guid || '',
      'GUID_7':                   headerRow.guid || '',
      'ID of Request Item List':  headerRow.id_of_request_item_list || '',
      'Last Changed By':          (headerRow.last_changed_by || '').toString().replace(/^0+/, ''),
      'Time Stamp':               headerRow.time_stamp || ((new Date() - new Date(1899, 11, 30)) / 86400000),
      'Time Zone':                'INDIA',
      'ID':                       (headerRow.personnel_number || headerRow.id || '').toString().replace(/^0+/, '')
    };
    await writeTableOutboundExcel('PTREQ_HEADER_Leave_Approved.xlsx', 'Sheet1', headRow);
  }

  // 3. PTREQ_ITEMS-Request Items.xlsx
  if (itemRow) {
    const itmRow = {
      'ID of Request Item List':  itemRow.id_of_request_item_list || '',
      'Request Item':             itemRow.request_item || 1,
      'GUID':                     itemRow.guid || '',
      'GUID_1':                   itemRow.guid_1 || itemRow.guid || '',
      'Request Item Type':        itemRow.request_item_type || 'ATTABS'
    };
    await writeTableOutboundExcel('PTREQ_ITEMS-Request Items.xlsx', 'Sheet1', itmRow);
  }

  // 4. IT2006_Leave_quota.xlsx
  if (quotaRow) {
    const qtaRow = {
      'Personnel number':         (quotaRow.personnel_number || '').toString().replace(/^0+/, ''),
      'Sub Type':                 quotaRow.sub_type || '01',
      'Object ID':                '', 'Lock indicator': '',
      'End Date':                 toSerial(quotaRow.end_date || '2026-12-31'),
      'Start Date':               toSerial(quotaRow.start_date || '2026-01-01'),
      'Infotype record no.':      '0',
      'Changed on':               toSerial(new Date().toISOString().slice(0, 10)),
      'Changed by':               (quotaRow.changed_by || '').toString().replace(/^0+/, ''),
      'Historical record': '', 'Text exists': '', 'Reference fields exist (cost assign.)': '', 'Conf. fields exist': '', 'Screen control': '', 'Reason for Change': '',
      'Reserved Field/Unused Field': '', 'Reserved Field/Unused Field_1': '', 'Reserved Field/Unused Field_2': '', 'Reserved Field/Unused Field_3': '',
      'Reserved Field/Unused Field of Length 2': '', 'Reserved Field/Unused Field of Length 2_1': '', 'Grouping Value': '',
      'Start time': 0, 'End time': 0, 'Prev. day indicator': '',
      'Absence quota type':       quotaRow.absence_quota_type || '1',
      'Quota number':             parseFloat(quotaRow.quota_number || '0'),
      'Quota deduction':          parseFloat(quotaRow.quota_deduction || '0'),
      'Quota counter':            quotaRow.quota_counter || '0',
      'Deduction from':           toSerial(quotaRow.deduction_from || '2026-01-01'),
      'Deduction to':             toSerial(quotaRow.deduction_to || '2026-12-31'),
      'Logical system':           'PECCLNT100', 'Definition set': '', 'Definition subset': '', 'Time data ID type': ''
    };
    await writeTableOutboundExcel('IT2006_Leave_quota.xlsx', 'Sheet1', qtaRow);
  }
}

// Function wrapper for backwards compatibility
async function writeLeaveCumulativeExcel(args) {
  return await writeLeaveOutboundFiles(args);
}

/**
 * @route   POST /api/leaves/approve
 */
router.post('/leaves/approve', authenticateToken, async (req, res) => {
  const { leave_id, remarks } = req.body;
  const managerId = req.user.employee_number;

  try {
    // 1. Fetch full leave request details
    const [appRows] = await pool.query(
      `SELECT * FROM ptreq_attabsdata_leave_apply_1 WHERE id_of_request_item = ? LIMIT 1`,
      [leave_id]
    );
    if (appRows.length === 0) return res.status(404).json({ error: 'Leave request not found' });
    const appRow = appRows[0];
    const applicantId = appRow.personnel_number;

    // 2. Get the ptreq_items bridge row (needed for correct header id_of_request_item_list)
    const [itemRows] = await pool.query(
      `SELECT * FROM ptreq_items WHERE guid_1 = ? LIMIT 1`,
      [leave_id]
    );
    const itemRow = itemRows.length > 0 ? itemRows[0] : null;
    const reqItemListId = itemRow ? itemRow.id_of_request_item_list : leave_id;

    // 3. Get current latest header status via ptreq_items join (correct path)
    const [headerRows] = await pool.query(
      `SELECT h.* FROM ptreq_header_leave_approved_1 h
       JOIN ptreq_items pi ON pi.id_of_request_item_list = h.id_of_request_item_list
       WHERE pi.guid_1 = ?
       ORDER BY h.row_id DESC LIMIT 1`,
      [leave_id]
    );
    const currentStatus = headerRows.length > 0 ? headerRows[0].document_status : 'SENT';
    const latestHeader = headerRows.length > 0 ? headerRows[0] : null;

    // Already finalized — refuse
    if (['APPROVED', 'POSTED', 'REJECTED', 'WITHDRAWN', 'CANCELED'].includes(currentStatus)) {
      return res.status(409).json({ error: 'Leave already processed', status: currentStatus });
    }

    // 4. Fetch agent mapping for the applicant
    const [agents] = await pool.query(
      `SELECT reporting_officer, reporting_officer_1 FROM zhcm_lr_t_agents_03072026 WHERE personnel_number = ? LIMIT 1`,
      [applicantId]
    );
    if (agents.length === 0) return res.status(404).json({ error: 'Agent mapping not found for employee' });

    const l1Raw = agents[0].reporting_officer ? agents[0].reporting_officer.toString().trim() : '0';
    const l2Raw = agents[0].reporting_officer_1 ? agents[0].reporting_officer_1.toString().trim() : '0';
    const hasValidL2 = l2Raw && l2Raw !== '0' && l2Raw !== '' && l2Raw !== 'N/A' && l2Raw !== l1Raw;

    const managerStr = managerId.toString().trim();
    const isL1 = (l1Raw !== '0' && l1Raw === managerStr) || (parseInt(l1Raw) === parseInt(managerStr));
    const isL2 = hasValidL2 && ((l2Raw === managerStr) || (parseInt(l2Raw) === parseInt(managerStr)));

    if (!isL1 && !isL2) {
      return res.status(403).json({ error: 'You are not a designated reporting officer for this employee' });
    }

    // 5. Determine next status based on level and hierarchy
    let nextStatus;
    if (isL1 && (currentStatus === 'SENT' || currentStatus === 'PENDING' || currentStatus === 'In Process')) {
      nextStatus = hasValidL2 ? 'SENT_L2' : 'APPROVED';
    } else if (isL2 && (currentStatus === 'SENT_L2' || currentStatus === 'L1_APPROVED')) {
      nextStatus = 'APPROVED';
    } else if (isL2 && currentStatus === 'SENT' && !hasValidL2) {
      // L2 is also the only approver (edge case)
      nextStatus = 'APPROVED';
    } else {
      return res.status(400).json({ error: `Cannot approve leave in current status: ${currentStatus}` });
    }

    // 6. Formatted audit fields
    const managerPaddedPernr = managerStr.padStart(8, '0');
    const changedByFormatted = `HR_app_${managerPaddedPernr}`;
    const nowTs = new Date().toISOString().replace('T', ' ').slice(0, 19);
    const docVersion = latestHeader ? (parseInt(latestHeader.document_version || '1') + 1).toString() : '1';
    const guid = latestHeader ? (latestHeader.guid || leave_id) : leave_id;
    const docIdent = (latestHeader && latestHeader.document_identification) ? latestHeader.document_identification : reqItemListId;

    // 7-9. Transactional: INSERT header row + UPDATE lock_indicator + deduct quota atomically
    const conn = await pool.getConnection();
    await conn.beginTransaction();
    let quotaRowForExcel = null;
    try {
      // 7. INSERT new header row (audit trail — one row per status change)
      await conn.query(
        `INSERT INTO ptreq_header_leave_approved_1
         (document_identification, document_version, document_category, document_status,
          guid, guid_1, guid_2, guid_3, guid_4, guid_5, guid_6, guid_7,
          id_of_request_item_list, last_changed_by, time_stamp, time_zone, id)
         VALUES (?, ?, 'ABSREQ', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'INDIA', ?)`,
        [docIdent, docVersion, nextStatus,
         guid, guid, guid, guid, guid, guid, guid, guid,
         reqItemListId, changedByFormatted, nowTs, applicantId]
      );

      // 8. Update lock_indicator in leave_apply table
      const lockIndicator = nextStatus === 'SENT_L2' ? 'P2' : (nextStatus === 'APPROVED' ? '' : 'P');
      await conn.query(
        `UPDATE ptreq_attabsdata_leave_apply_1 SET lock_indicator = ? WHERE id_of_request_item = ?`,
        [lockIndicator, leave_id]
      );

      // 9. If FULLY APPROVED → deduct from leave_quota (idempotency: check lock_indicator was NOT already blank)
      if (nextStatus === 'APPROVED') {
        const days = parseFloat(appRow.att__abs__days || appRow.calendar_days || 1);
        // Sub type mapping: leave sub_type → quota sub_type
        let quotaSubType = '01'; // EL (Earned Leave) - default
        if      (appRow.sub_type === '1001') quotaSubType = '02'; // CL  (Casual Leave)
        else if (appRow.sub_type === '1002') quotaSubType = '03'; // HPL (Half Pay Leave)
        else if (appRow.sub_type === '1010') quotaSubType = '05'; // Optional Leave

        // Guard: only deduct if the previous lock_indicator was NOT already blank (already approved)
        if (appRow.lock_indicator !== '') {
          await conn.query(
            `UPDATE leave_quota
             SET quota_deduction = CAST(CAST(COALESCE(quota_deduction, '0') AS DECIMAL(10,2)) + ? AS CHAR)
             WHERE personnel_number = ? AND sub_type = ?`,
            [days, applicantId, quotaSubType]
          );
        }

        // Fetch updated quota row for Excel export (outside transaction is fine here)
        const [updatedQuota] = await conn.query(
          `SELECT * FROM leave_quota WHERE personnel_number = ? AND sub_type = ? LIMIT 1`,
          [applicantId, quotaSubType]
        );
        quotaRowForExcel = updatedQuota.length > 0 ? updatedQuota[0] : null;
      }

      await conn.commit();
    } catch (txErr) {
      await conn.rollback();
      throw txErr;
    } finally {
      conn.release();
    }

    // 10. Build the new header row data for Excel
    const newHeaderRowData = {
      document_identification: leave_id,
      document_version: docVersion,
      document_status: nextStatus,
      guid, guid_1: guid,
      id_of_request_item_list: reqItemListId,
      last_changed_by: changedByFormatted,
      time_stamp: nowTs,
    };

    // 11. Write to daily cumulative Excel (all affected tables as sheets)
    await writeLeaveCumulativeExcel({
      leaveRow: appRow,
      headerRow: newHeaderRowData,
      itemRow: itemRow || { id_of_request_item_list: reqItemListId, guid_1: leave_id },
      quotaRow: quotaRowForExcel,
    });

    // 12. Record outbound change for FTP delta tracking
    await recordOutboundChange(
      'PTREQ_HEADER_Leave_Approved',
      leave_id,
      'UPDATE',
      { document_status: nextStatus, last_changed_by: changedByFormatted, req_item_list_id: reqItemListId },
      newHeaderRowData
    );

    // 13. Trigger background FTP sync
    try {
      const { runFtpSync } = require('../services/ftp_sync_service');
      runFtpSync().catch(err => console.error('[Immediate FTP Sync Error]', err.message));
    } catch (_) {}

    // 14. Notify
    await logApproval(managerId, 'Leave', leave_id, applicantId, 'Approved', remarks);
    const managerName = await getEmployeeName(managerId);
    const applicantName = await getEmployeeName(applicantId);

    if (nextStatus === 'APPROVED') {
      await createNotification(applicantId, 'Leave Request Approved',
        `Your leave request has been fully approved by ${managerName}.${remarks ? ' Remarks: ' + remarks : ''}`,
        'Leave');
      try {
        await smsService.sendLeaveApprovedSms({
          mobileNumber: smsService.DEFAULT_MOBILE,
          approverName: managerName,
          leaveType: appRow.sub_type === '1001' ? 'Casual Leave' : (appRow.sub_type === '1002' ? 'HPL' : 'Earned Leave'),
          startDate: appRow.start_date,
          endDate: appRow.end_date
        });
      } catch (smsErr) { console.error('[SMS Error Approved]', smsErr.message); }
    } else if (nextStatus === 'SENT_L2') {
      await createNotification(applicantId, 'Leave Request L1 Approved',
        `Your leave request was approved by L1 (${managerName}) and is now pending L2 approval.`, 'Leave');
      if (hasValidL2) {
        await createNotification(l2Raw, 'Pending Leave Approval',
          `Leave request for ${applicantName} (L1 approved by ${managerName}) requires your approval.`, 'Leave');
      }
      try {
        await smsService.sendLeaveL1ApprovedSms({
          mobileNumber: smsService.DEFAULT_MOBILE,
          title: 'Mr.',
          applicantName,
          leaveType: appRow.sub_type === '1001' ? 'Casual Leave' : (appRow.sub_type === '1002' ? 'HPL' : 'Earned Leave'),
          startDate: appRow.start_date,
          endDate: appRow.end_date,
          l1Title: 'Mr.',
          l1Name: managerName
        });
      } catch (smsErr) { console.error('[SMS Error L1 Approved]', smsErr.message); }
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
    // 1. Fetch leave details
    const [appRows] = await pool.query(
      `SELECT * FROM ptreq_attabsdata_leave_apply_1 WHERE id_of_request_item = ? LIMIT 1`,
      [leave_id]
    );
    if (appRows.length === 0) return res.status(404).json({ error: 'Leave request not found' });
    const appRow = appRows[0];
    const applicantId = appRow.personnel_number;

    // 2. Get ptreq_items bridge row
    const [itemRows] = await pool.query(
      `SELECT * FROM ptreq_items WHERE guid_1 = ? LIMIT 1`,
      [leave_id]
    );
    const itemRow = itemRows.length > 0 ? itemRows[0] : null;
    const reqItemListId = itemRow ? itemRow.id_of_request_item_list : leave_id;

    // 3. Get current header status
    const [headerRows] = await pool.query(
      `SELECT h.* FROM ptreq_header_leave_approved_1 h
       JOIN ptreq_items pi ON pi.id_of_request_item_list = h.id_of_request_item_list
       WHERE pi.guid_1 = ?
       ORDER BY h.row_id DESC LIMIT 1`,
      [leave_id]
    );
    const latestHeader = headerRows.length > 0 ? headerRows[0] : null;
    const currentStatus = latestHeader ? latestHeader.document_status : 'SENT';

    if (['APPROVED', 'POSTED', 'REJECTED', 'WITHDRAWN', 'CANCELED'].includes(currentStatus)) {
      return res.status(409).json({ error: 'Leave already processed', status: currentStatus });
    }

    // 4. Validate manager is a designated reporting officer
    const [agents] = await pool.query(
      `SELECT reporting_officer, reporting_officer_1 FROM zhcm_lr_t_agents_03072026 WHERE personnel_number = ? LIMIT 1`,
      [applicantId]
    );
    if (agents.length > 0) {
      const l1Raw = agents[0].reporting_officer ? agents[0].reporting_officer.toString().trim() : '0';
      const l2Raw = agents[0].reporting_officer_1 ? agents[0].reporting_officer_1.toString().trim() : '0';
      const managerStr = managerId.toString().trim();
      const isL1 = (l1Raw !== '0') && (l1Raw === managerStr || parseInt(l1Raw) === parseInt(managerStr));
      const isL2 = (l2Raw !== '0') && (l2Raw === managerStr || parseInt(l2Raw) === parseInt(managerStr));
      if (!isL1 && !isL2) {
        return res.status(403).json({ error: 'You are not a designated reporting officer for this employee' });
      }
    }

    // 5. Format audit fields
    const managerPaddedPernr = managerId.toString().trim().padStart(8, '0');
    const changedByFormatted = `HR_app_${managerPaddedPernr}`;
    const nowTs = new Date().toISOString().replace('T', ' ').slice(0, 19);
    const docVersion = latestHeader ? (parseInt(latestHeader.document_version || '1') + 1).toString() : '1';
    const guid = latestHeader ? (latestHeader.guid || leave_id) : leave_id;

    const docIdent = (latestHeader && latestHeader.document_identification) ? latestHeader.document_identification : reqItemListId;

    // 6. INSERT new header row with REJECTED status (audit trail)
    await pool.query(
      `INSERT INTO ptreq_header_leave_approved_1
       (document_identification, document_version, document_category, document_status,
        guid, guid_1, guid_2, guid_3, guid_4, guid_5, guid_6, guid_7,
        id_of_request_item_list, last_changed_by, time_stamp, time_zone, id)
       VALUES (?, ?, 'ABSREQ', 'REJECTED', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'INDIA', ?)`,
      [docIdent, docVersion,
       guid, guid, guid, guid, guid, guid, guid, guid,
       reqItemListId, changedByFormatted, nowTs, applicantId]
    );

    // 7. Set lock_indicator to R (rejected)
    await pool.query(
      `UPDATE ptreq_attabsdata_leave_apply_1 SET lock_indicator = 'R' WHERE id_of_request_item = ?`,
      [leave_id]
    );

    // 8. Write to daily cumulative Excel for FTP outbound
    const rejectedHeaderData = {
      document_identification: leave_id,
      document_version: docVersion,
      document_status: 'REJECTED',
      guid, guid_1: guid,
      id_of_request_item_list: reqItemListId,
      last_changed_by: changedByFormatted,
      time_stamp: nowTs,
    };
    await writeLeaveCumulativeExcel({
      leaveRow: appRow,
      headerRow: rejectedHeaderData,
      itemRow: itemRow || { id_of_request_item_list: reqItemListId, guid_1: leave_id },
      quotaRow: null,
    });

    // 9. Record outbound change
    await recordOutboundChange(
      'PTREQ_HEADER_Leave_Approved', leave_id, 'UPDATE',
      { document_status: 'REJECTED', last_changed_by: changedByFormatted, req_item_list_id: reqItemListId },
      rejectedHeaderData
    );

    // 10. Trigger FTP sync
    try {
      const { runFtpSync } = require('../services/ftp_sync_service');
      runFtpSync().catch(err => console.error('[Immediate FTP Sync Error]', err.message));
    } catch (_) {}

    // 11. Notify
    await logApproval(managerId, 'Leave', leave_id, applicantId, 'Rejected', remarks);
    const managerName = await getEmployeeName(managerId);
    await createNotification(applicantId, 'Leave Request Rejected',
      `Your leave request has been rejected by ${managerName}.${remarks ? ' Remarks: ' + remarks : ''}`,
      'Leave');
    try {
      await smsService.sendLeaveRejectedSms({
        mobileNumber: smsService.DEFAULT_MOBILE,
        approverName: managerName,
        leaveType: appRow.sub_type === '1001' ? 'Casual Leave' : (appRow.sub_type === '1002' ? 'HPL' : 'Earned Leave'),
        startDate: appRow.start_date,
        endDate: appRow.end_date
      });
    } catch (smsErr) { console.error('[SMS Error Rejected]', smsErr.message); }

    res.json({ message: 'Leave request rejected successfully' });
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
    const empPaddedPernr = employeeId.toString().trim().padStart(8, '0');
    const empChangedBy = `HR_app_${empPaddedPernr}`;

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
          changed_by = ?
        WHERE id = ?
      `;
      await pool.query(updateQuery, [destination, formattedStartDate, formattedEndDate, purpose, transport_mode, tour_type, newPlanningStatus, empChangedBy, existingId]);
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
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?)
      `;
      const [result] = await pool.query(insertQuery, [employeeId, destination, formattedStartDate, formattedEndDate, purpose, transport_mode, tour_type, newPlanningStatus, empChangedBy]);
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

    // Guard: already finalized?
    if (['2', '3'].includes(tour.planning_status)) {
      const statusLabel = tour.planning_status === '2' ? 'Approved' : 'Rejected';
      return res.status(409).json({ error: `Tour already ${statusLabel}`, status: tour.planning_status });
    }

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

    const managerPaddedPernr = managerId.toString().trim().padStart(8, '0');
    const mgrChangedBy = `HR_app_${managerPaddedPernr}`;
    const updateQuery = `
      UPDATE travel SET planning_status = ?, changed_on = NOW(), changed_by = ? WHERE id = ?
    `;
    await pool.query(updateQuery, [nextStatus, mgrChangedBy, tour_id]);
    await logApproval(managerId, 'Tour', tour_id, tour.personnel_number, 'Approved', remarks);

    await recordOutboundChange(
      'travel',
      tour_id,
      'UPDATE',
      { personnel_number: tour.personnel_number, trip_destination: tour.trip_destination, planning_status: nextStatus, changed_by: mgrChangedBy },
      { id: tour_id, personnel_number: tour.personnel_number, planning_status: nextStatus }
    );

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

      await recordOutboundChange(
        'travel',
        tour_id,
        'UPDATE',
        { personnel_number: tour.personnel_number, trip_destination: tour.trip_destination, planning_status: '3', changed_by: managerId },
        { id: tour_id, personnel_number: tour.personnel_number, planning_status: '3' }
      );

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
      id: (row.row_id || row.id || '').toString(),
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
  const targetEmpId = (employee_id || loggedInId).toString().trim();
  const cleanEmpId = targetEmpId.replace(/^0+/, '');
  const paddedPernr = cleanEmpId.padStart(8, '0');

  try {
    // 1. Validation: Only self or respective reporting officer can encash
    const agentQuery = `SELECT reporting_officer, reporting_officer_1 FROM zhcm_lr_t_agents_03072026 WHERE personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED) LIMIT 1`;
    const [agents] = await pool.query(agentQuery, [cleanEmpId, cleanEmpId]);
    if (agents.length === 0) {
      return res.status(400).json({ error: 'Applicant agent mapping not found' });
    }

    const { reporting_officer: l1, reporting_officer_1: l2 } = agents[0];
    if (cleanEmpId != loggedInId && l1 != loggedInId && l2 != loggedInId) {
      return res.status(403).json({ error: 'Unauthorized. Only self or the designated reporting officer can submit leave encashment.' });
    }

    // 2. Encashment rule: Max 50% of available Earned Leave quota
    const [quotaRows] = await pool.query(
      `SELECT * FROM leave_quota WHERE (personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED)) AND (absence_quota_type = '1' OR sub_type = '01' OR sub_type = '1000') ORDER BY deduction_to DESC LIMIT 1`,
      [cleanEmpId, cleanEmpId]
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
    const loggedInPaddedPernr = loggedInId.toString().trim().padStart(8, '0');
    const changedByFormatted = `HR_app_${loggedInPaddedPernr}`;
    const docNumber = '303' + Math.floor(100000000 + Math.random() * 900000000).toString();

    // 4. Insert into time_quota_compensation_infotype table
    const insertQuery = `
      INSERT INTO time_quota_compensation_infotype (
        personnel_number, sub_type, start_date, end_date, comp__quota_number, 
        quota_type, time_quota_compensation_method, changed_by, changed_on, infotype_record_no, logical_system, document_number,
        encashment_status, is_quota_deducted
      ) VALUES (?, '1000', CURDATE(), CURDATE(), ?, '01', '1000', ?, NOW(), '0', 'PECCLNT100', ?, 'PENDING', 0)
    `;
    const [result] = await pool.query(insertQuery, [paddedPernr, finalDays, changedByFormatted, docNumber]);

    // 6. Record outbound change (pending — will be updated on approval)
    await recordOutboundChange(
      'time_quota_compensation_infotype',
      docNumber,
      'INSERT',
      { personnel_number: paddedPernr, comp__quota_number: finalDays, changed_by: changedByFormatted, encashment_status: 'PENDING' },
      { personnel_number: paddedPernr, sub_type: '1000', comp__quota_number: finalDays, quota_type: '01', time_quota_compensation_method: '1000', changed_by: changedByFormatted, document_number: docNumber, encashment_status: 'PENDING' }
    );

    // 7. Notify applicant + ROs
    const applicantName = await getEmployeeName(cleanEmpId);
    await createNotification(cleanEmpId, 'Leave Encashment Submitted',
      `Your leave encashment request for ${finalDays} days has been submitted and is pending approval.`, 'Leave');
    if (l1 && l1 !== '0' && l1 !== 'N/A') {
      await createNotification(l1, 'New Encashment Request',
        `${applicantName} (${cleanEmpId}) submitted a leave encashment request for ${finalDays} days.`, 'Leave');
    }
    if (l2 && l2 !== '0' && l2 !== 'N/A' && l2 !== l1) {
      await createNotification(l2, 'New Encashment Request',
        `${applicantName} (${cleanEmpId}) submitted a leave encashment request for ${finalDays} days.`, 'Leave');
    }

    try {
      await smsService.sendLeaveEncashAppliedSms({
        mobileNumber: smsService.DEFAULT_MOBILE,
        applicantName,
        days: finalDays
      });
    } catch (smsErr) { console.error('[SMS Error Encash Apply]', smsErr.message); }

    res.status(201).json({
      message: 'Leave encashment request submitted successfully. Pending approval.',
      id: result.insertId,
      docNumber,
      appliedDays: finalDays,
      encashmentStatus: 'PENDING'
    });
  } catch (error) {
    console.error('[Leave Encashment Error]', error.message);
    res.status(500).json({ error: 'Failed to process leave encashment', message: error.message });
  }
});

/**
 * @route   POST /api/leave-encashment/approve
 * @desc    Approve a pending encashment — deducts quota ONCE using is_quota_deducted guard
 */
router.post('/leave-encashment/approve', authenticateToken, async (req, res) => {
  const { encashment_id, remarks } = req.body;
  const managerId = req.user.employee_number;

  try {
    if (!encashment_id) return res.status(400).json({ error: 'encashment_id is required' });

    // 1. Fetch the pending encashment record
    const [encRows] = await pool.query(
      `SELECT * FROM time_quota_compensation_infotype WHERE id = ? LIMIT 1`,
      [encashment_id]
    );
    if (encRows.length === 0) return res.status(404).json({ error: 'Encashment record not found' });
    const enc = encRows[0];

    // 2. Guard: already processed?
    if (enc.encashment_status && enc.encashment_status !== 'PENDING') {
      return res.status(409).json({ error: `Encashment already processed`, status: enc.encashment_status });
    }

    // 3. Verify manager is the L1 or L2 for the applicant
    const cleanEmpId = enc.personnel_number.toString().replace(/^0+/, '');
    const [agents] = await pool.query(
      `SELECT reporting_officer, reporting_officer_1 FROM zhcm_lr_t_agents_03072026 WHERE personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED) LIMIT 1`,
      [cleanEmpId, cleanEmpId]
    );
    if (agents.length > 0) {
      const l1 = (agents[0].reporting_officer || '0').toString().trim();
      const l2 = (agents[0].reporting_officer_1 || '0').toString().trim();
      const mgrStr = managerId.toString().trim();
      const isL1 = l1 !== '0' && (l1 === mgrStr || parseInt(l1) === parseInt(mgrStr));
      const isL2 = l2 !== '0' && (l2 === mgrStr || parseInt(l2) === parseInt(mgrStr));
      if (!isL1 && !isL2 && cleanEmpId !== mgrStr) {
        return res.status(403).json({ error: 'You are not designated to approve this encashment' });
      }
    }

    const managerPaddedPernr = managerId.toString().trim().padStart(8, '0');
    const changedByFormatted = `HR_app_${managerPaddedPernr}`;
    const finalDays = parseFloat(enc.comp__quota_number || 0);

    // 4. Transactional: update status + deduct quota (idempotency via is_quota_deducted = 0 check)
    const conn = await pool.getConnection();
    await conn.beginTransaction();
    try {
      // Update encashment_status
      await conn.query(
        `UPDATE time_quota_compensation_infotype 
         SET encashment_status = 'APPROVED', changed_by = ?, changed_on = NOW()
         WHERE id = ? AND (encashment_status = 'PENDING' OR encashment_status IS NULL)`,
        [changedByFormatted, encashment_id]
      );

      // Deduct quota ONLY if is_quota_deducted = 0 (double-deduction guard)
      const [guardResult] = await conn.query(
        `UPDATE time_quota_compensation_infotype SET is_quota_deducted = 1
         WHERE id = ? AND is_quota_deducted = 0`,
        [encashment_id]
      );

      if (guardResult.affectedRows === 1) {
        // Safe to deduct — runs exactly once
        await conn.query(
          `UPDATE leave_quota 
           SET quota_deduction = CAST(CAST(COALESCE(quota_deduction, '0') AS DECIMAL(10,2)) + ? AS CHAR) 
           WHERE (personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = CAST(? AS UNSIGNED)) 
             AND (absence_quota_type = '1' OR sub_type = '01' OR sub_type = '1000')`,
          [finalDays, cleanEmpId, cleanEmpId]
        );
      }

      await conn.commit();
    } catch (txErr) {
      await conn.rollback();
      throw txErr;
    } finally {
      conn.release();
    }

    // 5. Write Excel outbound for IT0416 (encashment)
    function toSerialDate(d) {
      const dt = new Date(d);
      return Math.floor((dt - new Date(1899, 11, 30)) / 86400000);
    }
    await writeTableOutboundExcel('IT0416_Time_Compensation.xlsx', 'time_quota_compensation_infotype', {
      'Personnel number': enc.personnel_number,
      'Sub Type': '1000',
      'Start Date': toSerialDate(new Date(enc.start_date || new Date())),
      'End Date': toSerialDate(new Date(enc.end_date || new Date())),
      'Comp. quota number': finalDays,
      'Quota type': 'A',
      'Time quota compensation method': '1000',
      'Changed On': toSerialDate(new Date()),
      'Changed By': changedByFormatted,
      'Infotype record no.': '0',
      'Logical system': 'PECCLNT100',
      'Document number': enc.document_number,
      'Absence quota type': '1',
      'Deduction rule': '0'
    });
    // 6. Record outbound change
    await recordOutboundChange(
      'time_quota_compensation_infotype',
      enc.document_number,
      'UPDATE',
      { encashment_status: 'APPROVED', changed_by: changedByFormatted },
      { personnel_number: enc.personnel_number, comp__quota_number: finalDays, encashment_status: 'APPROVED', document_number: enc.document_number }
    );

    // 7. Trigger FTP sync
    try {
      const { runFtpSync } = require('../services/ftp_sync_service');
      runFtpSync().catch(err => console.error('[Encashment Approve FTP Sync Error]', err.message));
    } catch (_) {}

    // 8. Notify
    await logApproval(managerId, 'Encashment', encashment_id, cleanEmpId, 'Approved', remarks);
    const managerName = await getEmployeeName(managerId);
    await createNotification(cleanEmpId, 'Leave Encashment Approved',
      `Your leave encashment request for ${finalDays} days has been approved by ${managerName}.${remarks ? ' Remarks: ' + remarks : ''}`,
      'Leave');
    try {
      await smsService.sendLeaveEncashApprovedSms({
        mobileNumber: smsService.DEFAULT_MOBILE,
        applicantName: await getEmployeeName(cleanEmpId),
        days: finalDays,
        approverName: managerName
      });
    } catch (smsErr) { console.error('[SMS Error Encash Approve]', smsErr.message); }

    res.json({ message: 'Encashment approved successfully', appliedDays: finalDays, status: 'APPROVED' });
  } catch (error) {
    console.error('[Encashment Approve Error]', error.message);
    res.status(500).json({ error: 'Failed to approve encashment', message: error.message });
  }
});

/**
 * @route   POST /api/leave-encashment/reject
 * @desc    Reject a pending encashment — quota is NOT deducted
 */
router.post('/leave-encashment/reject', authenticateToken, async (req, res) => {
  const { encashment_id, remarks } = req.body;
  const managerId = req.user.employee_number;

  try {
    if (!encashment_id) return res.status(400).json({ error: 'encashment_id is required' });

    const [encRows] = await pool.query(
      `SELECT * FROM time_quota_compensation_infotype WHERE id = ? LIMIT 1`,
      [encashment_id]
    );
    if (encRows.length === 0) return res.status(404).json({ error: 'Encashment record not found' });
    const enc = encRows[0];

    if (enc.encashment_status && enc.encashment_status !== 'PENDING') {
      return res.status(409).json({ error: 'Encashment already processed', status: enc.encashment_status });
    }

    const managerPaddedPernr = managerId.toString().trim().padStart(8, '0');
    const changedByFormatted = `HR_app_${managerPaddedPernr}`;

    // Update status to REJECTED — quota is untouched
    await pool.query(
      `UPDATE time_quota_compensation_infotype 
       SET encashment_status = 'REJECTED', changed_by = ?, changed_on = NOW()
       WHERE id = ? AND (encashment_status = 'PENDING' OR encashment_status IS NULL)`,
      [changedByFormatted, encashment_id]
    );

    await recordOutboundChange(
      'time_quota_compensation_infotype',
      enc.document_number,
      'UPDATE',
      { encashment_status: 'REJECTED', changed_by: changedByFormatted },
      { personnel_number: enc.personnel_number, encashment_status: 'REJECTED', document_number: enc.document_number }
    );

    await logApproval(managerId, 'Encashment', encashment_id, enc.personnel_number.toString().replace(/^0+/, ''), 'Rejected', remarks);
    const managerName = await getEmployeeName(managerId);
    await createNotification(enc.personnel_number.toString().replace(/^0+/, ''), 'Leave Encashment Rejected',
      `Your leave encashment request has been rejected by ${managerName}.${remarks ? ' Remarks: ' + remarks : ''}`,
      'Leave');
    try {
      await smsService.sendLeaveEncashRejectedSms({
        mobileNumber: smsService.DEFAULT_MOBILE,
        days: parseFloat(enc.comp__quota_number || 0)
      });
    } catch (smsErr) { console.error('[SMS Error Encash Reject]', smsErr.message); }

    res.json({ message: 'Encashment rejected successfully', status: 'REJECTED' });
  } catch (error) {
    console.error('[Encashment Reject Error]', error.message);
    res.status(500).json({ error: 'Failed to reject encashment', message: error.message });
  }
});

/**
 * @route   POST /api/send-sms
 * @desc    Send SMS notification using MOIL DLT templates (Templates 1 - 9)
 *          Default fallback mobile number: 9503864429
 */
router.post('/send-sms', authenticateToken, async (req, res) => {
  const {
    template_id, templateId,
    mobile, mobileNumber,
    applicant_name, applicantName,
    approver_name, approverName,
    leave_type, leaveType,
    start_date, startDate,
    end_date, endDate,
    days, title, l1_title, l1_name, actor_name
  } = req.body;

  const tId = String(template_id || templateId || '1').trim();
  const targetPhone = mobile || mobileNumber || smsService.DEFAULT_MOBILE;
  const appName = applicant_name || applicantName || 'Employee';
  const apprName = approver_name || approverName || 'Officer';
  const lType = leave_type || leaveType || 'Casual Leave';
  const sDate = start_date || startDate || '2026-08-20';
  const eDate = end_date || endDate || '2026-08-22';
  const numDays = days || 1;

  let result;
  try {
    switch (tId) {
      case '1':
      case '1107163177301329708':
        result = await smsService.sendLeaveAppliedSms({ mobileNumber: targetPhone, applicantName: appName, leaveType: lType, startDate: sDate, endDate: eDate });
        break;
      case '2':
      case '1107163177311027634':
        result = await smsService.sendLeaveApprovedSms({ mobileNumber: targetPhone, approverName: apprName, leaveType: lType, startDate: sDate, endDate: eDate });
        break;
      case '3':
      case '1107163177318779886':
        result = await smsService.sendLeaveRejectedSms({ mobileNumber: targetPhone, approverName: apprName, leaveType: lType, startDate: sDate, endDate: eDate });
        break;
      case '4':
      case '1107165717011044676':
        result = await smsService.sendLeaveEncashApprovedSms({ mobileNumber: targetPhone, applicantName: appName, days: numDays, approverName: apprName });
        break;
      case '5':
      case '1107165717016334079':
        result = await smsService.sendLeaveEncashRejectedSms({ mobileNumber: targetPhone, days: numDays });
        break;
      case '6':
      case '1107165717026952826':
        result = await smsService.sendLeaveEncashAppliedVariantSms({ mobileNumber: targetPhone, applicantName: appName, days: numDays });
        break;
      case '7':
      case '1107165901001503660':
        result = await smsService.sendLeaveEncashAppliedSms({ mobileNumber: targetPhone, applicantName: appName, days: numDays });
        break;
      case '8':
      case '1107165916221536406':
        result = await smsService.sendLeaveL1ApprovedSms({ mobileNumber: targetPhone, title: title || 'Mr.', applicantName: appName, leaveType: lType, startDate: sDate, endDate: eDate, l1Title: l1_title || 'Mr.', l1Name: l1_name || apprName });
        break;
      case '9':
      case '1107177547706676415':
        result = await smsService.sendApplicationNotedSms({ mobileNumber: targetPhone, actorName: actor_name || apprName, leaveType: lType, startDate: sDate, endDate: eDate });
        break;
      default:
        return res.status(400).json({ error: 'Invalid template_id. Must be 1-9 or valid DLT Template ID.' });
    }

    res.json({ message: 'SMS trigger initiated', templateId: tId, targetPhone, result });
  } catch (error) {
    console.error('[POST /api/send-sms Error]', error.message);
    res.status(500).json({ error: 'Failed to send SMS', message: error.message });
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
  let insertId = null;

  // 1. Store change record in app_outbound_changes table
  try {
    const changedJson = typeof changedColumns === 'string' ? changedColumns : JSON.stringify(changedColumns || {});
    const rowJson = typeof rowData === 'string' ? rowData : JSON.stringify(rowData || {});

    const [res] = await pool.query(
      `INSERT INTO app_outbound_changes (table_name, record_id, action_type, changed_columns, row_data, is_synced, created_at)
       VALUES (?, ?, ?, ?, ?, 0, NOW())`,
      [tableName, recordId, actionType, changedJson, rowJson]
    );
    insertId = res.insertId;
    console.log(`[Outbound Record DB] Stored outbound change #${insertId} for ${tableName}:${recordId}`);
  } catch (dbErr) {
    console.error('[Outbound Record DB Error]', dbErr.message);
  }

  // 2. Write JSON & Excel (.xlsx) export files for FTP Outbound Sync
  try {
    const outboundDirs = [
      process.env.FTP_OUTBOUND_DIR_LOCAL,
      path.join(__dirname, '../../outbound'),
      '/Users/apple/WebBeta/MOIL_PROJECT/Moil_employee_data/Outbound',
      path.join('/tmp', 'ftp_outbound')
    ].filter(Boolean);

    outboundDirs.forEach(dir => {
      if (!fs.existsSync(dir)) {
        try { fs.mkdirSync(dir, { recursive: true }); } catch (e) {}
      }
    });

    const timestamp = Date.now();
    const baseFileName = `outbound_${tableName}_${actionType}_${recordId}_${timestamp}`;
    const parsedRowData = typeof rowData === 'string' ? JSON.parse(rowData || '{}') : (rowData || {});

    // Prepare JSON Payload
    const jsonFileName = `${baseFileName}.json`;
    const payload = {
      id: insertId,
      table_name: tableName,
      record_id: recordId,
      action_type: actionType,
      changed_columns: typeof changedColumns === 'string' ? JSON.parse(changedColumns || '{}') : (changedColumns || {}),
      row_data: parsedRowData,
      created_at: new Date().toISOString()
    };
    const jsonStr = JSON.stringify(payload, null, 2);

    // Convert SAP date string "DD.MM.YYYY" to Excel serial number (same as inbound)
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

    const cc = typeof changedColumns === 'string' ? JSON.parse(changedColumns || '{}') : (changedColumns || {});
    const rd = typeof rowData === 'string' ? JSON.parse(rowData || '{}') : (rowData || {});

    let fileName = `${tableName}.xlsx`;
    let sheetName = tableName;
    let rowObj = null;

    if (tableName === 'PTREQ_ATTABSDATA_Leave_Apply' || tableName === 'ptreq_attabsdata_leave_apply_1') {
      fileName = 'PTREQ_ATTABSDATA_Leave_Apply.xlsx';
      sheetName = 'PTREQ_ATTABSDATA_Leave_Apply';
      const startDate = cc.start_date || rd.start_date || '';
      const endDate   = cc.end_date   || rd.end_date   || '';
      const days      = parseFloat(cc.days_count || rd.att__abs__days || '1');
      const hours     = days * 8.5;
      rowObj = {
        'ID of Request Item':       recordId,
        'Infotype operation':       actionType === 'INSERT' ? 'INS' : 'MOD',
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
        'Customer Field':           '', 'Customer Field_1': '', 'Customer Field_2': '', 'Customer Field_3': '', 'Customer Field_4': '',
        'Customer Field_5': '', 'Customer Field_6': '', 'Customer Field_7': '', 'Customer Field_8': '', 'Customer Field_9': '',
        'Prev. day indicator':      '',
        'Att./abs. days':           days,
        'Calendar days':            days,
        'Set hours':                '',
        'Full-day':                 'X',
        'Payroll days':             days,
        'Payroll hours':            hours,
        'Desc. of illness':         '', 'Desc. of illness_1': '',
        'Days credited':            0,
        'End of continued pay':     '', 'End of sick pay': '', 'Certified start': '', 'Confirmed on': '',
        'Subs.sickness ind.':       0, 'Ind. for repeated illness': 0,
      };
    } else if (tableName === 'PTREQ_HEADER_Leave_Approved' || tableName === 'ptreq_header_leave_approved_1') {
      fileName = 'PTREQ_HEADER_Leave_Approved.xlsx';
      sheetName = 'PTREQ_HEADER_Leave_Approved';
      const now = new Date();
      const excelTs = (now - new Date(1899, 11, 30)) / 86400000;
      const status  = cc.document_status || rd.document_status || 'SENT';
      const guid    = cc.document_identification || recordId || '';
      rowObj = {
        'Document Identification':    recordId,
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
        'ID of Request Item List':    cc.req_item_list_id || rd.req_item_list_id || recordId,
        'Last Changed By':            cc.last_changed_by || rd.last_changed_by || '',
        'Time Stamp':                 excelTs,
        'Time Zone':                  'INDIA',
        'ID':                         cc.personnel_number || rd.personnel_number || cc.last_changed_by || '',
      };
    } else if (tableName === 'time_quota_compensation_infotype') {
      fileName = 'IT0416_Time_Compensation.xlsx';
      sheetName = 'Sheet1';
      const pernr = (cc.personnel_number || rd.personnel_number || '').toString().replace(/^0+/, '');
      rowObj = {
        'Personnel number':           pernr,
        'Sub Type':                   rd.sub_type || '1000',
        'Object ID':                  '', 'Lock indicator': '',
        'End Date':                   dateToExcelSerial(rd.end_date || new Date().toISOString().slice(0,10)),
        'Start Date':                 dateToExcelSerial(rd.start_date || new Date().toISOString().slice(0,10)),
        'Infotype record no.':        '0',
        'Changed on':                 dateToExcelSerial(new Date().toISOString().slice(0,10)),
        'Changed by':                 (cc.changed_by || rd.changed_by || pernr).toString().replace(/^0+/, ''),
        'Historical record': '', 'Text exists': '', 'Reference fields exist (cost assign.)': '', 'Conf. fields exist': '', 'Screen control': '', 'Reason for Change': '',
        'Reserved Field/Unused Field': '', 'Reserved Field/Unused Field_1': '', 'Reserved Field/Unused Field_2': '', 'Reserved Field/Unused Field_3': '',
        'Reserved Field/Unused Field of Length 2': '', 'Reserved Field/Unused Field of Length 2_1': '', 'Grouping Value': '',
        'Time Quota Compensation Method': '1000',
        'Quota type':                 'A',
        'Currency':                   '',
        'Absence quota type':         '1',
        'Deduction rule':             '0',
        'Comp. quota number':         parseFloat(cc.comp__quota_number || rd.comp__quota_number || '0'),
        'Compensation amount':        0,
        'Wage Type':                  '5000',
        'Quota counter':              '0',
        'Logical system':             'PECCLNT100',
        'Document number':            recordId || rd.document_number || '',
        'Is not accounted':           ''
      };
    } else if (tableName === 'travel') {
      fileName = 'FTPT_REQ_HEAD-Travel request.xlsx';
      sheetName = 'Sheet1';
      const pernr = cc.personnel_number || rd.personnel_number || '';
      const tripNo = cc.trip_number || rd.trip_number || recordId || '';
      const startDate = cc.beginning_date_of_trip_segment || rd.beginning_date_of_trip_segment || '';
      const endDate = cc.end_date_of_trip_segment || rd.end_date_of_trip_segment || '';
      const dest = cc.trip_destination || rd.trip_destination || '';
      const reason = cc.reason_for_trip || rd.reason_for_trip || '';
      const status = rd.planning_status || cc.planning_status || '1';
      const changedBy = cc.changed_by || rd.changed_by || `HR_app_${pernr}`;

      rowObj = {
        'Personnel Number': pernr,
        'Trip Number': tripNo,
        'Version number of travel request': '99',
        'Plan Request Indicator': 'R',
        'Trip Destination': dest,
        'Country Key': 'IN',
        'Reason for Trip': reason,
        'Beginning Date of Trip Segment': dateToExcelSerial(startDate),
        'Start Time of Trip Segment': 0.8125,
        'End Date of Trip Segment': dateToExcelSerial(endDate),
        'End Time of Trip Segment': 0.83333333333333,
        'Trip Activity Type': 'B',
        'Total Cost': 0,
        'Currency': 'INR',
        'Planning Status': status,
        'Changed on': dateToExcelSerial(new Date().toISOString().slice(0, 10)),
        'Changed at': 0.75,
        'Changed by': changedBy,
        'Change Report': 'SAPMSSY1/',
        'Depart Res./Workplace': '',
        'Created By': pernr,
        'Approved By': changedBy,
        'Delivery Location': '',
        'Delivery Area': '',
        'Recipient of Delivery': '0',
        'Arrival Accommodations/New Place of Work': '',
        'Arrival at Home/Workplace': '',
        'Trip Activity Type_1': 'B',
        'Standing Approval of Bus.Trips': '',
        'Trip Type: Statutory': 'B',
        'TripType Enterprise': '',
        'Full Trip Segment Reimbursement': '',
        'Significant Official Interest': '',
        'Number of Passengers': '0',
        'Passenger with Other Employee': '',
        'Time Work Commences': 0,
        'Time Work Ends': 0,
        'Increased Max. Trip Segment Reimbursm': ''
      };
    } else {
      rowObj = Object.assign({}, cc, rd);
    }

    if (rowObj) {
      await writeTableOutboundExcel(fileName, sheetName, rowObj);
    }
  } catch (fileErr) {
    console.error('[Outbound Record File Error]', fileErr.message);
  }

  // Trigger immediate background FTP Outbound Sync to /HR_App/Outbound
  try {
    const { runFtpSync } = require('../services/ftp_sync_service');
    runFtpSync().catch(err => console.error('[Immediate Outbound FTP Sync Error]', err.message));
  } catch (_) {}

  return true;
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
  }
});

/**
 * @route   GET /api/inbound-registry
 * @desc    Returns list of all processed inbound files
 */
router.get('/inbound-registry', async (req, res) => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS inbound_sync_registry (
        id INT AUTO_INCREMENT PRIMARY KEY,
        file_name VARCHAR(255) UNIQUE,
        file_size BIGINT,
        last_modified VARCHAR(100),
        processed_at DATETIME
      )
    `);
    const [rows] = await pool.query('SELECT file_name, file_size, last_modified FROM inbound_sync_registry');
    res.json(rows);
  } catch (err) {
    console.error('[Inbound Registry GET Error]', err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * @route   POST /api/inbound-registry
 * @desc    Upserts processed inbound file record
 */
router.post('/inbound-registry', async (req, res) => {
  try {
    const { file_name, file_size, last_modified } = req.body;
    if (!file_name) {
      return res.status(400).json({ error: 'file_name is required' });
    }
    await pool.query(`
      CREATE TABLE IF NOT EXISTS inbound_sync_registry (
        id INT AUTO_INCREMENT PRIMARY KEY,
        file_name VARCHAR(255) UNIQUE,
        file_size BIGINT,
        last_modified VARCHAR(100),
        processed_at DATETIME
      )
    `);
    await pool.query(
      `INSERT INTO inbound_sync_registry (file_name, file_size, last_modified, processed_at)
       VALUES (?, ?, ?, NOW())
       ON DUPLICATE KEY UPDATE file_size = VALUES(file_size), last_modified = VALUES(last_modified), processed_at = NOW()`,
      [file_name, file_size, last_modified]
    );
    res.json({ success: true });
  } catch (err) {
    console.error('[Inbound Registry POST Error]', err.message);
    res.status(500).json({ error: err.message });
  }
});


/**
 * @route   ALL /api/trigger-ftp-sync
 * @desc    Triggers automated FTP Inbound/Outbound sync & DB upserts
 */
router.all('/trigger-ftp-sync', async (req, res) => {
  try {
    const { runFtpSync } = require('../services/ftp_sync_service');
    runFtpSync().catch(err => console.error('[Background FTP Sync Error]', err));
    res.json({ success: true, message: 'FTP Inbound/Outbound synchronization triggered successfully' });
  } catch (err) {
    console.error('[Trigger FTP Sync Error]', err.message);
    res.status(500).json({ error: 'Failed to trigger FTP sync' });
  }
});

const { getPayslipsForEmployee, syncPayslipsFromFtp, PAYSLIP_DIR } = require('../services/payslip_service');

/**
 * @route   GET /api/payslips
 * @desc    Get available payslips for employee ({empNo}_{mm}_{yyyy}.pdf)
 */
router.get(['/payslips', '/payslips/list'], async (req, res) => {
  try {
    const employeeId = req.query.employee_id || req.query.employeeId || (req.user ? req.user.employee_number : null);

    const forwardedHost = req.headers['x-forwarded-host'] || req.get('host') || '';
    const isLocal = forwardedHost.includes('127.0.0.1') || forwardedHost.includes('localhost') || forwardedHost.includes('3000');
    const publicBase = isLocal ? 'https://acubeai.com/test/moil_hr_app' : `https://${forwardedHost}/test/moil_hr_app`;

    // Background FTP sync — runs without blocking the response
    // Any new PDF placed in FTP /HR_App/Payslip will be picked up automatically
    syncPayslipsFromFtp().catch(err => console.warn('[Auto FTP Sync]', err.message));

    const payslips = await getPayslipsForEmployee(employeeId, publicBase);

    res.json(payslips);
  } catch (err) {
    console.error('[Get Payslips Error]', err.message);
    res.status(500).json({ error: 'Failed to fetch payslips list', message: err.message });
  }
});

/**
 * @route   GET /api/payslips/download/:filename
 * @desc    View/Download payslip PDF file
 */
router.get(['/payslips/download/:filename', '/payslips/view/:filename'], (req, res) => {
  try {
    const filename = req.params.filename;
    const safeFilename = path.basename(filename);
    const filePath = path.join(PAYSLIP_DIR, safeFilename);

    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ error: 'Payslip PDF file not found' });
    }

    const stat = fs.statSync(filePath);

    // Explicit CORS headers so Flutter web can fetch binary PDF bytes
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Type');

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Length', stat.size);
    res.setHeader('Content-Disposition', `inline; filename="${safeFilename}"`);

    const readStream = fs.createReadStream(filePath);
    return readStream.pipe(res);
  } catch (err) {
    console.error('[Download Payslip Error]', err.message);
    res.status(500).json({ error: 'Failed to download payslip' });
  }
});

/**
 * @route   POST /api/payslips/sync-ftp
 * @desc    Trigger FTP sync for /HR_App/Payslip PDFs
 */
router.post('/payslips/sync-ftp', async (req, res) => {
  try {
    const count = await syncPayslipsFromFtp();
    res.json({ success: true, message: `Synced ${count} payslips from FTP` });
  } catch (err) {
    console.error('[Payslip FTP Sync Error]', err.message);
    res.status(500).json({ error: 'Failed to sync payslips from FTP' });
  }
});

module.exports = router;
