// src/routes/sync.js
const express = require('express');
const { pool } = require('../config/db');

const router = express.Router();

/**
 * @route   GET /api/sync/pending-outbound
 * @desc    Returns all unsynced modified rows & columns for Outbound FTP export
 */
router.get('/pending-outbound', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM app_outbound_changes WHERE is_synced = 0 ORDER BY id ASC LIMIT 500');
    const parsed = rows.map(r => ({
      id: r.id,
      table_name: r.table_name,
      record_id: r.record_id,
      action_type: r.action_type,
      changed_columns: typeof r.changed_columns === 'string' ? JSON.parse(r.changed_columns || '{}') : r.changed_columns,
      row_data: typeof r.row_data === 'string' ? JSON.parse(r.row_data || '{}') : r.row_data,
      created_at: r.created_at
    }));
    res.json(parsed);
  } catch (err) {
    console.error('[Pending Outbound Error]', err.message);
    res.status(500).json({ error: 'Failed to fetch pending outbound changes' });
  }
});

/**
 * @route   POST /api/sync/mark-outbound-synced
 * @desc    Marks processed change IDs as synced
 */
router.post('/mark-outbound-synced', async (req, res) => {
  try {
    const { ids } = req.body;
    if (Array.isArray(ids) && ids.length > 0) {
      await pool.query('UPDATE app_outbound_changes SET is_synced = 1, synced_at = NOW() WHERE id IN (?)', [ids]);
    }
    res.json({ success: true, count: ids ? ids.length : 0 });
  } catch (err) {
    console.error('[Mark Outbound Synced Error]', err.message);
    res.status(500).json({ error: 'Failed to mark outbound changes as synced' });
  }
});

module.exports = router;
