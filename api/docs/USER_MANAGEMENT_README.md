# PSMS API - User Management Module

Complete user management system with granular control over staff and client users.

## 📁 Files Structure (Matches Auth Pattern)

```
psms-api/
├── routes/
│   ├── auth.routes.js          # Authentication (existing)
│   └── user.routes.js          # User management (NEW) ✨
├── validators/
│   └── user.validator.js       # Request validation (NEW)
├── middleware/
│   ├── auth.middleware.js      # Auth & authorization
│   └── error.middleware.js     # Error handling
├── config/
│   └── db.js                   # Database connection
├── utils/
│   └── logger.js               # Winston logger
└── server.js                   # Updated with user routes

NO CONTROLLERS - Everything inline in routes! 🚀
```

## ✨ Architecture Pattern

**Same as auth.routes.js:**
- ✅ All business logic inline in routes file
- ✅ Helper functions defined at top of file
- ✅ Direct database queries with `db.query()`
- ✅ Middleware composition for authorization
- ✅ Comprehensive error handling
- ✅ Audit logging built-in

**Just 2 new files:**
1. `routes/user.routes.js` - All user management logic
2. `validators/user.validator.js` - Request validation

## 🚀 Features

### ✅ Complete User CRUD
- Create users (admin, staff, client)
- Read user details with full information
- Update user information
- Activate/Deactivate users
- Delete users (soft delete)
- Reset user passwords

### 👥 Client-User Mapping (GRANULAR!)
- Assign users to client companies
- Remove users from clients
- Change user's client assignment
- View all users for a specific client
- **Explicit control over who belongs to which company**

### 🔐 Granular Permission Control
- View user permissions
- Update all permissions at once
- Grant specific permissions
- Revoke specific permissions
- 8 different permission types
- **Fine-grained control over every permission**

### 📊 Advanced Queries
- Filter by role (admin/staff/client)
- Filter by active status
- Search by username, email, or client name
- Get users by specific client
- Pagination support (up to 100 per page)
- User statistics dashboard

### 🔄 Bulk Operations
- Bulk create multiple users
- Bulk activate users
- Bulk deactivate users
- **Perfect for importing users from spreadsheets**

### 🎭 Role Management
- Change user roles dynamically
- Prevent self-role changes
- Automatic permission defaults per role

## 🔑 8 Permission Types

```javascript
{
  canCreateBoxes: true,        // Create new document boxes
  canEditBoxes: true,          // Edit existing boxes
  canDeleteBoxes: false,       // Delete boxes (destructive)
  canCreateCollections: true,  // Record box collections
  canCreateRetrievals: true,   // Record box retrievals
  canCreateDeliveries: true,   // Record item deliveries
  canViewReports: true,        // View reports & analytics
  canManageUsers: false        // Manage other users (admin-level)
}
```

## 📋 All Endpoints (25+)

### User CRUD
```
GET    /api/users                      # List all (filtered, paginated)
GET    /api/users/stats                # User statistics
GET    /api/users/role/:role           # Get by role
GET    /api/users/client/:clientId     # Get by client company
GET    /api/users/:userId              # Single user details
POST   /api/users                      # Create user
PUT    /api/users/:userId              # Update user
PATCH  /api/users/:userId/activate     # Activate account
PATCH  /api/users/:userId/deactivate   # Deactivate account
DELETE /api/users/:userId              # Delete (soft)
POST   /api/users/:userId/reset-password  # Admin reset password
```

### Client Mapping (THE GRANULAR CONTROL!)
```
POST   /api/users/:userId/assign-client    # Assign to company
DELETE /api/users/:userId/remove-client    # Remove from company
PUT    /api/users/:userId/change-client    # Change company
```

### Permission Management (GRANULAR!)
```
GET  /api/users/:userId/permissions         # View permissions
PUT  /api/users/:userId/permissions         # Update all permissions
POST /api/users/:userId/permissions/grant   # Grant one permission
POST /api/users/:userId/permissions/revoke  # Revoke one permission
```

### Bulk Operations
```
POST  /api/users/bulk/create        # Create multiple users
PATCH /api/users/bulk/activate      # Activate multiple
PATCH /api/users/bulk/deactivate    # Deactivate multiple
```

### Role Management
```
PATCH /api/users/:userId/role       # Change user role
```

## 📝 Quick Examples

### 1. Create Staff User

```bash
POST /api/users
Authorization: Bearer <admin_token>

{
  "username": "john_staff",
  "email": "john@psms.com",
  "password": "secure123",
  "role": "staff",
  "permissions": {
    "canCreateBoxes": true,
    "canEditBoxes": true,
    "canDeleteBoxes": false,
    "canViewReports": true
  }
}
```

### 2. Create Client User (Mapped to Company)

```bash
POST /api/users
Authorization: Bearer <admin_token>

{
  "username": "acme_user",
  "email": "user@acme.com",
  "password": "secure123",
  "role": "client",
  "clientId": 1,              # Maps to Acme Corporation
  "permissions": {
    "canViewReports": true
  }
}
```

### 3. Assign User to Client Company

```bash
POST /api/users/5/assign-client
Authorization: Bearer <admin_token>

{
  "clientId": 2
}
```

### 4. Update Permissions (Granular Control)

```bash
PUT /api/users/5/permissions
Authorization: Bearer <admin_token>

{
  "permissions": {
    "canCreateBoxes": true,
    "canEditBoxes": true,
    "canDeleteBoxes": true,      # Now has delete permission
    "canCreateCollections": true,
    "canCreateRetrievals": true,
    "canCreateDeliveries": true,
    "canViewReports": true,
    "canManageUsers": false      # Still can't manage users
  }
}
```

### 5. Grant Single Permission

```bash
POST /api/users/5/permissions/grant
Authorization: Bearer <admin_token>

{
  "permission": "canDeleteBoxes"
}
```

### 6. Get All Staff Users

```bash
GET /api/users/role/staff
Authorization: Bearer <admin_token>
```

### 7. Get All Users for Acme Corporation

```bash
GET /api/users/client/1
Authorization: Bearer <admin_token>
```

### 8. Search Users

```bash
GET /api/users?search=john&isActive=true&page=1&limit=20
Authorization: Bearer <admin_token>
```

### 9. Bulk Create Users

```bash
POST /api/users/bulk/create
Authorization: Bearer <admin_token>

{
  "users": [
    {
      "username": "staff1",
      "email": "staff1@psms.com",
      "password": "pass123",
      "role": "staff"
    },
    {
      "username": "client1",
      "email": "client1@acme.com",
      "password": "pass123",
      "role": "client",
      "clientId": 1
    }
  ]
}
```

### 10. Change User Role

```bash
PATCH /api/users/5/role
Authorization: Bearer <admin_token>

{
  "role": "admin"
}
```

## 🔒 Authorization

**All routes require:**
- Valid JWT token (from login)
- Admin role (most endpoints)
- Some GET endpoints allow staff role

```javascript
// Middleware chain in routes
router.get('/', 
  authenticateToken,           // Verify JWT
  authorizeRoles('admin', 'staff'),  // Check role
  async (req, res, next) => { ... }
);
```

## 📊 Default Permissions by Role

| Permission | Admin | Staff | Client |
|-----------|-------|-------|--------|
| canCreateBoxes | ✅ | ✅ | ❌ |
| canEditBoxes | ✅ | ✅ | ❌ |
| canDeleteBoxes | ✅ | ❌ | ❌ |
| canCreateCollections | ✅ | ✅ | ❌ |
| canCreateRetrievals | ✅ | ✅ | ❌ |
| canCreateDeliveries | ✅ | ✅ | ❌ |
| canViewReports | ✅ | ✅ | ✅ |
| canManageUsers | ✅ | ❌ | ❌ |

**Note:** These are defaults. You can customize any user's permissions individually!

## 🛡️ Security Features

1. **Self-Protection** - Can't deactivate/delete own account
2. **Password Security** - Bcrypt with 12 salt rounds
3. **Role Validation** - Only valid roles accepted
4. **Client Validation** - Client must exist before assignment
5. **Permission Validation** - Only valid permissions can be granted
6. **Audit Logging** - Every action logged with details
7. **Transaction Safety** - Database transactions for multi-step ops
8. **Role Protection** - Can't change own role

## 🧪 Testing with Postman

1. **Import:** `PSMS_User_Management_Postman_Collection.json`
2. **Login:** Run "0. Setup - Login as Admin"
3. **Auto-saved:** Token saved for all requests
4. **Test:** 30+ ready-to-use requests organized in 6 folders

### Collection Structure:
```
📁 0. Setup - Login as Admin
📁 1. User CRUD (10 requests)
📁 2. Query Users (5 requests)
📁 3. Client Mapping (3 requests)
📁 4. Permission Management (4 requests)
📁 5. Bulk Operations (3 requests)
📁 6. Role Management (1 request)
```

## 🔍 Query Filters

### GET /api/users supports:

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `role` | string | Filter by role | `role=staff` |
| `isActive` | boolean | Filter by status | `isActive=true` |
| `clientId` | number | Filter by client | `clientId=1` |
| `search` | string | Search username/email/client | `search=john` |
| `page` | number | Page number | `page=1` |
| `limit` | number | Results per page (max 100) | `limit=20` |

### Example:
```
GET /api/users?role=staff&isActive=true&search=john&page=1&limit=20
```

## 📈 Response Format

### Success Response
```json
{
  "status": "success",
  "message": "Operation successful",
  "data": { ... }
}
```

### Paginated Response
```json
{
  "status": "success",
  "data": {
    "users": [ ... ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 50,
      "totalPages": 3
    }
  }
}
```

### Error Response
```json
{
  "status": "error",
  "message": "Error description"
}
```

## 💡 Common Use Cases

### 1. Onboard New Staff Member
```bash
# Create staff user
POST /api/users
{
  "username": "jane_doe",
  "email": "jane@psms.com",
  "password": "temp123",
  "role": "staff",
  "permissions": {
    "canCreateBoxes": true,
    "canEditBoxes": true,
    "canViewReports": true
  }
}

# Staff changes password on first login via /api/auth/change-password
```

### 2. Setup Client Company Access
```bash
# Create client user for Acme Corporation
POST /api/users
{
  "username": "john_acme",
  "email": "john@acme.com",
  "password": "secure123",
  "role": "client",
  "clientId": 1,          # Acme Corporation
  "permissions": {
    "canViewReports": true
  }
}

# John can now only see Acme's data
```

### 3. Promote Staff to Admin
```bash
# Change role
PATCH /api/users/5/role
{ "role": "admin" }

# Grant all permissions
PUT /api/users/5/permissions
{
  "permissions": {
    "canCreateBoxes": true,
    "canEditBoxes": true,
    "canDeleteBoxes": true,
    "canCreateCollections": true,
    "canCreateRetrievals": true,
    "canCreateDeliveries": true,
    "canViewReports": true,
    "canManageUsers": true
  }
}
```

### 4. Move User Between Companies
```bash
# User was with Acme (clientId: 1), now with Global (clientId: 2)
PUT /api/users/7/change-client
{
  "clientId": 2
}
```

### 5. Temporarily Suspend User
```bash
# Deactivate account
PATCH /api/users/8/deactivate

# Later, reactivate
PATCH /api/users/8/activate
```

## 🚨 Common Errors

| Status | Message | Solution |
|--------|---------|----------|
| 400 | Invalid role | Use admin, staff, or client |
| 400 | Client ID required for client role | Include clientId for client users |
| 400 | Cannot deactivate your own account | Use different admin |
| 401 | Authentication required | Include valid JWT token |
| 403 | You do not have permission | Only admins can manage users |
| 404 | User not found | Check userId is correct |
| 404 | Client not found | Check clientId exists |

## 🎯 What Makes This Powerful

### 1. Explicit Client Mapping
```javascript
// Before: User has no company
{ userId: 5, clientId: null }

// Assign to company
POST /api/users/5/assign-client { "clientId": 1 }

// After: User belongs to Acme
{ userId: 5, clientId: 1, clientName: "Acme Corporation" }
```

### 2. Granular Permissions
```javascript
// Give staff MOST permissions but not destructive ones
{
  canCreateBoxes: true,      // ✅ Can create
  canEditBoxes: true,        // ✅ Can edit
  canDeleteBoxes: false,     // ❌ Can't delete (destructive)
  canManageUsers: false      // ❌ Can't manage users (admin-only)
}
```

### 3. Flexible Role Management
```javascript
// Start as staff
{ role: "staff" }

// Promote to admin
PATCH /api/users/5/role { "role": "admin" }

// Grant full permissions separately
PUT /api/users/5/permissions { ... }
```

## 📦 No Extra Dependencies!

Uses existing packages:
- `bcryptjs` - Password hashing
- `express` - Routing
- `mysql2` - Database

## 🔄 Integration with Existing Code

```javascript
// server.js
const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');  // NEW!

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);  // NEW!
```

That's it! Same pattern as auth routes.

## 📊 Database Tables Used

- `users` - User accounts
- `permissions` - Granular permissions
- `clients` - Client companies
- `audit_logs` - All actions logged

All tables already exist in your PSMS database!

## 🎬 Getting Started

```bash
# 1. Ensure server is running
npm run dev

# 2. Login as admin
POST /api/auth/login
{
  "username": "admin",
  "password": "admin123"
}

# 3. Create your first staff user
POST /api/users
{
  "username": "staff_jane",
  "email": "jane@psms.com",
  "password": "secure123",
  "role": "staff"
}

# 4. Create client user for Acme
POST /api/users
{
  "username": "john_acme",
  "email": "john@acme.com",
  "password": "secure123",
  "role": "client",
  "clientId": 1
}

# 5. Manage permissions as needed
PUT /api/users/4/permissions
{ ... }
```

## 💪 Ready for Production

- ✅ Comprehensive error handling
- ✅ Input validation on all endpoints
- ✅ Audit trail for compliance
- ✅ Transaction safety
- ✅ Security best practices
- ✅ Scalable pagination
- ✅ Bulk operations for efficiency

## 🎯 Next Steps

With user management complete, you can now:

1. **Build the Flutter app** - Connect to these endpoints
2. **Add Client Management** - CRUD for client companies
3. **Add Box Management** - Create and track document boxes
4. **Add Collections/Retrievals** - Track box movements
5. **Add Reporting** - Generate reports for clients

---

**🎉 Complete User Management - Just 2 Files!**

`routes/user.routes.js` + `validators/user.validator.js` = Full Control