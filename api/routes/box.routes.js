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

/**
 * Generate unique box number
 */
const generateBoxNumber = async (clientCode, year) => {
  const [boxes] = await db.query(
    `SELECT box_number FROM boxes WHERE box_number LIKE ? ORDER BY box_number DESC LIMIT 1`,
    [`${clientCode}-%`]
  );
  
  let sequence = 1;
  if (boxes.length > 0) {
    const lastBoxNumber = boxes[0].box_number;
    const match = lastBoxNumber.match(/[A-Z]+-(\d+)/);
    if (match) {
      sequence = parseInt(match[1]) + 1;
    }
  }
  
  const paddedSequence = String(sequence).padStart(4, '0');
  return `${clientCode}-${paddedSequence}`;
};

// ============================================
// BOX CRUD ROUTES
// ============================================

/**
 * @route   GET /api/boxes
 * @desc    Get all boxes with filtering and pagination
 * @access  Admin, Staff
 */
router.get('/', 
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { 
        clientId, 
        status, 
        pendingDestruction,
        rackingLabelId,
        search, 
        page = 1, 
        limit = 50,
        sortBy = 'created_at',
        sortOrder = 'DESC'
      } = req.query;
      
      let query = `
        SELECT b.box_id, b.box_number, b.box_description, b.date_received, 
               b.year_received, b.retention_years, b.destruction_year, b.status,
               b.created_at, b.updated_at,
               c.client_id, c.client_name, c.client_code,
               r.label_id, r.label_code, r.location_description,
               CASE 
                 WHEN b.destruction_year IS NOT NULL AND b.destruction_year <= YEAR(CURDATE()) AND b.status = 'stored'
                 THEN TRUE 
                 ELSE FALSE 
               END as is_pending_destruction
        FROM boxes b
        LEFT JOIN clients c ON b.client_id = c.client_id
        LEFT JOIN racking_labels r ON b.racking_label_id = r.label_id
        WHERE 1=1
      `;
      
      const params = [];
      
      // Apply filters
      if (clientId) {
        query += ' AND b.client_id = ?';
        params.push(clientId);
      }
      
      if (status) {
        query += ' AND b.status = ?';
        params.push(status);
      }
      
      if (rackingLabelId) {
        query += ' AND b.racking_label_id = ?';
        params.push(rackingLabelId);
      }
      
      if (pendingDestruction === 'true') {
        query += ' AND b.destruction_year <= YEAR(CURDATE()) AND b.status = ?';
        params.push('stored');
      }
      
      if (search) {
        query += ' AND (b.box_number LIKE ? OR b.box_description LIKE ? OR c.client_name LIKE ?)';
        const searchPattern = `%${search}%`;
        params.push(searchPattern, searchPattern, searchPattern);
      }
      
      // FIX: Create a separate count query instead of using string replacement
      let countQuery = `
        SELECT COUNT(*) as total
        FROM boxes b
        LEFT JOIN clients c ON b.client_id = c.client_id
        LEFT JOIN racking_labels r ON b.racking_label_id = r.label_id
        WHERE 1=1
      `;
      
      const countParams = [];
      
      // Apply the same filters to count query
      if (clientId) {
        countQuery += ' AND b.client_id = ?';
        countParams.push(clientId);
      }
      
      if (status) {
        countQuery += ' AND b.status = ?';
        countParams.push(status);
      }
      
      if (rackingLabelId) {
        countQuery += ' AND b.racking_label_id = ?';
        countParams.push(rackingLabelId);
      }
      
      if (pendingDestruction === 'true') {
        countQuery += ' AND b.destruction_year <= YEAR(CURDATE()) AND b.status = ?';
        countParams.push('stored');
      }
      
      if (search) {
        countQuery += ' AND (b.box_number LIKE ? OR b.box_description LIKE ? OR c.client_name LIKE ?)';
        const searchPattern = `%${search}%`;
        countParams.push(searchPattern, searchPattern, searchPattern);
      }
      
      // Execute count query
      const [countResult] = await db.query(countQuery, countParams);
      const total = countResult && countResult[0] ? countResult[0].total : 0;
      
      // Add sorting
      const validSortFields = ['box_number', 'date_received', 'destruction_year', 'created_at', 'status'];
      const sortField = validSortFields.includes(sortBy) ? sortBy : 'created_at';
      const order = sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';
      query += ` ORDER BY b.${sortField} ${order}`;
      
      // Add pagination
      const offset = (page - 1) * limit;
      query += ' LIMIT ? OFFSET ?';
      params.push(parseInt(limit), offset);
      
      const [boxes] = await db.query(query, params);
      
      const formattedBoxes = boxes.map(box => ({
        boxId: box.box_id,
        boxNumber: box.box_number,
        description: box.box_description,
        dateReceived: box.date_received,
        yearReceived: box.year_received,
        retentionYears: box.retention_years,
        destructionYear: box.destruction_year,
        status: box.status,
        isPendingDestruction: Boolean(box.is_pending_destruction),
        client: {
          clientId: box.client_id,
          clientName: box.client_name,
          clientCode: box.client_code
        },
        rackingLabel: box.label_id ? {
          labelId: box.label_id,
          labelCode: box.label_code,
          location: box.location_description
        } : null,
        createdAt: box.created_at,
        updatedAt: box.updated_at
      }));
      
      res.status(200).json({
        status: 'success',
        data: {
          boxes: formattedBoxes,
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
 * @route   GET /api/boxes/stats
 * @desc    Get box statistics
 * @access  Admin, Staff
 */
router.get('/stats',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const [stats] = await db.query(`
        SELECT 
          COUNT(*) as total_boxes,
          SUM(CASE WHEN status = 'stored' THEN 1 ELSE 0 END) as boxes_stored,
          SUM(CASE WHEN status = 'retrieved' THEN 1 ELSE 0 END) as boxes_retrieved,
          SUM(CASE WHEN status = 'destroyed' THEN 1 ELSE 0 END) as boxes_destroyed,
          SUM(CASE WHEN destruction_year <= YEAR(CURDATE()) AND status = 'stored' THEN 1 ELSE 0 END) as boxes_pending_destruction,
          COUNT(DISTINCT client_id) as total_clients_with_boxes
        FROM boxes
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
 * @route   GET /api/boxes/pending-destruction
 * @desc    Get boxes pending destruction
 * @access  Admin, Staff
 */
router.get('/pending-destruction',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const [boxes] = await db.query(`
        SELECT b.box_id, b.box_number, b.box_description, b.destruction_year,
               b.year_received, b.retention_years,
               c.client_id, c.client_name, c.client_code,
               r.label_code, r.location_description
        FROM boxes b
        LEFT JOIN clients c ON b.client_id = c.client_id
        LEFT JOIN racking_labels r ON b.racking_label_id = r.label_id
        WHERE b.destruction_year <= YEAR(CURDATE()) 
        AND b.status = 'stored'
        ORDER BY b.destruction_year ASC, b.box_number ASC
      `);
      
      const formattedBoxes = boxes.map(box => ({
        boxId: box.box_id,
        boxNumber: box.box_number,
        description: box.box_description,
        yearReceived: box.year_received,
        retentionYears: box.retention_years,
        destructionYear: box.destruction_year,
        yearsOverdue: new Date().getFullYear() - box.destruction_year,
        client: {
          clientId: box.client_id,
          clientName: box.client_name,
          clientCode: box.client_code
        },
        rackingLabel: {
          labelCode: box.label_code,
          location: box.location_description
        }
      }));
      
      res.status(200).json({
        status: 'success',
        data: {
          count: formattedBoxes.length,
          boxes: formattedBoxes
        }
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/boxes/client/:clientId
 * @desc    Get all boxes for a specific client
 * @access  Admin, Staff, Client (own boxes only)
 */
router.get('/client/:clientId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { clientId } = req.params;
      
      // If user is client, ensure they can only access their own boxes
      if (req.user.role === 'client' && req.user.clientId !== parseInt(clientId)) {
        throw new ValidationError('You can only access your own boxes');
      }
      
      const [boxes] = await db.query(`
        SELECT b.box_id, b.box_number, b.box_description, b.date_received,
               b.status, b.destruction_year,
               r.label_code, r.location_description
        FROM boxes b
        LEFT JOIN racking_labels r ON b.racking_label_id = r.label_id
        WHERE b.client_id = ?
        ORDER BY b.created_at DESC
      `, [clientId]);
      
      const formattedBoxes = boxes.map(box => ({
        boxId: box.box_id,
        boxNumber: box.box_number,
        description: box.box_description,
        dateReceived: box.date_received,
        status: box.status,
        destructionYear: box.destruction_year,
        rackingLabel: box.label_code ? {
          labelCode: box.label_code,
          location: box.location_description
        } : null
      }));
      
      res.status(200).json({
        status: 'success',
        data: {
          clientId: parseInt(clientId),
          count: formattedBoxes.length,
          boxes: formattedBoxes
        }
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/boxes/:boxId
 * @desc    Get single box by ID
 * @access  Admin, Staff, Client (own boxes only)
 */
router.get('/:boxId',
  authorizeRoles('admin', 'staff', 'client'),
  async (req, res, next) => {
    try {
      const { boxId } = req.params;
      
      const [boxes] = await db.query(`
        SELECT b.*, 
               c.client_name, c.client_code, c.contact_person, c.email as client_email, c.phone as client_phone,
               r.label_code, r.location_description, r.is_available
        FROM boxes b
        LEFT JOIN clients c ON b.client_id = c.client_id
        LEFT JOIN racking_labels r ON b.racking_label_id = r.label_id
        WHERE b.box_id = ?
      `, [boxId]);
      
      if (boxes.length === 0) {
        throw new NotFoundError('Box not found');
      }
      
      const box = boxes[0];
      
      // If user is client, ensure they can only access their own boxes
      if (req.user.role === 'client' && req.user.clientId !== box.client_id) {
        throw new ValidationError('You can only access your own boxes');
      }
      
      const formattedBox = {
        boxId: box.box_id,
        boxNumber: box.box_number,
        description: box.box_description,
        dateReceived: box.date_received,
        yearReceived: box.year_received,
        retentionYears: box.retention_years,
        destructionYear: box.destruction_year,
        status: box.status,
        isPendingDestruction: box.destruction_year && box.destruction_year <= new Date().getFullYear() && box.status === 'stored',
        client: {
          clientId: box.client_id,
          clientName: box.client_name,
          clientCode: box.client_code,
          contactPerson: box.contact_person,
          email: box.client_email,
          phone: box.client_phone
        },
        rackingLabel: box.racking_label_id ? {
          labelId: box.racking_label_id,
          labelCode: box.label_code,
          location: box.location_description,
          isAvailable: Boolean(box.is_available)
        } : null,
        createdAt: box.created_at,
        updatedAt: box.updated_at
      };
      
      res.status(200).json({
        status: 'success',
        data: formattedBox
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   POST /api/boxes
 * @desc    Create new box with client-coded box number
 * @access  Admin, Staff (with permission)
 */
router.post('/',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canCreateBoxes'),
  async (req, res, next) => {
    try {
      const { 
        clientId, 
        rackingLabelId, 
        boxIndex,  // User-provided index/suffix (e.g., "001", "001-A", "2024-001")
        boxDescription, 
        dateReceived, 
        retentionYears = 7 
      } = req.body;
      
      // Validate required fields
      if (!clientId || !dateReceived || !boxIndex) {
        throw new ValidationError('Client ID, date received, and box index are required');
      }
      
      // Validate box index format
      if (typeof boxIndex !== 'string' || boxIndex.trim().length === 0) {
        throw new ValidationError('Box index must be a non-empty string');
      }
      
      // Check client exists and get client code
      const [clients] = await db.query('SELECT client_code FROM clients WHERE client_id = ?', [clientId]);
      if (clients.length === 0) {
        throw new NotFoundError('Client not found');
      }
      
      const clientCode = clients[0].client_code;
      const formattedBoxIndex = boxIndex.trim().toUpperCase();
      const boxNumber = `${clientCode}-${formattedBoxIndex}`;
      
      // Check if box number already exists
      const [existingBoxes] = await db.query(
        'SELECT box_id FROM boxes WHERE box_number = ?',
        [boxNumber]
      );
      
      if (existingBoxes.length > 0) {
        throw new ValidationError(`Box number '${boxNumber}' already exists`);
      }
      
      // Check racking label exists and is available
      if (rackingLabelId) {
        const [labels] = await db.query(
          'SELECT label_id, is_available FROM racking_labels WHERE label_id = ?', 
          [rackingLabelId]
        );
        if (labels.length === 0) {
          throw new NotFoundError('Racking label not found');
        }
        if (!labels[0].is_available) {
          throw new ValidationError('Racking label is not available');
        }
      }
      
      // Extract year from dateReceived
      const receivedDate = new Date(dateReceived);
      const yearReceived = receivedDate.getFullYear();
      
      // Insert box (trigger will auto-calculate destruction_year)
      const [result] = await db.query(`
        INSERT INTO boxes (
          box_number, client_id, racking_label_id, box_description,
          date_received, year_received, retention_years, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'stored')
      `, [boxNumber, clientId, rackingLabelId || null, boxDescription, dateReceived, yearReceived, retentionYears]);
      
      const boxId = result.insertId;
      
      // Create audit log
      await createAuditLog(
        req.user.userId,
        'CREATE_BOX',
        'box',
        boxId,
        null,
        { boxNumber, clientId, boxIndex: formattedBoxIndex, rackingLabelId, retentionYears },
        req.ip,
        req.get('user-agent')
      );
      
      logger.info(`Box created: ${boxNumber} for client ${clientId} by ${req.user.username}`);
      
      res.status(201).json({
        status: 'success',
        message: 'Box created successfully',
        data: {
          boxId,
          boxNumber,
          boxIndex: formattedBoxIndex,
          clientId,
          rackingLabelId: rackingLabelId || null,
          description: boxDescription,
          dateReceived,
          yearReceived,
          retentionYears,
          destructionYear: yearReceived + retentionYears,
          status: 'stored'
        }
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PUT /api/boxes/:boxId
 * @desc    Update box details
 * @access  Admin, Staff (with permission)
 */
router.put('/:boxId',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canEditBoxes'),
  async (req, res, next) => {
    try {
      const { boxId } = req.params;
      const { boxDescription, rackingLabelId, retentionYears } = req.body;
      
      // Check box exists
      const [boxes] = await db.query('SELECT * FROM boxes WHERE box_id = ?', [boxId]);
      if (boxes.length === 0) {
        throw new NotFoundError('Box not found');
      }
      
      const oldBox = boxes[0];
      
      // Check racking label if provided
      if (rackingLabelId) {
        const [labels] = await db.query(
          'SELECT label_id, is_available FROM racking_labels WHERE label_id = ?', 
          [rackingLabelId]
        );
        if (labels.length === 0) {
          throw new NotFoundError('Racking label not found');
        }
      }
      
      // Build update query dynamically
      const updates = [];
      const params = [];
      
      if (boxDescription !== undefined) {
        updates.push('box_description = ?');
        params.push(boxDescription);
      }
      
      if (rackingLabelId !== undefined) {
        updates.push('racking_label_id = ?');
        params.push(rackingLabelId || null);
      }
      
      if (retentionYears !== undefined) {
        updates.push('retention_years = ?');
        params.push(retentionYears);
      }
      
      if (updates.length === 0) {
        throw new ValidationError('No fields to update');
      }
      
      params.push(boxId);
      
      // Update box (trigger will recalculate destruction_year if retention_years changed)
      await db.query(
        `UPDATE boxes SET ${updates.join(', ')} WHERE box_id = ?`,
        params
      );
      
      // Create audit log
      await createAuditLog(
        req.user.userId,
        'UPDATE_BOX',
        'box',
        boxId,
        { 
          box_description: oldBox.box_description, 
          racking_label_id: oldBox.racking_label_id,
          retention_years: oldBox.retention_years
        },
        { boxDescription, rackingLabelId, retentionYears },
        req.ip,
        req.get('user-agent')
      );
      
      logger.info(`Box updated: ${oldBox.box_number} by ${req.user.username}`);
      
      res.status(200).json({
        status: 'success',
        message: 'Box updated successfully'
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/boxes/:boxId/status
 * @desc    Change box status
 * @access  Admin, Staff (with permission)
 */
router.patch('/:boxId/status',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { boxId } = req.params;
      const { status } = req.body;
      
      // Validate status
      if (!['stored', 'retrieved', 'destroyed'].includes(status)) {
        throw new ValidationError('Invalid status. Must be stored, retrieved, or destroyed');
      }
      
      // Check box exists
      const [boxes] = await db.query('SELECT box_number, status FROM boxes WHERE box_id = ?', [boxId]);
      if (boxes.length === 0) {
        throw new NotFoundError('Box not found');
      }
      
      const oldStatus = boxes[0].status;
      
      // Update status
      await db.query('UPDATE boxes SET status = ? WHERE box_id = ?', [status, boxId]);
      
      // Create audit log
      await createAuditLog(
        req.user.userId,
        'CHANGE_BOX_STATUS',
        'box',
        boxId,
        { status: oldStatus },
        { status },
        req.ip,
        req.get('user-agent')
      );
      
      logger.info(`Box ${boxes[0].box_number} status changed from ${oldStatus} to ${status} by ${req.user.username}`);
      
      res.status(200).json({
        status: 'success',
        message: `Box status changed to ${status}`,
        data: {
          boxId: parseInt(boxId),
          oldStatus,
          newStatus: status
        }
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   DELETE /api/boxes/:boxId
 * @desc    Delete box
 * @access  Admin, Staff (with permission)
 */
router.delete('/:boxId',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canDeleteBoxes'),
  async (req, res, next) => {
    try {
      const { boxId } = req.params;
      
      // Check box exists
      const [boxes] = await db.query('SELECT box_number FROM boxes WHERE box_id = ?', [boxId]);
      if (boxes.length === 0) {
        throw new NotFoundError('Box not found');
      }
      
      const boxNumber = boxes[0].box_number;
      
      // Delete box
      await db.query('DELETE FROM boxes WHERE box_id = ?', [boxId]);
      
      // Create audit log
      await createAuditLog(
        req.user.userId,
        'DELETE_BOX',
        'box',
        boxId,
        { box_number: boxNumber },
        null,
        req.ip,
        req.get('user-agent')
      );
      
      logger.info(`Box deleted: ${boxNumber} by ${req.user.username}`);
      
      res.status(200).json({
        status: 'success',
        message: 'Box deleted successfully'
      });
      
    } catch (error) {
      next(error);
    }
  }
);

// ============================================
// BULK OPERATIONS
// ============================================

/**
 * @route   POST /api/boxes/bulk/create
 * @desc    Bulk create boxes with client-coded box numbers
 * @access  Admin, Staff (with permission)
 */
router.post('/bulk/create',
  authorizeRoles('admin', 'staff'),
  authorizePermission('canCreateBoxes'),
  async (req, res, next) => {
    try {
      const { boxes } = req.body;
      
      if (!Array.isArray(boxes) || boxes.length === 0) {
        throw new ValidationError('Boxes array is required and must not be empty');
      }
      
      const results = {
        success: [],
        failed: []
      };
      
      // First, get client codes for all boxes to avoid multiple queries
      const clientIds = [...new Set(boxes.map(b => b.clientId))];
      const [clientRecords] = await db.query(
        'SELECT client_id, client_code FROM clients WHERE client_id IN (?)',
        [clientIds]
      );
      
      const clientMap = new Map();
      clientRecords.forEach(client => {
        clientMap.set(client.client_id, client.client_code);
      });
      
      // Also check existing box numbers in batch
      const proposedBoxNumbers = [];
      const clientBoxMap = new Map(); // clientCode -> [boxIndices]
      
      for (const boxData of boxes) {
        const { clientId, boxIndex } = boxData;
        
        if (!clientMap.has(clientId)) {
          results.failed.push({
            clientId,
            boxIndex,
            error: 'Client not found'
          });
          continue;
        }
        
        const clientCode = clientMap.get(clientId);
        const formattedBoxIndex = boxIndex ? boxIndex.trim().toUpperCase() : null;
        
        if (!formattedBoxIndex) {
          results.failed.push({
            clientId,
            boxIndex,
            error: 'Box index is required'
          });
          continue;
        }
        
        const boxNumber = `${clientCode}-${formattedBoxIndex}`;
        proposedBoxNumbers.push(boxNumber);
        
        if (!clientBoxMap.has(clientCode)) {
          clientBoxMap.set(clientCode, new Set());
        }
        
        const clientBoxIndices = clientBoxMap.get(clientCode);
        if (clientBoxIndices.has(formattedBoxIndex)) {
          results.failed.push({
            clientId,
            boxIndex: formattedBoxIndex,
            error: `Duplicate box index '${formattedBoxIndex}' for client ${clientCode} in request`
          });
        } else {
          clientBoxIndices.add(formattedBoxIndex);
        }
      }
      
      // Check existing box numbers in database
      if (proposedBoxNumbers.length > 0) {
        const [existingBoxes] = await db.query(
          'SELECT box_number FROM boxes WHERE box_number IN (?)',
          [proposedBoxNumbers]
        );
        
        const existingSet = new Set(existingBoxes.map(b => b.box_number));
        
        // Process each box
        for (const boxData of boxes) {
          try {
            const { clientId, rackingLabelId, boxIndex, boxDescription, dateReceived, retentionYears = 7 } = boxData;
            
            // Skip if already marked as failed
            if (results.failed.some(f => f.clientId === clientId && f.boxIndex === boxIndex)) {
              continue;
            }
            
            const clientCode = clientMap.get(clientId);
            const formattedBoxIndex = boxIndex.trim().toUpperCase();
            const boxNumber = `${clientCode}-${formattedBoxIndex}`;
            
            // Check if box number already exists in database
            if (existingSet.has(boxNumber)) {
              throw new Error(`Box number '${boxNumber}' already exists`);
            }
            
            // Check racking label if provided
            if (rackingLabelId) {
              const [labels] = await db.query(
                'SELECT label_id, is_available FROM racking_labels WHERE label_id = ?', 
                [rackingLabelId]
              );
              if (labels.length === 0) {
                throw new Error('Racking label not found');
              }
              if (!labels[0].is_available) {
                throw new Error('Racking label is not available');
              }
            }
            
            const receivedDate = new Date(dateReceived);
            const yearReceived = receivedDate.getFullYear();
            
            // Insert box
            const [result] = await db.query(`
              INSERT INTO boxes (
                box_number, client_id, racking_label_id, box_description,
                date_received, year_received, retention_years, status
              ) VALUES (?, ?, ?, ?, ?, ?, ?, 'stored')
            `, [boxNumber, clientId, rackingLabelId || null, boxDescription, dateReceived, yearReceived, retentionYears]);
            
            results.success.push({ 
              boxNumber, 
              boxId: result.insertId,
              boxIndex: formattedBoxIndex 
            });
            
          } catch (error) {
            results.failed.push({ 
              clientId: boxData.clientId, 
              boxIndex: boxData.boxIndex,
              error: error.message 
            });
          }
        }
      }
      
      // Create audit log
      await createAuditLog(
        req.user.userId,
        'BULK_CREATE_BOXES',
        'box',
        null,
        null,
        { success: results.success.length, failed: results.failed.length },
        req.ip,
        req.get('user-agent')
      );
      
      logger.info(`Bulk create: ${results.success.length} boxes created, ${results.failed.length} failed by ${req.user.username}`);
      
      res.status(201).json({
        status: 'success',
        message: 'Bulk box creation completed',
        data: results
      });
      
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   PATCH /api/boxes/bulk/status
 * @desc    Bulk update box status
 * @access  Admin, Staff
 */
router.patch('/bulk/status',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { boxIds, status } = req.body;
      
      if (!Array.isArray(boxIds) || boxIds.length === 0) {
        throw new ValidationError('boxIds array is required and must not be empty');
      }
      
      if (!['stored', 'retrieved', 'destroyed'].includes(status)) {
        throw new ValidationError('Invalid status');
      }
      
      const placeholders = boxIds.map(() => '?').join(',');
      await db.query(`UPDATE boxes SET status = ? WHERE box_id IN (${placeholders})`, [status, ...boxIds]);
      
      // Create audit log
      await createAuditLog(
        req.user.userId,
        'BULK_UPDATE_BOX_STATUS',
        'box',
        null,
        null,
        { boxIds, status, count: boxIds.length },
        req.ip,
        req.get('user-agent')
      );
      
      logger.info(`Bulk status update: ${boxIds.length} boxes set to ${status} by ${req.user.username}`);
      
      res.status(200).json({
        status: 'success',
        message: `${boxIds.length} boxes updated to ${status} status`
      });
      
    } catch (error) {
      next(error);
    }
  }
);

// ==========================================
// REPORT ROUTES
// ==========================================

/**
 * @route   GET /api/boxes/report/single
 * @desc    Generate a box report, optionally filtered by client (single client)
 * @access  Admin, Staff
 */
router.get('/report/single',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { clientId } = req.query;

      // Build query
      let query = `
        SELECT 
          b.box_number,
          b.box_description,
          b.date_received,
          b.year_received,
          b.destruction_year,
          b.status,
          c.client_id,
          c.client_name,
          c.client_code,
          r.label_code AS rack_label,
          r.location_description AS rack_location
        FROM boxes b
        LEFT JOIN clients c ON b.client_id = c.client_id
        LEFT JOIN racking_labels r ON b.racking_label_id = r.label_id
        WHERE 1=1
      `;
      const params = [];

      if (clientId) {
        query += ' AND b.client_id = ?';
        params.push(clientId);
      }

      query += ' ORDER BY c.client_name, b.box_number';

      const [rows] = await db.query(query, params);

      // Format the report data (similar to the image provided)
      const reportData = rows.map(row => ({
        boxNumber: row.box_number,
        boxSize: 'A3',   // default, can be adjusted or derived from rack label if needed
        description: row.box_description,
        datesRange: row.date_received 
          ? new Date(row.date_received).toLocaleDateString('en-GB', { month: 'short', year: 'numeric' })
          : null,
        dataYears: row.year_received,
        destructionYear: row.destruction_year,
        status: row.status,
        rackLabel: row.rack_label,
        rackLocation: row.rack_location,
        client: {
          clientId: row.client_id,
          clientName: row.client_name,
          clientCode: row.client_code
        }
      }));

      // Audit log
      await createAuditLog(
        req.user.userId,
        'GENERATE_BOX_REPORT',
        'report',
        null,
        null,
        { clientId: clientId || 'all', count: reportData.length },
        req.ip,
        req.get('user-agent')
      );

      res.status(200).json({
        status: 'success',
        data: {
          generatedAt: new Date().toISOString(),
          filters: {
            clientId: clientId || null
          },
          boxes: reportData
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route   GET /api/boxes/report/bulk
 * @desc    Generate a bulk box report for multiple clients, with grouping and summaries
 * @access  Admin, Staff
 */
router.get('/report/bulk',
  authorizeRoles('admin', 'staff'),
  async (req, res, next) => {
    try {
      const { clientIds } = req.query;
      
      // Parse clientIds into an array of integers if provided
      let clientIdArray = [];
      if (clientIds) {
        clientIdArray = clientIds.split(',').map(id => parseInt(id.trim())).filter(id => !isNaN(id));
        if (clientIdArray.length === 0) {
          throw new ValidationError('Invalid clientIds format. Provide comma-separated numbers.');
        }
      }

      // Build base query to fetch boxes with client and racking label info
      let query = `
        SELECT 
          b.box_id,
          b.box_number,
          b.box_description,
          b.date_received,
          b.year_received,
          b.retention_years,
          b.destruction_year,
          b.status,
          c.client_id,
          c.client_name,
          c.client_code,
          r.label_code AS rack_label,
          r.location_description AS rack_location
        FROM boxes b
        LEFT JOIN clients c ON b.client_id = c.client_id
        LEFT JOIN racking_labels r ON b.racking_label_id = r.label_id
      `;
      
      const params = [];
      
      if (clientIdArray.length > 0) {
        query += ' WHERE b.client_id IN (?)';
        params.push(clientIdArray);
      }
      
      query += ' ORDER BY c.client_name, b.box_number';
      
      const [rows] = await db.query(query, params);

      // Group boxes by client
      const clientsMap = new Map();
      
      rows.forEach(row => {
        const clientId = row.client_id;
        if (!clientsMap.has(clientId)) {
          clientsMap.set(clientId, {
            clientId: row.client_id,
            clientName: row.client_name,
            clientCode: row.client_code,
            boxes: [],
            summary: {
              totalBoxes: 0,
              stored: 0,
              retrieved: 0,
              destroyed: 0,
              pendingDestruction: 0
            }
          });
        }
        
        const clientData = clientsMap.get(clientId);
        
        // Format box data similar to the image report
        const box = {
          boxNumber: row.box_number,
          boxSize: 'A3', // default
          description: row.box_description || '',
          datesRange: row.date_received 
            ? new Date(row.date_received).toLocaleDateString('en-GB', { month: 'short', year: 'numeric' })
            : '',
          dataYears: row.year_received ? row.year_received.toString() : '',
          destructionYear: row.destruction_year,
          status: row.status,
          rackLabel: row.rack_label,
          rackLocation: row.rack_location
        };
        
        clientData.boxes.push(box);
        
        // Update summary counts
        clientData.summary.totalBoxes++;
        if (row.status === 'stored') clientData.summary.stored++;
        else if (row.status === 'retrieved') clientData.summary.retrieved++;
        else if (row.status === 'destroyed') clientData.summary.destroyed++;
        
        // Check if pending destruction (destruction year <= current year and status = stored)
        if (row.destruction_year && row.destruction_year <= new Date().getFullYear() && row.status === 'stored') {
          clientData.summary.pendingDestruction++;
        }
      });

      // Convert map to array for output
      const clients = Array.from(clientsMap.values());

      // Overall totals
      const totalClients = clients.length;
      const totalBoxes = rows.length;

      // Audit log
      await createAuditLog(
        req.user.userId,
        'GENERATE_BULK_BOX_REPORT',
        'report',
        null,
        null,
        { clientIds: clientIdArray.length ? clientIdArray : 'all', count: totalBoxes },
        req.ip,
        req.get('user-agent')
      );

      res.status(200).json({
        status: 'success',
        data: {
          generatedAt: new Date().toISOString(),
          filters: {
            clientIds: clientIdArray.length ? clientIdArray : 'all'
          },
          summary: {
            totalClients,
            totalBoxes
          },
          clients
        }
      });

    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;