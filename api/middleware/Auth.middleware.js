const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const db = require('../config/db');
const logger = require('../utils/logger');

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Hash token for comparison
 */
const hashToken = (token) => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

// ============================================
// MIDDLEWARE FUNCTIONS
// ============================================

/**
 * Authenticate JWT token
 * Verifies token signature, expiry, and checks if blacklisted
 */
const authenticateToken = async (req, res, next) => {
  try {
    // Get token from Authorization header
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      return res.status(401).json({
        status: 'error',
        message: 'Access token is required'
      });
    }

    // Verify token
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

    // Verify user is still active
    const [users] = await db.query(
      'SELECT user_id, username, email, role, is_active FROM users WHERE user_id = ?',
      [decoded.userId]
    );

    if (users.length === 0 || !users[0].is_active) {
      return res.status(401).json({
        status: 'error',
        message: 'User account is inactive or not found'
      });
    }

    // Attach user info to request
    req.user = {
      userId: decoded.userId,
      username: decoded.username,
      email: decoded.email,
      role: decoded.role,
      clientId: decoded.clientId
    };

    next();

  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        status: 'error',
        message: 'Invalid token'
      });
    }
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        status: 'error',
        message: 'Token expired'
      });
    }
    logger.error('Token authentication error:', error);
    return res.status(500).json({
      status: 'error',
      message: 'Authentication failed'
    });
  }
};

/**
 * Authorize based on user roles
 * @param {Array<string>} allowedRoles - Array of allowed roles ['admin', 'staff', 'client']
 */
const authorizeRoles = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        status: 'error',
        message: 'Authentication required'
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      logger.warn(
        `Access denied for user ${req.user.username} (${req.user.role}) to ${req.method} ${req.originalUrl}`
      );
      return res.status(403).json({
        status: 'error',
        message: 'You do not have permission to access this resource'
      });
    }

    next();
  };
};

/**
 * Authorize based on specific permissions
 * @param {string} permission - Permission name (e.g., 'canCreateBoxes')
 */
const authorizePermission = (permission) => {
  return async (req, res, next) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          status: 'error',
          message: 'Authentication required'
        });
      }

      // Admin users have all permissions
      if (req.user.role === 'admin') {
        return next();
      }

      // Get user permissions from database
      const [permissions] = await db.query(
        'SELECT * FROM permissions WHERE user_id = ?',
        [req.user.userId]
      );

      if (permissions.length === 0) {
        return res.status(403).json({
          status: 'error',
          message: 'No permissions found for this user'
        });
      }

      const userPermissions = permissions[0];

      // Convert camelCase to snake_case for database column matching
      const dbPermissionName = permission.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);

      if (!userPermissions[dbPermissionName]) {
        logger.warn(
          `Permission denied for user ${req.user.username}: ${permission} on ${req.method} ${req.originalUrl}`
        );
        return res.status(403).json({
          status: 'error',
          message: 'You do not have permission to perform this action'
        });
      }

      next();

    } catch (error) {
      logger.error('Permission authorization error:', error);
      return res.status(500).json({
        status: 'error',
        message: 'Authorization failed'
      });
    }
  };
};

/**
 * Authorize client to access only their own data
 * Compares req.user.clientId with req.params.clientId or req.body.clientId
 */
const authorizeOwnClient = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      status: 'error',
      message: 'Authentication required'
    });
  }

  // Admin and staff can access any client data
  if (req.user.role === 'admin' || req.user.role === 'staff') {
    return next();
  }

  // For client role, check if accessing their own data
  const requestedClientId = parseInt(req.params.clientId || req.body.clientId || req.query.clientId);

  if (req.user.role === 'client' && req.user.clientId !== requestedClientId) {
    logger.warn(
      `Client ${req.user.username} attempted to access data for client ${requestedClientId}`
    );
    return res.status(403).json({
      status: 'error',
      message: 'You can only access your own data'
    });
  }

  next();
};

/**
 * Optional authentication - doesn't fail if no token provided
 * Useful for endpoints that have different behavior for authenticated vs unauthenticated users
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return next(); // No token provided, continue without authentication
    }

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Check if token is blacklisted
    const tokenHash = hashToken(token);
    const [blacklisted] = await db.query(
      'SELECT * FROM token_blacklist WHERE token_hash = ?',
      [tokenHash]
    );

    if (blacklisted.length === 0) {
      // Token is valid, attach user info
      req.user = {
        userId: decoded.userId,
        username: decoded.username,
        email: decoded.email,
        role: decoded.role,
        clientId: decoded.clientId
      };
    }

    next();

  } catch (error) {
    // Token verification failed, but continue without authentication
    next();
  }
};

// ============================================
// EXPORTS
// ============================================

module.exports = {
  authenticateToken,
  authorizeRoles,
  authorizePermission,
  authorizeOwnClient,
  optionalAuth
};