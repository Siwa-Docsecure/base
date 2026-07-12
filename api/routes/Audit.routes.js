const express = require('express');
const db = require('../config/db');
const { authenticateToken, authorizeRoles } = require('../middleware/Auth.middleware');
const logger = require('../utils/logger');
const { ValidationError } = require('../middleware/Error.middleware');

const router = express.Router();

// ============================================
// MIDDLEWARE
// ============================================

router.use(authenticateToken);
router.use(authorizeRoles('admin', 'staff'));

// ============================================
// HELPER — serialise one audit row
// ============================================

const parseJsonSafe = (str) => {
  if (!str) return null;
  try { return JSON.parse(str); } catch { return str; }
};

const formatAuditRow = (row) => ({
  auditId:    row.audit_id,
  action:     row.action,
  entityType: row.entity_type,
  entityId:   row.entity_id,
  oldValue:   parseJsonSafe(row.old_value),
  newValue:   parseJsonSafe(row.new_value),
  ipAddress:  row.ip_address,
  userAgent:  row.user_agent,
  timestamp:  row.created_at,
  actor: row.username
    ? { userId: row.user_id, username: row.username, role: row.role }
    : null,
});

// ============================================
// HELPER — build WHERE + params for shared filters
// ============================================

const buildAuditWhere = (query) => {
  const { userId, action, entityType, entityId, ipAddress, dateFrom, dateTo, search } = query;
  const conditions = [];
  const params     = [];

  if (userId)     { conditions.push('al.user_id = ?');     params.push(userId); }
  if (action)     { conditions.push('al.action LIKE ?');   params.push(`%${action}%`); }
  if (entityType) { conditions.push('al.entity_type = ?'); params.push(entityType); }
  if (entityId)   { conditions.push('al.entity_id = ?');   params.push(entityId); }
  if (ipAddress)  { conditions.push('al.ip_address = ?');  params.push(ipAddress); }
  if (dateFrom)   { conditions.push('al.created_at >= ?'); params.push(dateFrom); }
  if (dateTo)     { conditions.push('al.created_at <= ?'); params.push(dateTo + ' 23:59:59'); }
  if (search) {
    conditions.push('(al.action LIKE ? OR al.entity_type LIKE ? OR u.username LIKE ?)');
    const pat = `%${search}%`;
    params.push(pat, pat, pat);
  }

  return { clause: conditions.length ? `WHERE ${conditions.join(' AND ')}` : '', params };
};

// ============================================
// AUDIT LOG — paginated list                GET /api/audit
// ============================================

router.get('/', async (req, res, next) => {
  try {
    const page      = Math.max(1, parseInt(req.query.page  || 1,  10));
    const limit     = Math.min(200, parseInt(req.query.limit || 50, 10));
    const offset    = (page - 1) * limit;
    const sortOrder = req.query.sortOrder?.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

    const { clause, params } = buildAuditWhere(req.query);
    const baseSelect = `FROM audit_logs al LEFT JOIN users u ON al.user_id = u.user_id ${clause}`;

    const [[{ total }]] = await db.query(`SELECT COUNT(*) AS total ${baseSelect}`, params);
    const [rows] = await db.query(
      `SELECT al.audit_id, al.user_id, al.action, al.entity_type, al.entity_id,
              al.old_value, al.new_value, al.ip_address, al.user_agent, al.created_at,
              u.username, u.role
       ${baseSelect}
       ORDER BY al.created_at ${sortOrder}
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    res.status(200).json({
      status: 'success',
      data: {
        logs: rows.map(formatAuditRow),
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
      },
    });
  } catch (err) { next(err); }
});

// ============================================
// FIXED STATIC ROUTES BEFORE /:auditId
// These MUST come before the wildcard param route
// ============================================

// GET /api/audit/summary
router.get('/summary', authorizeRoles('admin'), async (req, res, next) => {
  try {
    const { dateFrom, dateTo } = req.query;
    const conditions = [];
    const params     = [];

    if (dateFrom) { conditions.push('al.created_at >= ?'); params.push(dateFrom); }
    if (dateTo)   { conditions.push('al.created_at <= ?'); params.push(dateTo + ' 23:59:59'); }

    const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const [[actionBreakdownRows], [entityBreakdownRows], [topActorsRows], [dailyVolumeRows]] =
      await Promise.all([
        db.query(
          `SELECT action, COUNT(*) AS cnt FROM audit_logs al ${whereClause} GROUP BY action ORDER BY cnt DESC`,
          [...params]
        ),
        db.query(
          `SELECT entity_type, COUNT(*) AS cnt FROM audit_logs al ${whereClause} GROUP BY entity_type ORDER BY cnt DESC`,
          [...params]
        ),
        db.query(
          `SELECT u.username, u.role, COUNT(*) AS event_count
           FROM audit_logs al LEFT JOIN users u ON al.user_id = u.user_id
           ${whereClause} GROUP BY al.user_id, u.username, u.role ORDER BY event_count DESC LIMIT 10`,
          [...params]
        ),
        db.query(
          `SELECT DATE(al.created_at) AS day, COUNT(*) AS event_count
           FROM audit_logs al
           ${whereClause || 'WHERE al.created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)'}
           GROUP BY DATE(al.created_at) ORDER BY day ASC`,
          conditions.length ? [...params] : []
        ),
      ]);

    const toMap = (rows, k, v) => rows.reduce((acc, r) => { acc[r[k]] = r[v]; return acc; }, {});

    res.status(200).json({
      status: 'success',
      data: {
        actionBreakdown: toMap(actionBreakdownRows, 'action', 'cnt'),
        entityBreakdown: toMap(entityBreakdownRows, 'entity_type', 'cnt'),
        topActors: topActorsRows.map((r) => ({ username: r.username, role: r.role, eventCount: r.event_count })),
        dailyVolume: dailyVolumeRows.map((r) => ({ day: r.day, eventCount: r.event_count })),
      },
    });
  } catch (err) { next(err); }
});

// GET /api/audit/export/csv
router.get('/export/csv', authorizeRoles('admin'), async (req, res, next) => {
  try {
    const exportLimit = Math.min(50000, parseInt(req.query.limit || 5000, 10));
    const { clause, params } = buildAuditWhere(req.query);

    const [rows] = await db.query(
      `SELECT al.audit_id, al.user_id, u.username, u.role,
              al.action, al.entity_type, al.entity_id,
              al.old_value, al.new_value, al.ip_address, al.user_agent, al.created_at
       FROM audit_logs al LEFT JOIN users u ON al.user_id = u.user_id
       ${clause} ORDER BY al.created_at DESC LIMIT ?`,
      [...params, exportLimit]
    );

    const headers = ['audit_id','user_id','username','role','action','entity_type','entity_id','old_value','new_value','ip_address','user_agent','created_at'];
    const escape  = (val) => {
      if (val === null || val === undefined) return '';
      const str = typeof val === 'object' ? JSON.stringify(val) : String(val);
      return str.includes(',') || str.includes('"') || str.includes('\n')
        ? `"${str.replace(/"/g, '""')}"` : str;
    };

    const csvLines = [
      headers.join(','),
      ...rows.map((r) =>
        [r.audit_id, r.user_id, r.username||'', r.role||'', r.action, r.entity_type,
         r.entity_id??'', r.old_value??'', r.new_value??'', r.ip_address??'', r.user_agent??'', r.created_at]
          .map(escape).join(',')
      ),
    ];

    const filename = `psms_audit_${new Date().toISOString().slice(0, 10)}.csv`;
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    logger.info(`Audit CSV export by ${req.user.username} — ${rows.length} rows`);
    return res.status(200).send(csvLines.join('\n'));
  } catch (err) { next(err); }
});

// GET /api/audit/export/json
router.get('/export/json', authorizeRoles('admin'), async (req, res, next) => {
  try {
    const exportLimit = Math.min(50000, parseInt(req.query.limit || 5000, 10));
    const { clause, params } = buildAuditWhere(req.query);

    const [rows] = await db.query(
      `SELECT al.audit_id, al.user_id, u.username, u.role,
              al.action, al.entity_type, al.entity_id,
              al.old_value, al.new_value, al.ip_address, al.user_agent, al.created_at
       FROM audit_logs al LEFT JOIN users u ON al.user_id = u.user_id
       ${clause} ORDER BY al.created_at DESC LIMIT ?`,
      [...params, exportLimit]
    );

    const filename = `psms_audit_${new Date().toISOString().slice(0, 10)}.json`;
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    logger.info(`Audit JSON export by ${req.user.username} — ${rows.length} rows`);

    return res.status(200).json({
      generatedAt: new Date().toISOString(),
      exportedBy:  req.user.username,
      filters:     req.query,
      totalRows:   rows.length,
      logs:        rows.map(formatAuditRow),
    });
  } catch (err) { next(err); }
});

// GET /api/audit/entity/:entityType/:entityId
router.get('/entity/:entityType/:entityId', async (req, res, next) => {
  try {
    const { entityType, entityId } = req.params;
    const [rows] = await db.query(
      `SELECT al.audit_id, al.user_id, al.action, al.entity_type, al.entity_id,
              al.old_value, al.new_value, al.ip_address, al.user_agent, al.created_at,
              u.username, u.role
       FROM audit_logs al LEFT JOIN users u ON al.user_id = u.user_id
       WHERE al.entity_type = ? AND al.entity_id = ?
       ORDER BY al.created_at DESC`,
      [entityType, entityId]
    );

    res.status(200).json({
      status: 'success',
      data: { entityType, entityId: parseInt(entityId, 10), totalEvents: rows.length, history: rows.map(formatAuditRow) },
    });
  } catch (err) { next(err); }
});

// GET /api/audit/users/:userId/activity
router.get('/users/:userId/activity', authorizeRoles('admin'), async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { dateFrom, dateTo } = req.query;
    const limit = Math.min(200, parseInt(req.query.limit || 50, 10));

    const conditions = ['al.user_id = ?'];
    const params     = [userId];
    if (dateFrom) { conditions.push('al.created_at >= ?'); params.push(dateFrom); }
    if (dateTo)   { conditions.push('al.created_at <= ?'); params.push(dateTo + ' 23:59:59'); }

    const whereClause = `WHERE ${conditions.join(' AND ')}`;

    const [[breakdown], [events]] = await Promise.all([
      db.query(`SELECT action, COUNT(*) AS cnt FROM audit_logs al ${whereClause} GROUP BY action ORDER BY cnt DESC`, [...params]),
      db.query(
        `SELECT al.audit_id, al.user_id, al.action, al.entity_type, al.entity_id,
                al.old_value, al.new_value, al.ip_address, al.user_agent, al.created_at,
                u.username, u.role
         FROM audit_logs al LEFT JOIN users u ON al.user_id = u.user_id
         ${whereClause} ORDER BY al.created_at DESC LIMIT ?`,
        [...params, limit]
      ),
    ]);

    res.status(200).json({
      status: 'success',
      data: {
        userId: parseInt(userId, 10),
        actionBreakdown: breakdown.reduce((acc, r) => { acc[r.action] = r.cnt; return acc; }, {}),
        recentEvents: events.map(formatAuditRow),
      },
    });
  } catch (err) { next(err); }
});

// ============================================
// SINGLE EVENT DETAIL          GET /api/audit/:auditId
// MUST come AFTER all static routes
// ============================================

router.get('/:auditId', async (req, res, next) => {
  try {
    const { auditId } = req.params;
    const [rows] = await db.query(
      `SELECT al.audit_id, al.user_id, al.action, al.entity_type, al.entity_id,
              al.old_value, al.new_value, al.ip_address, al.user_agent, al.created_at,
              u.username, u.role
       FROM audit_logs al LEFT JOIN users u ON al.user_id = u.user_id
       WHERE al.audit_id = ?`,
      [auditId]
    );

    if (!rows.length) return res.status(404).json({ status: 'error', message: 'Audit entry not found' });

    const event = formatAuditRow(rows[0]);
    let diff = null;

    if (event.oldValue && event.newValue &&
        typeof event.oldValue === 'object' && typeof event.newValue === 'object') {
      const allKeys = new Set([...Object.keys(event.oldValue), ...Object.keys(event.newValue)]);
      diff = {};
      for (const key of allKeys) {
        const before = event.oldValue[key];
        const after  = event.newValue[key];
        if (JSON.stringify(before) !== JSON.stringify(after)) diff[key] = { before, after };
      }
      if (!Object.keys(diff).length) diff = null;
    }

    res.status(200).json({ status: 'success', data: { ...event, diff } });
  } catch (err) { next(err); }
});

module.exports = router;