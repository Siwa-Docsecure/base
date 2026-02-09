const express = require('express');
const db = require('../config/db');
const { authenticateToken, authorizeRoles, authorizePermission } = require('../middleware/Auth.middleware');
const logger = require('../utils/logger');

const router = express.Router();

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
 * Validate email format
 */
const isValidEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

/**
 * Validate phone format (Eswatini format)
 */
const isValidPhone = (phone) => {
  // Allow formats: +268-XXXX-XXXX, +268XXXXXXXX, or local format
  const phoneRegex = /^(\+268[-\s]?)?[0-9]{4}[-\s]?[0-9]{4}$/;
  return phoneRegex.test(phone);
};

/**
 * Generate unique client code
 */
const generateClientCode = async () => {
  const [result] = await db.query(
    'SELECT client_code FROM clients ORDER BY client_id DESC LIMIT 1'
  );
  
  if (result.length === 0) {
    return 'CLI-001';
  }
  
  const lastCode = result[0].client_code;
  const lastNumber = parseInt(lastCode.split('-')[1]);
  const newNumber = (lastNumber + 1).toString().padStart(3, '0');
  return `CLI-${newNumber}`;
};

/**
 * Check if client code exists
 */
const clientCodeExists = async (clientCode, excludeClientId = null) => {
  let query = 'SELECT client_id FROM clients WHERE client_code = ?';
  const params = [clientCode];
  
  if (excludeClientId) {
    query += ' AND client_id != ?';
    params.push(excludeClientId);
  }
  
  const [result] = await db.query(query, params);
  return result.length > 0;
};

/**
 * Check if client email exists
 */
const clientEmailExists = async (email, excludeClientId = null) => {
  let query = 'SELECT client_id FROM clients WHERE email = ?';
  const params = [email];
  
  if (excludeClientId) {
    query += ' AND client_id != ?';
    params.push(excludeClientId);
  }
  
  const [result] = await db.query(query, params);
  return result.length > 0;
};

// ============================================
// ROUTES
// ============================================

/**
 * @route   GET /api/clients
 * @desc    Get all clients with filtering, sorting, and pagination
 * @access  Private (Admin, Staff)
 */
router.get('/', authenticateToken, authorizeRoles('admin', 'staff'), async (req, res, next) => {
  try {
    const {
      page = 1,
      limit = 10,
      sortBy = 'created_at',
      sortOrder = 'DESC',
      search = '',
      isActive = null,
      includeInactive = 'false'
    } = req.query;

    // Calculate offset
    const offset = (parseInt(page) - 1) * parseInt(limit);

    // Build WHERE clause
    let whereConditions = [];
    let queryParams = [];

    if (search) {
      whereConditions.push(`(
        c.client_name LIKE ? OR 
        c.client_code LIKE ? OR 
        c.contact_person LIKE ? OR 
        c.email LIKE ? OR 
        c.phone LIKE ?
      )`);
      const searchTerm = `%${search}%`;
      queryParams.push(searchTerm, searchTerm, searchTerm, searchTerm, searchTerm);
    }

    if (isActive !== null && isActive !== '') {
      whereConditions.push('c.is_active = ?');
      queryParams.push(isActive === 'true' ? 1 : 0);
    } else if (includeInactive === 'false') {
      whereConditions.push('c.is_active = TRUE');
    }

    const whereClause = whereConditions.length > 0 
      ? `WHERE ${whereConditions.join(' AND ')}` 
      : '';

    // Validate sortBy to prevent SQL injection
    const allowedSortFields = ['client_name', 'client_code', 'contact_person', 'email', 'created_at', 'updated_at'];
    const safeSortBy = allowedSortFields.includes(sortBy) ? sortBy : 'created_at';
    const safeSortOrder = sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

    // Get total count
    const countQuery = `
      SELECT COUNT(*) as total
      FROM clients c
      ${whereClause}
    `;
    const [[{ total }]] = await db.query(countQuery, queryParams);

    // Get clients with related data
    const query = `
      SELECT 
        c.*,
        COUNT(DISTINCT u.user_id) as user_count,
        COUNT(DISTINCT b.box_id) as box_count,
        COUNT(DISTINCT CASE WHEN b.status = 'stored' THEN b.box_id END) as stored_boxes,
        COUNT(DISTINCT CASE WHEN b.status = 'retrieved' THEN b.box_id END) as retrieved_boxes,
        COUNT(DISTINCT CASE WHEN b.status = 'destroyed' THEN b.box_id END) as destroyed_boxes
      FROM clients c
      LEFT JOIN users u ON c.client_id = u.client_id AND u.is_active = TRUE
      LEFT JOIN boxes b ON c.client_id = b.client_id
      ${whereClause}
      GROUP BY c.client_id
      ORDER BY c.${safeSortBy} ${safeSortOrder}
      LIMIT ? OFFSET ?
    `;
    
    queryParams.push(parseInt(limit), offset);
    const [clients] = await db.query(query, queryParams);

    // Format response
    const formattedClients = clients.map(client => ({
      clientId: client.client_id,
      clientName: client.client_name,
      clientCode: client.client_code,
      contactPerson: client.contact_person,
      email: client.email,
      phone: client.phone,
      address: client.address,
      isActive: Boolean(client.is_active),
      userCount: client.user_count,
      boxCount: client.box_count,
      storedBoxes: client.stored_boxes,
      retrievedBoxes: client.retrieved_boxes,
      destroyedBoxes: client.destroyed_boxes,
      createdAt: client.created_at,
      updatedAt: client.updated_at
    }));

    res.status(200).json({
      status: 'success',
      data: {
        clients: formattedClients,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(total / parseInt(limit)),
          totalItems: total,
          itemsPerPage: parseInt(limit)
        }
      }
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   GET /api/clients/:id
 * @desc    Get single client details
 * @access  Private (Admin, Staff, or Own Client)
 */
router.get('/:id', authenticateToken, async (req, res, next) => {
  try {
    const { id } = req.params;

    // Check permissions - client users can only view their own client
    if (req.user.role === 'client' && req.user.clientId !== parseInt(id)) {
      return res.status(403).json({
        status: 'error',
        message: 'You do not have permission to view this client'
      });
    }

    // Get client with detailed information
    const query = `
      SELECT 
        c.*,
        COUNT(DISTINCT u.user_id) as user_count,
        COUNT(DISTINCT b.box_id) as total_boxes,
        COUNT(DISTINCT CASE WHEN b.status = 'stored' THEN b.box_id END) as stored_boxes,
        COUNT(DISTINCT CASE WHEN b.status = 'retrieved' THEN b.box_id END) as retrieved_boxes,
        COUNT(DISTINCT CASE WHEN b.status = 'destroyed' THEN b.box_id END) as destroyed_boxes,
        COUNT(DISTINCT col.collection_id) as total_collections,
        COUNT(DISTINCT ret.retrieval_id) as total_retrievals,
        COUNT(DISTINCT del.delivery_id) as total_deliveries,
        COUNT(DISTINCT req.request_id) as total_requests,
        COUNT(DISTINCT CASE WHEN req.status = 'pending' THEN req.request_id END) as pending_requests
      FROM clients c
      LEFT JOIN users u ON c.client_id = u.client_id AND u.is_active = TRUE
      LEFT JOIN boxes b ON c.client_id = b.client_id
      LEFT JOIN collections col ON c.client_id = col.client_id
      LEFT JOIN retrievals ret ON c.client_id = ret.client_id
      LEFT JOIN deliveries del ON c.client_id = del.client_id
      LEFT JOIN requests req ON c.client_id = req.client_id
      WHERE c.client_id = ?
      GROUP BY c.client_id
    `;

    const [clients] = await db.query(query, [id]);

    if (clients.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Client not found'
      });
    }

    const client = clients[0];

    // Format response
    const clientDetails = {
      clientId: client.client_id,
      clientName: client.client_name,
      clientCode: client.client_code,
      contactPerson: client.contact_person,
      email: client.email,
      phone: client.phone,
      address: client.address,
      isActive: Boolean(client.is_active),
      statistics: {
        userCount: client.user_count,
        totalBoxes: client.total_boxes,
        storedBoxes: client.stored_boxes,
        retrievedBoxes: client.retrieved_boxes,
        destroyedBoxes: client.destroyed_boxes,
        totalCollections: client.total_collections,
        totalRetrievals: client.total_retrievals,
        totalDeliveries: client.total_deliveries,
        totalRequests: client.total_requests,
        pendingRequests: client.pending_requests
      },
      createdAt: client.created_at,
      updatedAt: client.updated_at
    };

    res.status(200).json({
      status: 'success',
      data: clientDetails
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   POST /api/clients
 * @desc    Create new client
 * @access  Private (Admin, Staff)
 */
router.post('/', authenticateToken, authorizeRoles('admin', 'staff'), async (req, res, next) => {
  try {
    const {
      clientName,
      clientCode,
      contactPerson,
      email,
      phone,
      address
    } = req.body;

    // Validation
    if (!clientName || !contactPerson) {
      return res.status(400).json({
        status: 'error',
        message: 'Client name and contact person are required'
      });
    }

    if (email && !isValidEmail(email)) {
      return res.status(400).json({
        status: 'error',
        message: 'Invalid email format'
      });
    }

    if (phone && !isValidPhone(phone)) {
      return res.status(400).json({
        status: 'error',
        message: 'Invalid phone format. Use format: +268-XXXX-XXXX'
      });
    }

    // Generate or validate client code
    let finalClientCode = clientCode;
    if (!finalClientCode) {
      finalClientCode = await generateClientCode();
    } else {
      // Check if provided code already exists
      if (await clientCodeExists(finalClientCode)) {
        return res.status(400).json({
          status: 'error',
          message: 'Client code already exists'
        });
      }
    }

    // Check if email already exists
    if (email && await clientEmailExists(email)) {
      return res.status(400).json({
        status: 'error',
        message: 'Email already exists'
      });
    }

    // Insert client
    const insertQuery = `
      INSERT INTO clients (client_name, client_code, contact_person, email, phone, address, is_active)
      VALUES (?, ?, ?, ?, ?, ?, TRUE)
    `;
    const [result] = await db.query(insertQuery, [
      clientName,
      finalClientCode,
      contactPerson,
      email || null,
      phone || null,
      address || null
    ]);

    const newClientId = result.insertId;

    // Get created client
    const [newClient] = await db.query('SELECT * FROM clients WHERE client_id = ?', [newClientId]);

    // Create audit log
    await createAuditLog(
      req.user.userId,
      'CREATE',
      'client',
      newClientId,
      null,
      newClient[0],
      req.ip,
      req.get('user-agent')
    );

    logger.info(`Client created: ${finalClientCode} by ${req.user.username}`);

    res.status(201).json({
      status: 'success',
      message: 'Client created successfully',
      data: {
        clientId: newClient[0].client_id,
        clientName: newClient[0].client_name,
        clientCode: newClient[0].client_code,
        contactPerson: newClient[0].contact_person,
        email: newClient[0].email,
        phone: newClient[0].phone,
        address: newClient[0].address,
        isActive: Boolean(newClient[0].is_active),
        createdAt: newClient[0].created_at
      }
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   PUT /api/clients/:id
 * @desc    Update client details
 * @access  Private (Admin, Staff)
 */
router.put('/:id', authenticateToken, authorizeRoles('admin', 'staff'), async (req, res, next) => {
  try {
    const { id } = req.params;
    const {
      clientName,
      clientCode,
      contactPerson,
      email,
      phone,
      address,
      isActive
    } = req.body;

    // Get existing client
    const [existingClients] = await db.query('SELECT * FROM clients WHERE client_id = ?', [id]);

    if (existingClients.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Client not found'
      });
    }

    const existingClient = existingClients[0];

    // Validation
    if (email && !isValidEmail(email)) {
      return res.status(400).json({
        status: 'error',
        message: 'Invalid email format'
      });
    }

    if (phone && !isValidPhone(phone)) {
      return res.status(400).json({
        status: 'error',
        message: 'Invalid phone format. Use format: +268-XXXX-XXXX'
      });
    }

    // Check if new client code already exists (excluding current client)
    if (clientCode && clientCode !== existingClient.client_code) {
      if (await clientCodeExists(clientCode, id)) {
        return res.status(400).json({
          status: 'error',
          message: 'Client code already exists'
        });
      }
    }

    // Check if new email already exists (excluding current client)
    if (email && email !== existingClient.email) {
      if (await clientEmailExists(email, id)) {
        return res.status(400).json({
          status: 'error',
          message: 'Email already exists'
        });
      }
    }

    // Build update query dynamically
    const updates = [];
    const params = [];

    if (clientName !== undefined) {
      updates.push('client_name = ?');
      params.push(clientName);
    }
    if (clientCode !== undefined) {
      updates.push('client_code = ?');
      params.push(clientCode);
    }
    if (contactPerson !== undefined) {
      updates.push('contact_person = ?');
      params.push(contactPerson);
    }
    if (email !== undefined) {
      updates.push('email = ?');
      params.push(email || null);
    }
    if (phone !== undefined) {
      updates.push('phone = ?');
      params.push(phone || null);
    }
    if (address !== undefined) {
      updates.push('address = ?');
      params.push(address || null);
    }
    if (isActive !== undefined) {
      updates.push('is_active = ?');
      params.push(isActive ? 1 : 0);
    }

    if (updates.length === 0) {
      return res.status(400).json({
        status: 'error',
        message: 'No fields to update'
      });
    }

    params.push(id);

    // Update client
    const updateQuery = `
      UPDATE clients 
      SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP
      WHERE client_id = ?
    `;
    await db.query(updateQuery, params);

    // Get updated client
    const [updatedClient] = await db.query('SELECT * FROM clients WHERE client_id = ?', [id]);

    // Create audit log
    await createAuditLog(
      req.user.userId,
      'UPDATE',
      'client',
      id,
      existingClient,
      updatedClient[0],
      req.ip,
      req.get('user-agent')
    );

    logger.info(`Client updated: ${updatedClient[0].client_code} by ${req.user.username}`);

    res.status(200).json({
      status: 'success',
      message: 'Client updated successfully',
      data: {
        clientId: updatedClient[0].client_id,
        clientName: updatedClient[0].client_name,
        clientCode: updatedClient[0].client_code,
        contactPerson: updatedClient[0].contact_person,
        email: updatedClient[0].email,
        phone: updatedClient[0].phone,
        address: updatedClient[0].address,
        isActive: Boolean(updatedClient[0].is_active),
        updatedAt: updatedClient[0].updated_at
      }
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   DELETE /api/clients/:id
 * @desc    Soft delete client (set is_active to false)
 * @access  Private (Admin only)
 */
router.delete('/:id', authenticateToken, authorizeRoles('admin'), async (req, res, next) => {
  try {
    const { id } = req.params;

    // Get existing client
    const [existingClients] = await db.query('SELECT * FROM clients WHERE client_id = ?', [id]);

    if (existingClients.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Client not found'
      });
    }

    const existingClient = existingClients[0];

    // Check if client has active boxes
    const [activeBoxes] = await db.query(
      'SELECT COUNT(*) as count FROM boxes WHERE client_id = ? AND status = "stored"',
      [id]
    );

    if (activeBoxes[0].count > 0) {
      return res.status(400).json({
        status: 'error',
        message: `Cannot delete client with ${activeBoxes[0].count} active stored boxes. Please retrieve or destroy all boxes first.`
      });
    }

    // Check if client has active users
    const [activeUsers] = await db.query(
      'SELECT COUNT(*) as count FROM users WHERE client_id = ? AND is_active = TRUE',
      [id]
    );

    if (activeUsers[0].count > 0) {
      return res.status(400).json({
        status: 'error',
        message: `Cannot delete client with ${activeUsers[0].count} active users. Please deactivate all users first.`
      });
    }

    // Soft delete client
    await db.query(
      'UPDATE clients SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP WHERE client_id = ?',
      [id]
    );

    // Create audit log
    await createAuditLog(
      req.user.userId,
      'DELETE',
      'client',
      id,
      existingClient,
      { is_active: false },
      req.ip,
      req.get('user-agent')
    );

    logger.info(`Client deleted: ${existingClient.client_code} by ${req.user.username}`);

    res.status(200).json({
      status: 'success',
      message: 'Client deleted successfully'
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   POST /api/clients/:id/activate
 * @desc    Reactivate a deactivated client
 * @access  Private (Admin only)
 */
router.post('/:id/activate', authenticateToken, authorizeRoles('admin'), async (req, res, next) => {
  try {
    const { id } = req.params;

    // Get existing client
    const [existingClients] = await db.query('SELECT * FROM clients WHERE client_id = ?', [id]);

    if (existingClients.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Client not found'
      });
    }

    const existingClient = existingClients[0];

    if (existingClient.is_active) {
      return res.status(400).json({
        status: 'error',
        message: 'Client is already active'
      });
    }

    // Activate client
    await db.query(
      'UPDATE clients SET is_active = TRUE, updated_at = CURRENT_TIMESTAMP WHERE client_id = ?',
      [id]
    );

    // Create audit log
    await createAuditLog(
      req.user.userId,
      'ACTIVATE',
      'client',
      id,
      existingClient,
      { is_active: true },
      req.ip,
      req.get('user-agent')
    );

    logger.info(`Client activated: ${existingClient.client_code} by ${req.user.username}`);

    res.status(200).json({
      status: 'success',
      message: 'Client activated successfully'
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   GET /api/clients/:id/users
 * @desc    Get all users associated with a client
 * @access  Private (Admin, Staff, or Own Client)
 */
router.get('/:id/users', authenticateToken, async (req, res, next) => {
  try {
    const { id } = req.params;

    // Check permissions - client users can only view their own client's users
    if (req.user.role === 'client' && req.user.clientId !== parseInt(id)) {
      return res.status(403).json({
        status: 'error',
        message: 'You do not have permission to view users for this client'
      });
    }

    // Verify client exists
    const [clients] = await db.query('SELECT * FROM clients WHERE client_id = ?', [id]);
    if (clients.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Client not found'
      });
    }

    // Get users with their permissions
    const query = `
      SELECT 
        u.user_id,
        u.username,
        u.email,
        u.role,
        u.is_active,
        u.created_at,
        u.updated_at,
        p.can_create_boxes,
        p.can_edit_boxes,
        p.can_delete_boxes,
        p.can_create_collections,
        p.can_create_retrievals,
        p.can_create_deliveries,
        p.can_view_reports,
        p.can_manage_users
      FROM users u
      LEFT JOIN permissions p ON u.user_id = p.user_id
      WHERE u.client_id = ?
      ORDER BY u.created_at DESC
    `;

    const [users] = await db.query(query, [id]);

    // Format response
    const formattedUsers = users.map(user => ({
      userId: user.user_id,
      username: user.username,
      email: user.email,
      role: user.role,
      isActive: Boolean(user.is_active),
      permissions: {
        canCreateBoxes: Boolean(user.can_create_boxes),
        canEditBoxes: Boolean(user.can_edit_boxes),
        canDeleteBoxes: Boolean(user.can_delete_boxes),
        canCreateCollections: Boolean(user.can_create_collections),
        canCreateRetrievals: Boolean(user.can_create_retrievals),
        canCreateDeliveries: Boolean(user.can_create_deliveries),
        canViewReports: Boolean(user.can_view_reports),
        canManageUsers: Boolean(user.can_manage_users)
      },
      createdAt: user.created_at,
      updatedAt: user.updated_at
    }));

    res.status(200).json({
      status: 'success',
      data: {
        clientId: parseInt(id),
        users: formattedUsers,
        totalUsers: formattedUsers.length
      }
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   GET /api/clients/:id/boxes
 * @desc    Get all boxes for a client with filtering
 * @access  Private (Admin, Staff, or Own Client)
 */
router.get('/:id/boxes', authenticateToken, async (req, res, next) => {
  try {
    const { id } = req.params;
    const {
      status = null,
      page = 1,
      limit = 10,
      sortBy = 'created_at',
      sortOrder = 'DESC'
    } = req.query;

    // Check permissions - client users can only view their own client's boxes
    if (req.user.role === 'client' && req.user.clientId !== parseInt(id)) {
      return res.status(403).json({
        status: 'error',
        message: 'You do not have permission to view boxes for this client'
      });
    }

    // Verify client exists
    const [clients] = await db.query('SELECT * FROM clients WHERE client_id = ?', [id]);
    if (clients.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Client not found'
      });
    }

    // Calculate offset
    const offset = (parseInt(page) - 1) * parseInt(limit);

    // Build WHERE clause
    let whereConditions = ['b.client_id = ?'];
    let queryParams = [id];

    if (status) {
      whereConditions.push('b.status = ?');
      queryParams.push(status);
    }

    const whereClause = `WHERE ${whereConditions.join(' AND ')}`;

    // Validate sortBy
    const allowedSortFields = ['box_number', 'date_received', 'destruction_year', 'status', 'created_at'];
    const safeSortBy = allowedSortFields.includes(sortBy) ? sortBy : 'created_at';
    const safeSortOrder = sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

    // Get total count
    const countQuery = `
      SELECT COUNT(*) as total
      FROM boxes b
      ${whereClause}
    `;
    const [[{ total }]] = await db.query(countQuery, queryParams);

    // Get boxes
    const query = `
      SELECT 
        b.*,
        r.label_code as racking_label_code,
        r.location_description as racking_location
      FROM boxes b
      LEFT JOIN racking_labels r ON b.racking_label_id = r.label_id
      ${whereClause}
      ORDER BY b.${safeSortBy} ${safeSortOrder}
      LIMIT ? OFFSET ?
    `;

    queryParams.push(parseInt(limit), offset);
    const [boxes] = await db.query(query, queryParams);

    // Format response
    const formattedBoxes = boxes.map(box => ({
      boxId: box.box_id,
      boxNumber: box.box_number,
      boxDescription: box.box_description,
      dateReceived: box.date_received,
      yearReceived: box.year_received,
      retentionYears: box.retention_years,
      destructionYear: box.destruction_year,
      status: box.status,
      rackingLabel: {
        labelId: box.racking_label_id,
        labelCode: box.racking_label_code,
        location: box.racking_location
      },
      createdAt: box.created_at,
      updatedAt: box.updated_at
    }));

    res.status(200).json({
      status: 'success',
      data: {
        clientId: parseInt(id),
        boxes: formattedBoxes,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(total / parseInt(limit)),
          totalItems: total,
          itemsPerPage: parseInt(limit)
        }
      }
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   GET /api/clients/:id/statistics
 * @desc    Get detailed statistics for a client
 * @access  Private (Admin, Staff, or Own Client)
 */
router.get('/:id/statistics', authenticateToken, async (req, res, next) => {
  try {
    const { id } = req.params;

    // Check permissions - client users can only view their own client's statistics
    if (req.user.role === 'client' && req.user.clientId !== parseInt(id)) {
      return res.status(403).json({
        status: 'error',
        message: 'You do not have permission to view statistics for this client'
      });
    }

    // Verify client exists
    const [clients] = await db.query('SELECT * FROM clients WHERE client_id = ?', [id]);
    if (clients.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Client not found'
      });
    }

    // Get comprehensive statistics
    const statsQuery = `
      SELECT 
        -- Box statistics
        COUNT(DISTINCT b.box_id) as total_boxes,
        COUNT(DISTINCT CASE WHEN b.status = 'stored' THEN b.box_id END) as stored_boxes,
        COUNT(DISTINCT CASE WHEN b.status = 'retrieved' THEN b.box_id END) as retrieved_boxes,
        COUNT(DISTINCT CASE WHEN b.status = 'destroyed' THEN b.box_id END) as destroyed_boxes,
        COUNT(DISTINCT CASE WHEN b.destruction_year <= YEAR(CURDATE()) AND b.status = 'stored' THEN b.box_id END) as boxes_pending_destruction,
        
        -- User statistics
        COUNT(DISTINCT u.user_id) as total_users,
        COUNT(DISTINCT CASE WHEN u.is_active = TRUE THEN u.user_id END) as active_users,
        
        -- Activity statistics
        COUNT(DISTINCT col.collection_id) as total_collections,
        COUNT(DISTINCT ret.retrieval_id) as total_retrievals,
        COUNT(DISTINCT del.delivery_id) as total_deliveries,
        
        -- Request statistics
        COUNT(DISTINCT req.request_id) as total_requests,
        COUNT(DISTINCT CASE WHEN req.status = 'pending' THEN req.request_id END) as pending_requests,
        COUNT(DISTINCT CASE WHEN req.status = 'approved' THEN req.request_id END) as approved_requests,
        COUNT(DISTINCT CASE WHEN req.status = 'completed' THEN req.request_id END) as completed_requests,
        COUNT(DISTINCT CASE WHEN req.status = 'cancelled' THEN req.request_id END) as cancelled_requests,
        
        -- Recent activity (last 30 days)
        COUNT(DISTINCT CASE WHEN DATE(col.created_at) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN col.collection_id END) as collections_last_30_days,
        COUNT(DISTINCT CASE WHEN DATE(ret.created_at) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN ret.retrieval_id END) as retrievals_last_30_days,
        COUNT(DISTINCT CASE WHEN DATE(del.created_at) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN del.delivery_id END) as deliveries_last_30_days
        
      FROM clients c
      LEFT JOIN users u ON c.client_id = u.client_id
      LEFT JOIN boxes b ON c.client_id = b.client_id
      LEFT JOIN collections col ON c.client_id = col.client_id
      LEFT JOIN retrievals ret ON c.client_id = ret.client_id
      LEFT JOIN deliveries del ON c.client_id = del.client_id
      LEFT JOIN requests req ON c.client_id = req.client_id
      WHERE c.client_id = ?
      GROUP BY c.client_id
    `;

    const [stats] = await db.query(statsQuery, [id]);

    res.status(200).json({
      status: 'success',
      data: {
        clientId: parseInt(id),
        clientName: clients[0].client_name,
        clientCode: clients[0].client_code,
        boxes: {
          total: stats[0].total_boxes,
          stored: stats[0].stored_boxes,
          retrieved: stats[0].retrieved_boxes,
          destroyed: stats[0].destroyed_boxes,
          pendingDestruction: stats[0].boxes_pending_destruction
        },
        users: {
          total: stats[0].total_users,
          active: stats[0].active_users
        },
        activities: {
          collections: {
            total: stats[0].total_collections,
            last30Days: stats[0].collections_last_30_days
          },
          retrievals: {
            total: stats[0].total_retrievals,
            last30Days: stats[0].retrievals_last_30_days
          },
          deliveries: {
            total: stats[0].total_deliveries,
            last30Days: stats[0].deliveries_last_30_days
          }
        },
        requests: {
          total: stats[0].total_requests,
          pending: stats[0].pending_requests,
          approved: stats[0].approved_requests,
          completed: stats[0].completed_requests,
          cancelled: stats[0].cancelled_requests
        }
      }
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   POST /api/clients/:id/assign-user
 * @desc    Assign/update a user's client association
 * @access  Private (Admin only)
 */
router.post('/:id/assign-user', authenticateToken, authorizeRoles('admin'), async (req, res, next) => {
  try {
    const { id } = req.params;
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({
        status: 'error',
        message: 'User ID is required'
      });
    }

    // Verify client exists
    const [clients] = await db.query('SELECT * FROM clients WHERE client_id = ?', [id]);
    if (clients.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Client not found'
      });
    }

    // Verify user exists and get current data
    const [users] = await db.query('SELECT * FROM users WHERE user_id = ?', [userId]);
    if (users.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'User not found'
      });
    }

    const user = users[0];

    // Only allow assigning client role users to clients
    if (user.role !== 'client') {
      return res.status(400).json({
        status: 'error',
        message: 'Only users with client role can be assigned to clients'
      });
    }

    // Update user's client association
    await db.query(
      'UPDATE users SET client_id = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?',
      [id, userId]
    );

    // Create audit log
    await createAuditLog(
      req.user.userId,
      'ASSIGN_USER',
      'client',
      id,
      { userId, previousClientId: user.client_id },
      { userId, newClientId: parseInt(id) },
      req.ip,
      req.get('user-agent')
    );

    logger.info(`User ${user.username} assigned to client ${clients[0].client_code} by ${req.user.username}`);

    res.status(200).json({
      status: 'success',
      message: 'User assigned to client successfully'
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   DELETE /api/clients/:id/users/:userId
 * @desc    Remove user from client (set client_id to NULL)
 * @access  Private (Admin only)
 */
router.delete('/:id/users/:userId', authenticateToken, authorizeRoles('admin'), async (req, res, next) => {
  try {
    const { id, userId } = req.params;

    // Verify client exists
    const [clients] = await db.query('SELECT * FROM clients WHERE client_id = ?', [id]);
    if (clients.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Client not found'
      });
    }

    // Verify user exists and is associated with this client
    const [users] = await db.query(
      'SELECT * FROM users WHERE user_id = ? AND client_id = ?',
      [userId, id]
    );

    if (users.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'User not found or not associated with this client'
      });
    }

    const user = users[0];

    // Remove client association
    await db.query(
      'UPDATE users SET client_id = NULL, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?',
      [userId]
    );

    // Create audit log
    await createAuditLog(
      req.user.userId,
      'REMOVE_USER',
      'client',
      id,
      { userId, clientId: parseInt(id) },
      { userId, clientId: null },
      req.ip,
      req.get('user-agent')
    );

    logger.info(`User ${user.username} removed from client ${clients[0].client_code} by ${req.user.username}`);

    res.status(200).json({
      status: 'success',
      message: 'User removed from client successfully'
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   GET /api/clients/:id/audit-logs
 * @desc    Get audit logs for a specific client
 * @access  Private (Admin only)
 */
router.get('/:id/audit-logs', authenticateToken, authorizeRoles('admin'), async (req, res, next) => {
  try {
    const { id } = req.params;
    const {
      page = 1,
      limit = 20,
      action = null
    } = req.query;

    // Verify client exists
    const [clients] = await db.query('SELECT * FROM clients WHERE client_id = ?', [id]);
    if (clients.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Client not found'
      });
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    // Build WHERE clause
    let whereConditions = ['entity_type = ? AND entity_id = ?'];
    let queryParams = ['client', id];

    if (action) {
      whereConditions.push('action = ?');
      queryParams.push(action);
    }

    const whereClause = `WHERE ${whereConditions.join(' AND ')}`;

    // Get total count
    const countQuery = `
      SELECT COUNT(*) as total
      FROM audit_logs
      ${whereClause}
    `;
    const [[{ total }]] = await db.query(countQuery, queryParams);

    // Get audit logs
    const query = `
      SELECT 
        al.*,
        u.username,
        u.role
      FROM audit_logs al
      LEFT JOIN users u ON al.user_id = u.user_id
      ${whereClause}
      ORDER BY al.created_at DESC
      LIMIT ? OFFSET ?
    `;

    queryParams.push(parseInt(limit), offset);
    const [logs] = await db.query(query, queryParams);

    // Format response
    const formattedLogs = logs.map(log => ({
      auditId: log.audit_id,
      action: log.action,
      user: {
        userId: log.user_id,
        username: log.username,
        role: log.role
      },
      oldValue: log.old_value ? JSON.parse(log.old_value) : null,
      newValue: log.new_value ? JSON.parse(log.new_value) : null,
      ipAddress: log.ip_address,
      userAgent: log.user_agent,
      createdAt: log.created_at
    }));

    res.status(200).json({
      status: 'success',
      data: {
        clientId: parseInt(id),
        logs: formattedLogs,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(total / parseInt(limit)),
          totalItems: total,
          itemsPerPage: parseInt(limit)
        }
      }
    });

  } catch (error) {
    next(error);
  }
});

module.exports = router;