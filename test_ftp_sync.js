// test_ftp_sync.js
const { runFtpSync } = require('./src/services/ftp_sync_service');

console.log('Testing FTP Synchronization Service...');
runFtpSync()
  .then(() => {
    console.log('FTP Sync Test Execution Completed.');
    process.exit(0);
  })
  .catch(err => {
    console.error('FTP Sync Test Failed:', err);
    process.exit(1);
  });
