const mysql = require('mysql2/promise');

async function dropOutboundTable() {
  const conn = await mysql.createConnection({
    host: '127.0.0.1', port: 3306,
    user: 'root', password: '',
    database: 'u156958239_moil_hr_app'
  });

  try {
    await conn.query('DROP TABLE IF EXISTS `app_outbound_changes`');
    console.log('✅ Dropped app_outbound_changes from local database!');
  } catch (e) {
    console.log('Error:', e.message);
  }

  await conn.end();
}
dropOutboundTable();
