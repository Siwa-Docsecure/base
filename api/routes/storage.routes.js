const express = require('express');
const db = require('../config/db');
const { authenticateToken } = require('../middleware/Auth.middleware');
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
    await db.query(query, [userId, action, entityType, entityId, JSON.stringify(oldValue), JSON.stringify(newValue), ipAddress, userAgent]);
  } catch (error) {
    logger.error('Failed to create audit log:', error);
  }
};

/**
 * Check if user has required role
 */
const checkRole = (user, allowedRoles) => {
  return allowedRoles.includes(user.role);
};

/**
 * Validate storage location data
 */
const validateStorageLocation = (data, isUpdate = false) => {
  const errors = [];
  
  if (!isUpdate || data.label_code !== undefined) {
    if (!data.label_code || data.label_code.trim().length < 3) {
      errors.push('Label code must be at least 3 characters');
    }
  }
  
  if (!isUpdate || data.location_description !== undefined) {
    if (!data.location_description || data.location_description.trim().length < 5) {
      errors.push('Location description must be at least 5 characters');
    }
  }
  
  return errors;
};

// ============================================
// MIDDLEWARE FUNCTIONS
// ============================================

/**
 * Middleware to check user role
 */
const requireRole = (allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        status: 'error',
        message: 'Unauthorized'
      });
    }
    
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        status: 'error',
        message: 'Forbidden: You do not have permission to access this resource'
      });
    }
    
    next();
  };
};

// ============================================
// ROUTES
// ============================================

/**
 * @route   GET /api/storage/locations
 * @desc    Get all storage locations with filtering and pagination
 * @access  Private (Admin, Staff)
 */
router.get('/locations', authenticateToken, requireRole(['admin', 'staff']), async (req, res, next) => {
  try {
    const {
      page = 1,
      limit = 20,
      search = '',
      is_available,
      sort_by = 'label_code',
      sort_order = 'ASC'
    } = req.query;

    const offset = (page - 1) * limit;
    const validSortColumns = ['label_id', 'label_code', 'location_description', 'is_available', 'created_at'];
    const validSortOrder = ['ASC', 'DESC'];
    
    const sortColumn = validSortColumns.includes(sort_by) ? sort_by : 'label_code';
    const order = validSortOrder.includes(sort_order.toUpperCase()) ? sort_order.toUpperCase() : 'ASC';

    // Build WHERE clause
    let whereClause = 'WHERE 1=1';
    const params = [];
    
    if (search) {
      whereClause += ' AND (label_code LIKE ? OR location_description LIKE ?)';
      params.push(`%${search}%`, `%${search}%`);
    }
    
    if (is_available !== undefined) {
      whereClause += ' AND is_available = ?';
      params.push(is_available === 'true' ? 1 : 0);
    }

    // Get total count
    const countQuery = `SELECT COUNT(*) as total FROM racking_labels ${whereClause}`;
    const [countResult] = await db.query(countQuery, params);
    const total = countResult[0].total;

    // Get paginated data
    const dataQuery = `
      SELECT 
        label_id, 
        label_code, 
        location_description, 
        is_available,
        (SELECT COUNT(*) FROM boxes WHERE racking_label_id = racking_labels.label_id) as boxes_count,
        created_at, 
        updated_at
      FROM racking_labels
      ${whereClause}
      ORDER BY ${sortColumn} ${order}
      LIMIT ? OFFSET ?
    `;
    
    params.push(parseInt(limit), offset);
    const [locations] = await db.query(dataQuery, params);

    res.status(200).json({
      status: 'success',
      data: {
        locations,
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
});

/**
 * @route   GET /api/storage/locations/available
 * @desc    Get available storage locations (not occupied)
 * @access  Private (Admin, Staff, Client)
 */
router.get('/locations/available', authenticateToken, async (req, res, next) => {
  try {
    const query = `
      SELECT 
        label_id, 
        label_code, 
        location_description,
        created_at
      FROM racking_labels
      WHERE is_available = TRUE
      ORDER BY label_code ASC
    `;
    
    const [locations] = await db.query(query);
    
    res.status(200).json({
      status: 'success',
      data: locations
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @route   GET /api/storage/locations/:id
 * @desc    Get specific storage location by ID
 * @access  Private (Admin, Staff)
 */
router.get('/locations/:id', authenticateToken, requireRole(['admin', 'staff']), async (req, res, next) => {
  try {
    const { id } = req.params;
    
    const query = `
      SELECT 
        rl.*,
        COUNT(b.box_id) as boxes_count,
        GROUP_CONCAT(DISTINCT b.box_number) as box_numbers,
        GROUP_CONCAT(DISTINCT c.client_name) as client_names
      FROM racking_labels rl
      LEFT JOIN boxes b ON rl.label_id = b.racking_label_id
      LEFT JOIN clients c ON b.client_id = c.client_id
      WHERE rl.label_id = ?
      GROUP BY rl.label_id
    `;
    
    const [locations] = await db.query(query, [id]);
    
    if (locations.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Storage location not found'
      });
    }
    
    const location = locations[0];
    
    // Get boxes at this location
    const boxesQuery = `
      SELECT 
        b.box_id,
        b.box_number,
        b.box_description,
        b.status,
        c.client_name,
        c.client_code
      FROM boxes b
      LEFT JOIN clients c ON b.client_id = c.client_id
      WHERE b.racking_label_id = ?
      ORDER BY b.box_number
    `;
    
    const [boxes] = await db.query(boxesQuery, [id]);
    
    location.boxes = boxes;
    
    res.status(200).json({
      status: 'success',
      data: location
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @route   POST /api/storage/locations
 * @desc    Create a new storage location
 * @access  Private (Admin, Staff)
 */
router.post('/locations', authenticateToken, requireRole(['admin', 'staff']), async (req, res, next) => {
  try {
    const { label_code, location_description, is_available = true } = req.body;
    
    // Validation
    const errors = validateStorageLocation({ label_code, location_description });
    if (errors.length > 0) {
      return res.status(400).json({
        status: 'error',
        message: 'Validation failed',
        errors
      });
    }
    
    // Check if label code already exists
    const [existing] = await db.query(
      'SELECT label_id FROM racking_labels WHERE label_code = ?',
      [label_code]
    );
    
    if (existing.length > 0) {
      return res.status(409).json({
        status: 'error',
        message: 'Label code already exists'
      });
    }
    
    // Create storage location
    const query = `
      INSERT INTO racking_labels (label_code, location_description, is_available)
      VALUES (?, ?, ?)
    `;
    
    const [result] = await db.query(query, [
      label_code.trim(),
      location_description.trim(),
      is_available ? 1 : 0
    ]);
    
    // Get created location
    const [newLocation] = await db.query(
      'SELECT * FROM racking_labels WHERE label_id = ?',
      [result.insertId]
    );
    
    // Create audit log
    await createAuditLog(
      req.user.userId,
      'CREATE',
      'storage_location',
      result.insertId,
      null,
      newLocation[0],
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`Storage location created: ${label_code} by ${req.user.username}`);
    
    res.status(201).json({
      status: 'success',
      message: 'Storage location created successfully',
      data: newLocation[0]
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @route   PUT /api/storage/locations/:id
 * @desc    Update a storage location
 * @access  Private (Admin, Staff)
 */
router.put('/locations/:id', authenticateToken, requireRole(['admin', 'staff']), async (req, res, next) => {
  try {
    const { id } = req.params;
    const { label_code, location_description, is_available } = req.body;
    
    // Check if location exists
    const [existing] = await db.query(
      'SELECT * FROM racking_labels WHERE label_id = ?',
      [id]
    );
    
    if (existing.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Storage location not found'
      });
    }
    
    const oldLocation = existing[0];
    
    // Validate data
    const errors = validateStorageLocation({ label_code, location_description }, true);
    if (errors.length > 0) {
      return res.status(400).json({
        status: 'error',
        message: 'Validation failed',
        errors
      });
    }
    
    // Check if label code already exists (if being changed)
    if (label_code && label_code !== oldLocation.label_code) {
      const [duplicate] = await db.query(
        'SELECT label_id FROM racking_labels WHERE label_code = ? AND label_id != ?',
        [label_code, id]
      );
      
      if (duplicate.length > 0) {
        return res.status(409).json({
          status: 'error',
          message: 'Label code already exists'
        });
      }
    }
    
    // Build update query
    const updates = [];
    const params = [];
    
    if (label_code !== undefined) {
      updates.push('label_code = ?');
      params.push(label_code.trim());
    }
    
    if (location_description !== undefined) {
      updates.push('location_description = ?');
      params.push(location_description.trim());
    }
    
    if (is_available !== undefined) {
      updates.push('is_available = ?');
      params.push(is_available ? 1 : 0);
    }
    
    // If no updates
    if (updates.length === 0) {
      return res.status(400).json({
        status: 'error',
        message: 'No data provided for update'
      });
    }
    
    updates.push('updated_at = CURRENT_TIMESTAMP');
    params.push(id);
    
    const query = `
      UPDATE racking_labels 
      SET ${updates.join(', ')}
      WHERE label_id = ?
    `;
    
    await db.query(query, params);
    
    // Get updated location
    const [updatedLocation] = await db.query(
      'SELECT * FROM racking_labels WHERE label_id = ?',
      [id]
    );
    
    // Create audit log
    await createAuditLog(
      req.user.userId,
      'UPDATE',
      'storage_location',
      id,
      oldLocation,
      updatedLocation[0],
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`Storage location updated: ${oldLocation.label_code} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'Storage location updated successfully',
      data: updatedLocation[0]
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @route   DELETE /api/storage/locations/:id
 * @desc    Delete a storage location (if not in use)
 * @access  Private (Admin only)
 */
router.delete('/locations/:id', authenticateToken, requireRole(['admin']), async (req, res, next) => {
  try {
    const { id } = req.params;
    
    // Check if location exists
    const [existing] = await db.query(
      'SELECT * FROM racking_labels WHERE label_id = ?',
      [id]
    );
    
    if (existing.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Storage location not found'
      });
    }
    
    const location = existing[0];
    
    // Check if location has boxes assigned
    const [boxes] = await db.query(
      'SELECT COUNT(*) as box_count FROM boxes WHERE racking_label_id = ?',
      [id]
    );
    
    if (boxes[0].box_count > 0) {
      return res.status(400).json({
        status: 'error',
        message: 'Cannot delete storage location that has boxes assigned',
        data: {
          box_count: boxes[0].box_count
        }
      });
    }
    
    // Delete location
    await db.query('DELETE FROM racking_labels WHERE label_id = ?', [id]);
    
    // Create audit log
    await createAuditLog(
      req.user.userId,
      'DELETE',
      'storage_location',
      id,
      location,
      null,
      req.ip,
      req.get('user-agent')
    );
    
    logger.info(`Storage location deleted: ${location.label_code} by ${req.user.username}`);
    
    res.status(200).json({
      status: 'success',
      message: 'Storage location deleted successfully'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @route   GET /api/storage/stats
 * @desc    Get storage statistics
 * @access  Private (Admin, Staff)
 */
router.get('/stats', authenticateToken, requireRole(['admin', 'staff']), async (req, res, next) => {
  try {
    // Get storage statistics
    const statsQuery = `
      SELECT 
        (SELECT COUNT(*) FROM racking_labels) as total_locations,
        (SELECT COUNT(*) FROM racking_labels WHERE is_available = TRUE) as available_locations,
        (SELECT COUNT(*) FROM racking_labels WHERE is_available = FALSE) as occupied_locations,
        (SELECT COUNT(*) FROM boxes) as total_boxes,
        (SELECT COUNT(DISTINCT racking_label_id) FROM boxes WHERE racking_label_id IS NOT NULL) as locations_in_use,
        (SELECT COUNT(*) FROM boxes WHERE racking_label_id IS NULL) as boxes_without_location
    `;
    
    const [stats] = await db.query(statsQuery);
    
    // Get location utilization
    const utilizationQuery = `
      SELECT 
        rl.label_code,
        rl.location_description,
        rl.is_available,
        COUNT(b.box_id) as box_count,
        CASE 
          WHEN rl.is_available = TRUE THEN 'Available'
          ELSE 'Occupied'
        END as status
      FROM racking_labels rl
      LEFT JOIN boxes b ON rl.label_id = b.racking_label_id
      GROUP BY rl.label_id
      ORDER BY rl.label_code
    `;
    
    const [utilization] = await db.query(utilizationQuery);
    
    // Get recent activities
    const recentActivitiesQuery = `
      SELECT 
        action,
        entity_type,
        entity_id,
        created_at
      FROM audit_logs
      WHERE entity_type IN ('storage_location', 'box')
      ORDER BY created_at DESC
      LIMIT 10
    `;
    
    const [recentActivities] = await db.query(recentActivitiesQuery);
    
    res.status(200).json({
      status: 'success',
      data: {
        summary: stats[0],
        utilization,
        recent_activities: recentActivities
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @route   GET /api/storage/status
 * @desc    Get storage system status and health
 * @access  Private (Admin, Staff)
 */
router.get('/status', authenticateToken, requireRole(['admin', 'staff']), async (req, res, next) => {
  try {
    // FIX: Replace stored procedure call with direct query
    const systemStatsQuery = `
      SELECT 
        (SELECT COUNT(*) FROM boxes) AS total_boxes,
        (SELECT COUNT(*) FROM boxes WHERE status = 'stored') AS boxes_stored,
        (SELECT COUNT(*) FROM boxes WHERE status = 'retrieved') AS boxes_retrieved,
        (SELECT COUNT(*) FROM boxes WHERE status = 'destroyed') AS boxes_destroyed,
        (SELECT COUNT(*) FROM boxes WHERE destruction_year <= YEAR(CURDATE()) AND status = 'stored') AS boxes_pending_destruction,
        (SELECT COUNT(*) FROM clients WHERE is_active = TRUE) AS total_clients,
        (SELECT COUNT(*) FROM users WHERE is_active = TRUE) AS total_users,
        (SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = TRUE) AS admin_users,
        (SELECT COUNT(*) FROM users WHERE role = 'staff' AND is_active = TRUE) AS staff_users,
        (SELECT COUNT(*) FROM users WHERE role = 'client' AND is_active = TRUE) AS client_users,
        (SELECT COUNT(*) FROM requests WHERE status = 'pending') AS pending_requests,
        (SELECT COUNT(*) FROM collections WHERE DATE(created_at) = CURDATE()) AS today_collections,
        (SELECT COUNT(*) FROM retrievals WHERE DATE(created_at) = CURDATE()) AS today_retrievals,
        (SELECT COUNT(*) FROM deliveries WHERE DATE(created_at) = CURDATE()) AS today_deliveries
    `;
    
    const [systemStats] = await db.query(systemStatsQuery);
    
    // Get storage-specific stats
    const storageStatsQuery = `
      SELECT 
        (SELECT COUNT(*) FROM boxes WHERE status = 'stored') as boxes_stored,
        (SELECT COUNT(*) FROM boxes WHERE status = 'retrieved') as boxes_retrieved,
        (SELECT COUNT(*) FROM boxes WHERE status = 'destroyed') as boxes_destroyed,
        (SELECT COUNT(*) FROM boxes WHERE destruction_year <= YEAR(CURDATE()) AND status = 'stored') as boxes_pending_destruction,
        (SELECT COUNT(*) FROM boxes WHERE racking_label_id IS NULL) as boxes_unassigned,
        (SELECT COUNT(*) FROM racking_labels) as total_storage_locations
    `;
    
    const [storageStats] = await db.query(storageStatsQuery);
    
    res.status(200).json({
      status: 'success',
      data: {
        system: systemStats[0],  // Changed from systemStats[0][0] to systemStats[0]
        storage: storageStats[0],
        timestamp: new Date().toISOString()
      }
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;