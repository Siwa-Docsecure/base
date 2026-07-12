const express = require('express');
const db = require('../config/db');
const { authenticateToken, authorizeRoles, authorizePermission } = require('../middleware/Auth.middleware');
const logger = require('../utils/logger');
const { ValidationError, NotFoundError } = require('../middleware/Error.middleware');

const router = express.Router();

// ============================================
// MIDDLEWARE - All report routes require auth
// ============================================

router.use(authenticateToken);
router.use(authorizeRoles('admin', 'staff'));
router.use(authorizePermission('canViewReports'));

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Build a dynamic WHERE clause from a filter map.
 * Returns { clause: string, params: array }
 */
const buildWhere = (filters) => {
  const conditions = [];
  const params = [];

  for (const [condition, value] of Object.entries(filters)) {
    if (value !== undefined && value !== null && value !== '') {
      conditions.push(condition);
      if (Array.isArray(value)) {
        params.push(...value);
      } else {
        params.push(value);
      }
    }
  }

  return {
    clause: conditions.length ? `WHERE ${conditions.join(' AND ')}` : '',
    params,
  };
};

/**
 * Parse comma-separated IDs into a validated integer array.
 */
const parseIdList = (raw) => {
  if (!raw) return [];
  return raw.split(',').map((id) => parseInt(id.trim(), 10)).filter((id) => !isNaN(id));
};

// ============================================
// BOX REPORTS
// ============================================

/**
 * @route   GET /api/reports/boxes
 * @desc    Comprehensive box report — filter by client, status, rack, date range,
 *          destruction year range, retention years, and free-text search.
 *          Grouped by client when ?grouped=true.
 * @access  Admin, Staff (canViewReports)
 * @query   clientIds        - Comma-separated client IDs (omit = all)
 * @query   status           - Comma-separated statuses: stored,retrieved,destroyed
 * @query   rackingLabelId   - Filter by a specific rack label
 * @query   search           - Search box_number or box_description
 * @query   dateFrom / dateTo      - date_received range (YYYY-MM-DD)
 * @query   destructionYearFrom / destructionYearTo
 * @query   retentionYears   - Exact retention year match
 * @query   pendingDestruction - 'true' restricts to overdue stored boxes
 * @query   grouped          - 'true' groups results by client
 * @query   includeStats     - 'true' (default) appends summary statistics
 */
router.get('/boxes', async (req, res, next) => {
  try {
    const {
      clientIds,
      status,
      rackingLabelId,
      search,
      dateFrom,
      dateTo,
      destructionYearFrom,
      destructionYearTo,
      retentionYears,
      pendingDestruction,
      grouped = 'false',
      includeStats = 'true',
    } = req.query;

    const conditions = [];
    const params = [];

    // --- Client filter ---
    const clientIdArray = parseIdList(clientIds);
    if (clientIdArray.length) {
      conditions.push(`b.client_id IN (${clientIdArray.map(() => '?').join(',')})`);
      params.push(...clientIdArray);
    }

    // --- Status filter (multi-value) ---
    if (status) {
      const statuses = status.split(',').map((s) => s.trim()).filter(Boolean);
      if (statuses.length === 1) {
        conditions.push('b.status = ?');
        params.push(statuses[0]);
      } else if (statuses.length > 1) {
        conditions.push(`b.status IN (${statuses.map(() => '?').join(',')})`);
        params.push(...statuses);
      }
    }

    // --- Rack label ---
    if (rackingLabelId) {
      conditions.push('b.racking_label_id = ?');
      params.push(rackingLabelId);
    }

    // --- Pending destruction ---
    if (pendingDestruction === 'true') {
      conditions.push("b.destruction_year <= YEAR(CURDATE()) AND b.status = 'stored'");
    }

    // --- Full-text search ---
    if (search) {
      conditions.push('(b.box_number LIKE ? OR b.box_description LIKE ?)');
      const pat = `%${search}%`;
      params.push(pat, pat);
    }

    // --- Date received range ---
    if (dateFrom) { conditions.push('b.date_received >= ?'); params.push(dateFrom); }
    if (dateTo)   { conditions.push('b.date_received <= ?'); params.push(dateTo); }

    // --- Destruction year range ---
    if (destructionYearFrom) { conditions.push('b.destruction_year >= ?'); params.push(parseInt(destructionYearFrom, 10)); }
    if (destructionYearTo)   { conditions.push('b.destruction_year <= ?'); params.push(parseInt(destructionYearTo, 10)); }

    // --- Retention years exact match ---
    if (retentionYears) {
      conditions.push('b.retention_years = ?');
      params.push(parseInt(retentionYears, 10));
    }

    const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const [rows] = await db.query(
      `SELECT
          b.box_id, b.box_number, b.box_description, b.box_size,
          b.data_years, b.date_range, b.box_image,
          b.date_received, b.year_received,
          b.retention_years, b.destruction_year, b.status,
          CASE
            WHEN b.destruction_year IS NOT NULL
              AND b.destruction_year <= YEAR(CURDATE())
              AND b.status = 'stored' THEN TRUE
            ELSE FALSE
          END AS is_pending_destruction,
          c.client_id, c.client_name, c.client_code,
          r.label_code AS rack_label, r.location_description AS rack_location
       FROM boxes b
       LEFT JOIN clients  c ON b.client_id        = c.client_id
       LEFT JOIN racking_labels r ON b.racking_label_id = r.label_id
       ${whereClause}
       ORDER BY c.client_name, b.box_number`,
      params
    );

    const currentYear = new Date().getFullYear();

    const formatBox = (row) => ({
      boxId:               row.box_id,
      boxNumber:           row.box_number,
      description:         row.box_description,
      boxSize:             row.box_size || 'A3',
      dataYears:           row.data_years,
      dateRange:           row.date_range,
      boxImage:            row.box_image,
      dateReceived:        row.date_received,
      yearReceived:        row.year_received,
      retentionYears:      row.retention_years,
      destructionYear:     row.destruction_year,
      status:              row.status,
      isPendingDestruction: Boolean(row.is_pending_destruction),
      client: {
        clientId:   row.client_id,
        clientName: row.client_name,
        clientCode: row.client_code,
      },
      rackLabel:    row.rack_label   || null,
      rackLocation: row.rack_location || null,
    });

    // --- Build summary statistics ---
    let summary = null;
    if (includeStats === 'true') {
      const statusCounts = rows.reduce((acc, r) => {
        acc[r.status] = (acc[r.status] || 0) + 1;
        return acc;
      }, {});

      summary = {
        totalBoxes:         rows.length,
        uniqueClients:      new Set(rows.map((r) => r.client_id)).size,
        statusCounts: {
          stored:    statusCounts.stored    || 0,
          retrieved: statusCounts.retrieved || 0,
          destroyed: statusCounts.destroyed || 0,
        },
        pendingDestruction: rows.filter(
          (r) => r.destruction_year && r.destruction_year <= currentYear && r.status === 'stored'
        ).length,
      };
    }

    // --- Flat or grouped response ---
    let data;
    if (grouped === 'true') {
      const clientMap = new Map();

      rows.forEach((row) => {
        if (!clientMap.has(row.client_id)) {
          clientMap.set(row.client_id, {
            clientId:   row.client_id,
            clientName: row.client_name,
            clientCode: row.client_code,
            boxes:      [],
            summary: { totalBoxes: 0, stored: 0, retrieved: 0, destroyed: 0, pendingDestruction: 0 },
          });
        }
        const entry = clientMap.get(row.client_id);
        entry.boxes.push(formatBox(row));
        entry.summary.totalBoxes++;
        if (row.status === 'stored')    entry.summary.stored++;
        if (row.status === 'retrieved') entry.summary.retrieved++;
        if (row.status === 'destroyed') entry.summary.destroyed++;
        if (row.destruction_year && row.destruction_year <= currentYear && row.status === 'stored') {
          entry.summary.pendingDestruction++;
        }
      });

      data = { clients: Array.from(clientMap.values()), summary };
    } else {
      data = { boxes: rows.map(formatBox), summary };
    }

    logger.info(
      `Box report generated by ${req.user.username} — ${rows.length} boxes, filters: ${JSON.stringify(req.query)}`
    );

    res.status(200).json({
      status:      'success',
      generatedAt: new Date().toISOString(),
      filters:     req.query,
      data,
    });
  } catch (err) {
    next(err);
  }
});

// ============================================
// COLLECTIONS REPORT
// ============================================

/**
 * @route   GET /api/reports/collections
 * @desc    Report on box collections per client, with optional date range.
 * @access  Admin, Staff (canViewReports)
 * @query   clientId   - Filter to a single client
 * @query   dateFrom / dateTo - collection_date range
 * @query   createdBy  - Filter by staff user ID who created the record
 * @query   includeStats
 */
router.get('/collections', async (req, res, next) => {
  try {
    const { clientId, dateFrom, dateTo, createdBy, includeStats = 'true' } = req.query;

    const conditions = [];
    const params = [];

    if (clientId)   { conditions.push('col.client_id = ?');             params.push(clientId); }
    if (dateFrom)   { conditions.push('col.collection_date >= ?');       params.push(dateFrom); }
    if (dateTo)     { conditions.push('col.collection_date <= ?');       params.push(dateTo); }
    if (createdBy)  { conditions.push('col.created_by = ?');             params.push(createdBy); }

    const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const [rows] = await db.query(
      `SELECT
          col.collection_id,
          col.total_boxes,
          col.box_description,
          col.dispatcher_name,
          col.collector_name,
          col.collection_date,
          col.pdf_path,
          col.created_at,
          c.client_id, c.client_name, c.client_code,
          u.username AS created_by_username
       FROM collections col
       LEFT JOIN clients c ON col.client_id  = c.client_id
       LEFT JOIN users   u ON col.created_by = u.user_id
       ${whereClause}
       ORDER BY col.collection_date DESC, col.created_at DESC`,
      params
    );

    const formatted = rows.map((r) => ({
      collectionId:    r.collection_id,
      totalBoxes:      r.total_boxes,
      boxDescription:  r.box_description,
      dispatcherName:  r.dispatcher_name,
      collectorName:   r.collector_name,
      collectionDate:  r.collection_date,
      pdfPath:         r.pdf_path,
      createdAt:       r.created_at,
      createdBy:       r.created_by_username,
      client: { clientId: r.client_id, clientName: r.client_name, clientCode: r.client_code },
    }));

    let summary = null;
    if (includeStats === 'true') {
      const totalBoxesCollected = rows.reduce((acc, r) => acc + r.total_boxes, 0);
      summary = {
        totalCollections:    rows.length,
        totalBoxesCollected,
        uniqueClients:       new Set(rows.map((r) => r.client_id)).size,
      };
    }

    res.status(200).json({
      status:      'success',
      generatedAt: new Date().toISOString(),
      filters:     req.query,
      data:        { collections: formatted, summary },
    });
  } catch (err) {
    next(err);
  }
});

// ============================================
// RETRIEVALS REPORT
// ============================================

/**
 * @route   GET /api/reports/retrievals
 * @desc    Report on box retrievals with status, signatures, and client info.
 * @access  Admin, Staff (canViewReports)
 * @query   clientId
 * @query   status  - pending | completed | retrieved (retrieval lifecycle)
 * @query   dateFrom / dateTo - retrieval_date range
 * @query   boxId   - Filter to a specific box
 * @query   includeStats
 */
router.get('/retrievals', async (req, res, next) => {
  try {
    const { clientId, status, dateFrom, dateTo, boxId, includeStats = 'true' } = req.query;

    const conditions = [];
    const params = [];

    if (clientId) { conditions.push('ret.client_id = ?');        params.push(clientId); }
    if (boxId)    { conditions.push('ret.box_id = ?');            params.push(boxId); }
    if (dateFrom) { conditions.push('ret.retrieval_date >= ?');   params.push(dateFrom); }
    if (dateTo)   { conditions.push('ret.retrieval_date <= ?');   params.push(dateTo); }

    if (status) {
      const statuses = status.split(',').map((s) => s.trim()).filter(Boolean);
      if (statuses.length === 1) {
        conditions.push('ret.status = ?');
        params.push(statuses[0]);
      } else {
        conditions.push(`ret.status IN (${statuses.map(() => '?').join(',')})`);
        params.push(...statuses);
      }
    }

    const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const [rows] = await db.query(
      `SELECT
          ret.retrieval_id,
          ret.retrieval_date,
          ret.retrieved_by,
          ret.reason,
          ret.status,
          ret.pdf_path,
          ret.created_at,
          CASE WHEN ret.client_signature IS NOT NULL THEN TRUE ELSE FALSE END AS has_client_sig,
          CASE WHEN ret.staff_signature  IS NOT NULL THEN TRUE ELSE FALSE END AS has_staff_sig,
          b.box_id, b.box_number, b.box_description, b.status AS box_status,
          c.client_id, c.client_name, c.client_code,
          u.username AS created_by_username
       FROM retrievals ret
       LEFT JOIN boxes   b ON ret.box_id    = b.box_id
       LEFT JOIN clients c ON ret.client_id = c.client_id
       LEFT JOIN users   u ON ret.created_by = u.user_id
       ${whereClause}
       ORDER BY ret.retrieval_date DESC, ret.created_at DESC`,
      params
    );

    const formatted = rows.map((r) => ({
      retrievalId:      r.retrieval_id,
      retrievalDate:    r.retrieval_date,
      retrievedBy:      r.retrieved_by,
      reason:           r.reason,
      status:           r.status,
      pdfPath:          r.pdf_path,
      createdAt:        r.created_at,
      createdBy:        r.created_by_username,
      signatures: {
        clientSigned: Boolean(r.has_client_sig),
        staffSigned:  Boolean(r.has_staff_sig),
      },
      box: {
        boxId:          r.box_id,
        boxNumber:      r.box_number,
        boxDescription: r.box_description,
        currentStatus:  r.box_status,
      },
      client: { clientId: r.client_id, clientName: r.client_name, clientCode: r.client_code },
    }));

    let summary = null;
    if (includeStats === 'true') {
      const statusCounts = rows.reduce((acc, r) => {
        acc[r.status] = (acc[r.status] || 0) + 1;
        return acc;
      }, {});
      summary = {
        totalRetrievals:  rows.length,
        uniqueClients:    new Set(rows.map((r) => r.client_id)).size,
        uniqueBoxes:      new Set(rows.map((r) => r.box_id)).size,
        statusCounts: {
          pending:   statusCounts.pending   || 0,
          completed: statusCounts.completed || 0,
          retrieved: statusCounts.retrieved || 0,
        },
      };
    }

    res.status(200).json({
      status:      'success',
      generatedAt: new Date().toISOString(),
      filters:     req.query,
      data:        { retrievals: formatted, summary },
    });
  } catch (err) {
    next(err);
  }
});

// ============================================
// DELIVERIES REPORT
// ============================================

/**
 * @route   GET /api/reports/deliveries
 * @desc    Report on item deliveries per client.
 * @access  Admin, Staff (canViewReports)
 * @query   clientId
 * @query   dateFrom / dateTo - delivery_date range
 * @query   itemName  - Partial match on item_name
 * @query   includeStats
 */
router.get('/deliveries', async (req, res, next) => {
  try {
    const { clientId, dateFrom, dateTo, itemName, includeStats = 'true' } = req.query;

    const conditions = [];
    const params = [];

    if (clientId) { conditions.push('d.client_id = ?');          params.push(clientId); }
    if (dateFrom) { conditions.push('d.delivery_date >= ?');      params.push(dateFrom); }
    if (dateTo)   { conditions.push('d.delivery_date <= ?');      params.push(dateTo); }
    if (itemName) {
      conditions.push('d.item_name LIKE ?');
      params.push(`%${itemName}%`);
    }

    const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const [rows] = await db.query(
      `SELECT
          d.delivery_id, d.item_name, d.quantity,
          d.delivery_date, d.receiver_name,
          d.acknowledgement_statement, d.pdf_path,
          d.created_at,
          CASE WHEN d.receiver_signature IS NOT NULL THEN TRUE ELSE FALSE END AS has_receiver_sig,
          c.client_id, c.client_name, c.client_code,
          u.username AS created_by_username
       FROM deliveries d
       LEFT JOIN clients c ON d.client_id  = c.client_id
       LEFT JOIN users   u ON d.created_by = u.user_id
       ${whereClause}
       ORDER BY d.delivery_date DESC, d.created_at DESC`,
      params
    );

    const formatted = rows.map((r) => ({
      deliveryId:              r.delivery_id,
      itemName:                r.item_name,
      quantity:                r.quantity,
      deliveryDate:            r.delivery_date,
      receiverName:            r.receiver_name,
      acknowledgementStatement: r.acknowledgement_statement,
      pdfPath:                 r.pdf_path,
      createdAt:               r.created_at,
      createdBy:               r.created_by_username,
      receiverSigned:          Boolean(r.has_receiver_sig),
      client: { clientId: r.client_id, clientName: r.client_name, clientCode: r.client_code },
    }));

    let summary = null;
    if (includeStats === 'true') {
      const totalQuantity = rows.reduce((acc, r) => acc + r.quantity, 0);
      summary = {
        totalDeliveries: rows.length,
        totalQuantity,
        uniqueClients:   new Set(rows.map((r) => r.client_id)).size,
      };
    }

    res.status(200).json({
      status:      'success',
      generatedAt: new Date().toISOString(),
      filters:     req.query,
      data:        { deliveries: formatted, summary },
    });
  } catch (err) {
    next(err);
  }
});

// ============================================
// CLIENT ACTIVITY REPORT
// ============================================

/**
 * @route   GET /api/reports/clients/:clientId/activity
 * @desc    Full activity summary for a single client — boxes, collections,
 *          retrievals, deliveries, and requests in one payload.
 * @access  Admin, Staff (canViewReports)
 */
router.get('/clients/:clientId/activity', async (req, res, next) => {
  try {
    const { clientId } = req.params;

    const [clientRows] = await db.query(
      'SELECT client_id, client_name, client_code, contact_person, email, phone FROM clients WHERE client_id = ?',
      [clientId]
    );
    if (!clientRows.length) throw new NotFoundError('Client not found');

    const client = clientRows[0];

    // Run all sub-queries in parallel
    const [[boxRows], [collectionRows], [retrievalRows], [deliveryRows], [requestRows]] =
      await Promise.all([
        db.query(
          `SELECT b.box_number, b.status, b.destruction_year,
                  b.box_size, b.date_received, r.label_code AS rack_label
           FROM boxes b
           LEFT JOIN racking_labels r ON b.racking_label_id = r.label_id
           WHERE b.client_id = ?
           ORDER BY b.created_at DESC`,
          [clientId]
        ),
        db.query(
          `SELECT collection_id, total_boxes, collection_date, dispatcher_name, collector_name
           FROM collections WHERE client_id = ? ORDER BY collection_date DESC`,
          [clientId]
        ),
        db.query(
          `SELECT ret.retrieval_id, ret.retrieval_date, ret.status, b.box_number
           FROM retrievals ret
           JOIN boxes b ON ret.box_id = b.box_id
           WHERE ret.client_id = ? ORDER BY ret.retrieval_date DESC`,
          [clientId]
        ),
        db.query(
          `SELECT delivery_id, item_name, quantity, delivery_date
           FROM deliveries WHERE client_id = ? ORDER BY delivery_date DESC`,
          [clientId]
        ),
        db.query(
          `SELECT request_id, request_type, status, requested_date, completed_date
           FROM requests WHERE client_id = ? ORDER BY requested_date DESC`,
          [clientId]
        ),
      ]);

    const currentYear = new Date().getFullYear();

    const boxSummary = {
      total:              boxRows.length,
      stored:             boxRows.filter((b) => b.status === 'stored').length,
      retrieved:          boxRows.filter((b) => b.status === 'retrieved').length,
      destroyed:          boxRows.filter((b) => b.status === 'destroyed').length,
      pendingDestruction: boxRows.filter(
        (b) => b.destruction_year && b.destruction_year <= currentYear && b.status === 'stored'
      ).length,
    };

    res.status(200).json({
      status:      'success',
      generatedAt: new Date().toISOString(),
      data: {
        client: {
          clientId:      client.client_id,
          clientName:    client.client_name,
          clientCode:    client.client_code,
          contactPerson: client.contact_person,
          email:         client.email,
          phone:         client.phone,
        },
        boxes:       { summary: boxSummary, records: boxRows },
        collections: { total: collectionRows.length, records: collectionRows },
        retrievals:  { total: retrievalRows.length,  records: retrievalRows },
        deliveries:  { total: deliveryRows.length,   records: deliveryRows },
        requests:    { total: requestRows.length,    records: requestRows },
      },
    });
  } catch (err) {
    next(err);
  }
});

// ============================================
// REQUESTS REPORT
// ============================================

/**
 * @route   GET /api/reports/requests
 * @desc    Report on client service requests.
 * @access  Admin, Staff (canViewReports)
 * @query   clientId
 * @query   requestType - retrieval | destruction | collection
 * @query   status      - pending | approved | completed | cancelled
 * @query   dateFrom / dateTo - requested_date range
 * @query   includeStats
 */
router.get('/requests', async (req, res, next) => {
  try {
    const { clientId, requestType, status, dateFrom, dateTo, includeStats = 'true' } = req.query;

    const conditions = [];
    const params = [];

    if (clientId)    { conditions.push('r.client_id = ?');       params.push(clientId); }
    if (requestType) { conditions.push('r.request_type = ?');    params.push(requestType); }
    if (status)      { conditions.push('r.status = ?');          params.push(status); }
    if (dateFrom)    { conditions.push('r.requested_date >= ?'); params.push(dateFrom); }
    if (dateTo)      { conditions.push('r.requested_date <= ?'); params.push(dateTo); }

    const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const [rows] = await db.query(
      `SELECT
          r.request_id, r.request_type, r.details,
          r.status, r.requested_date, r.completed_date, r.created_at,
          c.client_id, c.client_name, c.client_code,
          b.box_number
       FROM requests r
       LEFT JOIN clients c ON r.client_id = c.client_id
       LEFT JOIN boxes   b ON r.box_id    = b.box_id
       ${whereClause}
       ORDER BY r.requested_date DESC, r.created_at DESC`,
      params
    );

    const formatted = rows.map((r) => ({
      requestId:     r.request_id,
      requestType:   r.request_type,
      details:       r.details,
      status:        r.status,
      requestedDate: r.requested_date,
      completedDate: r.completed_date,
      createdAt:     r.created_at,
      boxNumber:     r.box_number || null,
      client: { clientId: r.client_id, clientName: r.client_name, clientCode: r.client_code },
    }));

    let summary = null;
    if (includeStats === 'true') {
      const statusCounts  = rows.reduce((acc, r) => { acc[r.status]      = (acc[r.status]      || 0) + 1; return acc; }, {});
      const typeCounts    = rows.reduce((acc, r) => { acc[r.request_type] = (acc[r.request_type] || 0) + 1; return acc; }, {});
      summary = {
        totalRequests:  rows.length,
        uniqueClients:  new Set(rows.map((r) => r.client_id)).size,
        byStatus:       statusCounts,
        byType:         typeCounts,
      };
    }

    res.status(200).json({
      status:      'success',
      generatedAt: new Date().toISOString(),
      filters:     req.query,
      data:        { requests: formatted, summary },
    });
  } catch (err) {
    next(err);
  }
});

// ============================================
// PENDING DESTRUCTION REPORT
// ============================================

/**
 * @route   GET /api/reports/boxes/pending-destruction
 * @desc    All stored boxes whose destruction year has passed.
 * @access  Admin, Staff (canViewReports)
 */
router.get('/boxes/pending-destruction', async (req, res, next) => {
  try {
    const { clientId } = req.query;
    const params = [];
    let extra = '';

    if (clientId) {
      extra = 'AND b.client_id = ?';
      params.push(clientId);
    }

    const [rows] = await db.query(
      `SELECT
          b.box_id, b.box_number, b.box_description,
          b.box_size, b.data_years, b.date_range,
          b.year_received, b.retention_years, b.destruction_year,
          (YEAR(CURDATE()) - b.destruction_year) AS years_overdue,
          c.client_id, c.client_name, c.client_code,
          r.label_code AS rack_label, r.location_description AS rack_location
       FROM boxes b
       LEFT JOIN clients c        ON b.client_id        = c.client_id
       LEFT JOIN racking_labels r ON b.racking_label_id = r.label_id
       WHERE b.destruction_year <= YEAR(CURDATE())
         AND b.status = 'stored'
         ${extra}
       ORDER BY b.destruction_year ASC, b.box_number ASC`,
      params
    );

    const formatted = rows.map((r) => ({
      boxId:           r.box_id,
      boxNumber:       r.box_number,
      description:     r.box_description,
      boxSize:         r.box_size || 'A3',
      dataYears:       r.data_years,
      dateRange:       r.date_range,
      yearReceived:    r.year_received,
      retentionYears:  r.retention_years,
      destructionYear: r.destruction_year,
      yearsOverdue:    r.years_overdue,
      rackLabel:       r.rack_label    || null,
      rackLocation:    r.rack_location || null,
      client: { clientId: r.client_id, clientName: r.client_name, clientCode: r.client_code },
    }));

    res.status(200).json({
      status:      'success',
      generatedAt: new Date().toISOString(),
      data:        { count: formatted.length, boxes: formatted },
    });
  } catch (err) {
    next(err);
  }
});

// ============================================
// STORAGE UTILISATION REPORT
// ============================================

/**
 * @route   GET /api/reports/storage/utilisation
 * @desc    Per-rack utilisation — total slots vs. occupied, grouped by rack label.
 * @access  Admin, Staff (canViewReports)
 */
router.get('/storage/utilisation', async (req, res, next) => {
  try {
    const [rows] = await db.query(
      `SELECT
          r.label_id, r.label_code, r.location_description, r.is_available,
          COUNT(b.box_id) AS boxes_stored
       FROM racking_labels r
       LEFT JOIN boxes b ON b.racking_label_id = r.label_id AND b.status = 'stored'
       GROUP BY r.label_id, r.label_code, r.location_description, r.is_available
       ORDER BY r.label_code`
    );

    const formatted = rows.map((r) => ({
      labelId:         r.label_id,
      labelCode:       r.label_code,
      location:        r.location_description,
      isAvailable:     Boolean(r.is_available),
      boxesStored:     r.boxes_stored,
    }));

    const totalRacks      = rows.length;
    const occupiedRacks   = rows.filter((r) => r.boxes_stored > 0).length;
    const availableRacks  = rows.filter((r) => r.is_available && r.boxes_stored === 0).length;

    res.status(200).json({
      status:      'success',
      generatedAt: new Date().toISOString(),
      data: {
        summary: { totalRacks, occupiedRacks, availableRacks },
        racks:   formatted,
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;