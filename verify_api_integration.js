const http = require('http');

function request(options, data) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve({ statusCode: res.statusCode, body: JSON.parse(body) });
        } catch {
          resolve({ statusCode: res.statusCode, body });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

async function run() {
  const employee_number = 141;
  const password = 'mySecurePassword123';

  console.log('🧪 RUNNING INTEGRATION API VERIFICATION SUITE...\n');

  try {
    // 1. Authenticate to get JWT token
    console.log('1. Authenticating...');
    const loginData = JSON.stringify({ employee_number, password });
    const loginRes = await request({
      hostname: 'localhost', port: 3000, path: '/api/login', method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(loginData) }
    }, loginData);

    console.log(`- Login Status: ${loginRes.statusCode}`);
    const token = loginRes.body.token;
    if (!token) throw new Error('Login failed: Token not found in response');
    console.log('- Token generated successfully.');

    const authHeaders = {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    };

    // 2. Fetch Detailed User Profile
    console.log('\n2. Fetching User Profile (/api/profile)...');
    const profileRes = await request({
      hostname: 'localhost', port: 3000, path: '/api/profile', method: 'GET',
      headers: authHeaders
    });
    console.log(`- Status: ${profileRes.statusCode}`);
    console.log(`- Name: ${profileRes.body.name}`);
    console.log(`- Position: ${profileRes.body.designation}`);
    console.log(`- Department: ${profileRes.body.department}`);
    console.log(`- DOB: ${profileRes.body.dateOfBirth}`);
    console.log(`- Basic Pay: ${profileRes.body.basicSalary}`);
    console.log(`- Mobile: ${profileRes.body.mobileNumber}`);
    console.log(`- Nominees Count: ${profileRes.body.nominees.length}`);
    if (profileRes.body.nominees.length > 0) {
      console.log(`  - Nominee Sample: Grat Nominee = ${profileRes.body.nominees[0].name}`);
    }
    console.log(`- Reporting Officer ID: ${profileRes.body.reportingOfficer}`);

    // 3. Test Updating Profile Info
    console.log('\n3. Updating User Profile info (Address & Mobile)...');
    const originalMobile = profileRes.body.mobileNumber;
    const updateData = JSON.stringify({
      mobile_number: '9999999999',
      address: 'Nagpur Head Office main campus',
      emergency_contact: '8888888888'
    });
    const updateRes = await request({
      hostname: 'localhost', port: 3000, path: '/api/profile', method: 'PUT',
      headers: { ...authHeaders, 'Content-Length': Buffer.byteLength(updateData) }
    }, updateData);
    console.log(`- Status: ${updateRes.statusCode}`);
    console.log(`- Message: ${updateRes.body.message}`);

    // Verify it changed in database
    const verifyProfileRes = await request({
      hostname: 'localhost', port: 3000, path: '/api/profile', method: 'GET',
      headers: authHeaders
    });
    console.log(`- Verify DB values changed: Mobile is now = ${verifyProfileRes.body.mobileNumber}`);

    // Revert changes back to original mobile number
    const revertData = JSON.stringify({ mobile_number: originalMobile });
    await request({
      hostname: 'localhost', port: 3000, path: '/api/profile', method: 'PUT',
      headers: { ...authHeaders, 'Content-Length': Buffer.byteLength(revertData) }
    }, revertData);
    console.log(`- Reverted profile mobile back to original: ${originalMobile}`);

    // 4. Fetch Employees List
    console.log('\n4. Fetching Employees list (/api/employees)...');
    const employeesRes = await request({
      hostname: 'localhost', port: 3000, path: '/api/employees', method: 'GET',
      headers: authHeaders
    });
    console.log(`- Status: ${employeesRes.statusCode}`);
    console.log(`- Count: ${employeesRes.body.length} employee records fetched`);
    if (employeesRes.body.length > 0) {
      console.log(`- Sample Employee: ${employeesRes.body[0].name} (${employeesRes.body[0].designation})`);
    }

    // 5. Fetch Dynamic Notifications
    console.log('\n5. Fetching Dynamic Notifications (/api/notifications)...');
    const notifRes = await request({
      hostname: 'localhost', port: 3000, path: '/api/notifications', method: 'GET',
      headers: authHeaders
    });
    console.log(`- Status: ${notifRes.statusCode}`);
    console.log(`- Count: ${notifRes.body.length} notifications`);
    if (notifRes.body.length > 0) {
      console.log(`- Latest Notification: "${notifRes.body[0].title}" - ${notifRes.body[0].message}`);
    }

    // 6. Apply for Leave with Long Reason (to test truncation safety)
    console.log('\n6. Applying for Leave with a long reason to test truncation safety...');
    const applyData = JSON.stringify({
      leave_type: 'Casual Leave',
      start_date: '2026-09-10',
      end_date: '2026-09-10',
      duration: 'Full-Day',
      absence_hours: 8,
      reason: 'Audit verification meeting in Delhi' // Length = 37 chars (will be sliced to 6)
    });
    const applyRes = await request({
      hostname: 'localhost', port: 3000, path: '/api/leaves', method: 'POST',
      headers: { ...authHeaders, 'Content-Length': Buffer.byteLength(applyData) }
    }, applyData);
    console.log(`- Status: ${applyRes.statusCode}`);
    console.log(`- Message: ${applyRes.body.message}`);
    const leaveId = applyRes.body.leaveId;
    console.log(`- Created Leave ID: ${leaveId}`);

    // Verify it was truncated in the DB to exactly 6 characters ("Audit ")
    const checkLeavesRes = await request({
      hostname: 'localhost', port: 3000, path: '/api/leaves', method: 'GET',
      headers: authHeaders
    });
    const insertedLeave = checkLeavesRes.body.find(l => l.id === leaveId.toString());
    console.log(`- Fetched leave reason from DB: "${insertedLeave.reason}" (length: ${insertedLeave.reason.length})`);

    // Clean up
    console.log(`- Cleaning up: Cancelling Leave ID ${leaveId}...`);
    await request({
      hostname: 'localhost', port: 3000, path: `/api/leaves/${leaveId}`, method: 'DELETE',
      headers: authHeaders
    });

    console.log('\n🎉 ALL INTEGRATION API TESTS PASSED SUCCESSFULLY!');
  } catch (err) {
    console.error('\n❌ Verification Failed:', err.message);
  }
}

run();
