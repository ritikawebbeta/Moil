const { Client } = require('ssh2');

const config = {
  host: '147.93.109.38',
  port: 65002,
  username: 'u156958239',
  password: 'Acubeai@$38'
};

const conn = new Client();

function executeCommand(conn, cmd) {
  return new Promise((resolve, reject) => {
    conn.exec(cmd, (err, stream) => {
      if (err) return reject(err);
      let stdout = '';
      let stderr = '';
      stream.on('close', (code, signal) => {
        resolve({ code, stdout, stderr });
      }).on('data', (data) => {
        stdout += data.toString();
      }).stderr.on('data', (data) => {
        stderr += data.toString();
      });
    });
  });
}

conn.on('ready', async () => {
  console.log('✅ SSH Connection established.');
  try {
    const nodeVer = await executeCommand(conn, 'node -v');
    console.log(`Node version: ${nodeVer.stdout.trim() || 'NOT FOUND'} (exit code: ${nodeVer.code})`);
    if (nodeVer.stderr) console.log(`Node Stderr: ${nodeVer.stderr}`);

    const npmVer = await executeCommand(conn, 'npm -v');
    console.log(`NPM version: ${npmVer.stdout.trim() || 'NOT FOUND'} (exit code: ${npmVer.code})`);
    if (npmVer.stderr) console.log(`NPM Stderr: ${npmVer.stderr}`);

    const pathRes = await executeCommand(conn, 'echo $PATH');
    console.log(`PATH: ${pathRes.stdout.trim()}`);
  } catch (err) {
    console.error('Error executing commands:', err.message);
  } finally {
    conn.end();
  }
}).connect(config);
