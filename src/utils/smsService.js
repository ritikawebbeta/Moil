const https = require('https');

const AUTH_URL = 'https://cts.myvi.in:8443/ManageSms/api/AuthJwt/Authenticate';
const SEND_SMS_URL = 'https://cts.myvi.in:8443/ManageSms/api/sms/Createsms/json/apikey=ng6q1u';

const AUTH_USERNAME = 'managesms';
const AUTH_PASSWORD = 'f9e5f1dbcbd155c505be2b925b32ac9237a3e8d';

const DEFAULT_MOBILE = '9689941705';
const SENDER_ID = 'MOILHO';

// Cached JWT token
let cachedToken = null;
let tokenExpiry = 0;

/**
 * Obtain JWT token from MyVI Auth API
 */
async function getAuthToken() {
  if (cachedToken && Date.now() < tokenExpiry) {
    return cachedToken;
  }

  return new Promise((resolve) => {
    const postData = JSON.stringify({
      username: AUTH_USERNAME,
      password: AUTH_PASSWORD
    });

    const req = https.request(AUTH_URL, {
      method: 'POST',
      rejectUnauthorized: false,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const token = data.trim().replace(/^"|"$/g, '');
          if (token && res.statusCode === 200) {
            cachedToken = token;
            tokenExpiry = Date.now() + (55 * 60 * 1000); // 55 minutes cache
            console.log('[SMS Auth] JWT token obtained successfully.');
            return resolve(token);
          }
        } catch (e) {
          console.error('[SMS Auth Parsing Error]', e.message);
        }
        resolve(null);
      });
    });

    req.on('error', (err) => {
      console.error('[SMS Auth Network Error]', err.message);
      resolve(null);
    });

    req.write(postData);
    req.end();
  });
}

/**
 * Core function to send SMS via MyVI Gateway
 */
async function sendSms({ mobileNumber, script, dltTemplateId }) {
  try {
    // FOR TESTING: Hardcoded test mobile number requested by user
    const targetPhone = '9689941705';

    /* =========================================================================
     * FUTURE PRODUCTION USE: Uncomment below to use dynamic recipient phone:
     * const phone = mobileNumber ? String(mobileNumber).trim().replace(/[^\d]/g, '').slice(-10) : DEFAULT_MOBILE;
     * const targetPhone = (phone.length === 10) ? phone : DEFAULT_MOBILE;
     * ========================================================================= */

    const token = await getAuthToken();

    const postData = JSON.stringify({
      msisdn: targetPhone,
      script: script,
      unicode: '0',
      senderid: SENDER_ID,
      pingbackurl: '',
      DLTTemplateid: dltTemplateId
    });

    const headers = {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    return new Promise((resolve) => {
      const req = https.request(SEND_SMS_URL, {
        method: 'POST',
        rejectUnauthorized: false,
        headers: headers
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          console.log(`[SMS Sent] To: ${targetPhone} | DLT ID: ${dltTemplateId} | Status: ${res.statusCode} | Response: ${data}`);
          resolve({ statusCode: res.statusCode, body: data });
        });
      });

      req.on('error', (err) => {
        console.error('[SMS Send Error]', err.message);
        resolve({ error: err.message });
      });

      req.write(postData);
      req.end();
    });
  } catch (error) {
    console.error('[sendSms Exception]', error.message);
  }
}

// Format Name (adds Mr. prefix if not present)
function formatNameWithSalutation(name) {
  if (!name) return 'Mr. Employee';
  const trimmed = name.trim();
  if (/^(Mr|Ms|Mrs|Dr)\b/i.test(trimmed)) {
    return trimmed;
  }
  return `Mr. ${trimmed}`;
}

// Format Date as DD.MM.YYYY
function formatSmsDate(dateInput) {
  if (!dateInput) return '01.01.2026';
  const str = String(dateInput).trim();
  if (/^\d{2}\.\d{2}\.\d{4}$/.test(str)) return str;
  if (/^\d{4}[-/]\d{2}[-/]\d{2}/.test(str)) {
    const parts = str.split('T')[0].split(' ')[0].split(/[-/]/);
    return `${parts[2]}.${parts[1]}.${parts[0]}`;
  }
  if (/^\d{2}[-/]\d{2}[-/]\d{4}/.test(str)) {
    const parts = str.split('T')[0].split(' ')[0].split(/[-/]/);
    return `${parts[0]}.${parts[1]}.${parts[2]}`;
  }
  const d = new Date(dateInput);
  if (isNaN(d.getTime())) return str;
  const day = String(d.getDate()).padStart(2, '0');
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const year = d.getFullYear();
  return `${day}.${month}.${year}`;
}

// Format Days as 00030 (5-digit zero-padded)
function formatDays5Digits(days) {
  const num = parseInt(days, 10) || 0;
  return String(num).padStart(5, '0');
}

/**
 * 1. ZHR_LEAVE_SEND (Leave Applied)
 * DLT ID: 1107163177301320100
 * Script: {Applicant_Name} has applied for {Leave_Type} from {Start_Date} to {End_Date} through ESS. Kindly take necessary action in this regard. MOIL Limited
 */
async function sendLeaveAppliedSms({ mobileNumber, applicantName, leaveType, startDate, endDate }) {
  const formattedName = formatNameWithSalutation(applicantName);
  const formattedStart = formatSmsDate(startDate);
  const formattedEnd = formatSmsDate(endDate);

  const script = `${formattedName} has applied for ${leaveType} from ${formattedStart} to ${formattedEnd} through ESS. Kindly take necessary action in this regard. MOIL Limited`;
  const dltTemplateId = '1107163177301320100';

  return await sendSms({ mobileNumber, script, dltTemplateId });
}

/**
 * 2. ZHR_LEAVE_APPROVE2 (Leave Approved)
 * DLT ID: 1107163177311020000
 * Script: {Approver_Name} has approved your application of {Leave_Type} from {Start_Date} to {End_Date} through ESS. This is for your information. MOIL Limited
 */
async function sendLeaveApprovedSms({ mobileNumber, approverName, leaveType, startDate, endDate }) {
  const formattedName = formatNameWithSalutation(approverName);
  const formattedStart = formatSmsDate(startDate);
  const formattedEnd = formatSmsDate(endDate);

  const script = `${formattedName} has approved your application of ${leaveType} from ${formattedStart} to ${formattedEnd} through ESS. This is for your information. MOIL Limited`;
  const dltTemplateId = '1107163177311020000';

  return await sendSms({ mobileNumber, script, dltTemplateId });
}

/**
 * 3 & 4. ZHR_LEAVE_REJECT1 / ZHR_LEAVE_REJECT2 (Leave Rejected)
 * DLT ID: 1107163177318770000
 * Script L1: {Approver_Name} has rejected1 your application of {Leave_Type} from {Start_Date} to {End_Date} through ESS. This is for your information. MOIL Limited
 * Script L2: {Approver_Name} has rejected2 your application of {Leave_Type} from {Start_Date} to {End_Date} through ESS. This is for your information. MOIL Limited
 */
async function sendLeaveRejectedSms({ mobileNumber, approverName, leaveType, startDate, endDate, stage = 1 }) {
  const formattedName = formatNameWithSalutation(approverName);
  const formattedStart = formatSmsDate(startDate);
  const formattedEnd = formatSmsDate(endDate);

  const rejectWord = (stage === 2) ? 'rejected2' : 'rejected1';
  const script = `${formattedName} has ${rejectWord} your application of ${leaveType} from ${formattedStart} to ${formattedEnd} through ESS. This is for your information. MOIL Limited`;
  const dltTemplateId = '1107163177318770000';

  return await sendSms({ mobileNumber, script, dltTemplateId });
}

/**
 * 5. ZHR_LEAVE_ENCASH_SEND (Encashment Applied)
 * DLT ID: 1107165901001500000
 * Script: {Applicant_Name} has applied for {Days} days encashment of leave through ESS. This is for your needful. MOIL Limited
 */
async function sendLeaveEncashAppliedSms({ mobileNumber, applicantName, days }) {
  const formattedName = formatNameWithSalutation(applicantName);
  const formattedDays = formatDays5Digits(days);

  const script = `${formattedName} has applied for ${formattedDays} days encashment of leave through ESS. This is for your needful. MOIL Limited`;
  const dltTemplateId = '1107165901001500000';

  return await sendSms({ mobileNumber, script, dltTemplateId });
}

/**
 * 6. ZHR_LEAVE_ENCASH_APP1 (Encashment Approved)
 * DLT ID: 1107165717011040000
 * Script: {Applicant_Name} encashment request for {Days} days has been approved by {Approver_Name}. Kindly process. MOIL Limited
 */
async function sendLeaveEncashApprovedSms({ mobileNumber, applicantName, approverName, days }) {
  const formattedAppName = formatNameWithSalutation(applicantName);
  const formattedApprName = formatNameWithSalutation(approverName);
  const formattedDays = formatDays5Digits(days);

  const script = `${formattedAppName} encashment request for ${formattedDays} days has been approved by ${formattedApprName}. Kindly process. MOIL Limited`;
  const dltTemplateId = '1107165717011040000';

  return await sendSms({ mobileNumber, script, dltTemplateId });
}

/**
 * 7. ZHR_LEAVE_ENCASH_REJ1 (Encashment Rejected)
 * DLT ID: 1107165717016330000
 * Script: {Applicant_Name} encashment request for {Days} days has been rejected by {Approver_Name}. Kindly process. MOIL Limited
 */
async function sendLeaveEncashRejectedSms({ mobileNumber, applicantName, approverName, days }) {
  const formattedAppName = formatNameWithSalutation(applicantName);
  const formattedApprName = formatNameWithSalutation(approverName);
  const formattedDays = formatDays5Digits(days);

  const script = `${formattedAppName} encashment request for ${formattedDays} days has been rejected by ${formattedApprName}. Kindly process. MOIL Limited`;
  const dltTemplateId = '1107165717016330000';

  return await sendSms({ mobileNumber, script, dltTemplateId });
}

module.exports = {
  sendSms,
  sendLeaveAppliedSms,
  sendLeaveApprovedSms,
  sendLeaveRejectedSms,
  sendLeaveEncashAppliedSms,
  sendLeaveEncashApprovedSms,
  sendLeaveEncashRejectedSms
};
