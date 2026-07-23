const mysql = require('mysql2/promise');
require('dotenv').config();

// Create the connection pool
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '3306', 10),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'u156958239_moil_hr_app',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0
});

// Test helper to verify configuration and connectivity on startup
async function testConnection() {
  try {
    const connection = await pool.getConnection();
    console.log(`[Database] Connection pool established. Connected to "${process.env.DB_NAME || 'u156958239_moil_hr_app'}" at ${process.env.DB_HOST || 'localhost'}`);
    connection.release();
    return true;
  } catch (error) {
    console.error('[Database] Connection failed. Error details:');
    console.error(`- Host: ${process.env.DB_HOST || 'localhost'}`);
    console.error(`- User: ${process.env.DB_USER}`);
    console.error(`- Database: ${process.env.DB_NAME || 'u156958239_moil_hr_app'}`);
    console.error(`- Message: ${error.message}`);
    return false;
  }
}

module.exports = {
  pool,
  testConnection
};
