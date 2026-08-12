const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const { testConnection } = require('./config/db');
const apiRouter = require('./routes/api');

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
