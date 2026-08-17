const https = require('https');

const AUTH_URL = 'https://cts.myvi.in:8443/ManageSms/api/AuthJwt/Authenticate';
const SEND_SMS_URL = 'https://cts.myvi.in:8443/ManageSms/api/sms/Createsms/json/apikey=ng6q1u';

const AUTH_USERNAME = 'managesms';
const AUTH_PASSWORD = 'f9e5f1dbcb1d155c505be2b925b32ac9237a3e8d';

const DEFAULT_MOBILE = '9503864429';
const SENDER_ID = 'MOILHO';

let cachedToken = null;
let tokenExpiry = 0;

/**
 * Obtain JWT token from MyVI Auth API (Server-side, like Postman)
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
            tokenExpiry = Date.now() + (55 * 60 * 1000);
            console.log('[SMS Auth Proxy] Token generated successfully.');
            return resolve(token);
          }
        } catch (e) {
          console.error('[SMS Auth Proxy Parsing Error]', e.message);
        }
        resolve(null);
      });
    });

    req.on('error', (err) => {
      console.error('[SMS Auth Proxy Network Error]', err.message);
      resolve(null);
    });

    req.write(postData);
    req.end();
  });
}

/**
 * Send SMS via MyVI Gateway (Server-side, like Postman)
 */
async function sendSms({ mobileNumber, script, dltTemplateId }, isRetry = false) {
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
        res.on('end', async () => {
          console.log(`[SMS Proxy Dispatch] Target: ${targetPhone} | DLT: ${dltTemplateId} | Status: ${res.statusCode} | Response: ${data}`);
          
          if (res.statusCode === 401 && !isRetry) {
            console.log('[SMS Proxy Dispatch] 401 Unauthorized received. Clearing token cache and retrying...');
            cachedToken = null;
            tokenExpiry = 0;
            const retryResult = await sendSms({ mobileNumber, script, dltTemplateId }, true);
            return resolve(retryResult);
          }

          resolve({ success: res.statusCode === 200, statusCode: res.statusCode, body: data });
        });
      });

      req.on('error', (err) => {
        console.error('[SMS Proxy Dispatch Error]', err.message);
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

module.exports = {
  getAuthToken,
  sendSms,
  DEFAULT_MOBILE
};
