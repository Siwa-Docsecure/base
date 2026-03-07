const express = require('express');
const { query } = require('../config/db');
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
 * Validate request type
 */
const isValidRequestType = (type) => {
  return ['retrieval', 'destruction', 'collection', 'delivery'].includes(type);
};

/**
 * Validate request status
 */
const isValidStatus = (status) => {
  return ['pending', 'approved', 'completed', 'cancelled'].includes(status);
};

// ============================================
// REQUEST ROUTES
// ============================================

/**
 * @route   GET /api/requests
 * @desc    Get all requests with filtering and pagination
 * @access  Admin, Staff
 */
router.get('/',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const {
        clientId,
        requestType,
        status,
        boxId,
        startDate,
        endDate,
        search,
        page = 1,
        limit = 50,
        sortBy = 'requested_date',
        sortOrder = 'DESC'
      } = req.query;

      let sql = `
        SELECT req.request_id, req.client_id, req.request_type, req.box_id,
               req.details, req.status, req.requested_date, req.completed_date,
               req.created_at, req.updated_at,
               c.client_name, c.client_code, c.contact_person, c.email,
               b.box_number, b.box_description
        FROM requests req
        LEFT JOIN clients c ON req.client_id = c.client_id
        LEFT JOIN boxes b ON req.box_id = b.box_id
        WHERE 1=1
      `;

      const params = [];

      // Apply filters
      if (clientId) {
        sql += ' AND req.client_id = ?';
        params.push(clientId);
      }

      if (requestType) {
        sql += ' AND req.request_type = ?';
        params.push(requestType);
      }

      if (status) {
        sql += ' AND req.status = ?';
        params.push(status);
      }

      if (boxId) {
        sql += ' AND req.box_id = ?';
        params.push(boxId);
      }

      if (startDate) {
        sql += ' AND req.requested_date >= ?';
        params.push(startDate);
      }

      if (endDate) {
        sql += ' AND req.requested_date <= ?';
        params.push(endDate);
      }

      if (search) {
        sql += ' AND (req.details LIKE ? OR c.client_name LIKE ? OR b.box_number LIKE ?)';
        const searchPattern = `%${search}%`;
        params.push(searchPattern, searchPattern, searchPattern);
      }

      // Count total
      const countSql = sql.replace(/SELECT .+ FROM/, 'SELECT COUNT(*) as total FROM');
      const [countResult] = await query(countSql, params);
      const total = countResult[0].total;

      // Add sorting
      const validSortFields = ['requested_date', 'status', 'request_type', 'created_at', 'updated_at'];
      const sortField = validSortFields.includes(sortBy) ? sortBy : 'requested_date';
      const order = sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';
      sql += ` ORDER BY req.${sortField} ${order}`;

      // Add pagination
      const offset = (page - 1) * limit;
      sql += ' LIMIT ? OFFSET ?';
      params.push(parseInt(limit), offset);

      const [requests] = await query(sql, params);

      const formattedRequests = requests.map(req => ({
        requestId: req.request_id,
        client: {
          clientId: req.client_id,
          clientName: req.client_name,
          clientCode: req.client_code,
          contactPerson: req.contact_person,
          email: req.email
        },
        requestType: req.request_type,
        box: req.box_id ? {
          boxId: req.box_id,
          boxNumber: req.box_number,
          boxDescription: req.box_description
        } : null,
        details: req.details,
        status: req.status,
        requestedDate: req.requested_date,
        completedDate: req.completed_date,
        createdAt: req.created_at,
        updatedAt: req.updated_at
      }));

      res.status(200).json({
        status: 'success',
        data: {
          requests: formattedRequests,
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
 * @route   GET /api/requests/stats
 * @desc    Get request statistics
 * @access  Admin, Staff
 */
router.get('/stats',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const [stats] = await query(`
        SELECT 
          COUNT(*) as total_requests,
          SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_requests,
          SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) as approved_requests,
          SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_requests,
          SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_requests,
          SUM(CASE WHEN request_type = 'retrieval' THEN 1 ELSE 0 END) as retrieval_requests,
          SUM(CASE WHEN request_type = 'collection' THEN 1 ELSE 0 END) as collection_requests,
          SUM(CASE WHEN request_type = 'destruction' THEN 1 ELSE 0 END) as destruction_requests,
          SUM(CASE WHEN request_type = 'delivery' THEN 1 ELSE 0 END) as delivery_requests,
          COUNT(DISTINCT client_id) as clients_with_requests,
          COUNT(CASE WHEN DATE(requested_date) = CURDATE() THEN 1 END) as today_requests,
          COUNT(CASE WHEN DATE(requested_date) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) THEN 1 END) as this_week_requests,
          COUNT(CASE WHEN DATE(requested_date) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) as this_month_requests
        FROM requests
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
 * @route   GET /api/requests/pending
 * @desc    Get all pending requests
 * @access  Admin, Staff
 */
router.get('/pending',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { requestType, clientId, limit = 50 } = req.query;

      let sql = `
        SELECT req.request_id, req.client_id, req.request_type, req.box_id,
               req.details, req.requested_date, req.created_at,
               c.client_name, c.client_code, c.contact_person,
               b.box_number, b.box_description
        FROM requests req
        LEFT JOIN clients c ON req.client_id = c.client_id
        LEFT JOIN boxes b ON req.box_id = b.box_id
        WHERE req.status = 'pending'
      `;

      const params = [];

      if (requestType) {
        sql += ' AND req.request_type = ?';
        params.push(requestType);
      }

      if (clientId) {
        sql += ' AND req.client_id = ?';
        params.push(clientId);
      }

      sql += ' ORDER BY req.requested_date ASC LIMIT ?';
      params.push(parseInt(limit));

      const [requests] = await query(sql, params);

      const formattedRequests = requests.map(req => ({
        requestId: req.request_id,
        client: {
          clientId: req.client_id,
          clientName: req.client_name,
          clientCode: req.client_code,
          contactPerson: req.contact_person
        },
        requestType: req.request_type,
        box: req.box_id ? {
          boxId: req.box_id,
          boxNumber: req.box_number,
          boxDescription: req.box_description
        } : null,
        details: req.details,
        requestedDate: req.requested_date,
        createdAt: req.created_at
      }));

      res.status(200).json({
        status: 'success',
        data: {
          requests: formattedRequests,
          total: requests.length
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/requests/my
 * @desc    Get my requests (for clients)
 * @access  Client
 */
router.get('/my',
  authorizeRoles('client'),
  async (req, res, next) => {
    try {
      const clientId = req.user.clientId;

      if (!clientId) {
        throw new ValidationError('Client ID not found in user profile');
      }

      const { requestType, status, page = 1, limit = 50 } = req.query;

      let sql = `
        SELECT req.request_id, req.request_type, req.box_id, req.details,
               req.status, req.requested_date, req.completed_date,
               req.created_at, req.updated_at,
               b.box_number, b.box_description
        FROM requests req
        LEFT JOIN boxes b ON req.box_id = b.box_id
        WHERE req.client_id = ?
      `;

      const params = [clientId];

      if (requestType) {
        sql += ' AND req.request_type = ?';
        params.push(requestType);
      }

      if (status) {
        sql += ' AND req.status = ?';
        params.push(status);
      }

      // Count total
      const countSql = sql.replace(/SELECT .+ FROM/, 'SELECT COUNT(*) as total FROM');
      const [countResult] = await query(countSql, params);
      const total = countResult[0].total;

      // Add pagination
      sql += ' ORDER BY req.requested_date DESC LIMIT ? OFFSET ?';
      const offset = (page - 1) * limit;
      params.push(parseInt(limit), offset);

      const [requests] = await query(sql, params);

      const formattedRequests = requests.map(req => ({
        requestId: req.request_id,
        requestType: req.request_type,
        box: req.box_id ? {
          boxId: req.box_id,
          boxNumber: req.box_number,
          boxDescription: req.box_description
        } : null,
        details: req.details,
        status: req.status,
        requestedDate: req.requested_date,
        completedDate: req.completed_date,
        createdAt: req.created_at,
        updatedAt: req.updated_at
      }));

      res.status(200).json({
        status: 'success',
        data: {
          requests: formattedRequests,
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
 * @route   GET /api/requests/my/pending
 * @desc    Get my pending requests
 * @access  Client
 */
router.get('/my/pending',
  authorizeRoles('client'),
  async (req, res, next) => {
    try {
      const clientId = req.user.clientId;

      if (!clientId) {
        throw new ValidationError('Client ID not found in user profile');
      }

      const [requests] = await query(`
        SELECT req.request_id, req.request_type, req.box_id, req.details,
               req.requested_date, req.created_at,
               b.box_number, b.box_description
        FROM requests req
        LEFT JOIN boxes b ON req.box_id = b.box_id
        WHERE req.client_id = ? AND req.status = 'pending'
        ORDER BY req.requested_date DESC
      `, [clientId]);

      const formattedRequests = requests.map(req => ({
        requestId: req.request_id,
        requestType: req.request_type,
        box: req.box_id ? {
          boxId: req.box_id,
          boxNumber: req.box_number,
          boxDescription: req.box_description
        } : null,
        details: req.details,
        requestedDate: req.requested_date,
        createdAt: req.created_at
      }));

      res.status(200).json({
        status: 'success',
        message: requests.length > 0 
          ? `You have ${requests.length} pending request(s)` 
          : 'No pending requests',
        data: {
          requests: formattedRequests,
          total: requests.length
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/requests/client/:clientId
 * @desc    Get all requests for a specific client
 * @access  Admin, Staff, Client (own requests only)
 */
router.get('/client/:clientId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { clientId } = req.params;

      // If user is client, ensure they can only access their own requests
      if (req.user.role === 'client' && req.user.clientId !== parseInt(clientId)) {
        throw new ValidationError('You can only access your own requests');
      }

      const [requests] = await query(`
        SELECT req.request_id, req.request_type, req.box_id, req.details,
               req.status, req.requested_date, req.completed_date,
               req.created_at, req.updated_at,
               b.box_number, b.box_description
        FROM requests req
        LEFT JOIN boxes b ON req.box_id = b.box_id
        WHERE req.client_id = ?
        ORDER BY req.requested_date DESC
      `, [clientId]);

      const formattedRequests = requests.map(req => ({
        requestId: req.request_id,
        requestType: req.request_type,
        box: req.box_id ? {
          boxId: req.box_id,
          boxNumber: req.box_number,
          boxDescription: req.box_description
        } : null,
        details: req.details,
        status: req.status,
        requestedDate: req.requested_date,
        completedDate: req.completed_date,
        createdAt: req.created_at,
        updatedAt: req.updated_at
      }));

      res.status(200).json({
        status: 'success',
        data: formattedRequests
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/requests/:requestId
 * @desc    Get single request by ID
 * @access  Admin, Staff, Client (own request only)
 */
router.get('/:requestId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { requestId } = req.params;

      const [requests] = await query(`
        SELECT req.request_id, req.client_id, req.request_type, req.box_id,
               req.details, req.status, req.requested_date, req.completed_date,
               req.created_at, req.updated_at,
               c.client_name, c.client_code, c.contact_person, c.email,
               b.box_number, b.box_description, b.status as box_status
        FROM requests req
        LEFT JOIN clients c ON req.client_id = c.client_id
        LEFT JOIN boxes b ON req.box_id = b.box_id
        WHERE req.request_id = ?
      `, [requestId]);

      if (requests.length === 0) {
        throw new NotFoundError('Request not found');
      }

      const req_data = requests[0];

      // If user is client, ensure they can only access their own request
      if (req.user.role === 'client' && req.user.clientId !== req_data.client_id) {
        throw new ValidationError('You can only access your own requests');
      }

      const formattedRequest = {
        requestId: req_data.request_id,
        client: {
          clientId: req_data.client_id,
          clientName: req_data.client_name,
          clientCode: req_data.client_code,
          contactPerson: req_data.contact_person,
          email: req_data.email
        },
        requestType: req_data.request_type,
        box: req_data.box_id ? {
          boxId: req_data.box_id,
          boxNumber: req_data.box_number,
          boxDescription: req_data.box_description,
          status: req_data.box_status
        } : null,
        details: req_data.details,
        status: req_data.status,
        requestedDate: req_data.requested_date,
        completedDate: req_data.completed_date,
        createdAt: req_data.created_at,
        updatedAt: req_data.updated_at
      };

      res.status(200).json({
        status: 'success',
        data: formattedRequest
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   POST /api/requests
 * @desc    Create new request
 * @access  Client, Admin, Staff
 */
router.post('/',
  authorizeRoles('client', 'admin', 'staff'),
  async (req, res, next) => {
    try {
      const {
        clientId,
        requestType,
        boxId,
        details,
        requestedDate
      } = req.body;

      // Validate request type
      if (!requestType || !isValidRequestType(requestType)) {
        throw new ValidationError('Valid request type is required (retrieval, collection, destruction, delivery)');
      }

      // If user is client, use their clientId
      const effectiveClientId = req.user.role === 'client' ? req.user.clientId : clientId;

      if (!effectiveClientId) {
        throw new ValidationError('Client ID is required');
      }

      if (!requestedDate) {
        throw new ValidationError('Requested date is required');
      }

      // Verify client exists
      const [clients] = await query('SELECT client_id FROM clients WHERE client_id = ?', [effectiveClientId]);
      if (clients.length === 0) {
        throw new NotFoundError('Client not found');
      }

      // If box is specified, verify it exists and belongs to client
      if (boxId) {
        const [boxes] = await query(
          'SELECT box_id, box_number, client_id, status FROM boxes WHERE box_id = ?',
          [boxId]
        );
        
        if (boxes.length === 0) {
          throw new NotFoundError('Box not found');
        }

        if (boxes[0].client_id !== parseInt(effectiveClientId)) {
          throw new ValidationError('Box does not belong to this client');
        }

        // Validate box status for specific request types
        if (requestType === 'retrieval' && boxes[0].status === 'retrieved') {
          throw new ValidationError('Box has already been retrieved');
        }

        if (requestType === 'destruction' && boxes[0].status === 'destroyed') {
          throw new ValidationError('Box has already been destroyed');
        }
      }

      // Box ID is required for retrieval and destruction requests
      if ((requestType === 'retrieval' || requestType === 'destruction') && !boxId) {
        throw new ValidationError(`Box ID is required for ${requestType} requests`);
      }

      // Insert request
      const [result] = await query(`
        INSERT INTO requests (
          client_id, request_type, box_id, details, requested_date, status
        ) VALUES (?, ?, ?, ?, ?, 'pending')
      `, [
        effectiveClientId,
        requestType,
        boxId || null,
        details || null,
        requestedDate
      ]);

      const requestId = result.insertId;

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'CREATE_REQUEST',
        'request',
        requestId,
        null,
        { clientId: effectiveClientId, requestType, boxId, requestedDate },
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Request created: ${requestId} (${requestType}) by ${req.user.username} for client ${effectiveClientId}`);

      res.status(201).json({
        status: 'success',
        message: 'Request created successfully',
        data: { 
          requestId,
          requestType,
          status: 'pending'
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/requests/:requestId/status
 * @desc    Update request status (approve, complete, cancel)
 * @access  Admin, Staff
 */
router.patch('/:requestId/status',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { requestId } = req.params;
      const { status, completedDate } = req.body;

      if (!status || !isValidStatus(status)) {
        throw new ValidationError('Valid status is required (pending, approved, completed, cancelled)');
      }

      // Check request exists
      const [requests] = await query(
        'SELECT request_id, status as current_status, request_type, client_id FROM requests WHERE request_id = ?',
        [requestId]
      );
      
      if (requests.length === 0) {
        throw new NotFoundError('Request not found');
      }

      const request = requests[0];
      const oldStatus = request.current_status;

      // Validate status transitions
      if (oldStatus === 'completed' || oldStatus === 'cancelled') {
        throw new ValidationError(`Cannot update ${oldStatus} request`);
      }

      // Prepare update
      const updates = ['status = ?'];
      const params = [status];

      // If marking as completed, set completed date
      if (status === 'completed') {
        updates.push('completed_date = ?');
        params.push(completedDate || new Date().toISOString().split('T')[0]);
      }

      params.push(requestId);

      // Update request status
      await query(
        `UPDATE requests SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE request_id = ?`,
        params
      );

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'UPDATE_REQUEST_STATUS',
        'request',
        requestId,
        { status: oldStatus },
        { status, completedDate },
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Request ${requestId} status updated: ${oldStatus} → ${status} by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: `Request ${status} successfully`,
        data: {
          requestId,
          oldStatus,
          newStatus: status,
          requestType: request.request_type
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/requests/:requestId
 * @desc    Update request details
 * @access  Admin, Staff, Client (own pending requests only)
 */
router.patch('/:requestId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { requestId } = req.params;
      const { details, requestedDate } = req.body;

      // Check request exists
      const [requests] = await query(
        'SELECT request_id, client_id, status, details as old_details, requested_date as old_requested_date FROM requests WHERE request_id = ?',
        [requestId]
      );
      
      if (requests.length === 0) {
        throw new NotFoundError('Request not found');
      }

      const request = requests[0];

      // If user is client, verify ownership and that request is pending
      if (req.user.role === 'client') {
        if (req.user.clientId !== request.client_id) {
          throw new ValidationError('You can only update your own requests');
        }
        if (request.status !== 'pending') {
          throw new ValidationError('You can only update pending requests');
        }
      }

      // Build update query
      const updates = [];
      const params = [];
      const changes = {};

      if (details !== undefined) {
        updates.push('details = ?');
        params.push(details);
        changes.details = details;
      }

      if (requestedDate !== undefined) {
        updates.push('requested_date = ?');
        params.push(requestedDate);
        changes.requestedDate = requestedDate;
      }

      if (updates.length === 0) {
        throw new ValidationError('At least one field must be provided for update');
      }

      params.push(requestId);

      // Update request
      await query(
        `UPDATE requests SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE request_id = ?`,
        params
      );

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'UPDATE_REQUEST',
        'request',
        requestId,
        { details: request.old_details, requestedDate: request.old_requested_date },
        changes,
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Request updated: ${requestId} by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: 'Request updated successfully'
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   DELETE /api/requests/:requestId
 * @desc    Delete/cancel request
 * @access  Admin, Client (own pending requests only)
 */
router.delete('/:requestId',
  authorizeRoles('admin', 'client'),
  async (req, res, next) => {
    try {
      const { requestId } = req.params;

      // Check request exists
      const [requests] = await query(
        'SELECT request_id, client_id, status, request_type FROM requests WHERE request_id = ?',
        [requestId]
      );
      
      if (requests.length === 0) {
        throw new NotFoundError('Request not found');
      }

      const request = requests[0];

      // If user is client, verify ownership and that request is pending
      if (req.user.role === 'client') {
        if (req.user.clientId !== request.client_id) {
          throw new ValidationError('You can only cancel your own requests');
        }
        if (request.status !== 'pending') {
          throw new ValidationError('You can only cancel pending requests');
        }
      }

      // Admin can delete, client can only cancel (update status to cancelled)
      if (req.user.role === 'admin') {
        // Delete request
        await query('DELETE FROM requests WHERE request_id = ?', [requestId]);

        // Create audit log
        await createAuditLog(
          req.user.userId,
          'DELETE_REQUEST',
          'request',
          requestId,
          { requestType: request.request_type },
          null,
          req.ip,
          req.get('user-agent')
        );

        logger.info(`Request deleted: ${requestId} by ${req.user.username}`);

        res.status(200).json({
          status: 'success',
          message: 'Request deleted successfully'
        });
      } else {
        // Cancel request (update status)
        await query(
          'UPDATE requests SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE request_id = ?',
          ['cancelled', requestId]
        );

        // Create audit log
        await createAuditLog(
          req.user.userId,
          'CANCEL_REQUEST',
          'request',
          requestId,
          { status: request.status },
          { status: 'cancelled' },
          req.ip,
          req.get('user-agent')
        );

        logger.info(`Request cancelled: ${requestId} by ${req.user.username}`);

        res.status(200).json({
          status: 'success',
          message: 'Request cancelled successfully'
        });
      }

    } catch (error) {
      next(error);
    }
  }
);

// ============================================
// BULK OPERATIONS
// ============================================

/**
 * @route   PATCH /api/requests/bulk/approve
 * @desc    Bulk approve requests
 * @access  Admin, Staff
 */
router.patch('/bulk/approve',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { requestIds } = req.body;

      if (!Array.isArray(requestIds) || requestIds.length === 0) {
        throw new ValidationError('requestIds array is required and must not be empty');
      }

      // Update all to approved
      const placeholders = requestIds.map(() => '?').join(',');
      await query(
        `UPDATE requests SET status = 'approved', updated_at = CURRENT_TIMESTAMP WHERE request_id IN (${placeholders}) AND status = 'pending'`,
        requestIds
      );

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'BULK_APPROVE_REQUESTS',
        'request',
        null,
        null,
        { requestIds, count: requestIds.length },
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Bulk approved ${requestIds.length} requests by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: `${requestIds.length} requests approved successfully`
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/requests/bulk/complete
 * @desc    Bulk complete requests
 * @access  Admin, Staff
 */
router.patch('/bulk/complete',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { requestIds, completedDate } = req.body;

      if (!Array.isArray(requestIds) || requestIds.length === 0) {
        throw new ValidationError('requestIds array is required and must not be empty');
      }

      const effectiveCompletedDate = completedDate || new Date().toISOString().split('T')[0];

      // Update all to completed
      const placeholders = requestIds.map(() => '?').join(',');
      await query(
        `UPDATE requests SET status = 'completed', completed_date = ?, updated_at = CURRENT_TIMESTAMP 
         WHERE request_id IN (${placeholders}) AND status IN ('pending', 'approved')`,
        [effectiveCompletedDate, ...requestIds]
      );

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'BULK_COMPLETE_REQUESTS',
        'request',
        null,
        null,
        { requestIds, count: requestIds.length, completedDate: effectiveCompletedDate },
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Bulk completed ${requestIds.length} requests by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: `${requestIds.length} requests completed successfully`
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
 * @route   GET /api/requests/reports/summary
 * @desc    Get requests summary by date range
 * @access  Admin, Staff
 */
router.get('/reports/summary',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { startDate, endDate, clientId, requestType } = req.query;

      let sql = `
        SELECT 
          DATE(requested_date) as date,
          COUNT(*) as request_count,
          COUNT(DISTINCT client_id) as unique_clients,
          SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_count,
          SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) as approved_count,
          SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count,
          SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_count
        FROM requests
        WHERE 1=1
      `;

      const params = [];

      if (startDate) {
        sql += ' AND requested_date >= ?';
        params.push(startDate);
      }

      if (endDate) {
        sql += ' AND requested_date <= ?';
        params.push(endDate);
      }

      if (clientId) {
        sql += ' AND client_id = ?';
        params.push(clientId);
      }

      if (requestType) {
        sql += ' AND request_type = ?';
        params.push(requestType);
      }

      sql += ' GROUP BY DATE(requested_date) ORDER BY date DESC';

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
 * @route   GET /api/requests/reports/by-client
 * @desc    Get requests grouped by client
 * @access  Admin, Staff
 */
router.get('/reports/by-client',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { startDate, endDate, requestType } = req.query;

      let sql = `
        SELECT 
          c.client_id,
          c.client_name,
          c.client_code,
          COUNT(req.request_id) as total_requests,
          SUM(CASE WHEN req.status = 'pending' THEN 1 ELSE 0 END) as pending_requests,
          SUM(CASE WHEN req.status = 'completed' THEN 1 ELSE 0 END) as completed_requests,
          MAX(req.requested_date) as last_request_date
        FROM clients c
        LEFT JOIN requests req ON c.client_id = req.client_id
        WHERE 1=1
      `;

      const params = [];

      if (startDate) {
        sql += ' AND req.requested_date >= ?';
        params.push(startDate);
      }

      if (endDate) {
        sql += ' AND req.requested_date <= ?';
        params.push(endDate);
      }

      if (requestType) {
        sql += ' AND req.request_type = ?';
        params.push(requestType);
      }

      sql += ' GROUP BY c.client_id, c.client_name, c.client_code ORDER BY total_requests DESC';

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

/**
 * @route   GET /api/requests/reports/by-type
 * @desc    Get requests grouped by type
 * @access  Admin, Staff
 */
router.get('/reports/by-type',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { startDate, endDate } = req.query;

      let sql = `
        SELECT 
          request_type,
          COUNT(*) as total_requests,
          SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_count,
          SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) as approved_count,
          SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count,
          SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_count,
          COUNT(DISTINCT client_id) as unique_clients
        FROM requests
        WHERE 1=1
      `;

      const params = [];

      if (startDate) {
        sql += ' AND requested_date >= ?';
        params.push(startDate);
      }

      if (endDate) {
        sql += ' AND requested_date <= ?';
        params.push(endDate);
      }

      sql += ' GROUP BY request_type ORDER BY total_requests DESC';

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