const { ValidationError } = require('../middleware/Error.middleware');

// ============================================
// VALIDATION SCHEMAS
// ============================================

const validationSchemas = {
  createUser: {
    username: { required: true, type: 'string', minLength: 3, maxLength: 100 },
    email: { required: true, type: 'email' },
    password: { required: true, type: 'string', minLength: 6 },
    role: { required: true, type: 'enum', values: ['admin', 'staff', 'client'] },
    clientId: { required: false, type: 'number' },
    permissions: { required: false, type: 'object' }
  },
  
  updateUser: {
    username: { required: true, type: 'string', minLength: 3, maxLength: 100 },
    email: { required: true, type: 'email' }
  },
  
  resetPassword: {
    newPassword: { required: true, type: 'string', minLength: 6 }
  },
  
  assignClient: {
    clientId: { required: true, type: 'number' }
  },
  
  updatePermissions: {
    permissions: {
      required: true,
      type: 'object',
      properties: {
        canCreateBoxes: { type: 'boolean' },
        canEditBoxes: { type: 'boolean' },
        canDeleteBoxes: { type: 'boolean' },
        canCreateCollections: { type: 'boolean' },
        canCreateRetrievals: { type: 'boolean' },
        canCreateDeliveries: { type: 'boolean' },
        canViewReports: { type: 'boolean' },
        canManageUsers: { type: 'boolean' }
      }
    }
  },
  
  grantPermission: {
    permission: {
      required: true,
      type: 'enum',
      values: [
        'canCreateBoxes', 'canEditBoxes', 'canDeleteBoxes',
        'canCreateCollections', 'canCreateRetrievals', 'canCreateDeliveries',
        'canViewReports', 'canManageUsers'
      ]
    }
  },
  
  bulkCreateUsers: {
    users: {
      required: true,
      type: 'array',
      minLength: 1,
      items: {
        username: { required: true, type: 'string', minLength: 3 },
        email: { required: true, type: 'email' },
        password: { required: true, type: 'string', minLength: 6 },
        role: { required: true, type: 'enum', values: ['admin', 'staff', 'client'] },
        clientId: { required: false, type: 'number' }
      }
    }
  },
  
  bulkOperation: {
    userIds: { required: true, type: 'array', minLength: 1, items: { type: 'number' } }
  },
  
  changeRole: {
    role: { required: true, type: 'enum', values: ['admin', 'staff', 'client'] }
  }
};

// ============================================
// VALIDATION HELPERS
// ============================================

/**
 * Validate email format
 */
const isValidEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

/**
 * Validate field based on schema
 */
const validateField = (field, value, schema) => {
  // Check required
  if (schema.required && (value === undefined || value === null || value === '')) {
    throw new ValidationError(`${field} is required`);
  }
  
  // If not required and value is empty, skip other validations
  if (!schema.required && (value === undefined || value === null || value === '')) {
    return;
  }
  
  // Check type
  if (schema.type === 'string' && typeof value !== 'string') {
    throw new ValidationError(`${field} must be a string`);
  }
  
  if (schema.type === 'number' && typeof value !== 'number') {
    throw new ValidationError(`${field} must be a number`);
  }
  
  if (schema.type === 'boolean' && typeof value !== 'boolean') {
    throw new ValidationError(`${field} must be a boolean`);
  }
  
  if (schema.type === 'array' && !Array.isArray(value)) {
    throw new ValidationError(`${field} must be an array`);
  }
  
  if (schema.type === 'object' && (typeof value !== 'object' || Array.isArray(value))) {
    throw new ValidationError(`${field} must be an object`);
  }
  
  if (schema.type === 'email' && !isValidEmail(value)) {
    throw new ValidationError(`${field} must be a valid email address`);
  }
  
  // Check enum values
  if (schema.type === 'enum' && !schema.values.includes(value)) {
    throw new ValidationError(`${field} must be one of: ${schema.values.join(', ')}`);
  }
  
  // Check string length
  if (schema.type === 'string' && schema.minLength && value.length < schema.minLength) {
    throw new ValidationError(`${field} must be at least ${schema.minLength} characters long`);
  }
  
  if (schema.type === 'string' && schema.maxLength && value.length > schema.maxLength) {
    throw new ValidationError(`${field} must be at most ${schema.maxLength} characters long`);
  }
  
  // Check array length
  if (schema.type === 'array' && schema.minLength && value.length < schema.minLength) {
    throw new ValidationError(`${field} must contain at least ${schema.minLength} items`);
  }
  
  if (schema.type === 'array' && schema.maxLength && value.length > schema.maxLength) {
    throw new ValidationError(`${field} must contain at most ${schema.maxLength} items`);
  }
  
  // Validate array items
  if (schema.type === 'array' && schema.items) {
    value.forEach((item, index) => {
      if (schema.items.type === 'number' && typeof item !== 'number') {
        throw new ValidationError(`${field}[${index}] must be a number`);
      }
      if (schema.items.type === 'string' && typeof item !== 'string') {
        throw new ValidationError(`${field}[${index}] must be a string`);
      }
      
      // Validate array item as object
      if (typeof schema.items === 'object' && !schema.items.type) {
        Object.keys(schema.items).forEach(key => {
          validateField(`${field}[${index}].${key}`, item[key], schema.items[key]);
        });
      }
    });
  }
  
  // Validate object properties
  if (schema.type === 'object' && schema.properties) {
    Object.keys(value).forEach(key => {
      if (schema.properties[key]) {
        validateField(`${field}.${key}`, value[key], schema.properties[key]);
      }
    });
  }
};

/**
 * Validate request body against schema
 */
const validateRequestBody = (body, schema) => {
  Object.keys(schema).forEach(field => {
    validateField(field, body[field], schema[field]);
  });
};

// ============================================
// VALIDATION MIDDLEWARE
// ============================================

/**
 * Create validation middleware for a specific schema
 */
exports.validateRequest = (schemaName) => {
  return (req, res, next) => {
    try {
      const schema = validationSchemas[schemaName];
      
      if (!schema) {
        throw new Error(`Validation schema '${schemaName}' not found`);
      }
      
      validateRequestBody(req.body, schema);
      
      next();
      
    } catch (error) {
      if (error instanceof ValidationError) {
        next(error);
      } else {
        next(new ValidationError(error.message));
      }
    }
  };
};

// ============================================
// CUSTOM VALIDATORS (for specific use cases)
// ============================================

/**
 * Validate user ID parameter
 */
exports.validateUserId = (req, res, next) => {
  try {
    const { userId } = req.params;
    
    if (!userId || isNaN(userId)) {
      throw new ValidationError('Invalid user ID');
    }
    
    next();
    
  } catch (error) {
    next(error);
  }
};

/**
 * Validate client ID parameter
 */
exports.validateClientId = (req, res, next) => {
  try {
    const { clientId } = req.params;
    
    if (!clientId || isNaN(clientId)) {
      throw new ValidationError('Invalid client ID');
    }
    
    next();
    
  } catch (error) {
    next(error);
  }
};

/**
 * Validate pagination parameters
 */
exports.validatePagination = (req, res, next) => {
  try {
    const { page, limit } = req.query;
    
    if (page && (isNaN(page) || parseInt(page) < 1)) {
      throw new ValidationError('Page must be a positive integer');
    }
    
    if (limit && (isNaN(limit) || parseInt(limit) < 1 || parseInt(limit) > 100)) {
      throw new ValidationError('Limit must be between 1 and 100');
    }
    
    next();
    
  } catch (error) {
    next(error);
  }
};