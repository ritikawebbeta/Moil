// src/routes/sync.js
const express = require('express');
const { pool } = require('../config/db');

const router = express.Router();

/**
 * @route   POST /api/sync/holidays
 * @desc    Sync holidays from SAP CSV file via SFTP to database (Mocked)
 */
router.post('/holidays', async (req, res) => {
  res.json({
    message: 'Holidays synchronization completed successfully (Mocked)',
    recordsSynced: 0
  });
});

/**
 * @route   POST /api/sync/employees
 * @desc    Sync employee master list from SAP CSV file via SFTP to database (Mocked)
 */
router.post('/employees', async (req, res) => {
  res.json({
    message: 'Employee master synchronization completed successfully (Mocked)',
    recordsSynced: 0
  });
});

module.exports = router;
