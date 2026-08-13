const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const { testConnection } = require('./config/db');
const apiRouter = require('./routes/api');
let smsService;
try {
  smsService = require('./utils/smsService');
} catch (_) {
  try {
    smsService = require('./src/utils/smsService');
  } catch (__) {
    console.error('[smsService Load Warning]', _.message);
  }
}

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Cache-Control', 'Pragma', 'Expires', 'X-Requested-With'],
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

// Disable caching and allow CORS headers on all API responses
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Cache-Control, Pragma, Expires, X-Requested-With');
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.setHeader('Surrogate-Control', 'no-store');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  next();
});

// Top-level CORS Proxy SMS Routes
app.get(['/api/sms/token', '/test/moil_hr_app/api/sms/token', '/api/token', '/test/moil_hr_app/api/token'], async (req, res) => {
  try {
    const token = await smsService.getAuthToken();
    if (token) return res.json({ success: true, token });
    return res.status(500).json({ error: 'Failed to obtain JWT auth token' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.post(['/api/send-sms', '/test/moil_hr_app/api/send-sms', '/api/sms/send', '/test/moil_hr_app/api/sms/send'], async (req, res) => {
  const { mobile, mobileNumber, script, dlt_template_id, dltTemplateId, template_id } = req.body;
  const targetPhone = mobile || mobileNumber || smsService.DEFAULT_MOBILE;
  const tId = dlt_template_id || dltTemplateId || template_id || '1107163177301329708';
  try {
    const result = await smsService.sendSms({ mobileNumber: targetPhone, script: script || 'MOIL LMS Notification', dltTemplateId: tId });
    return res.json({ message: 'SMS trigger processed', targetPhone, result });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to send SMS', message: err.message });
  }
});

// Static uploads folder
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
app.use('/test/moil_hr_app/uploads', express.static(path.join(__dirname, '../uploads')));

// Test database connection on startup
testConnection();

// Dedicated PDF file viewer/downloader route
app.get(['/payslip-pdf/:filename', '/test/moil_hr_app/payslip-pdf/:filename'], (req, res) => {
  const filename = req.params.filename;
  const safeFilename = path.basename(filename);
  const filePath = path.join(__dirname, '../uploads/payslips', safeFilename);

  if (!fs.existsSync(filePath)) {
    return res.status(404).send('File not found');
  }

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${safeFilename}"`);
  return res.sendFile(filePath);
});

// Dedicated Profile Photo viewer/streamer route
app.get(['/profile-photo/:empNo', '/test/moil_hr_app/profile-photo/:empNo', '/api/profile-photo/:empNo', '/test/moil_hr_app/api/profile-photo/:empNo'], (req, res) => {
  const rawEmpNo = req.params.empNo || '';
  const cleanId = rawEmpNo.trim().replace(/^0+/, '');
  const paddedId = cleanId ? cleanId.padStart(8, '0') : '';

  const candidateDirs = [
    path.join(__dirname, '../uploads/profiles/Photo'),
    path.join(__dirname, '../uploads/profiles'),
    path.join(__dirname, '../uploads/Photo'),
    path.join(__dirname, '../uploads'),
    '/home/u156958239/domains/acubeai.com/public_html/test/moil_hr_app/uploads/profiles/Photo',
    '/home/u156958239/domains/acubeai.com/public_html/test/moil_hr_app/uploads/profiles',
    '/home/u156958239/domains/acubeai.com/public_html/test/moil_hr_app/uploads'
  ];

  const candidateNames = [
    `${cleanId}.jpg`, `${cleanId}.png`, `${cleanId}.jpeg`, `${cleanId}.JPG`, `${cleanId}.PNG`,
    `${paddedId}.jpg`, `${paddedId}.png`, `${paddedId}.jpeg`, `${paddedId}.JPG`, `${paddedId}.PNG`,
    `${rawEmpNo}.jpg`, `${rawEmpNo}.png`, `${rawEmpNo}.jpeg`, `${rawEmpNo}.JPG`, `${rawEmpNo}.PNG`,
    `${cleanId}_self.jpg`, `${cleanId}_self.png`, `${cleanId}_self.jpeg`,
    `${paddedId}_self.jpg`, `${paddedId}_self.png`, `${paddedId}_self.jpeg`
  ];

  for (const dir of candidateDirs) {
    if (!fs.existsSync(dir)) continue;
    for (const name of candidateNames) {
      if (!name) continue;
      const fullPath = path.join(dir, name);
      if (fs.existsSync(fullPath)) {
        const ext = path.extname(name).toLowerCase();
        const contentType = (ext === '.png') ? 'image/png' : 'image/jpeg';
        res.setHeader('Content-Type', contentType);
        res.setHeader('Cache-Control', 'public, max-age=86400');
        return res.sendFile(fullPath);
      }
    }
  }

  return res.status(404).send('Photo not found');
});

// Routes
app.use('/api', apiRouter);
app.use('/test/moil_hr_app/api', apiRouter);

// Root route
app.get(['/', '/test/moil_hr_app/api'], (req, res) => {
  res.json({
    message: 'Welcome to the Moil HR App Backend API',
    status: 'Running',
    timestamp: new Date()
  });
});

// 404 Route handler
app.use((req, res, next) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Cannot ${req.method} ${req.originalUrl}`
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('[Unhandled Error]', err.stack);
  res.status(500).json({ error: 'Internal Server Error', message: err.message });
});

if (require.main === module || !module.parent) {
  app.listen(PORT, () => {
    console.log(`Moil Backend server listening on port ${PORT}`);

    // Automated FTP Synchronization: Initial run after 10s, then repeat every 15 minutes
    const { runFtpSync } = require('./services/ftp_sync_service');
    setTimeout(() => {
      runFtpSync().catch(err => console.error('[Initial FTP Sync Error]', err));
    }, 10000);

    const SYNC_INTERVAL_MS = 15 * 60 * 1000; // 15 minutes
    setInterval(() => {
      runFtpSync().catch(err => console.error('[Periodic FTP Sync Error]', err));
    }, SYNC_INTERVAL_MS);
  });
}

module.exports = app;
