const winston = require('winston');
const path = require('path');
const fs = require('fs');

// ============================================
// CONFIGURATION
// ============================================

// Create logs directory if it doesn't exist
const logsDir = path.join(__dirname, '..', 'logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir);
}

// Define log format
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  winston.format.json()
);

// Define console format for development
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    let msg = `${timestamp} [${level}]: ${message}`;
    if (Object.keys(meta).length > 0) {
      msg += ` ${JSON.stringify(meta, null, 2)}`;
    }
    return msg;
  })
);

// ============================================
// LOGGER INSTANCE
// ============================================

/**
 * Winston logger instance
 */
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  defaultMeta: { service: 'psms-api' },
  transports: [
    // Write all logs with level 'error' and below to error.log
    new winston.transports.File({
      filename: path.join(logsDir, 'error.log'),
      level: 'error',
      maxsize: 5242880, // 5MB
      maxFiles: 5
    }),
    
    // Write all logs with level 'info' and below to combined.log
    new winston.transports.File({
      filename: path.join(logsDir, 'combined.log'),
      maxsize: 5242880, // 5MB
      maxFiles: 5
    }),

    // Write all logs to daily rotating file
    new winston.transports.File({
      filename: path.join(logsDir, `app-${new Date().toISOString().split('T')[0]}.log`),
      maxsize: 5242880, // 5MB
      maxFiles: 30 // Keep logs for 30 days
    })
  ],
  
  // Don't exit on handled exceptions
  exitOnError: false
});

// ============================================
// CONSOLE TRANSPORT (Development)
// ============================================

// Add console logging in development
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: consoleFormat
  }));
}

// ============================================
// EXCEPTION HANDLING
// ============================================

// Handle uncaught exceptions
logger.exceptions.handle(
  new winston.transports.File({
    filename: path.join(logsDir, 'exceptions.log')
  })
);

// Handle unhandled promise rejections
logger.rejections.handle(
  new winston.transports.File({
    filename: path.join(logsDir, 'rejections.log')
  })
);

// ============================================
// HELPER METHODS
// ============================================

/**
 * Log HTTP request
 */
logger.logRequest = (req, res, responseTime) => {
  logger.info('HTTP Request', {
    method: req.method,
    url: req.originalUrl,
    status: res.statusCode,
    responseTime: `${responseTime}ms`,
    ip: req.ip,
    userAgent: req.get('user-agent'),
    userId: req.user?.userId,
    username: req.user?.username
  });
};

/**
 * Log database query
 */
logger.logQuery = (query, params, duration) => {
  if (process.env.LOG_QUERIES === 'true') {
    logger.debug('Database Query', {
      query,
      params,
      duration: `${duration}ms`
    });
  }
};

/**
 * Log authentication event
 */
logger.logAuth = (event, username, success, ip) => {
  logger.info('Authentication Event', {
    event,
    username,
    success,
    ip,
    timestamp: new Date().toISOString()
  });
};

/**
 * Log security event
 */
logger.logSecurity = (event, details) => {
  logger.warn('Security Event', {
    event,
    ...details,
    timestamp: new Date().toISOString()
  });
};

/**
 * Log business event
 */
logger.logBusiness = (event, details) => {
  logger.info('Business Event', {
    event,
    ...details,
    timestamp: new Date().toISOString()
  });
};

// ============================================
// EXPORTS
// ============================================

module.exports = logger;
