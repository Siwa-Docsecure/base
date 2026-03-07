const mysql = require('mysql2/promise');
const logger = require('../utils/logger');

// ============================================
// DATABASE CONNECTION CONFIGURATION
// ============================================

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'psms',
  waitForConnections: true,
  connectionLimit: parseInt(process.env.DB_CONNECTION_LIMIT) || 10,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
  charset: 'utf8mb4'
};

// ============================================
// CREATE CONNECTION POOL
// ============================================

let pool = null;

/**
 * Create and return database connection pool
 */
const createPool = () => {
  if (!pool) {
    pool = mysql.createPool(dbConfig);
    logger.info('✅ Database connection pool created');
    
    // Test connection
    pool.getConnection()
      .then(connection => {
        logger.info('✅ Database connection successful');
        connection.release();
      })
      .catch(error => {
        logger.error('❌ Database connection failed:', error.message);
        process.exit(1);
      });
  }
  return pool;
};

// ============================================
// DATABASE UTILITIES
// ============================================

/**
 * Execute query with automatic error handling
 */
const query = async (sql, params = []) => {
  const startTime = Date.now();
  
  try {
    const connection = await getPool().getConnection();
    try {
      const [results] = await connection.execute(sql, params);
      const duration = Date.now() - startTime;
      
      // Log slow queries
      if (duration > 1000) {
        logger.warn('Slow query detected', {
          query: sql.substring(0, 100),
          duration: `${duration}ms`
        });
      }
      
      return [results];
    } finally {
      connection.release();
    }
  } catch (error) {
    logger.error('Database query error:', {
      error: error.message,
      sql: sql.substring(0, 100),
      params: params
    });
    throw error;
  }
};

/**
 * Execute transaction
 */
const transaction = async (callback) => {
  const connection = await getPool().getConnection();
  
  try {
    await connection.beginTransaction();
    const result = await callback(connection);
    await connection.commit();
    return result;
  } catch (error) {
    await connection.rollback();
    logger.error('Transaction failed:', error.message);
    throw error;
  } finally {
    connection.release();
  }
};

/**
 * Get connection pool
 */
const getPool = () => {
  if (!pool) {
    return createPool();
  }
  return pool;
};

/**
 * Close all connections
 */
const closePool = async () => {
  if (pool) {
    await pool.end();
    logger.info('Database connection pool closed');
    pool = null;
  }
};

/**
 * Check database connection health
 */
const healthCheck = async () => {
  try {
    const [result] = await query('SELECT 1 as health');
    return result[0].health === 1;
  } catch (error) {
    logger.error('Database health check failed:', error.message);
    return false;
  }
};

/**
 * Get connection pool stats
 */
const getPoolStats = () => {
  if (!pool) {
    return null;
  }
  
  return {
    totalConnections: pool.pool._allConnections.length,
    freeConnections: pool.pool._freeConnections.length,
    queuedRequests: pool.pool._queue.length
  };
};

// ============================================
// INITIALIZATION
// ============================================

// Create pool on module load
createPool();

// Graceful shutdown
process.on('SIGINT', async () => {
  logger.info('Closing database connection pool...');
  await closePool();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  logger.info('Closing database connection pool...');
  await closePool();
  process.exit(0);
});

// ============================================
// EXPORTS
// ============================================

module.exports = {
  query,
  transaction,
  getPool,
  closePool,
  healthCheck,
  getPoolStats
};
