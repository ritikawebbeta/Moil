const https = require('https');

const AUTH_URL = 'https://cts.myvi.in:8443/ManageSms/api/AuthJwt/Authenticate';
const SEND_SMS_URL = 'https://cts.myvi.in:8443/ManageSms/api/sms/Createsms/json/apikey=ng6q1u';

const AUTH_USERNAME = 'managesms';
const AUTH_PASSWORD = 'f9e5f1dbcb1d155c505be2b925b32ac9237a3e8d';

const DEFAULT_MOBILE = '9503864429';
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
    const phone = mobileNumber ? String(mobileNumber).trim().replace(/[^\d]/g, '').slice(-10) : DEFAULT_MOBILE;
    const targetPhone = (phone.length === 10) ? phone : DEFAULT_MOBILE;

    const token = await getAuthToken();

    const postData = JSON.stringify({
      msisdn: targetPhone,
      script: script,
      unicode: '0',
      senderid: SENDER_ID,
      pingbackurl: '',
      DLTTemplateid: String(dltTemplateId)
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
          console.log(`[SMS Sent] To: ${targetPhone} | DLT ID: ${dltTemplateId} | Script: "${script}" | Response: ${data}`);
          resolve({ success: res.statusCode === 200, statusCode: res.statusCode, body: data, targetPhone, dltTemplateId });
        });
      });

      req.on('error', (err) => {
        console.error('[SMS Send Error]', err.message);
        resolve({ success: false, error: err.message });
      });

      req.write(postData);
      req.end();
    });
  } catch (error) {
    console.error('[sendSms Exception]', error.message);
    return { success: false, error: error.message };
  }
}

// Helper: Format Date as DD.MM.YYYY
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

// ─────────────────────────────────────────────────────────────────────────────
// MOIL DLT SMS TEMPLATE IMPLEMENTATIONS (1 - 9)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Template 1: Leave Applied (to Approver/RO)
 * DLT ID: 1107163177301329708
 * Text: {#var#} has applied for {#var#} from {#var#} to {#var#} through ESS. Kindly take necessary action in this regard. MOIL Limited
 */
async function sendLeaveAppliedSms({ mobileNumber, applicantName, leaveType, startDate, endDate }) {
  const script = `${applicantName} has applied for ${leaveType} from ${formatSmsDate(startDate)} to ${formatSmsDate(endDate)} through ESS. Kindly take necessary action in this regard. MOIL Limited`;
  return await sendSms({ mobileNumber, script, dltTemplateId: '1107163177301329708' });
}

/**
 * Template 2: Leave Approved (to Applicant)
 * DLT ID: 1107163177311027634
 * Text: {#var#} has approved your application for {#var#} from {#var#} to {#var#} through ESS. This is for your information. MOIL Limited
 */
async function sendLeaveApprovedSms({ mobileNumber, approverName, leaveType, startDate, endDate }) {
  const script = `${approverName} has approved your application for ${leaveType} from ${formatSmsDate(startDate)} to ${formatSmsDate(endDate)} through ESS. This is for your information. MOIL Limited`;
  return await sendSms({ mobileNumber, script, dltTemplateId: '1107163177311027634' });
}

/**
 * Template 3: Leave Rejected (to Applicant)
 * DLT ID: 1107163177318779886
 * Text: {#var#} has rejected your application for {#var#} from {#var#} to {#var#} through ESS. This is for your information. MOIL Limited
 */
async function sendLeaveRejectedSms({ mobileNumber, approverName, leaveType, startDate, endDate }) {
  const script = `${approverName} has rejected your application for ${leaveType} from ${formatSmsDate(startDate)} to ${formatSmsDate(endDate)} through ESS. This is for your information. MOIL Limited`;
  return await sendSms({ mobileNumber, script, dltTemplateId: '1107163177318779886' });
}

/**
 * Template 4: Leave Encashment Approved
 * DLT ID: 1107165717011044676
 * Text: {#var#} leave encashment request for {#var#} days has been approved by {#var#} Kindly process. MOIL Limited
 */
async function sendLeaveEncashApprovedSms({ mobileNumber, applicantName, days, approverName }) {
  const script = `${applicantName} leave encashment request for ${days} days has been approved by ${approverName} Kindly process. MOIL Limited`;
  return await sendSms({ mobileNumber, script, dltTemplateId: '1107165717011044676' });
}

/**
 * Template 5: Leave Encashment Rejected
 * DLT ID: 1107165717016334079
 * Text: Your leave encashment request for {#var#}days has been Rejected. This is for your information. MOIL Limited
 */
async function sendLeaveEncashRejectedSms({ mobileNumber, days }) {
  const script = `Your leave encashment request for ${days}days has been Rejected. This is for your information. MOIL Limited`;
  return await sendSms({ mobileNumber, script, dltTemplateId: '1107165717016334079' });
}

/**
 * Template 6: Leave Encashment Applied (Variant A)
 * DLT ID: 1107165717026952826
 * Text: {#var#}has applied for{#var#} &lv_days& days encashment of leave through ESS.  This is for your needful. MOIL Limited
 */
async function sendLeaveEncashAppliedVariantSms({ mobileNumber, applicantName, days }) {
  const script = `${applicantName}has applied for ${days} days encashment of leave through ESS.  This is for your needful. MOIL Limited`;
  return await sendSms({ mobileNumber, script, dltTemplateId: '1107165717026952826' });
}

/**
 * Template 7: Leave Encashment Applied (Variant B - Standard)
 * DLT ID: 1107165901001503660
 * Text: {#var#} has applied for {#var#} days encashment of leave through ESS.  This is for your needful. MOIL Limited
 */
async function sendLeaveEncashAppliedSms({ mobileNumber, applicantName, days }) {
  const script = `${applicantName} has applied for ${days} days encashment of leave through ESS.  This is for your needful. MOIL Limited`;
  return await sendSms({ mobileNumber, script, dltTemplateId: '1107165901001503660' });
}

/**
 * Template 8: Leave L1 Approved (Passed to L2)
 * DLT ID: 1107165916221536406
 * Text: {#var#}   {#var#} has applied for {#var#} from  {#var#} to {#var#} through ESS, which is approved by  {#var#} {#var#}. This is for your needful. MOIL Limited
 */
async function sendLeaveL1ApprovedSms({ mobileNumber, title, applicantName, leaveType, startDate, endDate, l1Title, l1Name }) {
  const script = `${title || 'Mr.'} ${applicantName} has applied for ${leaveType} from ${formatSmsDate(startDate)} to ${formatSmsDate(endDate)} through ESS, which is approved by ${l1Title || 'Mr.'} ${l1Name}. This is for your needful. MOIL Limited`;
  return await sendSms({ mobileNumber, script, dltTemplateId: '1107165916221536406' });
}

/**
 * Template 9: Application Noted
 * DLT ID: 1107177547706676415
 * Text: {#alp#} has noted your application for {#alp#} from {#alp#} to {#alp#} through ESS. This is for your information. MOIL Limited
 */
async function sendApplicationNotedSms({ mobileNumber, actorName, leaveType, startDate, endDate }) {
  const script = `${actorName} has noted your application for ${leaveType} from ${formatSmsDate(startDate)} to ${formatSmsDate(endDate)} through ESS. This is for your information. MOIL Limited`;
  return await sendSms({ mobileNumber, script, dltTemplateId: '110777547706676415' });
}

module.exports = {
  sendSms,
  sendLeaveAppliedSms,         // T1 - 1107163177301329708
  sendLeaveApprovedSms,        // T2 - 1107163177311027634
  sendLeaveRejectedSms,        // T3 - 1107163177318779886
  sendLeaveEncashApprovedSms,  // T4 - 1107165717011044676
  sendLeaveEncashRejectedSms,  // T5 - 1107165717016334079
  sendLeaveEncashAppliedVariantSms, // T6 - 1107165717026952826
  sendLeaveEncashAppliedSms,   // T7 - 1107165901001503660
  sendLeaveL1ApprovedSms,      // T8 - 1107165916221536406
  sendApplicationNotedSms,     // T9 - 1107177547706676415
  DEFAULT_MOBILE
};
