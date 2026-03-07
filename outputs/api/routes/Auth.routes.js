const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const db = require('../config/db');
const { authenticateToken } = require('../middleware/Auth.middleware');
const logger = require('../utils/logger');

const router = express.Router();

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Generate JWT token
 */
const generateToken = (user) => {
  return jwt.sign(
    {
      userId: user.user_id,
      username: user.username,
      email: user.email,
      role: user.role,
      clientId: user.client_id
    },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
  );
};

/**
 * Generate refresh token
 */
const generateRefreshToken = (user) => {
  return jwt.sign(
    { userId: user.user_id },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' }
  );
};

/**
 * Hash token for storage (SHA-256)
 */
const hashToken = (token) => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

/**
 * Create audit log entry
 */
const createAuditLog = async (userId, action, entityType, entityId, newValue, ipAddress, userAgent) => {
  try {
    const query = `
      INSERT INTO audit_logs (user_id, action, entity_type, entity_id, new_value, ip_address, user_agent)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `;
    await db.query(query, [userId, action, entityType, entityId, JSON.stringify(newValue), ipAddress, userAgent]);
  } catch (error) {
    logger.error('Failed to create audit log:', error);
  }
};

// ============================================
// ROUTES
// ============================================

/**
 * @route   POST /api/auth/login
 * @desc    Login user (admin, staff, or client)
 * @access  Public
 */
router.post('/login', async (req, res, next) => {
  try {
    const { username, password } = req.body;

    // Validation
    if (!username || !password) {
      return res.status(400).json({
        status: 'error',
        message: 'Username and password are required'
      });
    }

    // Find user by username or email
    const query = `
      SELECT u.*, p.*, c.client_name, c.client_code
      FROM users u
      LEFT JOIN permissions p ON u.user_id = p.user_id
      LEFT JOIN clients c ON u.client_id = c.client_id
      WHERE (u.username = ? OR u.email = ?) AND u.is_active = TRUE
    `;
    const [users] = await db.query(query, [username, username]);

    if (users.length === 0) {
      return res.status(401).json({
        status: 'error',
        message: 'Invalid credentials'
      });
    }

    const user = users[0];

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({
        status: 'error',
        message: 'Invalid credentials'
      });
    }

    // Generate tokens
    const accessToken = generateToken(user);
    const refreshToken = generateRefreshToken(user);

    // Create audit log
    await createAuditLog(
      user.user_id,
      'LOGIN',
      'auth',
      null,
      { username: user.username, role: user.role },
      req.ip,
      req.get('user-agent')
    );

    // Prepare user response (exclude sensitive data)
    const userResponse = {
      userId: user.user_id,
      username: user.username,
      email: user.email,
      role: user.role,
      clientId: user.client_id,
      clientName: user.client_name,
      clientCode: user.client_code,
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

    logger.info(`User logged in: ${user.username} (${user.role})`);

    res.status(200).json({
      status: 'success',
      message: 'Login successful',
      data: {
        user: userResponse,
        accessToken,
        refreshToken
      }
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   POST /api/auth/logout
 * @desc    Logout user and blacklist token
 * @access  Private
 */
router.post('/logout', authenticateToken, async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.status(400).json({
        status: 'error',
        message: 'No token provided'
      });
    }

    // Hash the token
    const tokenHash = hashToken(token);

    // Decode token to get expiry
    const decoded = jwt.decode(token);
    const expiresAt = new Date(decoded.exp * 1000);

    // Add token to blacklist
    const query = `
      INSERT INTO token_blacklist (token_hash, user_id, expires_at)
      VALUES (?, ?, ?)
    `;
    await db.query(query, [tokenHash, req.user.userId, expiresAt]);

    // Create audit log
    await createAuditLog(
      req.user.userId,
      'LOGOUT',
      'auth',
      null,
      null,
      req.ip,
      req.get('user-agent')
    );

    logger.info(`User logged out: ${req.user.username}`);

    res.status(200).json({
      status: 'success',
      message: 'Logout successful'
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   POST /api/auth/refresh
 * @desc    Refresh access token using refresh token
 * @access  Public
 */
router.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        status: 'error',
        message: 'Refresh token is required'
      });
    }

    // Verify refresh token
    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);

    // Get user details
    const query = `
      SELECT u.*, p.*, c.client_name, c.client_code
      FROM users u
      LEFT JOIN permissions p ON u.user_id = p.user_id
      LEFT JOIN clients c ON u.client_id = c.client_id
      WHERE u.user_id = ? AND u.is_active = TRUE
    `;
    const [users] = await db.query(query, [decoded.userId]);

    if (users.length === 0) {
      return res.status(401).json({
        status: 'error',
        message: 'Invalid refresh token'
      });
    }

    const user = users[0];

    // Generate new access token
    const newAccessToken = generateToken(user);

    logger.info(`Token refreshed for user: ${user.username}`);

    res.status(200).json({
      status: 'success',
      message: 'Token refreshed successfully',
      data: {
        accessToken: newAccessToken
      }
    });

  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({
        status: 'error',
        message: 'Invalid or expired refresh token'
      });
    }
    next(error);
  }
});

/**
 * @route   GET /api/auth/profile
 * @desc    Get current user profile
 * @access  Private
 */
router.get('/profile', authenticateToken, async (req, res, next) => {
  try {
    // Get full user details
    const query = `
      SELECT u.*, p.*, c.client_name, c.client_code, c.contact_person, c.email as client_email, c.phone as client_phone
      FROM users u
      LEFT JOIN permissions p ON u.user_id = p.user_id
      LEFT JOIN clients c ON u.client_id = c.client_id
      WHERE u.user_id = ? AND u.is_active = TRUE
    `;
    const [users] = await db.query(query, [req.user.userId]);

    if (users.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'User not found'
      });
    }

    const user = users[0];

    // Prepare response
    const userProfile = {
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
        email: user.client_email,
        phone: user.client_phone
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
      data: userProfile
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   POST /api/auth/change-password
 * @desc    Change user password
 * @access  Private
 */
router.post('/change-password', authenticateToken, async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;

    // Validation
    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        status: 'error',
        message: 'Current password and new password are required'
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        status: 'error',
        message: 'New password must be at least 6 characters long'
      });
    }

    // Get user's current password hash
    const [users] = await db.query(
      'SELECT password_hash FROM users WHERE user_id = ?',
      [req.user.userId]
    );

    if (users.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'User not found'
      });
    }

    // Verify current password
    const isPasswordValid = await bcrypt.compare(currentPassword, users[0].password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({
        status: 'error',
        message: 'Current password is incorrect'
      });
    }

    // Hash new password
    const newPasswordHash = await bcrypt.hash(newPassword, 12);

    // Update password
    await db.query(
      'UPDATE users SET password_hash = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?',
      [newPasswordHash, req.user.userId]
    );

    // Create audit log
    await createAuditLog(
      req.user.userId,
      'CHANGE_PASSWORD',
      'user',
      req.user.userId,
      { message: 'Password changed successfully' },
      req.ip,
      req.get('user-agent')
    );

    logger.info(`Password changed for user: ${req.user.username}`);

    res.status(200).json({
      status: 'success',
      message: 'Password changed successfully'
    });

  } catch (error) {
    next(error);
  }
});

/**
 * @route   POST /api/auth/verify-token
 * @desc    Verify if token is valid and not blacklisted
 * @access  Public
 */
router.post('/verify-token', async (req, res, next) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({
        status: 'error',
        message: 'Token is required'
      });
    }

    // Verify token signature and expiry
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Check if token is blacklisted
    const tokenHash = hashToken(token);
    const [blacklisted] = await db.query(
      'SELECT * FROM token_blacklist WHERE token_hash = ?',
      [tokenHash]
    );

    if (blacklisted.length > 0) {
      return res.status(401).json({
        status: 'error',
        message: 'Token has been revoked'
      });
    }

    res.status(200).json({
      status: 'success',
      message: 'Token is valid',
      data: {
        userId: decoded.userId,
        username: decoded.username,
        role: decoded.role
      }
    });

  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({
        status: 'error',
        message: 'Invalid or expired token'
      });
    }
    next(error);
  }
});

module.exports = router;