const express = require('express');
const db = require('../config/db');
const { authenticateToken, authorizeRoles, authorizePermission } = require('../middleware/Auth.middleware');
const logger = require('../utils/logger');
const { ValidationError } = require('../middleware/Error.middleware');

const router = express.Router();

// ============================================
// MIDDLEWARE
// ============================================

router.use(authenticateToken);

// ============================================
// OVERVIEW STATS
// ============================================

/**
 * @route   GET /api/dashboard/overview
 * @desc    High-level KPIs for the main dashboard.
 *          Admins and staff see full system stats.
 *          Client role sees only their own data.
 * @access  Admin, Staff, Client
 */
router.get('/overview', async (req, res, next) => {
  try {
    const { role, userId, clientId: userClientId } = req.user;
    const isClient = role === 'client';

    // --- Box stats ---
    const boxWhere   = isClient ? 'WHERE client_id = ?' : '';
    const boxParams  = isClient ? [userClientId] : [];

    const [[boxStats]] = await db.query(
      `SELECT
          COUNT(*) AS total_boxes,
          SUM(CASE WHEN status = 'stored'    THEN 1 ELSE 0 END) AS boxes_stored,
          SUM(CASE WHEN status = 'retrieved' THEN 1 ELSE 0 END) AS boxes_retrieved,
          SUM(CASE WHEN status = 'destroyed' THEN 1 ELSE 0 END) AS boxes_destroyed,
          SUM(CASE
            WHEN destruction_year <= YEAR(CURDATE()) AND status = 'stored' THEN 1
            ELSE 0
          END) AS boxes_pending_destruction
       FROM boxes ${boxWhere}`,
      boxParams
    );

    // --- Activity today ---
    const todayWhere  = isClient ? 'AND client_id = ?' : '';
    const todayParams = isClient ? [userClientId] : [];

    const [[todayStats]] = await db.query(
      `SELECT
          (SELECT COUNT(*) FROM collections  WHERE DATE(created_at) = CURDATE() ${todayWhere}) AS collections_today,
          (SELECT COUNT(*) FROM retrievals   WHERE DATE(created_at) = CURDATE() ${todayWhere}) AS retrievals_today,
          (SELECT COUNT(*) FROM deliveries   WHERE DATE(created_at) = CURDATE() ${todayWhere}) AS deliveries_today,
          (SELECT COUNT(*) FROM requests     WHERE status = 'pending'           ${todayWhere}) AS pending_requests`,
      [...todayParams, ...todayParams, ...todayParams, ...todayParams]
    );

    // --- Client / user counts (admin + staff only) ---
    let systemStats = null;
    if (!isClient) {
      const [[sys]] = await db.query(
        `SELECT
            (SELECT COUNT(*) FROM clients WHERE is_active = TRUE) AS total_clients,
            (SELECT COUNT(*) FROM users   WHERE is_active = TRUE) AS total_users,
            (SELECT COUNT(*) FROM users   WHERE role = 'admin' AND is_active = TRUE) AS admin_users,
            (SELECT COUNT(*) FROM users   WHERE role = 'staff' AND is_active = TRUE) AS staff_users,
            (SELECT COUNT(*) FROM users   WHERE role = 'client' AND is_active = TRUE) AS client_users`
      );
      systemStats = {
        totalClients:  sys.total_clients,
        totalUsers:    sys.total_users,
        usersByRole: {
          admin:  sys.admin_users,
          staff:  sys.staff_users,
          client: sys.client_users,
        },
      };
    }

    // --- 7-day trend (boxes received) ---
    const trendWhere  = isClient ? 'AND b.client_id = ?' : '';
    const trendParams = isClient ? [userClientId] : [];

    const [trend] = await db.query(
      `SELECT
          DATE(created_at)   AS day,
          COUNT(*)           AS boxes_added
       FROM boxes b
       WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
         ${trendWhere}
       GROUP BY DATE(created_at)
       ORDER BY day ASC`,
      trendParams
    );

    res.status(200).json({
      status: 'success',
      data: {
        boxes: {
          total:              boxStats.total_boxes,
          stored:             boxStats.boxes_stored,
          retrieved:          boxStats.boxes_retrieved,
          destroyed:          boxStats.boxes_destroyed,
          pendingDestruction: boxStats.boxes_pending_destruction,
        },
        activity: {
          collectionsToday: todayStats.collections_today,
          retrievalsToday:  todayStats.retrievals_today,
          deliveriesToday:  todayStats.deliveries_today,
          pendingRequests:  todayStats.pending_requests,
        },
        systemStats,
        trend7Days: trend.map((r) => ({ day: r.day, boxesAdded: r.boxes_added })),
      },
    });
  } catch (err) {
    next(err);
  }
});

// ============================================
// RECENT ACTIVITY FEED
// ============================================

/**
 * @route   GET /api/dashboard/activity-feed
 * @desc    Latest N audit-log events — useful as a live activity feed.
 * @access  Admin, Staff
 * @query   limit     - Number of events (default 20, max 100)
 * @query   entityType - Filter to a specific entity type
 */
router.get(
  '/activity-feed',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const limit      = Math.min(parseInt(req.query.limit || 20, 10), 100);
      const entityType = req.query.entityType;

      const conditions = [];
      const params     = [];

      if (entityType) {
        conditions.push('al.entity_type = ?');
        params.push(entityType);
      }

      const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
      params.push(limit);

      const [events] = await db.query(
        `SELECT
            al.audit_id, al.action, al.entity_type, al.entity_id,
            al.ip_address, al.created_at,
            u.username, u.role
         FROM audit_logs al
         LEFT JOIN users u ON al.user_id = u.user_id
         ${whereClause}
         ORDER BY al.created_at DESC
         LIMIT ?`,
        params
      );

      const formatted = events.map((e) => ({
        auditId:    e.audit_id,
        action:     e.action,
        entityType: e.entity_type,
        entityId:   e.entity_id,
        ipAddress:  e.ip_address,
        timestamp:  e.created_at,
        user: e.username ? { username: e.username, role: e.role } : null,
      }));

      res.status(200).json({ status: 'success', data: { events: formatted } });
    } catch (err) {
      next(err);
    }
  }
);

// ============================================
// BOXES BY STATUS BREAKDOWN
// ============================================

/**
 * @route   GET /api/dashboard/boxes/by-status
 * @desc    Box count breakdown by status per client — useful for pie/bar charts.
 * @access  Admin, Staff
 */
router.get(
  '/boxes/by-status',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const [rows] = await db.query(
        `SELECT
            c.client_id, c.client_name, c.client_code,
            SUM(CASE WHEN b.status = 'stored'    THEN 1 ELSE 0 END) AS stored,
            SUM(CASE WHEN b.status = 'retrieved' THEN 1 ELSE 0 END) AS retrieved,
            SUM(CASE WHEN b.status = 'destroyed' THEN 1 ELSE 0 END) AS destroyed,
            COUNT(b.box_id) AS total
         FROM clients c
         LEFT JOIN boxes b ON b.client_id = c.client_id
         WHERE c.is_active = TRUE
         GROUP BY c.client_id, c.client_name, c.client_code
         ORDER BY total DESC`
      );

      const formatted = rows.map((r) => ({
        clientId:   r.client_id,
        clientName: r.client_name,
        clientCode: r.client_code,
        stored:     r.stored,
        retrieved:  r.retrieved,
        destroyed:  r.destroyed,
        total:      r.total,
      }));

      res.status(200).json({ status: 'success', data: { clients: formatted } });
    } catch (err) {
      next(err);
    }
  }
);

// ============================================
// MONTHLY ACTIVITY TREND
// ============================================

/**
 * @route   GET /api/dashboard/trends/monthly
 * @desc    Monthly counts for collections, retrievals, and deliveries
 *          over the past N months.
 * @access  Admin, Staff
 * @query   months - How many months to look back (default 12, max 24)
 */
router.get(
  '/trends/monthly',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const months = Math.min(parseInt(req.query.months || 12, 10), 24);

      const [rows] = await db.query(
        `SELECT
            DATE_FORMAT(period.d, '%Y-%m') AS month,
            COALESCE(col.cnt,  0) AS collections,
            COALESCE(ret.cnt,  0) AS retrievals,
            COALESCE(del.cnt,  0) AS deliveries
         FROM (
           SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL seq.n MONTH), '%Y-%m-01') AS d
           FROM (
             SELECT 0  AS n UNION SELECT 1  UNION SELECT 2  UNION SELECT 3
             UNION SELECT 4  UNION SELECT 5  UNION SELECT 6  UNION SELECT 7
             UNION SELECT 8  UNION SELECT 9  UNION SELECT 10 UNION SELECT 11
             UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15
             UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19
             UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23
           ) seq
           WHERE seq.n < ?
         ) period
         LEFT JOIN (
           SELECT DATE_FORMAT(created_at, '%Y-%m') AS m, COUNT(*) AS cnt
           FROM collections GROUP BY m
         ) col ON col.m = DATE_FORMAT(period.d, '%Y-%m')
         LEFT JOIN (
           SELECT DATE_FORMAT(created_at, '%Y-%m') AS m, COUNT(*) AS cnt
           FROM retrievals GROUP BY m
         ) ret ON ret.m = DATE_FORMAT(period.d, '%Y-%m')
         LEFT JOIN (
           SELECT DATE_FORMAT(created_at, '%Y-%m') AS m, COUNT(*) AS cnt
           FROM deliveries GROUP BY m
         ) del ON del.m = DATE_FORMAT(period.d, '%Y-%m')
         ORDER BY month ASC`,
        [months]
      );

      res.status(200).json({
        status: 'success',
        data:   { months: rows },
      });
    } catch (err) {
      next(err);
    }
  }
);

// ============================================
// DESTRUCTION CALENDAR
// ============================================

/**
 * @route   GET /api/dashboard/destruction-calendar
 * @desc    Boxes grouped by destruction year — useful for a countdown calendar.
 * @access  Admin, Staff
 */
router.get(
  '/destruction-calendar',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const [rows] = await db.query(
        `SELECT
            b.destruction_year,
            COUNT(*) AS box_count,
            SUM(CASE WHEN b.destruction_year <= YEAR(CURDATE()) THEN 1 ELSE 0 END) AS overdue_count
         FROM boxes b
         WHERE b.status = 'stored' AND b.destruction_year IS NOT NULL
         GROUP BY b.destruction_year
         ORDER BY b.destruction_year ASC`
      );

      const currentYear = new Date().getFullYear();
      const formatted   = rows.map((r) => ({
        destructionYear: r.destruction_year,
        boxCount:        r.box_count,
        overdueCount:    r.overdue_count,
        isOverdue:       r.destruction_year <= currentYear,
      }));

      res.status(200).json({ status: 'success', data: { calendar: formatted } });
    } catch (err) {
      next(err);
    }
  }
);

// ============================================
// QUICK CONTROLS (permission-gated)
// ============================================

/**
 * @route   GET /api/dashboard/controls
 * @desc    Returns the calling user's effective permissions so the
 *          frontend can render/hide action buttons appropriately.
 * @access  Admin, Staff, Client
 */
router.get('/controls', async (req, res, next) => {
  try {
    const { userId } = req.user;

    const [rows] = await db.query(
      `SELECT
          can_create_boxes, can_edit_boxes, can_delete_boxes,
          can_create_collections, can_create_retrievals,
          can_create_deliveries, can_view_reports, can_manage_users
       FROM permissions
       WHERE user_id = ?`,
      [userId]
    );

    const perms = rows[0] || {};

    res.status(200).json({
      status: 'success',
      data: {
        permissions: {
          canCreateBoxes:       Boolean(perms.can_create_boxes),
          canEditBoxes:         Boolean(perms.can_edit_boxes),
          canDeleteBoxes:       Boolean(perms.can_delete_boxes),
          canCreateCollections: Boolean(perms.can_create_collections),
          canCreateRetrievals:  Boolean(perms.can_create_retrievals),
          canCreateDeliveries:  Boolean(perms.can_create_deliveries),
          canViewReports:       Boolean(perms.can_view_reports),
          canManageUsers:       Boolean(perms.can_manage_users),
        },
      },
    });
  } catch (err) {
    next(err);
  }
});

// ============================================
// DAILY STATS SNAPSHOT
// ============================================

/**
 * @route   GET /api/dashboard/daily-stats
 * @desc    Returns the daily_stats table entries for charting over time.
 * @access  Admin, Staff
 * @query   days - How many historical days to return (default 30, max 365)
 */
router.get(
  '/daily-stats',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const days = Math.min(parseInt(req.query.days || 30, 10), 365);

      const [rows] = await db.query(
        `SELECT
            stat_date,
            total_boxes, total_clients,
            boxes_stored, boxes_retrieved, boxes_destroyed,
            collections_count, retrievals_count, deliveries_count,
            active_users
         FROM daily_stats
         WHERE stat_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
         ORDER BY stat_date ASC`,
        [days]
      );

      res.status(200).json({
        status: 'success',
        data:   { snapshots: rows },
      });
    } catch (err) {
      next(err);
    }
  }
);

module.exports = router;