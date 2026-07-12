const express = require('express');
const db = require('../config/db');
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
    const query = `
      INSERT INTO audit_logs (user_id, action, entity_type, entity_id, old_value, new_value, ip_address, user_agent)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `;
    await db.query(query, [
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

// ============================================
// DELIVERY ROUTES
// ============================================

/**
 * @route   GET /api/deliveries
 * @desc    Get all deliveries with filtering and pagination
 * @access  Admin, Staff
 */
router.get('/', 
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { 
        clientId, 
        startDate,
        endDate,
        search, 
        page = 1, 
        limit = 50,
        sortBy = 'delivery_date',
        sortOrder = 'DESC'
      } = req.query;
      
      let query = `
        SELECT d.delivery_id, d.client_id, d.item_name, d.quantity,
               d.delivery_date, d.receiver_name, d.acknowledgement_statement,
               d.pdf_path, d.created_at, d.created_by,
               c.client_name, c.client_code, c.contact_person,
               u.username as created_by_username
        FROM deliveries d
        LEFT JOIN clients c ON d.client_id = c.client_id
        LEFT JOIN users u ON d.created_by = u.user_id
        WHERE 1=1
      `;
      
      const params = [];
      
      // Apply filters
      if (clientId) {
        query += ' AND d.client_id = ?';
        params.push(clientId);
      }
      
      if (startDate) {
        query += ' AND d.delivery_date >= ?';
        params.push(startDate);
      }
      
      if (endDate) {
        query += ' AND d.delivery_date <= ?';
        params.push(endDate);
      }
      
      if (search) {
        query += ' AND (d.item_name LIKE ? OR c.client_name LIKE ? OR d.receiver_name LIKE ?)';
        const searchPattern = `%${search}%`;
        params.push(searchPattern, searchPattern, searchPattern);
      }
      
      // Count total
      const countQuery = query.replace(/SELECT .+ FROM/, 'SELECT COUNT(*) as total FROM');
      const [countResult] = await db.query(countQuery, params);
      const total = countResult[0].total;
      
      // Add sorting
      const validSortFields = ['delivery_date', 'quantity', 'created_at', 'item_name'];
      const sortField = validSortFields.includes(sortBy) ? sortBy : 'delivery_date';
      const order = sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';
      query += ` ORDER BY d.${sortField} ${order}`;
      
      // Add pagination
      const offset = (page - 1) * limit;
      query += ' LIMIT ? OFFSET ?';
      params.push(parseInt(limit), offset);
      
      const [deliveries] = await db.query(query, params);
      
      const formattedDeliveries = deliveries.map(delivery => ({
        deliveryId: delivery.delivery_id,
        client: {
          clientId: delivery.client_id,
          clientName: delivery.client_name,
          clientCode: delivery.client_code,
          contactPerson: delivery.contact_person
        },
        itemName: delivery.item_name,
        quantity: delivery.quantity,
        deliveryDate: delivery.delivery_date,
        receiverName: delivery.receiver_name,
        acknowledgementStatement: delivery.acknowledgement_statement,
        pdfPath: delivery.pdf_path,
        createdBy: {
          userId: delivery.created_by,
          username: delivery.created_by_username
        },
        createdAt: delivery.created_at
      }));
      
      res.status(200).json({
        status: 'success',
        data: {
          deliveries: formattedDeliveries,
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
 * @route   GET /api/deliveries/stats
 * @desc    Get delivery statistics
 * @access  Admin, Staff
 */
router.get('/stats',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const [stats] = await db.query(`
        SELECT 
          COUNT(*) as total_deliveries,
          SUM(quantity) as total_items_delivered,
          COUNT(DISTINCT client_id) as clients_with_deliveries,
          COUNT(CASE WHEN DATE(delivery_date) = CURDATE() THEN 1 END) as today_deliveries,
          COUNT(CASE WHEN DATE(delivery_date) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) THEN 1 END) as this_week_deliveries,
          COUNT(CASE WHEN DATE(delivery_date) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) as this_month_deliveries,
          COUNT(DISTINCT item_name) as unique_items
        FROM deliveries
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
 * @route   GET /api/deliveries/recent
 * @desc    Get recent deliveries
 * @access  Admin, Staff
 */
router.get('/recent',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { limit = 10 } = req.query;
      
      const [deliveries] = await db.query(`
        SELECT d.delivery_id, d.item_name, d.quantity, d.delivery_date,
               c.client_name, c.client_code,
               u.username as created_by_username
        FROM deliveries d
        LEFT JOIN clients c ON d.client_id = c.client_id
        LEFT JOIN users u ON d.created_by = u.user_id
        ORDER BY d.created_at DESC
        LIMIT ?
      `, [parseInt(limit)]);
      
      const formattedDeliveries = deliveries.map(d => ({
        deliveryId: d.delivery_id,
        clientName: d.client_name,
        clientCode: d.client_code,
        itemName: d.item_name,
        quantity: d.quantity,
        deliveryDate: d.delivery_date,
        createdBy: d.created_by_username
      }));
      
      res.status(200).json({
        status: 'success',
        data: formattedDeliveries
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/deliveries/client/:clientId
 * @desc    Get all deliveries for a specific client
 * @access  Admin, Staff, Client (own deliveries only)
 */
router.get('/client/:clientId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { clientId } = req.params;
      
      // If user is client, ensure they can only access their own deliveries
      if (req.user.role === 'client' && req.user.clientId !== parseInt(clientId)) {
        throw new ValidationError('You can only access your own deliveries');
      }
      
      const [deliveries] = await db.query(`
        SELECT d.delivery_id, d.item_name, d.quantity, d.delivery_date,
               d.receiver_name, d.acknowledgement_statement, d.pdf_path, d.created_at,
               u.username as created_by_username
        FROM deliveries d
        LEFT JOIN users u ON d.created_by = u.user_id
        WHERE d.client_id = ?
        ORDER BY d.delivery_date DESC
      `, [clientId]);
      
      const formattedDeliveries = deliveries.map(d => ({
        deliveryId: d.delivery_id,
        itemName: d.item_name,
        quantity: d.quantity,
        deliveryDate: d.delivery_date,
        receiverName: d.receiver_name,
        acknowledgementStatement: d.acknowledgement_statement,
        pdfPath: d.pdf_path,
        createdBy: d.created_by_username,
        createdAt: d.created_at
      }));
      
      res.status(200).json({
        status: 'success',
        data: {
          clientId: parseInt(clientId),
          count: formattedDeliveries.length,
          deliveries: formattedDeliveries
        }
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/deliveries/:deliveryId
 * @desc    Get single delivery by ID
 * @access  Admin, Staff, Client (own deliveries only)
 */
router.get('/:deliveryId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { deliveryId } = req.params;
      
      const [deliveries] = await db.query(`
        SELECT d.*, 
               c.client_name, c.client_code, c.contact_person, c.email as client_email, c.phone as client_phone,
               u.username as created_by_username, u.email as created_by_email
        FROM deliveries d
        LEFT JOIN clients c ON d.client_id = c.client_id
        LEFT JOIN users u ON d.created_by = u.user_id
        WHERE d.delivery_id = ?
      `, [deliveryId]);
      
      if (deliveries.length === 0) {
        throw new NotFoundError('Delivery not found');
      }
      
      const d = deliveries[0];
      
      // If user is client, ensure they can only access their own deliveries
      if (req.user.role === 'client' && req.user.clientId !== d.client_id) {
        throw new ValidationError('You can only access your own deliveries');
      }
      
      const formattedDelivery = {
        deliveryId: d.delivery_id,
        client: {
          clientId: d.client_id,
          clientName: d.client_name,
          clientCode: d.client_code,
          contactPerson: d.contact_person,
          email: d.client_email,
          phone: d.client_phone
        },
        itemName: d.item_name,
        quantity: d.quantity,
        deliveryDate: d.delivery_date,
        receiverName: d.receiver_name,
        receiverSignature: d.receiver_signature,
        acknowledgementStatement: d.acknowledgement_statement,
        pdfPath: d.pdf_path,
        createdBy: {
          userId: d.created_by,
          username: d.created_by_username,
          email: d.created_by_email
        },
        createdAt: d.created_at
      };
      
      res.status(200).json({
        status: 'success',
        data: formattedDelivery
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   POST /api/deliveries
 * @desc    Create new delivery record
 * @access  Admin, Staff (with permission)
 */
router.post('/',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canCreateDeliveries'),
  async (req, res, next) => {
    try {
      const { 
        clientId, 
        itemName,
        quantity,
        deliveryDate,
        receiverName,
        receiverSignature,
        acknowledgementStatement
      } = req.body;
      
      // Validate required fields
      if (!clientId || !itemName || !quantity || !deliveryDate || !receiverName) {
        throw new ValidationError('Client ID, item name, quantity, delivery date, and receiver name are required');
      }
      
      if (quantity < 1) {
        throw new ValidationError('Quantity must be at least 1');
      }
      
      // Check client exists
      const [clients] = await db.query('SELECT client_id FROM clients WHERE client_id = ?', [clientId]);
      if (clients.length === 0) {
        throw new NotFoundError('Client not found');
      }
      
      // Insert delivery
      const [result] = await db.query(`
        INSERT INTO deliveries (
          client_id, item_name, quantity, delivery_date, receiver_name,
          receiver_signature, acknowledgement_statement, created_by
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        clientId, 
        itemName, 
        quantity, 
        deliveryDate, 
        receiverName,
        receiverSignature || null,
        acknowledgementStatement || null,
        req.user.userId
      ]);
      
      const deliveryId = result.insertId;
      
      // Create audit log
      await createAuditLog(
        req.user.userId,
        'CREATE_DELIVERY',
        'delivery',
        deliveryId,
        null,
        { clientId, itemName, quantity, deliveryDate },
        req.ip,
        req.get('user-agent')
      );
      
      logger.info(`Delivery created: ${deliveryId} for client ${clientId} (${quantity} x ${itemName}) by ${req.user.username}`);
      
      res.status(201).json({
        status: 'success',
        message: 'Delivery created successfully',
        data: {
          deliveryId,
          clientId,
          itemName,
          quantity,
          deliveryDate,
          receiverName,
          createdBy: req.user.userId
        }
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PUT /api/deliveries/:deliveryId
 * @desc    Update delivery details
 * @access  Admin, Staff (with permission)
 */
router.put('/:deliveryId',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canCreateDeliveries'),
  async (req, res, next) => {
    try {
      const { deliveryId } = req.params;
      const { 
        itemName,
        quantity,
        deliveryDate,
        receiverName,
        acknowledgementStatement
      } = req.body;
      
      // Check delivery exists
      const [deliveries] = await db.query('SELECT * FROM deliveries WHERE delivery_id = ?', [deliveryId]);
      if (deliveries.length === 0) {
        throw new NotFoundError('Delivery not found');
      }
      
      const oldDelivery = deliveries[0];
      
      // Build update query dynamically
      const updates = [];
      const params = [];
      
      if (itemName !== undefined) {
        updates.push('item_name = ?');
        params.push(itemName);
      }
      
      if (quantity !== undefined) {
        if (quantity < 1) {
          throw new ValidationError('Quantity must be at least 1');
        }
        updates.push('quantity = ?');
        params.push(quantity);
      }
      
      if (deliveryDate !== undefined) {
        updates.push('delivery_date = ?');
        params.push(deliveryDate);
      }
      
      if (receiverName !== undefined) {
        updates.push('receiver_name = ?');
        params.push(receiverName);
      }
      
      if (acknowledgementStatement !== undefined) {
        updates.push('acknowledgement_statement = ?');
        params.push(acknowledgementStatement);
      }
      
      if (updates.length === 0) {
        throw new ValidationError('No fields to update');
      }
      
      params.push(deliveryId);
      
      // Update delivery
      await db.query(
        `UPDATE deliveries SET ${updates.join(', ')} WHERE delivery_id = ?`,
        params
      );
      
      // Create audit log
      await createAuditLog(
        req.user.userId,
        'UPDATE_DELIVERY',
        'delivery',
        deliveryId,
        oldDelivery,
        { itemName, quantity, deliveryDate, receiverName, acknowledgementStatement },
        req.ip,
        req.get('user-agent')
      );
      
      logger.info(`Delivery updated: ${deliveryId} by ${req.user.username}`);
      
      res.status(200).json({
        status: 'success',
        message: 'Delivery updated successfully'
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/deliveries/:deliveryId/signature
 * @desc    Update delivery signature
 * @access  Admin, Staff (with permission)
 */
router.patch('/:deliveryId/signature',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canCreateDeliveries'),
  async (req, res, next) => {
    try {
      const { deliveryId } = req.params;
      const { receiverSignature } = req.body;
      
      if (!receiverSignature) {
        throw new ValidationError('Receiver signature is required');
      }
      
      // Check delivery exists
      const [deliveries] = await db.query('SELECT delivery_id FROM deliveries WHERE delivery_id = ?', [deliveryId]);
      if (deliveries.length === 0) {
        throw new NotFoundError('Delivery not found');
      }
      
      // Update signature
      await db.query(
        'UPDATE deliveries SET receiver_signature = ? WHERE delivery_id = ?',
        [receiverSignature, deliveryId]
      );
      
      // Create audit log
      await createAuditLog(
        req.user.userId,
        'UPDATE_DELIVERY_SIGNATURE',
        'delivery',
        deliveryId,
        null,
        { hasSignature: true },
        req.ip,
        req.get('user-agent')
      );
      
      logger.info(`Delivery signature updated: ${deliveryId} by ${req.user.username}`);
      
      res.status(200).json({
        status: 'success',
        message: 'Signature updated successfully'
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/deliveries/:deliveryId/pdf
 * @desc    Update delivery PDF path
 * @access  Admin, Staff
 */
router.patch('/:deliveryId/pdf',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { deliveryId } = req.params;
      const { pdfPath } = req.body;
      
      if (!pdfPath) {
        throw new ValidationError('PDF path is required');
      }
      
      // Check delivery exists
      const [deliveries] = await db.query('SELECT delivery_id FROM deliveries WHERE delivery_id = ?', [deliveryId]);
      if (deliveries.length === 0) {
        throw new NotFoundError('Delivery not found');
      }
      
      // Update PDF path
      await db.query('UPDATE deliveries SET pdf_path = ? WHERE delivery_id = ?', [pdfPath, deliveryId]);
      
      // Create audit log
      await createAuditLog(
        req.user.userId,
        'UPDATE_DELIVERY_PDF',
        'delivery',
        deliveryId,
        null,
        { pdfPath },
        req.ip,
        req.get('user-agent')
      );
      
      logger.info(`Delivery PDF path updated: ${deliveryId} by ${req.user.username}`);
      
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
 * @route   DELETE /api/deliveries/:deliveryId
 * @desc    Delete delivery
 * @access  Admin (only)
 */
router.delete('/:deliveryId',
  authorizeRoles('admin'),
  async (req, res, next) => {
    try {
      const { deliveryId } = req.params;
      
      // Check delivery exists
      const [deliveries] = await db.query('SELECT delivery_id FROM deliveries WHERE delivery_id = ?', [deliveryId]);
      if (deliveries.length === 0) {
        throw new NotFoundError('Delivery not found');
      }
      
      // Delete delivery
      await db.query('DELETE FROM deliveries WHERE delivery_id = ?', [deliveryId]);
      
      // Create audit log
      await createAuditLog(
        req.user.userId,
        'DELETE_DELIVERY',
        'delivery',
        deliveryId,
        null,
        null,
        req.ip,
        req.get('user-agent')
      );
      
      logger.info(`Delivery deleted: ${deliveryId} by ${req.user.username}`);
      
      res.status(200).json({
        status: 'success',
        message: 'Delivery deleted successfully'
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
 * @route   GET /api/deliveries/reports/summary
 * @desc    Get deliveries summary by date range
 * @access  Admin, Staff
 */
router.get('/reports/summary',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { startDate, endDate, clientId } = req.query;
      
      let query = `
        SELECT 
          DATE(delivery_date) as date,
          COUNT(*) as delivery_count,
          SUM(quantity) as total_items,
          COUNT(DISTINCT client_id) as unique_clients,
          COUNT(DISTINCT item_name) as unique_items
        FROM deliveries
        WHERE 1=1
      `;
      
      const params = [];
      
      if (startDate) {
        query += ' AND delivery_date >= ?';
        params.push(startDate);
      }
      
      if (endDate) {
        query += ' AND delivery_date <= ?';
        params.push(endDate);
      }
      
      if (clientId) {
        query += ' AND client_id = ?';
        params.push(clientId);
      }
      
      query += ' GROUP BY DATE(delivery_date) ORDER BY date DESC';
      
      const [summary] = await db.query(query, params);
      
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
 * @route   GET /api/deliveries/reports/by-client
 * @desc    Get deliveries grouped by client
 * @access  Admin, Staff
 */
router.get('/reports/by-client',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { startDate, endDate } = req.query;
      
      let query = `
        SELECT 
          c.client_id,
          c.client_name,
          c.client_code,
          COUNT(d.delivery_id) as delivery_count,
          SUM(d.quantity) as total_items_delivered,
          MAX(d.delivery_date) as last_delivery_date
        FROM clients c
        LEFT JOIN deliveries d ON c.client_id = d.client_id
        WHERE 1=1
      `;
      
      const params = [];
      
      if (startDate) {
        query += ' AND d.delivery_date >= ?';
        params.push(startDate);
      }
      
      if (endDate) {
        query += ' AND d.delivery_date <= ?';
        params.push(endDate);
      }
      
      query += ' GROUP BY c.client_id, c.client_name, c.client_code ORDER BY total_items_delivered DESC';
      
      const [report] = await db.query(query, params);
      
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
 * @route   GET /api/deliveries/reports/by-item
 * @desc    Get deliveries grouped by item type
 * @access  Admin, Staff
 */
router.get('/reports/by-item',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { startDate, endDate } = req.query;
      
      let query = `
        SELECT 
          item_name,
          COUNT(*) as delivery_count,
          SUM(quantity) as total_quantity,
          COUNT(DISTINCT client_id) as clients_count,
          MAX(delivery_date) as last_delivered
        FROM deliveries
        WHERE 1=1
      `;
      
      const params = [];
      
      if (startDate) {
        query += ' AND delivery_date >= ?';
        params.push(startDate);
      }
      
      if (endDate) {
        query += ' AND delivery_date <= ?';
        params.push(endDate);
      }
      
      query += ' GROUP BY item_name ORDER BY total_quantity DESC';
      
      const [report] = await db.query(query, params);
      
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