const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const authenticateToken = require('../middleware/auth');
const { pool } = require('../config/db');

// Helper to format dates consistently (DD-MM-YYYY)
function formatDate(date) {
  if (!date) return null;
  const d = new Date(date);
  if (isNaN(d.getTime())) return null;
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

// Generate random 32-char uppercase hex string (for UUIDs / GUIDs)
function generateHexId() {
  return crypto.randomBytes(16).toString('hex').toUpperCase();
}

async function logApproval(managerId, requestType, requestId, applicantId, action, remarks) {
  try {
    const cleanApplicantId = applicantId.toString().trim().replaceAll(RegExp('^0+'), '');
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
  if (row.date_of_appointment) {
    serviceHistory.push({
      date: formatDate(row.date_of_appointment),
      action: 'Appointment',
      reason: row.hire_action_reason || 'Regular Joining'
    });
  }
  if (row.latest_promotion_dt) {
    serviceHistory.push({
      date: formatDate(row.latest_promotion_dt),
      action: 'Promotion',
      reason: 'Regular Promotion'
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
    lastPromotionDate: formatDate(row.latest_promotion_dt),
    appointmentType: row.hire_action_reason || 'Regular',
    category: row.caste || 'GEN',
    bloodGroup: row.blood_group || 'O+',
    gender: (row.gender || '').toString().trim() === '2' ? 'Female' : ((row.gender || '').toString().trim() === '1' ? 'Male' : (row.gender || 'Male')),
    maritalStatus: row.marital_status || 'Single',
    basicSalary: parseFloat(row.basic_pay || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 }),
    presentPlaceOfPosting: row.personnel_subarea_text || 'Head Office',
    presentPostingDate: formatDate(row.dopp || row.act_doj_on_promt_dt),
    retirementDate: formatDate(row.date_of_retirement),
    mobile: row.mobile_number || 'N/A',
    mobileNumber: row.mobile_number || 'N/A',
    email: row.email_id || 'N/A',
    uanNo: row.uan || 'N/A',
    pan_number: row.pan_number || 'N/A',
    aadhaarNo: row.aadhar_number || 'N/A',
    pranNo: row.praan_no || 'N/A',
    pfNo: row.employee_pf_number || 'N/A',
    pensionNo: row.pension_id || 'N/A',
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
 * @route   POST /api/login
 */
router.post('/login', async (req, res) => {
  const employee_number = req.body.employee_number || req.body.employee_id || req.body.employeeId;
  const password = req.body.password;

  if (!employee_number || !password) {
    return res.status(400).json({ error: 'Employee number and password are required' });
  }

  try {
    // 1. Fetch employee details from manpower
    const empQuery = `SELECT * FROM manpower WHERE employee_number = ? LIMIT 1`;
    const [empRows] = await pool.query(empQuery, [employee_number]);
    
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
    const credQuery = `SELECT password FROM user_accounts WHERE employee_number = ? LIMIT 1`;
    const [credRows] = await pool.query(credQuery, [employee_number]);
    
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

    // Fetch family members from it0021_family_member (only active records)
    const [familyRows] = await pool.query(
      'SELECT * FROM it0021_family_member WHERE (personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = ?) AND end_date >= NOW()', 
      [employeeId, employeeId]
    );
    profileData.familyMembers = familyRows.map(f => {
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
        const dobDate = new Date(f.date_of_birth);
        if (!isNaN(dobDate.getTime())) {
          const today = new Date();
          let calculatedAge = today.getFullYear() - dobDate.getFullYear();
          const monthDiff = today.getMonth() - dobDate.getMonth();
          if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < dobDate.getDate())) {
            calculatedAge--;
          }
          age = calculatedAge.toString();
        }
      }

      return {
        name: `${f.first_name || ''} ${f.middle_name || ''} ${f.last_name || ''}`.trim().replace(/\s+/g, ' ') || 'N/A',
        relation,
        dob: formatDate(f.date_of_birth) || 'N/A',
        age,
        gender: genderStr
      };
    });

    // Fetch nominations from it0591_nomination (only active records)
    const [nomineeRows] = await pool.query(
      'SELECT * FROM it0591_nomination WHERE (personnel_number = ? OR CAST(personnel_number AS UNSIGNED) = ?) AND end_date >= NOW()', 
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
      JOIN ptreq_header_leave_approved_1 h ON a.id_of_request_item = h.document_identification
      LEFT JOIN zhcm_lr_t_agents_03072026 ag ON CAST(a.personnel_number AS UNSIGNED) = CAST(ag.personnel_number AS UNSIGNED)
      LEFT JOIN manpower ro ON CAST(ag.reporting_officer AS UNSIGNED) = ro.employee_number
      LEFT JOIN manpower ro1 ON CAST(ag.reporting_officer_1 AS UNSIGNED) = ro1.employee_number
      WHERE a.personnel_number = ?
      ORDER BY a.start_date DESC
    `;
    const [rows] = await pool.query(query, [employeeId]);
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

      return {
        id: row.id_of_request_item,
        employeeId: row.personnel_number.toString(),
        leaveType,
        startDate: row.start_date,
        startTime: row.start_time || '00:00:00',
        endDate: row.end_date,
        endTime: row.end_time || '00:00:00',
        duration: `${row.att_abs_days || 1} Day(s)`,
        status,
        appliedOn: row.start_date,
        approvedOn: status === 'Approved' ? row.end_date : null,
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
 * @route   GET /api/leave-balances
 */
router.get('/leave-balances', authenticateToken, async (req, res) => {
  const employeeId = req.query.employee_id || req.user.employee_number;
  try {
    const [rows] = await pool.query('SELECT * FROM leave_quota WHERE personnel_number = ?', [employeeId]);
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
 * @route   POST /api/leaves/apply
 */
router.post('/leaves/apply', authenticateToken, async (req, res) => {
  const { leave_type, start_date, end_date, start_time, end_time, duration, reason } = req.body;
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
      // Calculate leave days count
      const daysCount = 1.0; // default to 1 day if not calculated
      const startDateTimeStr = `${start_date} 00:00:00`;
      const endDateTimeStr = `${end_date} 00:00:00`;

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
        reqItemId, beginTimeStr, endTimeStr, employeeId, subType, startDateTimeStr, endDateTimeStr, daysCount, daysCount, daysCount
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
        reqItemId, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, randomGuid, employeeId, nextId
      ]);

      // Sync into old absence table to prevent layout breakages
      const absenceQuery = `
        INSERT INTO absence (personnel_number, sub_type, start_date, end_date, start_time, end_time, att_abs_days, lock_indicator, changed_on, changed_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'P', NOW(), 'HR_app')
      `;
      await conn.query(absenceQuery, [
        employeeId, subType === '1000' ? '1' : (subType === '1001' ? '2' : '3'), startDateTimeStr, endDateTimeStr, beginTimeStr, endTimeStr, daysCount
      ]);

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
    const [rows] = await pool.query('SELECT * FROM travel WHERE personnel_number = ? ORDER BY beginning_date_of_trip_segment DESC', [employeeId]);
    const tours = rows.map(row => {
      let status = 'Approved';
      if (row.planning_status === '1') status = 'Pending L1';
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
        startDate: row.beginning_date_of_trip_segment,
        endDate: row.end_date_of_trip_segment,
        travelPurpose: row.reason_for_trip || 'Official Work',
        transportMode: row.depart_res_workplace || 'Train',
        tourType: activityType,
        status,
        appliedOn: row.changed_on || row.beginning_date_of_trip_segment,
        approvedOn: row.planning_status === '2' ? row.changed_on : null
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
  const { destination, start_date, end_date, purpose, transport_mode, tour_type } = req.body;
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

    const query = `
      INSERT INTO travel (personnel_number, trip_destination, beginning_date_of_trip_segment, end_date_of_trip_segment, reason_for_trip, depart_res_workplace, trip_activity_type, planning_status, changed_on, changed_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, '1', NOW(), 'HR_app')
    `;
    const [result] = await pool.query(query, [employeeId, destination, start_date, end_date, purpose, transport_mode, tour_type]);

    // Trigger notifications for applicant, RO, and RO1
    const applicantName = await getEmployeeName(employeeId);
    const datesText = `${start_date || ''} to ${end_date || ''}`;

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

    res.status(201).json({ message: 'Tour request submitted successfully', tourId: result.insertId });
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
      SELECT tr.*, m.employee_name AS applicant_name, ag.designation
      FROM travel tr
      JOIN manpower m ON CAST(tr.personnel_number AS UNSIGNED) = CAST(m.employee_number AS UNSIGNED)
      JOIN zhcm_lr_t_agents_03072026 ag ON CAST(tr.personnel_number AS UNSIGNED) = CAST(ag.personnel_number AS UNSIGNED)
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
        startDate: row.beginning_date_of_trip_segment,
        endDate: row.end_date_of_trip_segment,
        travelPurpose: row.reason_for_trip || 'Official Visit',
        transportMode: row.depart_res_workplace || 'Train',
        processor: 'Manager',
        status,
        remarks: row.reason_for_trip,
        appliedOn: row.changed_on || row.beginning_date_of_trip_segment
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
router.post('/api/tours/approve', authenticateToken, async (req, res) => {
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
  try {
    await pool.query(
      'UPDATE notifications SET is_read = TRUE WHERE employee_id = ? OR CAST(employee_id AS UNSIGNED) = CAST(? AS UNSIGNED)',
      [employeeId, employeeId]
    );
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
    const query = `
      SELECT 
        m.*, 
        a.reporting_officer, 
        a.reporting_officer_1, 
        ro.employee_name AS reporting_officer_name,
        ro1.employee_name AS reporting_officer_1_name
      FROM manpower m 
      JOIN zhcm_lr_t_agents_03072026 a ON CAST(m.employee_number AS UNSIGNED) = CAST(a.personnel_number AS UNSIGNED)
      LEFT JOIN manpower ro ON CAST(a.reporting_officer AS UNSIGNED) = ro.employee_number
      LEFT JOIN manpower ro1 ON CAST(a.reporting_officer_1 AS UNSIGNED) = ro1.employee_number
      WHERE CAST(a.reporting_officer AS UNSIGNED) = CAST(? AS UNSIGNED) OR CAST(a.reporting_officer_1 AS UNSIGNED) = CAST(? AS UNSIGNED)
    `;
    const [rows] = await pool.query(query, [managerId, managerId]);
    const employees = rows.map(row => mapEmployeeRow(row));
    res.json(employees);
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
  const cleanEmpId = employee_id.toString().trim().replaceAll(RegExp('^0+'), '');

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
      // 2. Fetch travel segments for this team member
      const toursQuery = `
        SELECT * FROM travel 
        WHERE personnel_number = ? AND planning_status IN ('1', '2', '11')
        ORDER BY beginning_date_of_trip_segment DESC
      `;
      const [tours] = await pool.query(toursQuery, [sub.employee_number]);

      const formattedTours = tours.map(row => {
        let activityType = 'Official Tour';
        const rawAct = (row.trip_activity_type || '').toString().trim().toUpperCase();
        if (rawAct === 'B') {
          activityType = 'Official Tour';
        } else if (rawAct && rawAct !== 'NULL') {
          activityType = rawAct;
        }

        let status = 'Approved';
        if (row.planning_status === '1') status = 'Pending L1';
        else if (row.planning_status === '11') status = 'Pending L2';

        return {
          startDate: row.beginning_date_of_trip_segment,
          endDate: row.end_date_of_trip_segment,
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
    res.status(500).json({ error: 'Failed to fetch tours team calendar details', message: error.message });
  }
});

module.exports = router;
