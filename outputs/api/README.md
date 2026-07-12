# PSMS API - Authentication Module

Physical Storage Management System - Backend Authentication API

## 📁 Project Structure

```
psms-api/
├── config/
│   └── db.js                    # Database connection configuration
├── middleware/
│   ├── auth.middleware.js       # Authentication & authorization middleware
│   └── error.middleware.js      # Error handling middleware
├── routes/
│   └── auth.routes.js           # Authentication routes
├── utils/
│   └── logger.js                # Winston logger utility
├── logs/                        # Application logs (auto-generated)
├── .env                         # Environment variables (create from .env.example)
├── .env.example                 # Environment variables template
├── package.json                 # Project dependencies
└── server.js                    # Main application entry point
```

## 🚀 Getting Started

### Prerequisites

- Node.js >= 16.0.0
- MySQL >= 8.0
- npm >= 8.0.0

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd psms-api
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up database**
   - Create MySQL database using the provided `psms_database.sql` or `psms.sql` file
   - Import the SQL file into your MySQL server

4. **Configure environment variables**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and update the following:
   - `DB_PASSWORD`: Your MySQL password
   - `JWT_SECRET`: Strong secret key for JWT tokens
   - `JWT_REFRESH_SECRET`: Strong secret key for refresh tokens

5. **Start the server**
   ```bash
   # Development mode with auto-reload
   npm run dev
   
   # Production mode
   npm start
   ```

6. **Verify installation**
   - Navigate to `http://localhost:3000/health`
   - You should see: `{"status":"success","message":"PSMS API is running"}`

## 🔐 Authentication API Endpoints

### Base URL
```
http://localhost:3000/api/auth
```

### 1. Login
**POST** `/api/auth/login`

Authenticate user and receive access tokens.

**Request Body:**
```json
{
  "username": "admin",
  "password": "admin123"
}
```

**Response (200 OK):**
```json
{
  "status": "success",
  "message": "Login successful",
  "data": {
    "user": {
      "userId": 1,
      "username": "admin",
      "email": "admin@docsecure.com",
      "role": "admin",
      "clientId": null,
      "clientName": null,
      "clientCode": null,
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
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### 2. Logout
**POST** `/api/auth/logout`

Logout user and invalidate access token.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "status": "success",
  "message": "Logout successful"
}
```

### 3. Refresh Token
**POST** `/api/auth/refresh`

Refresh access token using refresh token.

**Request Body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response (200 OK):**
```json
{
  "status": "success",
  "message": "Token refreshed successfully",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### 4. Get Profile
**GET** `/api/auth/profile`

Get current user's profile information.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "status": "success",
  "data": {
    "userId": 1,
    "username": "admin",
    "email": "admin@docsecure.com",
    "role": "admin",
    "isActive": true,
    "createdAt": "2025-11-18T11:11:04.000Z",
    "updatedAt": "2025-11-19T01:54:02.000Z",
    "client": null,
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
}
```

### 5. Change Password
**POST** `/api/auth/change-password`

Change current user's password.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "currentPassword": "admin123",
  "newPassword": "newSecurePassword123"
}
```

**Response (200 OK):**
```json
{
  "status": "success",
  "message": "Password changed successfully"
}
```

### 6. Verify Token
**POST** `/api/auth/verify-token`

Verify if an access token is valid.

**Request Body:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response (200 OK):**
```json
{
  "status": "success",
  "message": "Token is valid",
  "data": {
    "userId": 1,
    "username": "admin",
    "role": "admin"
  }
}
```

## 🔑 Default Credentials

The database comes with three default users:

1. **Admin User**
   - Username: `admin`
   - Password: `admin123`
   - Role: `admin`

2. **Staff User**
   - Username: `staff1`
   - Password: `admin123`
   - Role: `staff`

3. **Client User**
   - Username: `client1`
   - Password: `admin123`
   - Role: `client`

**⚠️ IMPORTANT:** Change these passwords in production!

## 🛡️ Middleware Usage

### Authentication Middleware

Protect routes that require authentication:

```javascript
const { authenticateToken } = require('./middleware/auth.middleware');

router.get('/protected-route', authenticateToken, (req, res) => {
  // req.user contains authenticated user info
  res.json({ user: req.user });
});
```

### Role-Based Authorization

Restrict routes to specific roles:

```javascript
const { authenticateToken, authorizeRoles } = require('./middleware/auth.middleware');

// Only admin and staff can access
router.post('/admin-only', 
  authenticateToken, 
  authorizeRoles('admin', 'staff'), 
  (req, res) => {
    res.json({ message: 'Admin or staff access granted' });
  }
);
```

### Permission-Based Authorization

Check specific permissions:

```javascript
const { authenticateToken, authorizePermission } = require('./middleware/auth.middleware');

// Only users with 'canCreateBoxes' permission can access
router.post('/boxes', 
  authenticateToken, 
  authorizePermission('canCreateBoxes'), 
  (req, res) => {
    res.json({ message: 'Box creation allowed' });
  }
);
```

### Client Data Access Control

Ensure clients can only access their own data:

```javascript
const { authenticateToken, authorizeOwnClient } = require('./middleware/auth.middleware');

// Clients can only access their own data, admin/staff can access all
router.get('/clients/:clientId/boxes', 
  authenticateToken, 
  authorizeOwnClient, 
  (req, res) => {
    res.json({ clientId: req.params.clientId });
  }
);
```

## 📝 Error Responses

All error responses follow this format:

```json
{
  "status": "error",
  "message": "Error description"
}
```

### Common HTTP Status Codes

- **200** - Success
- **201** - Created
- **400** - Bad Request (validation error)
- **401** - Unauthorized (authentication required)
- **403** - Forbidden (insufficient permissions)
- **404** - Not Found
- **500** - Internal Server Error

## 🔒 Security Features

1. **Password Hashing**: Uses bcrypt with 12 salt rounds
2. **JWT Tokens**: Signed and expiring tokens
3. **Token Blacklisting**: Logout invalidates tokens
4. **Token Refresh**: Separate refresh tokens with longer expiry
5. **Role-Based Access Control (RBAC)**: Three user roles (admin, staff, client)
6. **Permission-Based Access**: Granular permissions per user
7. **Audit Logging**: All authentication events logged
8. **Helmet.js**: Security headers
9. **CORS**: Configurable cross-origin resource sharing

## 📊 Logging

Logs are stored in the `logs/` directory:

- `error.log` - Error-level logs
- `combined.log` - All logs
- `app-YYYY-MM-DD.log` - Daily rotating logs
- `exceptions.log` - Uncaught exceptions
- `rejections.log` - Unhandled promise rejections

## 🧪 Testing

Test the authentication endpoints using curl or Postman:

### Login Example (curl)
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### Get Profile Example (curl)
```bash
curl -X GET http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## 🚦 Health Check

Monitor API health:

```bash
curl http://localhost:3000/health
```

## 🔧 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment (development/production) | `development` |
| `PORT` | Server port | `3000` |
| `DB_HOST` | MySQL host | `localhost` |
| `DB_PORT` | MySQL port | `3306` |
| `DB_USER` | MySQL username | `root` |
| `DB_PASSWORD` | MySQL password | - |
| `DB_NAME` | Database name | `psms` |
| `JWT_SECRET` | JWT signing secret | - |
| `JWT_EXPIRES_IN` | JWT expiry duration | `24h` |
| `JWT_REFRESH_SECRET` | Refresh token secret | - |
| `JWT_REFRESH_EXPIRES_IN` | Refresh token expiry | `7d` |
| `ALLOWED_ORIGINS` | CORS allowed origins | `*` |
| `LOG_LEVEL` | Logging level | `info` |

## 📦 Dependencies

### Production
- `express` - Web framework
- `mysql2` - MySQL client with promise support
- `bcryptjs` - Password hashing
- `jsonwebtoken` - JWT implementation
- `winston` - Logging library
- `helmet` - Security headers
- `cors` - CORS middleware
- `morgan` - HTTP request logger
- `dotenv` - Environment variable management

### Development
- `nodemon` - Auto-restart during development
- `eslint` - Code linting
- `jest` - Testing framework
- `supertest` - HTTP assertions

## 🤝 Contributing

1. Follow the existing code structure
2. Use meaningful commit messages
3. Add JSDoc comments to functions
4. Test all endpoints before committing

## 📄 License

MIT

## 🆘 Support

For issues or questions, please contact the development team.

---

**Built with ❤️ for PSMS**
