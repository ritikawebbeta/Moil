const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
require('dotenv').config();

const { testConnection } = require('./config/db');
const apiRouter = require('./routes/api');
const syncRouter = require('./routes/sync');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

// Static uploads folder
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
app.use('/test/moil_hr_app/uploads', express.static(path.join(__dirname, '../uploads')));

// Test database connection on startup
testConnection();

// Routes
app.use('/api', apiRouter);
app.use('/test/moil_hr_app/api', apiRouter);
app.use('/api/sync', syncRouter);
app.use('/test/moil_hr_app/api/sync', syncRouter);

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
  console.error('[Server Error]', err.stack || err.message);
  res.status(err.status || 500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

// Start the server
app.listen(PORT, () => {
  console.log(`[Server] Express server is running on http://localhost:${PORT}`);
});

module.exports = app;
