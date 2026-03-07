const bcrypt = require('bcryptjs');
const db = require('../config/db');
const logger = require('../utils/logger');
const { ValidationError, NotFoundError, DatabaseError } = require('../middleware/error.middleware');

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
 * Check if user exists
 */
const checkUserExists = async (userId) => {
  const [users] = await db.query('SELECT user_id FROM users WHERE user_id = ?', [userId]);
  if (users.length === 0) {
    throw new NotFoundError('User not found');
  }
  return users[0];
};

/**
 * Check if client exists
 */
const checkClientExists = async (clientId) => {
  const [clients] = await db.query('SELECT client_id FROM clients WHERE client_id = ?', [clientId]);
  if (clients.length === 0) {
    throw new NotFoundError('Client not found');
  }
  return clients[0];
};

// ============================================
// USER CRUD OPERATIONS
// ============================================

/**
 * Get all users with optional filtering
 */
exports.getAllUsers = async (req, res, next) => {
  try {
    const { role, isActive, clientId, search, page = 1, limit = 50 } = req.query;
    
    let query = `
      SELECT u.user_id, u.username, u.email, u.role, u.client_id, u.is_active,
             u.created_at, u.updated_at,
             c.client_name, c.client_code,
             p.can_create_boxes, p.can_edit_boxes, p.can_delete_boxes,
             p.can_create_collections, p.can_create_retrievals, p.can_create_deliveries,
             p.can_view_reports, p.can_manage_users
      FROM users u
      LEFT JOIN clients c ON u.client_id = c.client_id
      LEFT JOIN permissions p ON u.user_id = p.user_id
      WHERE 1=1
    `;
    
    const params = [];
    
    // Apply filters
    if (role) {
      query += ' AND u.role = ?';
      params.push(role);
    }
    
    if (isActive !== undefined) {
      query += ' AND u.is_active = ?';
      params.push(isActive === 'true' ? 1 : 0);
    }
    
    if (clientId) {
      query += ' AND u.client_id = ?';
      params.push(clientId);
    }
    
    if (search) {
      query += ' AND (u.username LIKE ? OR u.email LIKE ? OR c.client_name LIKE ?)';
      const searchPattern = `%${search}%`;
      params.push(searchPattern, searchPattern, searchPattern);
    }
    
    // Count total records
    const countQuery = query.replace(/SELECT .+ FROM/, 'SELECT COUNT(*) as total FROM');
    const [countResult] = await db.query(countQuery, params);
    const total = countResult[0].total;
    
    // Add pagination
    const offset = (page - 1) * limit;
    query += ' ORDER BY u.created_at DESC LIMIT ? OFFSET ?';
    params.push(parseInt(limit), offset);
    
    const [users] = await db.query(query, params);
    
    // Format response
    const formattedUsers = users.map(user => ({
      userId: user.user_id,
      username: user.username,
      email: user.email,
      role: user.role,
      isActive: Boolean(user.is_active),
      client: user.client_id ? {
        clientId: user.client_id,
        clientName: user.client_name,
        clientCode: user.client_code
      } : null,
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
        users: formattedUsers,
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
};

/**
 * Get user statistics
 */
exports.getUserStats = async (req, res, next) => {
  try {
    const [stats] = await db.query(`
      SELECT 
        COUNT(*) as total_users,
        SUM(CASE WHEN is_active = TRUE THEN 1 ELSE 0 END) as active_users,
        SUM(CASE WHEN is_active = FALSE THEN 1 ELSE 0 END) as inactive_users,
        SUM(CASE WHEN role = 'admin' THEN 1 ELSE 0 END) as admin_users,
        SUM(CASE WHEN role = 'staff' THEN 1 ELSE 0 END) as staff_users,
        SUM(CASE WHEN role = 'client' THEN 1 ELSE 0 END) as client_users
      FROM users
    `);
    
    res.status(200).json({
      status: 'success',
      data: stats[0]
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Get users by role
 */
exports.getUsersByRole = async (req, res, next) => {
  try {
    const { role } = req.params;
    
    // Validate role
    if (!['admin', 'staff', 'client'].includes(role)) {
      throw new ValidationError('Invalid role. Must be admin, staff, or client');
    }
    
    const [users] = await db.query(`
      SELECT u.user_id, u.username, u.email, u.role, u.client_id, u.is_active,
             c.client_name, c.client_code
      FROM users u
      LEFT JOIN clients c ON u.client_id = c.client_id
      WHERE u.role = ?
      ORDER BY u.username
    `, [role]);
    
    const formattedUsers = users.map(user => ({
      userId: user.user_id,
      username: user.username,
      email: user.email,
      role: user.role,
      isActive: Boolean(user.is_active),
      client: user.client_id ? {
        clientId: user.client_id,
        clientName: user.client_name,
        clientCode: user.client_code
      } : null
    }));
    
    res.status(200).json({
      status: 'success',
      data: {
        role,
        count: formattedUsers.length,
        users: formattedUsers
      }
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Get users by client
 */
exports.getUsersByClient = async (req, res, next) => {
  try {
    const { clientId } = req.params;
    
    // Check if client exists
    await checkClientExists(clientId);
    
    const [users] = await db.query(`
      SELECT u.user_id, u.username, u.email, u.role, u.is_active, u.created_at,
             p.can_view_reports
      FROM users u
      LEFT JOIN permissions p ON u.user_id = p.user_id
      WHERE u.client_id = ?
      ORDER BY u.username
    `, [clientId]);
    
    const formattedUsers = users.map(user => ({
      userId: user.user_id,
      username: user.username,
      email: user.email,
      role: user.role,
      isActive: Boolean(user.is_active),
      canViewReports: Boolean(user.can_view_reports),
      createdAt: user.created_at
    }));
    
    res.status(200).json({
      status: 'success',
      data: {
        clientId: parseInt(clientId),
        userCount: formattedUsers.length,
        users: formattedUsers
      }
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Get single user by ID
 */
exports.getUserById = async (req, res, next) => {
  try {
    const { userId } = req.params;
    
    const [users] = await db.query(`
      SELECT u.*, c.client_name, c.client_code, c.contact_person, c.email as client_email,
             p.*
      FROM users u
      LEFT JOIN clients c ON u.client_id = c.client_id
      LEFT JOIN permissions p ON u.user_id = p.user_id
      WHERE u.user_id = ?
    `, [userId]);
    
    if (users.length === 0) {
      throw new NotFoundError('User not found');
    }
    
    const user = users[0];
    
    const formattedUser = {
      userId: user.user_id,
      username: user.username,
      email: user.email,
      role: user.role,
      isActive: Boolean(user.is_active),
      createdAt: user.created_at,
      updatedAt: user.updated_at,
      client: user.client_id ? {
        clientId: user.client_id,
        clientName: user.client_name,
        clientCode: user.client_code,
        contactPerson: user.contact_person,
        email: user.client_email
      } : null,
      permissions: {
        canCreateBoxes: Boolean(user.can_create_boxes),
        canEditBoxes: Boolean(user.can_edit_boxes),
        canDeleteBoxes: Boolean(user.can_delete_boxes),
        canCreateCollections: Boolean(user.can_create_collections),
        canCreateRetrievals: Boolean(user.can_create_retrievals),
        canCreateDeliveries: Boolean(user.can_create_deliveries),
        canViewReports: Boolean(user.can_view_reports),
        canManageUsers: Boolean(user.can_manage_users)
      }
    };
    
    res.status(200).json({
      status: 'success',
      data: formattedUser
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Create new user
 */
exports.createUser = async (req, res, next) => {
  try {
    const { username, email, password, role, clientId, permissions } = req.body;
    
    // Validate role
    if (!['admin', 'staff', 'client'].includes(role)) {
      throw new ValidationError('Invalid role. Must be admin, staff, or client');
    }
    
    // If role is client, clientId is required
    if (role === 'client' && !clientId) {
      throw new ValidationError('Client ID is required for client role');
    }
    
    // If role is not client, clientId should not be provided
    if (role !== 'client' && clientId) {
      throw new ValidationError('Client ID should only be provided for client role');
    }
    
    // Check if client exists
    if (clientId) {
      await checkClientExists(clientId);
    }
    
    // Hash password
    const passwordHash = await bcrypt.hash(password, 12);
    
    // Use transaction
    const result = await db.transaction(async (connection) => {
      // Insert user
      const [userResult] = await connection.execute(
        'INSERT INTO users (username, email, password_hash, role, client_id, is_active) VALUES (?, ?, ?, ?, ?, TRUE)',
        [username, email, passwordHash, role, clientId || null]
      );
      
      const newUserId = userResult.insertId;
      
      // Set default permissions based on role
      let defaultPermissions = {
        canCreateBoxes: false,
        canEditBoxes: false,
        canDeleteBoxes: false,
        canCreateCollections: false,
        canCreateRetrievals: false,
        canCreateDeliveries: false,
        canViewReports: false,
        canManageUsers: false
      };
      
      if (role === 'admin') {
        // Admin gets all permissions
        defaultPermissions = {
          canCreateBoxes: true,
          canEditBoxes: true,
          canDeleteBoxes: true,
          canCreateCollections: true,
          canCreateRetrievals: true,
          canCreateDeliveries: true,
          canViewReports: true,
          canManageUsers: true
        };
      } else if (role === 'staff') {
        // Staff gets most permissions except delete and manage users
        defaultPermissions = {
          canCreateBoxes: true,
          canEditBoxes: true,
          canDeleteBoxes: false,
          canCreateCollections: true,
          canCreateRetrievals: true,
          canCreateDeliveries: true,
          canViewReports: true,
          canManageUsers: false
        };
      } else if (role === 'client') {
        // Client only gets view reports
        defaultPermissions = {
          canViewReports: true
        };
      }
      
      // Override with provided permissions
      const finalPermissions = { ...defaultPermissions, ...(permissions || {}) };
      
      // Insert permissions
      await connection.execute(`
        INSERT INTO permissions (
          user_id, can_create_boxes, can_edit_boxes, can_delete_boxes,
          can_create_collections, can_create_retrievals, can_create_deliveries,
          can_view_reports, can_manage_users
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        newUserId,
        finalPermissions.canCreateBoxes,
        finalPermissions.canEditBoxes,
        finalPermissions.canDeleteBoxes,
        finalPermissions.canCreateCollections,
        finalPermissions.canCreateRetrievals,
        finalPermissions.canCreateDeliveries,
        finalPermissions.canViewReports,
        finalPermissions.canManageUsers
      ]);
      
      return { userId: newUserId, permissions: finalPermissions };
    });
    
    // Create audit log
    await createAuditLog(
      req.user.userId,
      'CREATE_USER',
      'user',
      result.userId,
      null,
      { username, email, role, clientId },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`User created: ${username} (${role}) by ${req.user.username}`);
    
    res.status(201).json({
      status: 'success',
      message: 'User created successfully',
      data: {
        userId: result.userId,
        username,
        email,
        role,
        clientId: clientId || null,
        permissions: result.permissions
      }
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Update user details
 */
exports.updateUser = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { username, email } = req.body;
    
    // Check if user exists
    const [existingUsers] = await db.query('SELECT * FROM users WHERE user_id = ?', [userId]);
    if (existingUsers.length === 0) {
      throw new NotFoundError('User not found');
    }
    
    const oldUser = existingUsers[0];
    
    // Update user
    await db.query(
      'UPDATE users SET username = ?, email = ? WHERE user_id = ?',
      [username, email, userId]
    );
    
    // Create audit log
    await createAuditLog(
      req.user.userId,
      'UPDATE_USER',
      'user',
      userId,
      { username: oldUser.username, email: oldUser.email },
      { username, email },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`User updated: ${username} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'User updated successfully',
      data: {
        userId: parseInt(userId),
        username,
        email
      }
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Activate user
 */
exports.activateUser = async (req, res, next) => {
  try {
    const { userId } = req.params;
    
    await checkUserExists(userId);
    
    await db.query('UPDATE users SET is_active = TRUE WHERE user_id = ?', [userId]);
    
    await createAuditLog(
      req.user.userId,
      'ACTIVATE_USER',
      'user',
      userId,
      { is_active: false },
      { is_active: true },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`User activated: ID ${userId} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'User activated successfully'
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Deactivate user
 */
exports.deactivateUser = async (req, res, next) => {
  try {
    const { userId } = req.params;
    
    // Prevent deactivating self
    if (parseInt(userId) === req.user.userId) {
      throw new ValidationError('Cannot deactivate your own account');
    }
    
    await checkUserExists(userId);
    
    await db.query('UPDATE users SET is_active = FALSE WHERE user_id = ?', [userId]);
    
    await createAuditLog(
      req.user.userId,
      'DEACTIVATE_USER',
      'user',
      userId,
      { is_active: true },
      { is_active: false },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`User deactivated: ID ${userId} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'User deactivated successfully'
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Delete user (soft delete)
 */
exports.deleteUser = async (req, res, next) => {
  try {
    const { userId } = req.params;
    
    // Prevent deleting self
    if (parseInt(userId) === req.user.userId) {
      throw new ValidationError('Cannot delete your own account');
    }
    
    await checkUserExists(userId);
    
    await db.query('UPDATE users SET is_active = FALSE WHERE user_id = ?', [userId]);
    
    await createAuditLog(
      req.user.userId,
      'DELETE_USER',
      'user',
      userId,
      null,
      { deleted: true },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`User deleted: ID ${userId} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'User deleted successfully'
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Reset user password
 */
exports.resetPassword = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { newPassword } = req.body;
    
    await checkUserExists(userId);
    
    // Hash new password
    const passwordHash = await bcrypt.hash(newPassword, 12);
    
    await db.query('UPDATE users SET password_hash = ? WHERE user_id = ?', [passwordHash, userId]);
    
    await createAuditLog(
      req.user.userId,
      'RESET_PASSWORD',
      'user',
      userId,
      null,
      { message: 'Password reset by admin' },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`Password reset for user ID ${userId} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'Password reset successfully'
    });
    
  } catch (error) {
    next(error);
  }
};

// ============================================
// CLIENT-USER MAPPING
// ============================================

/**
 * Assign user to client
 */
exports.assignUserToClient = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { clientId } = req.body;
    
    await checkUserExists(userId);
    await checkClientExists(clientId);
    
    // Get user details
    const [users] = await db.query('SELECT username, role, client_id FROM users WHERE user_id = ?', [userId]);
    const user = users[0];
    
    // Check if user already has a client
    if (user.client_id) {
      throw new ValidationError('User is already assigned to a client. Use change-client endpoint instead.');
    }
    
    // Update user
    await db.query('UPDATE users SET client_id = ? WHERE user_id = ?', [clientId, userId]);
    
    await createAuditLog(
      req.user.userId,
      'ASSIGN_CLIENT',
      'user',
      userId,
      { client_id: null },
      { client_id: clientId },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`User ${user.username} assigned to client ${clientId} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'User assigned to client successfully',
      data: {
        userId: parseInt(userId),
        clientId: parseInt(clientId)
      }
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Remove user from client
 */
exports.removeUserFromClient = async (req, res, next) => {
  try {
    const { userId } = req.params;
    
    await checkUserExists(userId);
    
    // Get user details
    const [users] = await db.query('SELECT username, client_id FROM users WHERE user_id = ?', [userId]);
    const user = users[0];
    
    if (!user.client_id) {
      throw new ValidationError('User is not assigned to any client');
    }
    
    const oldClientId = user.client_id;
    
    // Update user
    await db.query('UPDATE users SET client_id = NULL WHERE user_id = ?', [userId]);
    
    await createAuditLog(
      req.user.userId,
      'REMOVE_CLIENT',
      'user',
      userId,
      { client_id: oldClientId },
      { client_id: null },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`User ${user.username} removed from client ${oldClientId} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'User removed from client successfully'
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Change user's client
 */
exports.changeUserClient = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { clientId } = req.body;
    
    await checkUserExists(userId);
    await checkClientExists(clientId);
    
    // Get user details
    const [users] = await db.query('SELECT username, client_id FROM users WHERE user_id = ?', [userId]);
    const user = users[0];
    const oldClientId = user.client_id;
    
    // Update user
    await db.query('UPDATE users SET client_id = ? WHERE user_id = ?', [clientId, userId]);
    
    await createAuditLog(
      req.user.userId,
      'CHANGE_CLIENT',
      'user',
      userId,
      { client_id: oldClientId },
      { client_id: clientId },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`User ${user.username} client changed from ${oldClientId} to ${clientId} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'User client changed successfully',
      data: {
        userId: parseInt(userId),
        oldClientId,
        newClientId: parseInt(clientId)
      }
    });
    
  } catch (error) {
    next(error);
  }
};

// ============================================
// PERMISSION MANAGEMENT
// ============================================

/**
 * Get user permissions
 */
exports.getUserPermissions = async (req, res, next) => {
  try {
    const { userId } = req.params;
    
    await checkUserExists(userId);
    
    const [permissions] = await db.query('SELECT * FROM permissions WHERE user_id = ?', [userId]);
    
    if (permissions.length === 0) {
      throw new NotFoundError('Permissions not found for this user');
    }
    
    const perm = permissions[0];
    
    res.status(200).json({
      status: 'success',
      data: {
        userId: parseInt(userId),
        permissions: {
          canCreateBoxes: Boolean(perm.can_create_boxes),
          canEditBoxes: Boolean(perm.can_edit_boxes),
          canDeleteBoxes: Boolean(perm.can_delete_boxes),
          canCreateCollections: Boolean(perm.can_create_collections),
          canCreateRetrievals: Boolean(perm.can_create_retrievals),
          canCreateDeliveries: Boolean(perm.can_create_deliveries),
          canViewReports: Boolean(perm.can_view_reports),
          canManageUsers: Boolean(perm.can_manage_users)
        }
      }
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Update user permissions (full replacement)
 */
exports.updateUserPermissions = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { permissions } = req.body;
    
    await checkUserExists(userId);
    
    // Get old permissions
    const [oldPerms] = await db.query('SELECT * FROM permissions WHERE user_id = ?', [userId]);
    
    // Update permissions
    await db.query(`
      UPDATE permissions SET
        can_create_boxes = ?,
        can_edit_boxes = ?,
        can_delete_boxes = ?,
        can_create_collections = ?,
        can_create_retrievals = ?,
        can_create_deliveries = ?,
        can_view_reports = ?,
        can_manage_users = ?
      WHERE user_id = ?
    `, [
      permissions.canCreateBoxes ?? false,
      permissions.canEditBoxes ?? false,
      permissions.canDeleteBoxes ?? false,
      permissions.canCreateCollections ?? false,
      permissions.canCreateRetrievals ?? false,
      permissions.canCreateDeliveries ?? false,
      permissions.canViewReports ?? false,
      permissions.canManageUsers ?? false,
      userId
    ]);
    
    await createAuditLog(
      req.user.userId,
      'UPDATE_PERMISSIONS',
      'permissions',
      userId,
      oldPerms[0],
      permissions,
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`Permissions updated for user ID ${userId} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'Permissions updated successfully',
      data: {
        userId: parseInt(userId),
        permissions
      }
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Grant specific permission
 */
exports.grantPermission = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { permission } = req.body;
    
    await checkUserExists(userId);
    
    // Convert camelCase to snake_case
    const dbPermission = permission.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
    
    // Validate permission name
    const validPermissions = [
      'can_create_boxes', 'can_edit_boxes', 'can_delete_boxes',
      'can_create_collections', 'can_create_retrievals', 'can_create_deliveries',
      'can_view_reports', 'can_manage_users'
    ];
    
    if (!validPermissions.includes(dbPermission)) {
      throw new ValidationError('Invalid permission name');
    }
    
    await db.query(`UPDATE permissions SET ${dbPermission} = TRUE WHERE user_id = ?`, [userId]);
    
    await createAuditLog(
      req.user.userId,
      'GRANT_PERMISSION',
      'permissions',
      userId,
      { [permission]: false },
      { [permission]: true },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`Permission ${permission} granted to user ID ${userId} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: `Permission ${permission} granted successfully`
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Revoke specific permission
 */
exports.revokePermission = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { permission } = req.body;
    
    await checkUserExists(userId);
    
    // Convert camelCase to snake_case
    const dbPermission = permission.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
    
    // Validate permission name
    const validPermissions = [
      'can_create_boxes', 'can_edit_boxes', 'can_delete_boxes',
      'can_create_collections', 'can_create_retrievals', 'can_create_deliveries',
      'can_view_reports', 'can_manage_users'
    ];
    
    if (!validPermissions.includes(dbPermission)) {
      throw new ValidationError('Invalid permission name');
    }
    
    await db.query(`UPDATE permissions SET ${dbPermission} = FALSE WHERE user_id = ?`, [userId]);
    
    await createAuditLog(
      req.user.userId,
      'REVOKE_PERMISSION',
      'permissions',
      userId,
      { [permission]: true },
      { [permission]: false },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`Permission ${permission} revoked from user ID ${userId} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: `Permission ${permission} revoked successfully`
    });
    
  } catch (error) {
    next(error);
  }
};

// ============================================
// BULK OPERATIONS
// ============================================

/**
 * Bulk create users
 */
exports.bulkCreateUsers = async (req, res, next) => {
  try {
    const { users } = req.body;
    
    if (!Array.isArray(users) || users.length === 0) {
      throw new ValidationError('Users array is required and must not be empty');
    }
    
    const results = {
      success: [],
      failed: []
    };
    
    for (const userData of users) {
      try {
        const { username, email, password, role, clientId } = userData;
        
        // Hash password
        const passwordHash = await bcrypt.hash(password, 12);
        
        // Create user in transaction
        await db.transaction(async (connection) => {
          const [userResult] = await connection.execute(
            'INSERT INTO users (username, email, password_hash, role, client_id, is_active) VALUES (?, ?, ?, ?, ?, TRUE)',
            [username, email, passwordHash, role, clientId || null]
          );
          
          const newUserId = userResult.insertId;
          
          // Set default permissions based on role
          let permissions = { canViewReports: false };
          if (role === 'admin') {
            permissions = {
              canCreateBoxes: true, canEditBoxes: true, canDeleteBoxes: true,
              canCreateCollections: true, canCreateRetrievals: true, canCreateDeliveries: true,
              canViewReports: true, canManageUsers: true
            };
          } else if (role === 'staff') {
            permissions = {
              canCreateBoxes: true, canEditBoxes: true, canDeleteBoxes: false,
              canCreateCollections: true, canCreateRetrievals: true, canCreateDeliveries: true,
              canViewReports: true, canManageUsers: false
            };
          } else if (role === 'client') {
            permissions = { canViewReports: true };
          }
          
          await connection.execute(`
            INSERT INTO permissions (
              user_id, can_create_boxes, can_edit_boxes, can_delete_boxes,
              can_create_collections, can_create_retrievals, can_create_deliveries,
              can_view_reports, can_manage_users
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          `, [
            newUserId,
            permissions.canCreateBoxes ?? false,
            permissions.canEditBoxes ?? false,
            permissions.canDeleteBoxes ?? false,
            permissions.canCreateCollections ?? false,
            permissions.canCreateRetrievals ?? false,
            permissions.canCreateDeliveries ?? false,
            permissions.canViewReports ?? false,
            permissions.canManageUsers ?? false
          ]);
          
          results.success.push({ username, userId: newUserId });
        });
        
      } catch (error) {
        results.failed.push({ username: userData.username, error: error.message });
      }
    }
    
    await createAuditLog(
      req.user.userId,
      'BULK_CREATE_USERS',
      'user',
      null,
      null,
      { success: results.success.length, failed: results.failed.length },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`Bulk create: ${results.success.length} users created, ${results.failed.length} failed by ${req.user.username}`);
    
    res.status(201).json({
      status: 'success',
      message: 'Bulk user creation completed',
      data: results
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Bulk deactivate users
 */
exports.bulkDeactivateUsers = async (req, res, next) => {
  try {
    const { userIds } = req.body;
    
    if (!Array.isArray(userIds) || userIds.length === 0) {
      throw new ValidationError('userIds array is required and must not be empty');
    }
    
    // Prevent deactivating self
    if (userIds.includes(req.user.userId)) {
      throw new ValidationError('Cannot deactivate your own account');
    }
    
    const placeholders = userIds.map(() => '?').join(',');
    await db.query(`UPDATE users SET is_active = FALSE WHERE user_id IN (${placeholders})`, userIds);
    
    await createAuditLog(
      req.user.userId,
      'BULK_DEACTIVATE_USERS',
      'user',
      null,
      null,
      { userIds, count: userIds.length },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`Bulk deactivated ${userIds.length} users by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: `${userIds.length} users deactivated successfully`
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Bulk activate users
 */
exports.bulkActivateUsers = async (req, res, next) => {
  try {
    const { userIds } = req.body;
    
    if (!Array.isArray(userIds) || userIds.length === 0) {
      throw new ValidationError('userIds array is required and must not be empty');
    }
    
    const placeholders = userIds.map(() => '?').join(',');
    await db.query(`UPDATE users SET is_active = TRUE WHERE user_id IN (${placeholders})`, userIds);
    
    await createAuditLog(
      req.user.userId,
      'BULK_ACTIVATE_USERS',
      'user',
      null,
      null,
      { userIds, count: userIds.length },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`Bulk activated ${userIds.length} users by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: `${userIds.length} users activated successfully`
    });
    
  } catch (error) {
    next(error);
  }
};

// ============================================
// ROLE MANAGEMENT
// ============================================

/**
 * Change user role
 */
exports.changeUserRole = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { role } = req.body;
    
    // Validate role
    if (!['admin', 'staff', 'client'].includes(role)) {
      throw new ValidationError('Invalid role. Must be admin, staff, or client');
    }
    
    // Prevent changing own role
    if (parseInt(userId) === req.user.userId) {
      throw new ValidationError('Cannot change your own role');
    }
    
    // Get current user details
    const [users] = await db.query('SELECT username, role FROM users WHERE user_id = ?', [userId]);
    if (users.length === 0) {
      throw new NotFoundError('User not found');
    }
    
    const oldRole = users[0].role;
    
    // Update role
    await db.query('UPDATE users SET role = ? WHERE user_id = ?', [role, userId]);
    
    await createAuditLog(
      req.user.userId,
      'CHANGE_ROLE',
      'user',
      userId,
      { role: oldRole },
      { role },
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`User ${users[0].username} role changed from ${oldRole} to ${role} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'User role changed successfully',
      data: {
        userId: parseInt(userId),
        oldRole,
        newRole: role
      }
    });
    
  } catch (error) {
    next(error);
  }
};
