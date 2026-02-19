const express = require('express');
const { query, transaction } = require('../config/db');
const { authenticateToken, authorizeRoles, authorizePermission } = require('../middleware/Auth.middleware');
const logger = require('../utils/logger');
const { ValidationError, NotFoundError } = require('../middleware/Error.middleware');

const router = express.Router();

// ============================================
// MIDDLEWARE - All routes require authentication
// ============================================

router.use(authenticateToken);

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Create audit log entry
 */
const createAuditLog = async (userId, action, entityType, entityId, oldValue, newValue, ipAddress, userAgent) => {
  try {
    const sql = `
      INSERT INTO audit_logs (user_id, action, entity_type, entity_id, old_value, new_value, ip_address, user_agent)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `;
    await query(sql, [
      userId,
      action,
      entityType,
      entityId,
      oldValue ? JSON.stringify(oldValue) : null,
      newValue ? JSON.stringify(newValue) : null,
      ipAddress,
      userAgent
    ]);
  } catch (error) {
    logger.error('Failed to create audit log:', error);
  }
};

/**
 * Check if retrieval is complete (has client signature)
 */
const isRetrievalComplete = (clientSignature) => {
  return clientSignature !== null && clientSignature !== undefined && clientSignature !== '';
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
        clientId,
        boxId,
        startDate,
        endDate,
        search,
        page = 1,
        limit = 50,
        sortBy = 'retrieval_date',
        sortOrder = 'DESC'
      } = req.query;

      let sql = `
        SELECT ret.retrieval_id, ret.client_id, ret.box_id, ret.retrieval_date,
               ret.retrieved_by, ret.reason, ret.client_signature, ret.staff_signature,
               ret.pdf_path, ret.created_at, ret.created_by,
               c.client_name, c.client_code, c.contact_person,
               b.box_number, b.box_description,
               u.username as created_by_username
        FROM retrievals ret
        LEFT JOIN clients c ON ret.client_id = c.client_id
        LEFT JOIN boxes b ON ret.box_id = b.box_id
        LEFT JOIN users u ON ret.created_by = u.user_id
        WHERE 1=1
      `;

      const params = [];

      // Apply filters
      if (clientId) {
        sql += ' AND ret.client_id = ?';
        params.push(clientId);
      }

      if (boxId) {
        sql += ' AND ret.box_id = ?';
        params.push(boxId);
      }

      if (startDate) {
        sql += ' AND ret.retrieval_date >= ?';
        params.push(startDate);
      }

      if (endDate) {
        sql += ' AND ret.retrieval_date <= ?';
        params.push(endDate);
      }

      if (search) {
        sql += ' AND (ret.retrieved_by LIKE ? OR ret.reason LIKE ? OR c.client_name LIKE ? OR b.box_number LIKE ?)';
        const searchPattern = `%${search}%`;
        params.push(searchPattern, searchPattern, searchPattern, searchPattern);
      }

      // Count total
      const countSql = sql.replace(/SELECT .+ FROM/, 'SELECT COUNT(*) as total FROM');
      const [countResult] = await query(countSql, params);
      const total = countResult[0].total;

      // Add sorting
      const validSortFields = ['retrieval_date', 'created_at'];
      const sortField = validSortFields.includes(sortBy) ? sortBy : 'retrieval_date';
      const order = sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';
      sql += ` ORDER BY ret.${sortField} ${order}`;

      // Add pagination
      const offset = (page - 1) * limit;
      sql += ' LIMIT ? OFFSET ?';
      params.push(parseInt(limit), offset);

      const [retrievals] = await query(sql, params);

      const formattedRetrievals = retrievals.map(ret => ({
        retrievalId: ret.retrieval_id,
        client: {
          clientId: ret.client_id,
          clientName: ret.client_name,
          clientCode: ret.client_code,
          contactPerson: ret.contact_person
        },
        box: {
          boxId: ret.box_id,
          boxNumber: ret.box_number,
          boxDescription: ret.box_description
        },
        retrievalDate: ret.retrieval_date,
        retrievedBy: ret.retrieved_by,
        reason: ret.reason,
        hasClientSignature: isRetrievalComplete(ret.client_signature),
        hasStaffSignature: !!ret.staff_signature,
        isComplete: isRetrievalComplete(ret.client_signature),
        clientSignature: ret.client_signature,
        staffSignature: ret.staff_signature,
        pdfPath: ret.pdf_path,
        createdBy: {
          userId: ret.created_by,
          username: ret.created_by_username
        },
        createdAt: ret.created_at
      }));

      res.status(200).json({
        status: 'success',
        data: {
          retrievals: formattedRetrievals,
          pagination: {
            page: parseInt(page),
            limit: parseInt(limit),
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
          COUNT(*) as total_retrievals,
          COUNT(DISTINCT client_id) as clients_with_retrievals,
          COUNT(DISTINCT box_id) as unique_boxes_retrieved,
          COUNT(CASE WHEN DATE(retrieval_date) = CURDATE() THEN 1 END) as today_retrievals,
          COUNT(CASE WHEN DATE(retrieval_date) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) THEN 1 END) as this_week_retrievals,
          COUNT(CASE WHEN DATE(retrieval_date) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) as this_month_retrievals
        FROM retrievals
      `);

      res.status(200).json({
        status: 'success',
        data: stats[0]
      });

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
               c.client_name, c.client_code,
               b.box_number,
               u.username as created_by_username
        FROM retrievals ret
        LEFT JOIN clients c ON ret.client_id = c.client_id
        LEFT JOIN boxes b ON ret.box_id = b.box_id
        LEFT JOIN users u ON ret.created_by = u.user_id
        ORDER BY ret.created_at DESC
        LIMIT ?
      `, [parseInt(limit)]);

      const formattedRetrievals = retrievals.map(ret => ({
        retrievalId: ret.retrieval_id,
        clientName: ret.client_name,
        clientCode: ret.client_code,
        boxNumber: ret.box_number,
        retrievalDate: ret.retrieval_date,
        retrievedBy: ret.retrieved_by,
        createdBy: ret.created_by_username
      }));

      res.status(200).json({
        status: 'success',
        data: formattedRetrievals
      });

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
               ret.retrieved_by, ret.reason, ret.staff_signature, ret.created_at,
               c.client_name, c.client_code, c.contact_person,
               b.box_number, b.box_description,
               u.username as created_by_username
        FROM retrievals ret
        LEFT JOIN clients c ON ret.client_id = c.client_id
        LEFT JOIN boxes b ON ret.box_id = b.box_id
        LEFT JOIN users u ON ret.created_by = u.user_id
        WHERE ret.client_signature IS NULL
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
        retrievalId: ret.retrieval_id,
        client: {
          clientId: ret.client_id,
          clientName: ret.client_name,
          clientCode: ret.client_code,
          contactPerson: ret.contact_person
        },
        box: {
          boxId: ret.box_id,
          boxNumber: ret.box_number,
          boxDescription: ret.box_description
        },
        retrievalDate: ret.retrieval_date,
        retrievedBy: ret.retrieved_by,
        reason: ret.reason,
        hasStaffSignature: !!ret.staff_signature,
        awaitingClientSignature: true,
        createdBy: ret.created_by_username,
        createdAt: ret.created_at
      }));

      res.status(200).json({
        status: 'success',
        data: {
          retrievals: formattedRetrievals,
          total: retrievals.length
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/retrievals/pending/my
 * @desc    Get my pending retrievals (for clients to see what needs signing)
 * @access  Client
 */
router.get('/pending/my',
  authorizeRoles('client'),
  async (req, res, next) => {
    try {
      const clientId = req.user.clientId;

      if (!clientId) {
        throw new ValidationError('Client ID not found in user profile');
      }

      const [retrievals] = await query(`
        SELECT ret.retrieval_id, ret.box_id, ret.retrieval_date,
               ret.retrieved_by, ret.reason, ret.staff_signature, ret.created_at,
               b.box_number, b.box_description,
               u.username as created_by_username
        FROM retrievals ret
        LEFT JOIN boxes b ON ret.box_id = b.box_id
        LEFT JOIN users u ON ret.created_by = u.user_id
        WHERE ret.client_id = ? AND ret.client_signature IS NULL
        ORDER BY ret.created_at DESC
      `, [clientId]);

      const formattedRetrievals = retrievals.map(ret => ({
        retrievalId: ret.retrieval_id,
        box: {
          boxId: ret.box_id,
          boxNumber: ret.box_number,
          boxDescription: ret.box_description
        },
        retrievalDate: ret.retrieval_date,
        retrievedBy: ret.retrieved_by,
        reason: ret.reason,
        hasStaffSignature: !!ret.staff_signature,
        awaitingClientSignature: true,
        createdBy: ret.created_by_username,
        createdAt: ret.created_at
      }));

      res.status(200).json({
        status: 'success',
        message: retrievals.length > 0 
          ? `You have ${retrievals.length} retrieval(s) awaiting your signature` 
          : 'No pending retrievals',
        data: {
          retrievals: formattedRetrievals,
          total: retrievals.length
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/retrievals/client/:clientId
 * @desc    Get all retrievals for a specific client
 * @access  Admin, Staff, Client (own retrievals only)
 */
router.get('/client/:clientId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { clientId } = req.params;

      // If user is client, ensure they can only access their own retrievals
      if (req.user.role === 'client' && req.user.clientId !== parseInt(clientId)) {
        throw new ValidationError('You can only access your own retrievals');
      }

      const [retrievals] = await query(`
        SELECT ret.retrieval_id, ret.box_id, ret.retrieval_date,
               ret.retrieved_by, ret.reason, ret.client_signature,
               ret.staff_signature, ret.pdf_path, ret.created_at,
               b.box_number, b.box_description,
               u.username as created_by_username
        FROM retrievals ret
        LEFT JOIN boxes b ON ret.box_id = b.box_id
        LEFT JOIN users u ON ret.created_by = u.user_id
        WHERE ret.client_id = ?
        ORDER BY ret.retrieval_date DESC
      `, [clientId]);

      const formattedRetrievals = retrievals.map(ret => ({
        retrievalId: ret.retrieval_id,
        box: {
          boxId: ret.box_id,
          boxNumber: ret.box_number,
          boxDescription: ret.box_description
        },
        retrievalDate: ret.retrieval_date,
        retrievedBy: ret.retrieved_by,
        reason: ret.reason,
        hasClientSignature: isRetrievalComplete(ret.client_signature),
        hasStaffSignature: !!ret.staff_signature,
        isComplete: isRetrievalComplete(ret.client_signature),
        clientSignature: ret.client_signature,
        staffSignature: ret.staff_signature,
        pdfPath: ret.pdf_path,
        createdBy: ret.created_by_username,
        createdAt: ret.created_at
      }));

      res.status(200).json({
        status: 'success',
        data: formattedRetrievals
      });

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
               ret.reason, ret.client_signature, ret.staff_signature,
               ret.pdf_path, ret.created_at,
               c.client_id, c.client_name, c.client_code,
               u.username as created_by_username
        FROM retrievals ret
        LEFT JOIN clients c ON ret.client_id = c.client_id
        LEFT JOIN users u ON ret.created_by = u.user_id
        WHERE ret.box_id = ?
        ORDER BY ret.retrieval_date DESC
      `, [boxId]);

      const formattedRetrievals = retrievals.map(ret => ({
        retrievalId: ret.retrieval_id,
        client: {
          clientId: ret.client_id,
          clientName: ret.client_name,
          clientCode: ret.client_code
        },
        retrievalDate: ret.retrieval_date,
        retrievedBy: ret.retrieved_by,
        reason: ret.reason,
        hasClientSignature: isRetrievalComplete(ret.client_signature),
        hasStaffSignature: !!ret.staff_signature,
        isComplete: isRetrievalComplete(ret.client_signature),
        clientSignature: ret.client_signature,
        staffSignature: ret.staff_signature,
        pdfPath: ret.pdf_path,
        createdBy: ret.created_by_username,
        createdAt: ret.created_at
      }));

      res.status(200).json({
        status: 'success',
        data: formattedRetrievals
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/retrievals/:retrievalId
 * @desc    Get single retrieval by ID
 * @access  Admin, Staff, Client (own retrieval only)
 */
router.get('/:retrievalId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { retrievalId } = req.params;

      const [retrievals] = await query(`
        SELECT ret.retrieval_id, ret.client_id, ret.box_id, ret.retrieval_date,
               ret.retrieved_by, ret.reason, ret.client_signature,
               ret.staff_signature, ret.pdf_path, ret.created_at, ret.created_by,
               c.client_name, c.client_code, c.contact_person, c.email,
               b.box_number, b.box_description,
               u.username as created_by_username
        FROM retrievals ret
        LEFT JOIN clients c ON ret.client_id = c.client_id
        LEFT JOIN boxes b ON ret.box_id = b.box_id
        LEFT JOIN users u ON ret.created_by = u.user_id
        WHERE ret.retrieval_id = ?
      `, [retrievalId]);

      if (retrievals.length === 0) {
        throw new NotFoundError('Retrieval not found');
      }

      const ret = retrievals[0];

      // If user is client, ensure they can only access their own retrieval
      if (req.user.role === 'client' && req.user.clientId !== ret.client_id) {
        throw new ValidationError('You can only access your own retrievals');
      }

      const formattedRetrieval = {
        retrievalId: ret.retrieval_id,
        client: {
          clientId: ret.client_id,
          clientName: ret.client_name,
          clientCode: ret.client_code,
          contactPerson: ret.contact_person,
          email: ret.email
        },
        box: {
          boxId: ret.box_id,
          boxNumber: ret.box_number,
          boxDescription: ret.box_description
        },
        retrievalDate: ret.retrieval_date,
        retrievedBy: ret.retrieved_by,
        reason: ret.reason,
        hasClientSignature: isRetrievalComplete(ret.client_signature),
        hasStaffSignature: !!ret.staff_signature,
        isComplete: isRetrievalComplete(ret.client_signature),
        clientSignature: ret.client_signature,
        staffSignature: ret.staff_signature,
        pdfPath: ret.pdf_path,
        createdBy: {
          userId: ret.created_by,
          username: ret.created_by_username
        },
        createdAt: ret.created_at
      };

      res.status(200).json({
        status: 'success',
        data: formattedRetrieval
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   POST /api/retrievals
 * @desc    Create new retrieval (box status remains 'stored' until client signs)
 * @access  Admin, Staff (with permission)
 */
router.post('/',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canCreateRetrievals'),
  async (req, res, next) => {
    try {
      const {
        clientId,
        boxId,
        retrievalDate,
        retrievedBy,
        reason,
        staffSignature
      } = req.body;

      // Validate required fields
      if (!clientId || !boxId || !retrievalDate) {
        throw new ValidationError('Client ID, Box ID, and Retrieval Date are required');
      }

      // Verify client exists
      const [clients] = await query('SELECT client_id FROM clients WHERE client_id = ?', [clientId]);
      if (clients.length === 0) {
        throw new NotFoundError('Client not found');
      }

      // Verify box exists and belongs to client
      const [boxes] = await query(
        'SELECT box_id, box_number, client_id, status FROM boxes WHERE box_id = ?',
        [boxId]
      );
      if (boxes.length === 0) {
        throw new NotFoundError('Box not found');
      }

      if (boxes[0].client_id !== parseInt(clientId)) {
        throw new ValidationError('Box does not belong to this client');
      }

      if (boxes[0].status === 'retrieved') {
        throw new ValidationError('Box has already been retrieved');
      }

      if (boxes[0].status === 'destroyed') {
        throw new ValidationError('Box has been destroyed and cannot be retrieved');
      }

      // Insert retrieval (without client signature - box stays 'stored')
      const [result] = await query(`
        INSERT INTO retrievals (
          client_id, box_id, retrieval_date, retrieved_by, reason,
          client_signature, staff_signature, created_by
        ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?)
      `, [
        clientId,
        boxId,
        retrievalDate,
        retrievedBy || null,
        reason || null,
        staffSignature || null,
        req.user.userId
      ]);

      const retrievalId = result.insertId;

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'CREATE_RETRIEVAL',
        'retrieval',
        retrievalId,
        null,
        { clientId, boxId, retrievalDate, boxNumber: boxes[0].box_number, status: 'pending_signature' },
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Retrieval created: ${retrievalId} for box ${boxes[0].box_number} by ${req.user.username} (pending client signature)`);

      res.status(201).json({
        status: 'success',
        message: 'Retrieval created successfully. Awaiting client signature to complete.',
        data: { 
          retrievalId,
          boxId: boxes[0].box_id,
          boxNumber: boxes[0].box_number,
          requiresClientSignature: true
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/retrievals/:retrievalId/signatures
 * @desc    Update retrieval signatures (client signature marks retrieval complete and updates box status)
 * @access  Admin, Staff, Client (for client signature only)
 */
router.patch('/:retrievalId/signatures',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { retrievalId } = req.params;
      const { clientSignature, staffSignature } = req.body;

      // Use transaction for atomic updates
      const result = await transaction(async (connection) => {
        // Check retrieval exists and get details
        const [retrievals] = await connection.execute(`
          SELECT ret.retrieval_id, ret.client_id, ret.box_id, ret.client_signature, ret.staff_signature,
                 b.box_number, b.status as box_status
          FROM retrievals ret
          LEFT JOIN boxes b ON ret.box_id = b.box_id
          WHERE ret.retrieval_id = ?
        `, [retrievalId]);
        
        if (retrievals.length === 0) {
          throw new NotFoundError('Retrieval not found');
        }

        const retrieval = retrievals[0];

        // If user is client, verify they own this retrieval and can only update client signature
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

        // Build update query
        const updates = [];
        const params = [];
        let isClientSigning = false;

        if (clientSignature !== undefined) {
          updates.push('client_signature = ?');
          params.push(clientSignature);
          isClientSigning = true;
        }

        if (staffSignature !== undefined) {
          // Only admin/staff can update staff signature
          if (req.user.role === 'client') {
            throw new ValidationError('Only staff can provide staff signature');
          }
          updates.push('staff_signature = ?');
          params.push(staffSignature);
        }

        if (updates.length === 0) {
          throw new ValidationError('At least one signature must be provided');
        }

        params.push(retrievalId);

        // Update signatures
        await connection.execute(
          `UPDATE retrievals SET ${updates.join(', ')} WHERE retrieval_id = ?`,
          params
        );

        let boxStatusChanged = false;
        let newBoxStatus = retrieval.box_status;

        // If client signature is being added, mark the box as 'retrieved'
        if (isClientSigning && clientSignature) {
          // Only update box status if it's currently 'stored'
          if (retrieval.box_status === 'stored') {
            await connection.execute(
              'UPDATE boxes SET status = ? WHERE box_id = ?',
              ['retrieved', retrieval.box_id]
            );
            boxStatusChanged = true;
            newBoxStatus = 'retrieved';

            // Create audit log for box status change
            await createAuditLog(
              req.user.userId,
              'BOX_STATUS_CHANGE_ON_RETRIEVAL',
              'box',
              retrieval.box_id,
              { status: 'stored' },
              { status: 'retrieved', triggeredBy: 'client_signature', retrievalId },
              req.ip,
              req.get('user-agent')
            );

            logger.info(`Box ${retrieval.box_number} marked as retrieved via client signature on retrieval ${retrievalId}`);
          }
        }

        // Create audit log for signature update
        await createAuditLog(
          req.user.userId,
          'UPDATE_RETRIEVAL_SIGNATURES',
          'retrieval',
          retrievalId,
          { 
            hadClientSignature: !!retrieval.client_signature, 
            hadStaffSignature: !!retrieval.staff_signature 
          },
          { 
            hasClientSignature: !!(clientSignature || retrieval.client_signature), 
            hasStaffSignature: !!(staffSignature || retrieval.staff_signature),
            boxStatusChanged,
            newBoxStatus
          },
          req.ip,
          req.get('user-agent')
        );

        return {
          retrieval,
          isClientSigning,
          boxStatusChanged,
          newBoxStatus
        };
      });

      const message = result.boxStatusChanged 
        ? 'Signatures updated successfully. Retrieval completed and box marked as retrieved.'
        : 'Signatures updated successfully';

      logger.info(`Retrieval signatures updated: ${retrievalId} by ${req.user.username}${result.boxStatusChanged ? ' - Box status changed to retrieved' : ''}`);

      res.status(200).json({
        status: 'success',
        message,
        data: {
          retrievalId,
          boxId: result.retrieval.box_id,
          boxNumber: result.retrieval.box_number,
          retrievalCompleted: result.isClientSigning,
          boxStatusChanged: result.boxStatusChanged,
          boxStatus: result.newBoxStatus
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
      const { pdfPath } = req.body;

      if (!pdfPath) {
        throw new ValidationError('PDF path is required');
      }

      // Check retrieval exists
      const [retrievals] = await query('SELECT retrieval_id FROM retrievals WHERE retrieval_id = ?', [retrievalId]);
      if (retrievals.length === 0) {
        throw new NotFoundError('Retrieval not found');
      }

      // Update PDF path
      await query('UPDATE retrievals SET pdf_path = ? WHERE retrieval_id = ?', [pdfPath, retrievalId]);

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'UPDATE_RETRIEVAL_PDF',
        'retrieval',
        retrievalId,
        null,
        { pdfPath },
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Retrieval PDF path updated: ${retrievalId} by ${req.user.username}`);

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
 * @desc    Manually mark a box as retrieved (override/manual process - normally done via client signature)
 * @access  Admin, Staff
 */
router.patch('/box/:boxId/mark-retrieved',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { boxId } = req.params;

      // Check box exists
      const [boxes] = await query(
        'SELECT box_id, box_number, status FROM boxes WHERE box_id = ?',
        [boxId]
      );
      
      if (boxes.length === 0) {
        throw new NotFoundError('Box not found');
      }

      const box = boxes[0];
      const oldStatus = box.status;

      if (oldStatus === 'retrieved') {
        throw new ValidationError('Box is already marked as retrieved');
      }

      // Update box status to retrieved
      await query('UPDATE boxes SET status = ? WHERE box_id = ?', ['retrieved', boxId]);

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'MANUAL_MARK_BOX_RETRIEVED',
        'box',
        boxId,
        { status: oldStatus },
        { status: 'retrieved', note: 'Manual override - not via client signature' },
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Box manually marked as retrieved: ${box.box_number} by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: 'Box manually marked as retrieved successfully',
        data: {
          boxId: box.box_id,
          boxNumber: box.box_number,
          oldStatus,
          newStatus: 'retrieved',
          note: 'Manual override - normally done via client signature on retrieval'
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
 * @access  Admin (only)
 */
router.delete('/:retrievalId',
  authorizeRoles('admin'),
  async (req, res, next) => {
    try {
      const { retrievalId } = req.params;

      // Check retrieval exists
      const [retrievals] = await query('SELECT retrieval_id FROM retrievals WHERE retrieval_id = ?', [retrievalId]);
      if (retrievals.length === 0) {
        throw new NotFoundError('Retrieval not found');
      }

      // Delete retrieval
      await query('DELETE FROM retrievals WHERE retrieval_id = ?', [retrievalId]);

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'DELETE_RETRIEVAL',
        'retrieval',
        retrievalId,
        null,
        null,
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Retrieval deleted: ${retrievalId} by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: 'Retrieval deleted successfully'
      });

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
          DATE(retrieval_date) as date,
          COUNT(*) as retrieval_count,
          COUNT(DISTINCT client_id) as unique_clients,
          COUNT(DISTINCT box_id) as unique_boxes
        FROM retrievals
        WHERE 1=1
      `;

      const params = [];

      if (startDate) {
        sql += ' AND retrieval_date >= ?';
        params.push(startDate);
      }

      if (endDate) {
        sql += ' AND retrieval_date <= ?';
        params.push(endDate);
      }

      if (clientId) {
        sql += ' AND client_id = ?';
        params.push(clientId);
      }

      sql += ' GROUP BY DATE(retrieval_date) ORDER BY date DESC';

      const [summary] = await query(sql, params);

      res.status(200).json({
        status: 'success',
        data: summary
      });

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
          c.client_id,
          c.client_name,
          c.client_code,
          COUNT(ret.retrieval_id) as retrieval_count,
          COUNT(DISTINCT ret.box_id) as boxes_retrieved,
          MAX(ret.retrieval_date) as last_retrieval_date
        FROM clients c
        LEFT JOIN retrievals ret ON c.client_id = ret.client_id
        WHERE 1=1
      `;

      const params = [];

      if (startDate) {
        sql += ' AND ret.retrieval_date >= ?';
        params.push(startDate);
      }

      if (endDate) {
        sql += ' AND ret.retrieval_date <= ?';
        params.push(endDate);
      }

      sql += ' GROUP BY c.client_id, c.client_name, c.client_code ORDER BY retrieval_count DESC';

      const [report] = await query(sql, params);

      res.status(200).json({
        status: 'success',
        data: report
      });

    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;