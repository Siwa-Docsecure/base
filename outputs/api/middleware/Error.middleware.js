const logger = require('../utils/logger');

// ============================================
// ERROR CLASSES
// ============================================

/**
 * Custom Application Error
 */
class AppError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.statusCode = statusCode;
    this.status = `${statusCode}`.startsWith('4') ? 'fail' : 'error';
    this.isOperational = true;

    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Validation Error
 */
class ValidationError extends AppError {
  constructor(message) {
    super(message, 400);
  }
}

/**
 * Authentication Error
 */
class AuthenticationError extends AppError {
  constructor(message = 'Authentication failed') {
    super(message, 401);
  }
}

/**
 * Authorization Error
 */
class AuthorizationError extends AppError {
  constructor(message = 'You do not have permission to access this resource') {
    super(message, 403);
  }
}

/**
 * Not Found Error
 */
class NotFoundError extends AppError {
  constructor(message = 'Resource not found') {
    super(message, 404);
  }
}

/**
 * Database Error
 */
class DatabaseError extends AppError {
  constructor(message = 'Database operation failed') {
    super(message, 500);
  }
}

// ============================================
// ERROR HANDLING FUNCTIONS
// ============================================

/**
 * Handle MySQL errors
 */
const handleMySQLError = (error) => {
  // Duplicate entry error
  if (error.code === 'ER_DUP_ENTRY') {
    const field = error.sqlMessage.match(/for key '(.+?)'/)?.[1] || 'field';
    return new ValidationError(`Duplicate value for ${field}`);
  }

  // Foreign key constraint error
  if (error.code === 'ER_NO_REFERENCED_ROW_2') {
    return new ValidationError('Referenced record does not exist');
  }

  // Foreign key constraint fails on delete
  if (error.code === 'ER_ROW_IS_REFERENCED_2') {
    return new ValidationError('Cannot delete record as it is referenced by other records');
  }

  // Data too long error
  if (error.code === 'ER_DATA_TOO_LONG') {
    return new ValidationError('Data exceeds maximum length');
  }

  // Bad field error
  if (error.code === 'ER_BAD_FIELD_ERROR') {
    return new DatabaseError('Invalid database field');
  }

  // Connection error
  if (error.code === 'ECONNREFUSED') {
    return new DatabaseError('Database connection failed');
  }

  return new DatabaseError('Database operation failed');
};

/**
 * Handle JWT errors
 */
const handleJWTError = () => {
  return new AuthenticationError('Invalid token. Please log in again');
};

/**
 * Handle JWT expired error
 */
const handleJWTExpiredError = () => {
  return new AuthenticationError('Token expired. Please log in again');
};

/**
 * Send error response in development
 */
const sendErrorDev = (err, res) => {
  logger.error('ERROR 💥', err);

  res.status(err.statusCode).json({
    status: err.status,
    message: err.message,
    error: err,
    stack: err.stack
  });
};

/**
 * Send error response in production
 */
const sendErrorProd = (err, res) => {
  // Operational, trusted error: send message to client
  if (err.isOperational) {
    logger.error(`${err.statusCode} - ${err.message}`);
    
    res.status(err.statusCode).json({
      status: err.status,
      message: err.message
    });
  } 
  // Programming or other unknown error: don't leak error details
  else {
    logger.error('ERROR 💥', err);

    res.status(500).json({
      status: 'error',
      message: 'Something went wrong'
    });
  }
};

// ============================================
// GLOBAL ERROR HANDLER MIDDLEWARE
// ============================================

/**
 * Global error handling middleware
 * Must be used as the last middleware in the app
 */
const errorHandler = (err, req, res, next) => {
  let error = { ...err };
  error.message = err.message;
  error.statusCode = err.statusCode || 500;
  error.status = err.status || 'error';

  // Log error details
  logger.error(`${req.method} ${req.originalUrl} - ${error.statusCode}`);
  logger.error(error.message);

  // Handle specific error types
  if (err.code?.startsWith('ER_')) {
    error = handleMySQLError(err);
  }
  if (err.name === 'JsonWebTokenError') {
    error = handleJWTError();
  }
  if (err.name === 'TokenExpiredError') {
    error = handleJWTExpiredError();
  }
  if (err.name === 'ValidationError') {
    error = new ValidationError(err.message);
  }

  // Send error response based on environment
  if (process.env.NODE_ENV === 'development') {
    sendErrorDev(error, res);
  } else {
    sendErrorProd(error, res);
  }
};

/**
 * Async error wrapper
 * Wraps async route handlers to catch errors and pass to error middleware
 */
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

/**
 * 404 Not Found handler
 */
const notFound = (req, res, next) => {
  const error = new NotFoundError(`Route ${req.originalUrl} not found`);
  next(error);
};

// ============================================
// EXPORTS
// ============================================

module.exports = {
  // Error classes
  AppError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  NotFoundError,
  DatabaseError,
  
  // Middleware
  errorHandler,
  asyncHandler,
  notFound
};