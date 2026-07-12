const express = require('express');
const { query, transaction } = require('../config/db');
const { authenticateToken, authorizeRoles, authorizePermission } = require('../middleware/Auth.middleware');
const logger = require('../utils/logger');
const { ValidationError, NotFoundError } = require('../middleware/Error.middleware');

const router = express.Router();

// ============================================
// DB MIGRATION (run once)
// ============================================
// ALTER TABLE retrievals
//   ADD COLUMN status ENUM('pending','completed','retrieved') NOT NULL DEFAULT 'pending';
//
// -- Back-fill existing rows:
// UPDATE retrievals SET status = 'completed'
//   WHERE client_signature IS NOT NULL AND client_signature != '';
// UPDATE retrievals SET status = 'pending'
//   WHERE client_signature IS NULL OR client_signature = '';

// ============================================
// MIDDLEWARE
// ============================================

router.use(authenticateToken);

// ============================================
// CONSTANTS
// ============================================

const VALID_STATUSES = ['pending', 'completed', 'retrieved'];

// ============================================
// HELPER FUNCTIONS
// ============================================

const createAuditLog = async (userId, action, entityType, entityId, oldValue, newValue, ipAddress, userAgent) => {
  try {
    await query(
      `INSERT INTO audit_logs (user_id, action, entity_type, entity_id, old_value, new_value, ip_address, user_agent)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        userId, action, entityType, entityId,
        oldValue ? JSON.stringify(oldValue) : null,
        newValue ? JSON.stringify(newValue) : null,
        ipAddress, userAgent
      ]
    );
  } catch (error) {
    logger.error('Failed to create audit log:', error);
  }
};

/**
 * Derives the logical status from the retrieval row.
 * Falls back to the stored `status` column value; this helper is used
 * when formatting rows that were fetched before the column existed.
 */
const deriveStatus = (row) => {
  if (row.status) return row.status;
  return row.client_signature ? 'completed' : 'pending';
};

// ============================================
// RETRIEVAL ROUTES
// ============================================

/**
 * @route   GET /api/retrievals
 * @desc    Get all retrievals with filtering and pagination
 * @access  Admin, Staff
 */
router.get('/',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const {
        clientId, boxId, status,
        startDate, endDate, search,
        page = 1, limit = 50,
        sortBy = 'retrieval_date', sortOrder = 'DESC'
      } = req.query;

      let sql = `
        SELECT ret.retrieval_id, ret.client_id, ret.box_id, ret.retrieval_date,
               ret.retrieved_by, ret.reason, ret.status,
               ret.client_signature, ret.staff_signature,
               ret.pdf_path, ret.created_at, ret.created_by,
               c.client_name, c.client_code, c.contact_person,
               b.box_number, b.box_description,
               u.username AS created_by_username
        FROM retrievals ret
        LEFT JOIN clients c ON ret.client_id = c.client_id
        LEFT JOIN boxes b   ON ret.box_id    = b.box_id
        LEFT JOIN users u   ON ret.created_by = u.user_id
        WHERE 1=1
      `;
      const params = [];

      if (clientId)  { sql += ' AND ret.client_id = ?';          params.push(clientId); }
      if (boxId)     { sql += ' AND ret.box_id = ?';             params.push(boxId); }
      if (status)    { sql += ' AND ret.status = ?';             params.push(status); }
      if (startDate) { sql += ' AND ret.retrieval_date >= ?';    params.push(startDate); }
      if (endDate)   { sql += ' AND ret.retrieval_date <= ?';    params.push(endDate); }
      if (search) {
        sql += ' AND (ret.retrieved_by LIKE ? OR ret.reason LIKE ? OR c.client_name LIKE ? OR b.box_number LIKE ?)';
        const p = `%${search}%`;
        params.push(p, p, p, p);
      }

      const countSql = sql.replace(/SELECT .+ FROM/, 'SELECT COUNT(*) AS total FROM');
      const [countResult] = await query(countSql, params);
      const total = countResult[0].total;

      const validSortFields = ['retrieval_date', 'created_at'];
      const sortField = validSortFields.includes(sortBy) ? sortBy : 'retrieval_date';
      const order     = sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';
      sql += ` ORDER BY ret.${sortField} ${order}`;

      const offset = (page - 1) * limit;
      sql += ' LIMIT ? OFFSET ?';
      params.push(parseInt(limit), offset);

      const [retrievals] = await query(sql, params);

      const formattedRetrievals = retrievals.map(ret => ({
        retrievalId:  ret.retrieval_id,
        retrievalNumber: `RET-${String(ret.retrieval_id).padStart(5, '0')}`,
        status:       deriveStatus(ret),
        client: {
          clientId:      ret.client_id,
          clientName:    ret.client_name,
          clientCode:    ret.client_code,
          contactPerson: ret.contact_person
        },
        box: {
          boxId:          ret.box_id,
          boxNumber:      ret.box_number,
          boxDescription: ret.box_description
        },
        retrievalDate:      ret.retrieval_date,
        retrievedBy:        ret.retrieved_by,
        reason:             ret.reason,
        hasClientSignature: !!(ret.client_signature),
        hasStaffSignature:  !!(ret.staff_signature),
        isComplete:         deriveStatus(ret) === 'completed' || deriveStatus(ret) === 'retrieved',
        clientSignature:    ret.client_signature,
        staffSignature:     ret.staff_signature,
        pdfPath:            ret.pdf_path,
        createdBy: {
          userId:   ret.created_by,
          username: ret.created_by_username
        },
        createdAt: ret.created_at
      }));

      res.status(200).json({
        status: 'success',
        data: {
          retrievals: formattedRetrievals,
          pagination: {
            page:       parseInt(page),
            limit:      parseInt(limit),
            total,
            totalPages: Math.ceil(total / limit)
          }
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/retrievals/stats
 * @desc    Get retrieval statistics
 * @access  Admin, Staff
 */
router.get('/stats',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const [stats] = await query(`
        SELECT 
          COUNT(*) AS total_retrievals,
          COUNT(CASE WHEN status = 'pending'   THEN 1 END) AS pending_retrievals,
          COUNT(CASE WHEN status = 'completed' THEN 1 END) AS completed_retrievals,
          COUNT(CASE WHEN status = 'retrieved' THEN 1 END) AS retrieved_retrievals,
          COUNT(DISTINCT client_id) AS clients_with_retrievals,
          COUNT(DISTINCT box_id)    AS unique_boxes_retrieved,
          COUNT(CASE WHEN DATE(retrieval_date) = CURDATE() THEN 1 END) AS today_retrievals,
          COUNT(CASE WHEN DATE(retrieval_date) >= DATE_SUB(CURDATE(), INTERVAL 7  DAY) THEN 1 END) AS this_week_retrievals,
          COUNT(CASE WHEN DATE(retrieval_date) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) AS this_month_retrievals
        FROM retrievals
      `);

      res.status(200).json({ status: 'success', data: stats[0] });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/retrievals/recent
 * @desc    Get recent retrievals
 * @access  Admin, Staff
 */
router.get('/recent',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { limit = 10 } = req.query;

      const [retrievals] = await query(`
        SELECT ret.retrieval_id, ret.retrieval_date, ret.retrieved_by,
               ret.status, ret.client_signature, ret.staff_signature, ret.reason,
               c.client_name, c.client_code,
               b.box_number, b.box_description,
               u.username AS created_by_username
        FROM retrievals ret
        LEFT JOIN clients c ON ret.client_id = c.client_id
        LEFT JOIN boxes b   ON ret.box_id    = b.box_id
        LEFT JOIN users u   ON ret.created_by = u.user_id
        ORDER BY ret.created_at DESC
        LIMIT ?
      `, [parseInt(limit)]);

      const formattedRetrievals = retrievals.map(ret => ({
        retrievalId:        ret.retrieval_id,
        retrievalNumber:    `RET-${String(ret.retrieval_id).padStart(5, '0')}`,
        status:             deriveStatus(ret),
        clientName:         ret.client_name,
        clientCode:         ret.client_code,
        boxNumber:          ret.box_number,
        boxDescription:     ret.box_description,
        retrievalDate:      ret.retrieval_date,
        retrievedBy:        ret.retrieved_by,
        reason:             ret.reason,
        // Signature fields — required so Flutter can show the correct
        // signature chips and step indicators on the Recent tab.
        hasClientSignature: !!(ret.client_signature),
        hasStaffSignature:  !!(ret.staff_signature),
        clientSignature:    ret.client_signature,
        staffSignature:     ret.staff_signature,
        createdBy:          ret.created_by_username
      }));

      res.status(200).json({ status: 'success', data: formattedRetrievals });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/retrievals/pending
 * @desc    Get retrievals pending client signature
 * @access  Admin, Staff
 */
router.get('/pending',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { clientId, limit = 50 } = req.query;

      let sql = `
        SELECT ret.retrieval_id, ret.client_id, ret.box_id, ret.retrieval_date,
               ret.retrieved_by, ret.reason, ret.staff_signature, ret.status, ret.created_at,
               c.client_name, c.client_code, c.contact_person,
               b.box_number, b.box_description,
               u.username AS created_by_username
        FROM retrievals ret
        LEFT JOIN clients c ON ret.client_id = c.client_id
        LEFT JOIN boxes b   ON ret.box_id    = b.box_id
        LEFT JOIN users u   ON ret.created_by = u.user_id
        WHERE ret.status = 'pending'
      `;
      const params = [];

      if (clientId) {
        sql += ' AND ret.client_id = ?';
        params.push(clientId);
      }

      sql += ' ORDER BY ret.created_at DESC LIMIT ?';
      params.push(parseInt(limit));

      const [retrievals] = await query(sql, params);

      const formattedRetrievals = retrievals.map(ret => ({
        retrievalId:     ret.retrieval_id,
        retrievalNumber: `RET-${String(ret.retrieval_id).padStart(5, '0')}`,
        status:          deriveStatus(ret),
        client: {
          clientId:      ret.client_id,
          clientName:    ret.client_name,
          clientCode:    ret.client_code,
          contactPerson: ret.contact_person
        },
        box: {
          boxId:          ret.box_id,
          boxNumber:      ret.box_number,
          boxDescription: ret.box_description
        },
        retrievalDate:         ret.retrieval_date,
        retrievedBy:           ret.retrieved_by,
        reason:                ret.reason,
        hasStaffSignature:     !!(ret.staff_signature),
        awaitingClientSignature: true,
        createdBy:             ret.created_by_username,
        createdAt:             ret.created_at
      }));

      res.status(200).json({
        status: 'success',
        data: { retrievals: formattedRetrievals, total: retrievals.length }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/retrievals/pending/my
 * @desc    Get pending retrievals for the logged-in client
 * @access  Client
 */
router.get('/pending/my',
  authorizeRoles('client'),
  async (req, res, next) => {
    try {
      const clientId = req.user.clientId;
      if (!clientId) throw new ValidationError('Client ID not found in user profile');

      const [retrievals] = await query(`
        SELECT ret.retrieval_id, ret.box_id, ret.retrieval_date,
               ret.retrieved_by, ret.reason, ret.staff_signature, ret.status, ret.created_at,
               b.box_number, b.box_description,
               u.username AS created_by_username
        FROM retrievals ret
        LEFT JOIN boxes b ON ret.box_id    = b.box_id
        LEFT JOIN users u ON ret.created_by = u.user_id
        WHERE ret.client_id = ? AND ret.status = 'pending'
        ORDER BY ret.created_at DESC
      `, [clientId]);

      const formattedRetrievals = retrievals.map(ret => ({
        retrievalId:     ret.retrieval_id,
        retrievalNumber: `RET-${String(ret.retrieval_id).padStart(5, '0')}`,
        status:          deriveStatus(ret),
        box: {
          boxId:          ret.box_id,
          boxNumber:      ret.box_number,
          boxDescription: ret.box_description
        },
        retrievalDate:           ret.retrieval_date,
        retrievedBy:             ret.retrieved_by,
        reason:                  ret.reason,
        hasStaffSignature:       !!(ret.staff_signature),
        awaitingClientSignature: true,
        createdBy:               ret.created_by_username,
        createdAt:               ret.created_at
      }));

      res.status(200).json({
        status: 'success',
        message: retrievals.length > 0
          ? `You have ${retrievals.length} retrieval(s) awaiting your signature`
          : 'No pending retrievals',
        data: { retrievals: formattedRetrievals, total: retrievals.length }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/retrievals/client/:clientId
 * @desc    Get all retrievals for a specific client
 * @access  Admin, Staff, Client (own only)
 */
router.get('/client/:clientId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { clientId } = req.params;

      if (req.user.role === 'client' && req.user.clientId !== parseInt(clientId)) {
        throw new ValidationError('You can only access your own retrievals');
      }

      const [retrievals] = await query(`
        SELECT ret.retrieval_id, ret.box_id, ret.retrieval_date,
               ret.retrieved_by, ret.reason, ret.status,
               ret.client_signature, ret.staff_signature, ret.pdf_path, ret.created_at,
               b.box_number, b.box_description,
               u.username AS created_by_username
        FROM retrievals ret
        LEFT JOIN boxes b ON ret.box_id    = b.box_id
        LEFT JOIN users u ON ret.created_by = u.user_id
        WHERE ret.client_id = ?
        ORDER BY ret.retrieval_date DESC
      `, [clientId]);

      const formattedRetrievals = retrievals.map(ret => ({
        retrievalId:        ret.retrieval_id,
        retrievalNumber:    `RET-${String(ret.retrieval_id).padStart(5, '0')}`,
        status:             deriveStatus(ret),
        box: {
          boxId:          ret.box_id,
          boxNumber:      ret.box_number,
          boxDescription: ret.box_description
        },
        retrievalDate:      ret.retrieval_date,
        retrievedBy:        ret.retrieved_by,
        reason:             ret.reason,
        hasClientSignature: !!(ret.client_signature),
        hasStaffSignature:  !!(ret.staff_signature),
        isComplete:         deriveStatus(ret) !== 'pending',
        clientSignature:    ret.client_signature,
        staffSignature:     ret.staff_signature,
        pdfPath:            ret.pdf_path,
        createdBy:          ret.created_by_username,
        createdAt:          ret.created_at
      }));

      res.status(200).json({ status: 'success', data: formattedRetrievals });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/retrievals/box/:boxId
 * @desc    Get all retrievals for a specific box
 * @access  Admin, Staff
 */
router.get('/box/:boxId',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { boxId } = req.params;

      const [retrievals] = await query(`
        SELECT ret.retrieval_id, ret.retrieval_date, ret.retrieved_by,
               ret.reason, ret.status,
               ret.client_signature, ret.staff_signature, ret.pdf_path, ret.created_at,
               c.client_id, c.client_name, c.client_code,
               u.username AS created_by_username
        FROM retrievals ret
        LEFT JOIN clients c ON ret.client_id = c.client_id
        LEFT JOIN users u   ON ret.created_by = u.user_id
        WHERE ret.box_id = ?
        ORDER BY ret.retrieval_date DESC
      `, [boxId]);

      const formattedRetrievals = retrievals.map(ret => ({
        retrievalId:        ret.retrieval_id,
        retrievalNumber:    `RET-${String(ret.retrieval_id).padStart(5, '0')}`,
        status:             deriveStatus(ret),
        client: {
          clientId:   ret.client_id,
          clientName: ret.client_name,
          clientCode: ret.client_code
        },
        retrievalDate:      ret.retrieval_date,
        retrievedBy:        ret.retrieved_by,
        reason:             ret.reason,
        hasClientSignature: !!(ret.client_signature),
        hasStaffSignature:  !!(ret.staff_signature),
        isComplete:         deriveStatus(ret) !== 'pending',
        clientSignature:    ret.client_signature,
        staffSignature:     ret.staff_signature,
        pdfPath:            ret.pdf_path,
        createdBy:          ret.created_by_username,
        createdAt:          ret.created_at
      }));

      res.status(200).json({ status: 'success', data: formattedRetrievals });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/retrievals/:retrievalId
 * @desc    Get single retrieval by ID
 * @access  Admin, Staff, Client (own only)
 */
router.get('/:retrievalId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { retrievalId } = req.params;

      const [retrievals] = await query(`
        SELECT ret.retrieval_id, ret.client_id, ret.box_id, ret.retrieval_date,
               ret.retrieved_by, ret.reason, ret.status,
               ret.client_signature, ret.staff_signature, ret.pdf_path,
               ret.created_at, ret.created_by,
               c.client_name, c.client_code, c.contact_person, c.email,
               b.box_number, b.box_description,
               u.username AS created_by_username
        FROM retrievals ret
        LEFT JOIN clients c ON ret.client_id = c.client_id
        LEFT JOIN boxes b   ON ret.box_id    = b.box_id
        LEFT JOIN users u   ON ret.created_by = u.user_id
        WHERE ret.retrieval_id = ?
      `, [retrievalId]);

      if (retrievals.length === 0) throw new NotFoundError('Retrieval not found');

      const ret = retrievals[0];

      if (req.user.role === 'client' && req.user.clientId !== ret.client_id) {
        throw new ValidationError('You can only access your own retrievals');
      }

      const formattedRetrieval = {
        retrievalId:     ret.retrieval_id,
        retrievalNumber: `RET-${String(ret.retrieval_id).padStart(5, '0')}`,
        status:          deriveStatus(ret),
        client: {
          clientId:      ret.client_id,
          clientName:    ret.client_name,
          clientCode:    ret.client_code,
          contactPerson: ret.contact_person,
          email:         ret.email
        },
        box: {
          boxId:          ret.box_id,
          boxNumber:      ret.box_number,
          boxDescription: ret.box_description
        },
        retrievalDate:      ret.retrieval_date,
        retrievedBy:        ret.retrieved_by,
        reason:             ret.reason,
        hasClientSignature: !!(ret.client_signature),
        hasStaffSignature:  !!(ret.staff_signature),
        isComplete:         deriveStatus(ret) !== 'pending',
        clientSignature:    ret.client_signature,
        staffSignature:     ret.staff_signature,
        pdfPath:            ret.pdf_path,
        createdBy: {
          userId:   ret.created_by,
          username: ret.created_by_username
        },
        createdAt: ret.created_at
      };

      res.status(200).json({ status: 'success', data: formattedRetrieval });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   POST /api/retrievals
 * @desc    Create new retrieval — status starts as 'pending'
 * @access  Admin, Staff (with permission)
 */
router.post('/',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canCreateRetrievals'),
  async (req, res, next) => {
    try {
      const { clientId, boxId, retrievalDate, retrievedBy, reason, staffSignature } = req.body;

      if (!clientId || !boxId || !retrievalDate) {
        throw new ValidationError('Client ID, Box ID, and Retrieval Date are required');
      }

      const [clients] = await query('SELECT client_id FROM clients WHERE client_id = ?', [clientId]);
      if (clients.length === 0) throw new NotFoundError('Client not found');

      const [boxes] = await query(
        'SELECT box_id, box_number, client_id, status FROM boxes WHERE box_id = ?', [boxId]
      );
      if (boxes.length === 0) throw new NotFoundError('Box not found');
      if (boxes[0].client_id !== parseInt(clientId)) throw new ValidationError('Box does not belong to this client');
      if (boxes[0].status === 'retrieved') throw new ValidationError('Box has already been retrieved');
      if (boxes[0].status === 'destroyed') throw new ValidationError('Box has been destroyed and cannot be retrieved');

      const [result] = await query(`
        INSERT INTO retrievals
          (client_id, box_id, retrieval_date, retrieved_by, reason,
           client_signature, staff_signature, status, created_by)
        VALUES (?, ?, ?, ?, ?, NULL, ?, 'pending', ?)
      `, [
        clientId, boxId, retrievalDate,
        retrievedBy || null,
        reason      || null,
        staffSignature || null,
        req.user.userId
      ]);

      const retrievalId = result.insertId;

      await createAuditLog(
        req.user.userId, 'CREATE_RETRIEVAL', 'retrieval', retrievalId,
        null,
        { clientId, boxId, retrievalDate, boxNumber: boxes[0].box_number, status: 'pending' },
        req.ip, req.get('user-agent')
      );

      logger.info(`Retrieval created: ${retrievalId} for box ${boxes[0].box_number} by ${req.user.username}`);

      res.status(201).json({
        status: 'success',
        message: 'Retrieval created successfully. Awaiting client signature to complete.',
        data: {
          retrievalId,
          retrievalNumber: `RET-${String(retrievalId).padStart(5, '0')}`,
          boxId:    boxes[0].box_id,
          boxNumber: boxes[0].box_number,
          status:   'pending',
          requiresClientSignature: true
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/retrievals/:retrievalId/status
 * @desc    Manually update retrieval status (admin/staff override)
 *          Valid values: 'pending' | 'completed' | 'retrieved'
 *          When set to 'completed' or 'retrieved' the linked box is also
 *          marked as 'retrieved' (unless it already is).
 * @access  Admin, Staff
 */
router.patch('/:retrievalId/status',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { retrievalId } = req.params;
      const { status }      = req.body;

      // Validate
      if (!status) throw new ValidationError('status is required');
      if (!VALID_STATUSES.includes(status)) {
        throw new ValidationError(`Invalid status. Must be one of: ${VALID_STATUSES.join(', ')}`);
      }

      const result = await transaction(async (connection) => {
        // Fetch current retrieval
        const [rows] = await connection.execute(`
          SELECT ret.retrieval_id, ret.status AS current_status, ret.box_id,
                 b.box_number, b.status AS box_status
          FROM retrievals ret
          LEFT JOIN boxes b ON ret.box_id = b.box_id
          WHERE ret.retrieval_id = ?
        `, [retrievalId]);

        if (rows.length === 0) throw new NotFoundError('Retrieval not found');

        const { current_status, box_id, box_number, box_status } = rows[0];

        if (current_status === status) {
          throw new ValidationError(`Retrieval is already set to '${status}'`);
        }

        // Update retrieval status
        await connection.execute(
          'UPDATE retrievals SET status = ? WHERE retrieval_id = ?',
          [status, retrievalId]
        );

        // When marking completed/retrieved, also flip the box to 'retrieved'
        // so the warehouse inventory stays accurate.
        let boxUpdated = false;
        if ((status === 'completed' || status === 'retrieved') && box_status !== 'retrieved') {
          await connection.execute(
            'UPDATE boxes SET status = ? WHERE box_id = ?',
            ['retrieved', box_id]
          );
          boxUpdated = true;

          await createAuditLog(
            req.user.userId, 'BOX_STATUS_CHANGE_ON_STATUS_UPDATE', 'box', box_id,
            { status: box_status },
            { status: 'retrieved', triggeredBy: 'manual_status_update', retrievalId },
            req.ip, req.get('user-agent')
          );

          logger.info(`Box ${box_number} marked as retrieved via manual status update on retrieval ${retrievalId}`);
        }

        // When rolling back to pending, flip the box back to 'stored'
        // so staff can process the retrieval properly again.
        if (status === 'pending' && box_status === 'retrieved') {
          await connection.execute(
            'UPDATE boxes SET status = ? WHERE box_id = ?',
            ['stored', box_id]
          );
          boxUpdated = true;

          await createAuditLog(
            req.user.userId, 'BOX_STATUS_CHANGE_ON_STATUS_ROLLBACK', 'box', box_id,
            { status: box_status },
            { status: 'stored', triggeredBy: 'status_rollback_to_pending', retrievalId },
            req.ip, req.get('user-agent')
          );

          logger.info(`Box ${box_number} rolled back to stored via status rollback on retrieval ${retrievalId}`);
        }

        await createAuditLog(
          req.user.userId, 'UPDATE_RETRIEVAL_STATUS', 'retrieval', retrievalId,
          { status: current_status },
          { status, boxUpdated },
          req.ip, req.get('user-agent')
        );

        return { previousStatus: current_status, box_id, box_number, boxUpdated };
      });

      logger.info(`Retrieval ${retrievalId} status changed: ${result.previousStatus} → ${status} by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: `Retrieval status updated to '${status}' successfully`,
        data: {
          retrievalId:    parseInt(retrievalId),
          retrievalNumber:`RET-${String(retrievalId).padStart(5, '0')}`,
          previousStatus: result.previousStatus,
          newStatus:      status,
          boxId:          result.box_id,
          boxNumber:      result.box_number,
          boxUpdated:     result.boxUpdated
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/retrievals/:retrievalId/signatures
 * @desc    Update signatures — adding a client signature automatically sets
 *          status to 'completed' and marks the box as 'retrieved'.
 * @access  Admin, Staff, Client (client signature only)
 */
router.patch('/:retrievalId/signatures',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { retrievalId } = req.params;
      const { clientSignature, staffSignature } = req.body;

      const result = await transaction(async (connection) => {
        const [rows] = await connection.execute(`
          SELECT ret.retrieval_id, ret.client_id, ret.box_id,
                 ret.client_signature, ret.staff_signature, ret.status,
                 b.box_number, b.status AS box_status
          FROM retrievals ret
          LEFT JOIN boxes b ON ret.box_id = b.box_id
          WHERE ret.retrieval_id = ?
        `, [retrievalId]);

        if (rows.length === 0) throw new NotFoundError('Retrieval not found');
        const retrieval = rows[0];

        // Client role restrictions
        if (req.user.role === 'client') {
          if (req.user.clientId !== retrieval.client_id) {
            throw new ValidationError('You can only sign your own retrievals');
          }
          if (staffSignature !== undefined) {
            throw new ValidationError('Clients can only provide client signature');
          }
          if (!clientSignature) {
            throw new ValidationError('Client signature is required');
          }
        }

        const updates  = [];
        const params   = [];
        let isClientSigning = false;

        if (clientSignature !== undefined) {
          updates.push('client_signature = ?');
          params.push(clientSignature);
          isClientSigning = true;
        }

        if (staffSignature !== undefined) {
          if (req.user.role === 'client') throw new ValidationError('Only staff can provide staff signature');
          updates.push('staff_signature = ?');
          params.push(staffSignature);
        }

        if (updates.length === 0) throw new ValidationError('At least one signature must be provided');

        // Auto-set status to 'completed' when client signs
        let newStatus = retrieval.status;
        if (isClientSigning && clientSignature) {
          updates.push('status = ?');
          params.push('completed');
          newStatus = 'completed';
        }

        params.push(retrievalId);
        await connection.execute(
          `UPDATE retrievals SET ${updates.join(', ')} WHERE retrieval_id = ?`,
          params
        );

        // Flip box to 'retrieved' when client signs (if still stored)
        let boxStatusChanged = false;
        let newBoxStatus     = retrieval.box_status;

        if (isClientSigning && clientSignature && retrieval.box_status === 'stored') {
          await connection.execute(
            'UPDATE boxes SET status = ? WHERE box_id = ?',
            ['retrieved', retrieval.box_id]
          );
          boxStatusChanged = true;
          newBoxStatus     = 'retrieved';

          await createAuditLog(
            req.user.userId, 'BOX_STATUS_CHANGE_ON_RETRIEVAL', 'box', retrieval.box_id,
            { status: 'stored' },
            { status: 'retrieved', triggeredBy: 'client_signature', retrievalId },
            req.ip, req.get('user-agent')
          );

          logger.info(`Box ${retrieval.box_number} marked as retrieved via client signature on retrieval ${retrievalId}`);
        }

        await createAuditLog(
          req.user.userId, 'UPDATE_RETRIEVAL_SIGNATURES', 'retrieval', retrievalId,
          { hadClientSignature: !!(retrieval.client_signature), hadStaffSignature: !!(retrieval.staff_signature) },
          { hasClientSignature: !!(clientSignature || retrieval.client_signature), hasStaffSignature: !!(staffSignature || retrieval.staff_signature), newStatus, boxStatusChanged, newBoxStatus },
          req.ip, req.get('user-agent')
        );

        return { retrieval, isClientSigning, newStatus, boxStatusChanged, newBoxStatus };
      });

      const message = result.boxStatusChanged
        ? 'Signatures updated. Retrieval completed and box marked as retrieved.'
        : 'Signatures updated successfully';

      logger.info(`Retrieval ${retrievalId} signatures updated by ${req.user.username}${result.boxStatusChanged ? ' — box marked retrieved' : ''}`);

      res.status(200).json({
        status: 'success',
        message,
        data: {
          retrievalId:        parseInt(retrievalId),
          retrievalNumber:    `RET-${String(retrievalId).padStart(5, '0')}`,
          newStatus:          result.newStatus,
          boxId:              result.retrieval.box_id,
          boxNumber:          result.retrieval.box_number,
          retrievalCompleted: result.isClientSigning,
          boxStatusChanged:   result.boxStatusChanged,
          boxStatus:          result.newBoxStatus
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/retrievals/:retrievalId/pdf
 * @desc    Update retrieval PDF path
 * @access  Admin, Staff
 */
router.patch('/:retrievalId/pdf',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { retrievalId } = req.params;
      const { pdfPath }     = req.body;

      if (!pdfPath) throw new ValidationError('PDF path is required');

      const [rows] = await query('SELECT retrieval_id FROM retrievals WHERE retrieval_id = ?', [retrievalId]);
      if (rows.length === 0) throw new NotFoundError('Retrieval not found');

      await query('UPDATE retrievals SET pdf_path = ? WHERE retrieval_id = ?', [pdfPath, retrievalId]);

      await createAuditLog(
        req.user.userId, 'UPDATE_RETRIEVAL_PDF', 'retrieval', retrievalId,
        null, { pdfPath }, req.ip, req.get('user-agent')
      );

      logger.info(`Retrieval PDF updated: ${retrievalId} by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: 'PDF path updated successfully',
        data: { pdfPath }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/retrievals/box/:boxId/mark-retrieved
 * @desc    Manually mark a box as retrieved (admin override)
 * @access  Admin, Staff
 */
router.patch('/box/:boxId/mark-retrieved',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { boxId } = req.params;

      const [boxes] = await query(
        'SELECT box_id, box_number, status FROM boxes WHERE box_id = ?', [boxId]
      );
      if (boxes.length === 0) throw new NotFoundError('Box not found');

      const box       = boxes[0];
      const oldStatus = box.status;

      if (oldStatus === 'retrieved') throw new ValidationError('Box is already marked as retrieved');

      await query('UPDATE boxes SET status = ? WHERE box_id = ?', ['retrieved', boxId]);

      await createAuditLog(
        req.user.userId, 'MANUAL_MARK_BOX_RETRIEVED', 'box', boxId,
        { status: oldStatus },
        { status: 'retrieved', note: 'Manual override' },
        req.ip, req.get('user-agent')
      );

      logger.info(`Box ${box.box_number} manually marked as retrieved by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: 'Box manually marked as retrieved successfully',
        data: {
          boxId:    box.box_id,
          boxNumber: box.box_number,
          oldStatus,
          newStatus: 'retrieved',
          note: 'Manual override — normally done via client signature on retrieval'
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   DELETE /api/retrievals/:retrievalId
 * @desc    Delete retrieval
 * @access  Admin only
 */
router.delete('/:retrievalId',
  authorizeRoles('admin'),
  async (req, res, next) => {
    try {
      const { retrievalId } = req.params;

      const [rows] = await query('SELECT retrieval_id FROM retrievals WHERE retrieval_id = ?', [retrievalId]);
      if (rows.length === 0) throw new NotFoundError('Retrieval not found');

      await query('DELETE FROM retrievals WHERE retrieval_id = ?', [retrievalId]);

      await createAuditLog(
        req.user.userId, 'DELETE_RETRIEVAL', 'retrieval', retrievalId,
        null, null, req.ip, req.get('user-agent')
      );

      logger.info(`Retrieval deleted: ${retrievalId} by ${req.user.username}`);

      res.status(200).json({ status: 'success', message: 'Retrieval deleted successfully' });

    } catch (error) {
      next(error);
    }
  }
);

// ============================================
// REPORTING ROUTES
// ============================================

/**
 * @route   GET /api/retrievals/reports/summary
 * @desc    Get retrievals summary by date range
 * @access  Admin, Staff
 */
router.get('/reports/summary',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { startDate, endDate, clientId } = req.query;

      let sql = `
        SELECT 
          DATE(retrieval_date)                                         AS date,
          COUNT(*)                                                     AS retrieval_count,
          COUNT(CASE WHEN status = 'completed' THEN 1 END)            AS completed_count,
          COUNT(CASE WHEN status = 'pending'   THEN 1 END)            AS pending_count,
          COUNT(DISTINCT client_id)                                    AS unique_clients,
          COUNT(DISTINCT box_id)                                       AS unique_boxes
        FROM retrievals
        WHERE 1=1
      `;
      const params = [];

      if (startDate) { sql += ' AND retrieval_date >= ?'; params.push(startDate); }
      if (endDate)   { sql += ' AND retrieval_date <= ?'; params.push(endDate); }
      if (clientId)  { sql += ' AND client_id = ?';       params.push(clientId); }

      sql += ' GROUP BY DATE(retrieval_date) ORDER BY date DESC';

      const [summary] = await query(sql, params);
      res.status(200).json({ status: 'success', data: summary });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/retrievals/reports/by-client
 * @desc    Get retrievals grouped by client
 * @access  Admin, Staff
 */
router.get('/reports/by-client',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { startDate, endDate } = req.query;

      let sql = `
        SELECT 
          c.client_id, c.client_name, c.client_code,
          COUNT(ret.retrieval_id)                             AS retrieval_count,
          COUNT(CASE WHEN ret.status = 'completed' THEN 1 END) AS completed_count,
          COUNT(CASE WHEN ret.status = 'pending'   THEN 1 END) AS pending_count,
          COUNT(DISTINCT ret.box_id)                          AS boxes_retrieved,
          MAX(ret.retrieval_date)                             AS last_retrieval_date
        FROM clients c
        LEFT JOIN retrievals ret ON c.client_id = ret.client_id
        WHERE 1=1
      `;
      const params = [];

      if (startDate) { sql += ' AND ret.retrieval_date >= ?'; params.push(startDate); }
      if (endDate)   { sql += ' AND ret.retrieval_date <= ?'; params.push(endDate); }

      sql += ' GROUP BY c.client_id, c.client_name, c.client_code ORDER BY retrieval_count DESC';

      const [report] = await query(sql, params);
      res.status(200).json({ status: 'success', data: report });

    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;