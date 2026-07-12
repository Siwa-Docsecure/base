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
// COLLECTION ROUTES
// ============================================

/**
 * @route   GET /api/collections
 * @desc    Get all collections with filtering and pagination
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
        sortBy = 'collection_date',
        sortOrder = 'DESC'
      } = req.query;

      let query = `
        SELECT col.collection_id, col.client_id, col.total_boxes, col.box_description,
               col.dispatcher_name, col.collector_name, col.collection_date,
               col.dispatcher_signature, col.collector_signature,
               col.pdf_path, col.created_at, col.created_by,
               c.client_name, c.client_code, c.contact_person,
               u.username as created_by_username
        FROM collections col
        LEFT JOIN clients c ON col.client_id = c.client_id
        LEFT JOIN users u ON col.created_by = u.user_id
        WHERE 1=1
      `;

      const params = [];

      // Apply filters
      if (clientId) {
        query += ' AND col.client_id = ?';
        params.push(clientId);
      }

      if (startDate) {
        query += ' AND col.collection_date >= ?';
        params.push(startDate);
      }

      if (endDate) {
        query += ' AND col.collection_date <= ?';
        params.push(endDate);
      }

      if (search) {
        query += ' AND (col.box_description LIKE ? OR c.client_name LIKE ? OR col.dispatcher_name LIKE ? OR col.collector_name LIKE ?)';
        const searchPattern = `%${search}%`;
        params.push(searchPattern, searchPattern, searchPattern, searchPattern);
      }

      // Count total
      const countQuery = query.replace(/SELECT .+ FROM/, 'SELECT COUNT(*) as total FROM');
      const [countResult] = await db.query(countQuery, params);
      const total = countResult[0].total;

      // Add sorting
      const validSortFields = ['collection_date', 'total_boxes', 'created_at'];
      const sortField = validSortFields.includes(sortBy) ? sortBy : 'collection_date';
      const order = sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';
      query += ` ORDER BY col.${sortField} ${order}`;

      // Add pagination
      const offset = (page - 1) * limit;
      query += ' LIMIT ? OFFSET ?';
      params.push(parseInt(limit), offset);

      const [collections] = await db.query(query, params);

      const formattedCollections = collections.map(col => ({
        collectionId: col.collection_id,
        client: {
          clientId: col.client_id,
          clientName: col.client_name,
          clientCode: col.client_code,
          contactPerson: col.contact_person
        },
        totalBoxes: col.total_boxes,
        boxDescription: col.box_description,
        dispatcherName: col.dispatcher_name,
        collectorName: col.collector_name,
        dispatcherSignature: col.dispatcher_signature,
        collectorSignature: col.collector_signature,
        collectionDate: col.collection_date,
        pdfPath: col.pdf_path,
        createdBy: {
          userId: col.created_by,
          username: col.created_by_username
        },
        createdAt: col.created_at
      }));

      res.status(200).json({
        status: 'success',
        data: {
          collections: formattedCollections,
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
 * @route   GET /api/collections/stats
 * @desc    Get collection statistics
 * @access  Admin, Staff
 */
router.get('/stats',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const [stats] = await db.query(`
        SELECT 
          COUNT(*) as total_collections,
          SUM(total_boxes) as total_boxes_collected,
          COUNT(DISTINCT client_id) as clients_with_collections,
          COUNT(CASE WHEN DATE(collection_date) = CURDATE() THEN 1 END) as today_collections,
          COUNT(CASE WHEN DATE(collection_date) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) THEN 1 END) as this_week_collections,
          COUNT(CASE WHEN DATE(collection_date) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) as this_month_collections
        FROM collections
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
 * @route   GET /api/collections/recent
 * @desc    Get recent collections
 * @access  Admin, Staff
 */
router.get('/recent',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { limit = 10 } = req.query;

      const [collections] = await db.query(`
        SELECT col.collection_id, col.total_boxes, col.collection_date,
               c.client_name, c.client_code,
               u.username as created_by_username
        FROM collections col
        LEFT JOIN clients c ON col.client_id = c.client_id
        LEFT JOIN users u ON col.created_by = u.user_id
        ORDER BY col.created_at DESC
        LIMIT ?
      `, [parseInt(limit)]);

      const formattedCollections = collections.map(col => ({
        collectionId: col.collection_id,
        clientName: col.client_name,
        clientCode: col.client_code,
        totalBoxes: col.total_boxes,
        collectionDate: col.collection_date,
        createdBy: col.created_by_username
      }));

      res.status(200).json({
        status: 'success',
        data: formattedCollections
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/collections/client/:clientId
 * @desc    Get all collections for a specific client
 * @access  Admin, Staff, Client (own collections only)
 */
router.get('/client/:clientId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { clientId } = req.params;

      // If user is client, ensure they can only access their own collections
      if (req.user.role === 'client' && req.user.clientId !== parseInt(clientId)) {
        throw new ValidationError('You can only access your own collections');
      }

      const [collections] = await db.query(`
        SELECT col.collection_id, col.total_boxes, col.box_description,
               col.dispatcher_name, col.collector_name, col.collection_date,
               col.dispatcher_signature, col.collector_signature,
               col.pdf_path, col.created_at,
               u.username as created_by_username
        FROM collections col
        LEFT JOIN users u ON col.created_by = u.user_id
        WHERE col.client_id = ?
        ORDER BY col.collection_date DESC
      `, [clientId]);

      const formattedCollections = collections.map(col => ({
        collectionId: col.collection_id,
        totalBoxes: col.total_boxes,
        boxDescription: col.box_description,
        dispatcherName: col.dispatcher_name,
        collectorName: col.collector_name,
        dispatcherSignature: col.dispatcher_signature, 
        collectorSignature: col.collector_signature,
        collectionDate: col.collection_date,
        pdfPath: col.pdf_path,
        createdBy: col.created_by_username,
        createdAt: col.created_at
      }));

      res.status(200).json({
        status: 'success',
        data: {
          clientId: parseInt(clientId),
          count: formattedCollections.length,
          collections: formattedCollections
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/collections/:collectionId
 * @desc    Get single collection by ID
 * @access  Admin, Staff, Client (own collections only)
 */
router.get('/:collectionId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { collectionId } = req.params;

      const [collections] = await db.query(`
        SELECT col.*, 
               c.client_name, c.client_code, c.contact_person, c.email as client_email, c.phone as client_phone,
               u.username as created_by_username, u.email as created_by_email
        FROM collections col
        LEFT JOIN clients c ON col.client_id = c.client_id
        LEFT JOIN users u ON col.created_by = u.user_id
        WHERE col.collection_id = ?
      `, [collectionId]);

      if (collections.length === 0) {
        throw new NotFoundError('Collection not found');
      }

      const col = collections[0];

      // If user is client, ensure they can only access their own collections
      if (req.user.role === 'client' && req.user.clientId !== col.client_id) {
        throw new ValidationError('You can only access your own collections');
      }

      const formattedCollection = {
        collectionId: col.collection_id,
        client: {
          clientId: col.client_id,
          clientName: col.client_name,
          clientCode: col.client_code,
          contactPerson: col.contact_person,
          email: col.client_email,
          phone: col.client_phone
        },
        totalBoxes: col.total_boxes,
        boxDescription: col.box_description,
        dispatcherName: col.dispatcher_name,
        collectorName: col.collector_name,
        dispatcherSignature: col.dispatcher_signature,
        collectorSignature: col.collector_signature,
        collectionDate: col.collection_date,
        pdfPath: col.pdf_path,
        createdBy: {
          userId: col.created_by,
          username: col.created_by_username,
          email: col.created_by_email
        },
        createdAt: col.created_at
      };

      res.status(200).json({
        status: 'success',
        data: formattedCollection
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   POST /api/collections
 * @desc    Create new collection record
 * @access  Admin, Staff (with permission)
 */
router.post('/',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canCreateCollections'),
  async (req, res, next) => {
    try {
      const {
        clientId,
        totalBoxes,
        boxDescription,
        dispatcherName,
        collectorName,
        dispatcherSignature,
        collectorSignature,
        collectionDate
      } = req.body;

      // Validate required fields
      if (!clientId || !totalBoxes || !dispatcherName || !collectorName || !collectionDate) {
        throw new ValidationError('Client ID, total boxes, dispatcher name, collector name, and collection date are required');
      }

      if (totalBoxes < 1) {
        throw new ValidationError('Total boxes must be at least 1');
      }

      // Check client exists
      const [clients] = await db.query('SELECT client_id FROM clients WHERE client_id = ?', [clientId]);
      if (clients.length === 0) {
        throw new NotFoundError('Client not found');
      }

      // Insert collection
      const [result] = await db.query(`
        INSERT INTO collections (
          client_id, total_boxes, box_description, dispatcher_name, collector_name,
          dispatcher_signature, collector_signature, collection_date, created_by
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        clientId,
        totalBoxes,
        boxDescription || null,
        dispatcherName,
        collectorName,
        dispatcherSignature || null,
        collectorSignature || null,
        collectionDate,
        req.user.userId
      ]);

      const collectionId = result.insertId;

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'CREATE_COLLECTION',
        'collection',
        collectionId,
        null,
        { clientId, totalBoxes, collectionDate },
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Collection created: ${collectionId} for client ${clientId} (${totalBoxes} boxes) by ${req.user.username}`);

      res.status(201).json({
        status: 'success',
        message: 'Collection created successfully',
        data: {
          collectionId,
          clientId,
          totalBoxes,
          boxDescription,
          dispatcherName,
          collectorName,
          collectionDate,
          createdBy: req.user.userId
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PUT /api/collections/:collectionId
 * @desc    Update collection details
 * @access  Admin, Staff (with permission)
 */
router.put('/:collectionId',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canCreateCollections'),
  async (req, res, next) => {
    try {
      const { collectionId } = req.params;
      const {
        totalBoxes,
        boxDescription,
        dispatcherName,
        collectorName,
        dispatcherSignature,
        collectorSignature,
        collectionDate
      } = req.body;

      // Check collection exists
      const [collections] = await db.query('SELECT * FROM collections WHERE collection_id = ?', [collectionId]);
      if (collections.length === 0) {
        throw new NotFoundError('Collection not found');
      }

      const oldCollection = collections[0];

      // Build update query dynamically
      const updates = [];
      const params = [];

      if (totalBoxes !== undefined) {
        updates.push('total_boxes = ?');
        params.push(totalBoxes);
      }

      if (boxDescription !== undefined) {
        updates.push('box_description = ?');
        params.push(boxDescription);
      }

      if (dispatcherName !== undefined) {
        updates.push('dispatcher_name = ?');
        params.push(dispatcherName);
      }

      if (collectorName !== undefined) {
        updates.push('collector_name = ?');
        params.push(collectorName);
      }

      if (dispatcherSignature !== undefined) {
        updates.push('dispatcher_signature = ?');
        params.push(dispatcherSignature);
      }

      if (collectorSignature !== undefined) {
        updates.push('collector_signature = ?');
        params.push(collectorSignature);
      }

      if (collectionDate !== undefined) {
        updates.push('collection_date = ?');
        params.push(collectionDate);
      }

      if (updates.length === 0) {
        throw new ValidationError('No fields to update');
      }

      params.push(collectionId);

      // Update collection
      await db.query(
        `UPDATE collections SET ${updates.join(', ')} WHERE collection_id = ?`,
        params
      );

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'UPDATE_COLLECTION',
        'collection',
        collectionId,
        oldCollection,
        { totalBoxes, boxDescription, dispatcherName, collectorName, collectionDate },
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Collection updated: ${collectionId} by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: 'Collection updated successfully'
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/collections/:collectionId/signatures
 * @desc    Update collection signatures
 * @access  Admin, Staff (with permission)
 */
router.patch('/:collectionId/signatures',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canCreateCollections'),
  async (req, res, next) => {
    try {
      const { collectionId } = req.params;
      const { dispatcherSignature, collectorSignature } = req.body;

      // Check collection exists
      const [collections] = await db.query('SELECT collection_id FROM collections WHERE collection_id = ?', [collectionId]);
      if (collections.length === 0) {
        throw new NotFoundError('Collection not found');
      }

      // Build update query
      const updates = [];
      const params = [];

      if (dispatcherSignature !== undefined) {
        updates.push('dispatcher_signature = ?');
        params.push(dispatcherSignature);
      }

      if (collectorSignature !== undefined) {
        updates.push('collector_signature = ?');
        params.push(collectorSignature);
      }

      if (updates.length === 0) {
        throw new ValidationError('At least one signature must be provided');
      }

      params.push(collectionId);

      // Update signatures
      await db.query(
        `UPDATE collections SET ${updates.join(', ')} WHERE collection_id = ?`,
        params
      );

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'UPDATE_COLLECTION_SIGNATURES',
        'collection',
        collectionId,
        null,
        { hasDispatcherSignature: !!dispatcherSignature, hasCollectorSignature: !!collectorSignature },
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Collection signatures updated: ${collectionId} by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: 'Signatures updated successfully'
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/collections/:collectionId/pdf
 * @desc    Update collection PDF path
 * @access  Admin, Staff
 */
router.patch('/:collectionId/pdf',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { collectionId } = req.params;
      const { pdfPath } = req.body;

      if (!pdfPath) {
        throw new ValidationError('PDF path is required');
      }

      // Check collection exists
      const [collections] = await db.query('SELECT collection_id FROM collections WHERE collection_id = ?', [collectionId]);
      if (collections.length === 0) {
        throw new NotFoundError('Collection not found');
      }

      // Update PDF path
      await db.query('UPDATE collections SET pdf_path = ? WHERE collection_id = ?', [pdfPath, collectionId]);

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'UPDATE_COLLECTION_PDF',
        'collection',
        collectionId,
        null,
        { pdfPath },
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Collection PDF path updated: ${collectionId} by ${req.user.username}`);

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
 * @route   DELETE /api/collections/:collectionId
 * @desc    Delete collection
 * @access  Admin (only)
 */
router.delete('/:collectionId',
  authorizeRoles('admin'),
  async (req, res, next) => {
    try {
      const { collectionId } = req.params;

      // Check collection exists
      const [collections] = await db.query('SELECT collection_id FROM collections WHERE collection_id = ?', [collectionId]);
      if (collections.length === 0) {
        throw new NotFoundError('Collection not found');
      }

      // Delete collection
      await db.query('DELETE FROM collections WHERE collection_id = ?', [collectionId]);

      // Create audit log
      await createAuditLog(
        req.user.userId,
        'DELETE_COLLECTION',
        'collection',
        collectionId,
        null,
        null,
        req.ip,
        req.get('user-agent')
      );

      logger.info(`Collection deleted: ${collectionId} by ${req.user.username}`);

      res.status(200).json({
        status: 'success',
        message: 'Collection deleted successfully'
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
 * @route   GET /api/collections/reports/summary
 * @desc    Get collections summary by date range
 * @access  Admin, Staff
 */
router.get('/reports/summary',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { startDate, endDate, clientId } = req.query;

      let query = `
        SELECT 
          DATE(collection_date) as date,
          COUNT(*) as collection_count,
          SUM(total_boxes) as total_boxes,
          COUNT(DISTINCT client_id) as unique_clients
        FROM collections
        WHERE 1=1
      `;

      const params = [];

      if (startDate) {
        query += ' AND collection_date >= ?';
        params.push(startDate);
      }

      if (endDate) {
        query += ' AND collection_date <= ?';
        params.push(endDate);
      }

      if (clientId) {
        query += ' AND client_id = ?';
        params.push(clientId);
      }

      query += ' GROUP BY DATE(collection_date) ORDER BY date DESC';

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
 * @route   GET /api/collections/reports/by-client
 * @desc    Get collections grouped by client
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
          COUNT(col.collection_id) as collection_count,
          SUM(col.total_boxes) as total_boxes_collected,
          MAX(col.collection_date) as last_collection_date
        FROM clients c
        LEFT JOIN collections col ON c.client_id = col.client_id
        WHERE 1=1
      `;

      const params = [];

      if (startDate) {
        query += ' AND col.collection_date >= ?';
        params.push(startDate);
      }

      if (endDate) {
        query += ' AND col.collection_date <= ?';
        params.push(endDate);
      }

      query += ' GROUP BY c.client_id, c.client_name, c.client_code ORDER BY total_boxes_collected DESC';

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