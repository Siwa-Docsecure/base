# PSMS API - Box & Collection Management

Complete box tracking and collection management system with filtering, pagination, and bulk operations.

## 📁 Files Structure (Inline Routes Pattern)

```
psms-api/
├── routes/
│   ├── auth.routes.js          # Authentication ✅
│   ├── user.routes.js          # User management ✅
│   ├── box.routes.js           # Box management (NEW) ✨
│   └── collection.routes.js    # Collections (NEW) ✨
├── validators/
│   └── user.validator.js
├── middleware/
│   ├── auth.middleware.js      # Has authorizePermission!
│   └── error.middleware.js
├── config/
│   └── db.js
├── utils/
│   └── logger.js
└── server.js                   # Updated with new routes

NO CONTROLLERS - Everything inline! 🚀
```

## 🎯 What's New

### **Box Management (box.routes.js)**
Track physical document storage boxes with:
- half Auto-generated box numbers (BOX-CLI001-0001)
- Client assignment
- Physical racking location
- Retention period tracking
- Destruction year calculation
- Status tracking (stored/retrieved/destroyed)
- Pending destruction alerts

### **Collection Management (collection.routes.js)**
Record box collection activities with:
- Client collection records
- Digital signatures (dispatcher & collector)
- PDF receipt generation
- Date tracking
- Box count tracking
- Collection reports

---

## 📦 BOX MANAGEMENT

### **Box Object Structure**

```javascript
{
  boxId: 1,
  boxNumber: "BOX-CLI001-0001",        // Auto-generated
  description: "Financial Records 2024",
  dateReceived: "2024-01-15",
  yearReceived: 2024,
  retentionYears: 7,
  destructionYear: 2031,               // Auto-calculated
  status: "stored",                    // stored/retrieved/destroyed
  isPendingDestruction: false,
  client: {
    clientId: 1,
    clientName: "Acme Corporation",
    clientCode: "CLI-001"
  },
  rackingLabel: {
    labelId: 1,
    labelCode: "RACK-A-01",
    location: "Warehouse A - Section 1 - Level 1"
  },
  createdAt: "2024-01-15T10:30:00Z",
  updatedAt: "2024-01-15T10:30:00Z"
}
```

### **Box Endpoints (13)**

#### Get All Boxes (Filtered & Paginated)
```bash
GET /api/boxes
Authorization: Bearer <token>
Roles: admin, staff

Query Parameters:
- clientId (number): Filter by client
- status (string): stored/retrieved/destroyed
- pendingDestruction (boolean): Only pending destruction
- rackingLabelId (number): Filter by location
- search (string): Search box number/description/client
- page (number): Page number (default: 1)
- limit (number): Results per page (default: 50)
- sortBy (string): box_number/date_received/destruction_year/created_at
- sortOrder (string): ASC/DESC (default: DESC)

Example:
GET /api/boxes?clientId=1&status=stored&page=1&limit=20
```

#### Get Box Statistics
```bash
GET /api/boxes/stats
Authorization: Bearer <token>
Roles: admin, staff

Response:
{
  "status": "success",
  "data": {
    "total_boxes": 150,
    "boxes_stored": 120,
    "boxes_retrieved": 20,
    "boxes_destroyed": 10,
    "boxes_pending_destruction": 5,
    "total_clients_with_boxes": 12
  }
}
```

#### Get Pending Destruction Boxes
```bash
GET /api/boxes/pending-destruction
Authorization: Bearer <token>
Roles: admin, staff

Response: List of boxes where destruction_year <= current year
```

#### Get Boxes by Client
```bash
GET /api/boxes/client/:clientId
Authorization: Bearer <token>
Roles: admin, staff, client (own boxes only)

Example:
GET /api/boxes/client/1
```

#### Get Single Box
```bash
GET /api/boxes/:boxId
Authorization: Bearer <token>
Roles: admin, staff, client (own boxes only)

Example:
GET /api/boxes/123
```

#### Create Box
```bash
POST /api/boxes
Authorization: Bearer <token>
Roles: admin, staff (with canCreateBoxes permission)

{
  "clientId": 1,
  "rackingLabelId": 5,              // Optional
  "boxDescription": "Financial Records Q1-Q4 2024",
  "dateReceived": "2024-01-15",
  "retentionYears": 7               // Default: 7
}

Response:
{
  "status": "success",
  "message": "Box created successfully",
  "data": {
    "boxId": 16,
    "boxNumber": "BOX-CLI001-0016",  // Auto-generated
    "clientId": 1,
    "destructionYear": 2031           // Auto-calculated
  }
}
```

**Box Number Generation:**
- Format: `BOX-{CLIENT_CODE}-{SEQUENCE}`
- Example: `BOX-CLI001-0001`, `BOX-CLI001-0002`
- Auto-increments per client
- 4-digit padded sequence

#### Update Box
```bash
PUT /api/boxes/:boxId
Authorization: Bearer <token>
Roles: admin, staff (with canEditBoxes permission)

{
  "boxDescription": "Updated description",
  "rackingLabelId": 10,
  "retentionYears": 10
}

Note: Updating retentionYears recalculates destructionYear
```

#### Change Box Status
```bash
PATCH /api/boxes/:boxId/status
Authorization: Bearer <token>
Roles: admin, staff

{
  "status": "retrieved"  // stored/retrieved/destroyed
}
```

#### Delete Box
```bash
DELETE /api/boxes/:boxId
Authorization: Bearer <token>
Roles: admin, staff (with canDeleteBoxes permission)
```

#### Bulk Create Boxes
```bash
POST /api/boxes/bulk/create
Authorization: Bearer <token>
Roles: admin, staff (with canCreateBoxes permission)

{
  "boxes": [
    {
      "clientId": 1,
      "boxDescription": "HR Files 2024",
      "dateReceived": "2024-01-15",
      "retentionYears": 7
    },
    {
      "clientId": 1,
      "boxDescription": "Legal Contracts",
      "dateReceived": "2024-02-01",
      "retentionYears": 10
    }
  ]
}

Response:
{
  "status": "success",
  "data": {
    "success": [
      { "boxNumber": "BOX-CLI001-0017", "boxId": 17 },
      { "boxNumber": "BOX-CLI001-0018", "boxId": 18 }
    ],
    "failed": []
  }
}
```

#### Bulk Update Box Status
```bash
PATCH /api/boxes/bulk/status
Authorization: Bearer <token>
Roles: admin, staff

{
  "boxIds": [1, 2, 3, 4, 5],
  "status": "destroyed"
}
```

---

## 📋 COLLECTION MANAGEMENT

### **Collection Object Structure**

```javascript
{
  collectionId: 1,
  client: {
    clientId: 1,
    clientName: "Acme Corporation",
    clientCode: "CLI-001",
    contactPerson: "John Smith"
  },
  totalBoxes: 15,
  boxDescription: "Q4 2024 Financial Records",
  dispatcherName: "John Smith",
  collectorName: "Jane Doe",
  dispatcherSignature: "data:image/png;base64,...",  // Optional
  collectorSignature: "data:image/png;base64,...",   // Optional
  collectionDate: "2024-11-15",
  pdfPath: "/receipts/collection-123.pdf",           // Optional
  createdBy: {
    userId: 2,
    username: "staff_jane"
  },
  createdAt: "2024-11-15T10:30:00Z"
}
```

### **Collection Endpoints (13)**

#### Get All Collections (Filtered & Paginated)
```bash
GET /api/collections
Authorization: Bearer <token>
Roles: admin, staff

Query Parameters:
- clientId (number): Filter by client
- startDate (date): From date
- endDate (date): To date
- search (string): Search description/client/dispatcher/collector
- page (number): Page number
- limit (number): Results per page
- sortBy (string): collection_date/total_boxes/created_at
- sortOrder (string): ASC/DESC

Example:
GET /api/collections?clientId=1&startDate=2024-01-01&endDate=2024-12-31
```

#### Get Collection Statistics
```bash
GET /api/collections/stats
Authorization: Bearer <token>
Roles: admin, staff

Response:
{
  "status": "success",
  "data": {
    "total_collections": 250,
    "total_boxes_collected": 1500,
    "clients_with_collections": 15,
    "today_collections": 5,
    "this_week_collections": 25,
    "this_month_collections": 80
  }
}
```

#### Get Recent Collections
```bash
GET /api/collections/recent?limit=10
Authorization: Bearer <token>
Roles: admin, staff

Returns: Last N collections
```

#### Get Collections by Client
```bash
GET /api/collections/client/:clientId
Authorization: Bearer <token>
Roles: admin, staff, client (own collections only)

Example:
GET /api/collections/client/1
```

#### Get Single Collection
```bash
GET /api/collections/:collectionId
Authorization: Bearer <token>
Roles: admin, staff, client (own collections only)

Includes: Full details with signatures
```

#### Create Collection
```bash
POST /api/collections
Authorization: Bearer <token>
Roles: admin, staff (with canCreateCollections permission)

{
  "clientId": 1,
  "totalBoxes": 15,
  "boxDescription": "Q4 Financial Records",
  "dispatcherName": "John Smith",
  "collectorName": "Jane Doe",
  "dispatcherSignature": "data:image/png;base64,...",  // Optional
  "collectorSignature": "data:image/png;base64,...",   // Optional
  "collectionDate": "2024-11-15"
}

Response:
{
  "status": "success",
  "message": "Collection created successfully",
  "data": {
    "collectionId": 51,
    "clientId": 1,
    "totalBoxes": 15,
    "collectionDate": "2024-11-15"
  }
}
```

#### Update Collection
```bash
PUT /api/collections/:collectionId
Authorization: Bearer <token>
Roles: admin, staff (with canCreateCollections permission)

{
  "totalBoxes": 18,
  "boxDescription": "Updated description",
  "dispatcherName": "John Smith Jr."
}
```

#### Update Collection Signatures
```bash
PATCH /api/collections/:collectionId/signatures
Authorization: Bearer <token>
Roles: admin, staff (with canCreateCollections permission)

{
  "dispatcherSignature": "data:image/png;base64,...",
  "collectorSignature": "data:image/png;base64,..."
}
```

#### Update Collection PDF Path
```bash
PATCH /api/collections/:collectionId/pdf
Authorization: Bearer <token>
Roles: admin, staff

{
  "pdfPath": "/receipts/collection-51.pdf"
}
```

#### Delete Collection
```bash
DELETE /api/collections/:collectionId
Authorization: Bearer <token>
Roles: admin (only)
```

#### Get Collections Summary Report
```bash
GET /api/collections/reports/summary
Authorization: Bearer <token>
Roles: admin, staff

Query Parameters:
- startDate (date): From date
- endDate (date): To date
- clientId (number): Optional client filter

Response: Daily breakdown of collections
[
  {
    "date": "2024-11-15",
    "collection_count": 5,
    "total_boxes": 75,
    "unique_clients": 3
  }
]
```

#### Get Collections by Client Report
```bash
GET /api/collections/reports/by-client
Authorization: Bearer <token>
Roles: admin, staff

Query Parameters:
- startDate (date): From date
- endDate (date): To date

Response: Collections grouped by client
[
  {
    "client_id": 1,
    "client_name": "Acme Corporation",
    "client_code": "CLI-001",
    "collection_count": 15,
    "total_boxes_collected": 225,
    "last_collection_date": "2024-11-15"
  }
]
```

---

## 🔐 Permissions Used

### Box Management
- `canCreateBoxes` - Create new boxes (staff/admin)
- `canEditBoxes` - Update box details (staff/admin)
- `canDeleteBoxes` - Delete boxes (admin, some staff)

### Collection Management
- `canCreateCollections` - Create/update collections (staff/admin)

**Client Users:**
- Can view their own boxes: `GET /api/boxes/client/:clientId`
- Can view their own collections: `GET /api/collections/client/:clientId`
- Cannot create, update, or delete

---

## 🚀 Quick Examples

### 1. Create Box with Auto-Generated Number

```bash
POST /api/boxes
Authorization: Bearer <admin_token>

{
  "clientId": 1,
  "rackingLabelId": 5,
  "boxDescription": "Financial Records 2024",
  "dateReceived": "2024-01-15",
  "retentionYears": 7
}

# Returns: BOX-CLI001-0001 (auto-generated)
# Destruction year: 2031 (auto-calculated)
```

### 2. Find Boxes Pending Destruction

```bash
GET /api/boxes/pending-destruction
Authorization: Bearer <admin_token>

# Returns all boxes where destruction_year <= 2026 and status = 'stored'
```

### 3. Bulk Import Boxes

```bash
POST /api/boxes/bulk/create
Authorization: Bearer <staff_token>

{
  "boxes": [
    {
      "clientId": 1,
      "boxDescription": "HR Files Jan-Mar",
      "dateReceived": "2024-01-01",
      "retentionYears": 7
    },
    {
      "clientId": 1,
      "boxDescription": "HR Files Apr-Jun",
      "dateReceived": "2024-04-01",
      "retentionYears": 7
    }
  ]
}
```

### 4. Record a Collection with Signatures

```bash
POST /api/collections
Authorization: Bearer <staff_token>

{
  "clientId": 1,
  "totalBoxes": 10,
  "boxDescription": "Monthly collection - Nov 2024",
  "dispatcherName": "John Smith",
  "collectorName": "Jane Doe",
  "dispatcherSignature": "data:image/png;base64,iVBORw0KGgoAAAANS...",
  "collectorSignature": "data:image/png;base64,iVBORw0KGgoAAAANS...",
  "collectionDate": "2024-11-15"
}
```

### 5. Search Boxes

```bash
# By client
GET /api/boxes?clientId=1&status=stored

# By keyword
GET /api/boxes?search=financial

# Pending destruction
GET /api/boxes?pendingDestruction=true

# By location
GET /api/boxes?rackingLabelId=5
```

### 6. Generate Collection Reports

```bash
# Daily summary
GET /api/collections/reports/summary?startDate=2024-11-01&endDate=2024-11-30

# By client
GET /api/collections/reports/by-client?startDate=2024-01-01&endDate=2024-12-31
```

---

## 📊 Database Triggers

### Auto-Calculate Destruction Year

The `boxes` table has triggers that automatically calculate `destruction_year`:

```sql
destruction_year = year_received + retention_years
```

**Example:**
- Box received: 2024
- Retention: 7 years
- Destruction year: 2031 (auto-calculated)

When you update `retentionYears`, the trigger recalculates `destructionYear` automatically!

---

## 🎯 Business Logic

### Box Number Generation

1. Get client code from `clients` table
2. Find highest sequence for that client
3. Increment and pad to 4 digits
4. Format: `BOX-{CLIENT_CODE}-{SEQUENCE}`

**Example for CLI-001:**
- First box: `BOX-CLI001-0001`
- Second box: `BOX-CLI001-0002`
- Third box: `BOX-CLI001-0003`

### Pending Destruction Detection

A box is pending destruction when:
- `destruction_year <= current_year`
- `status = 'stored'`

Query includes computed field: `is_pending_destruction`

---

## 🔒 Access Control

### Admin
- Full access to all boxes and collections
- Can delete boxes and collections
- Can perform bulk operations

### Staff (with permissions)
- Can create boxes (if `canCreateBoxes`)
- Can edit boxes (if `canEditBoxes`)
- Can delete boxes (if `canDeleteBoxes`)
- Can create collections (if `canCreateCollections`)
- Can view all boxes and collections

### Client Users
- Can ONLY view their own boxes
- Can ONLY view their own collections
- Cannot create, update, or delete
- Enforced by checking `req.user.clientId === box.client_id`

---

## 📝 Response Format

### Success
```json
{
  "status": "success",
  "message": "Operation successful",
  "data": { ... }
}
```

### Paginated
```json
{
  "status": "success",
  "data": {
    "boxes": [ ... ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "total": 150,
      "totalPages": 3
    }
  }
}
```

### Error
```json
{
  "status": "error",
  "message": "Error description"
}
```

---

## 🚨 Common Errors

| Status | Message | Solution |
|--------|---------|----------|
| 400 | Client ID and date received are required | Include both fields |
| 400 | Invalid status | Use stored/retrieved/destroyed |
| 400 | Total boxes must be at least 1 | Minimum 1 box |
| 403 | Permission denied | User needs canCreateBoxes |
| 403 | You can only access your own boxes | Client accessing another client's data |
| 404 | Box not found | Check boxId is correct |
| 404 | Client not found | Check clientId exists |
| 404 | Racking label not found | Check labelId exists |

---

## 💡 Integration Tips

### For Flutter App

1. **List Boxes for Client**
```dart
final response = await http.get(
  Uri.parse('$baseUrl/api/boxes/client/$clientId'),
  headers: {'Authorization': 'Bearer $token'}
);
```

2. **Create Box**
```dart
final response = await http.post(
  Uri.parse('$baseUrl/api/boxes'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json'
  },
  body: jsonEncode({
    'clientId': clientId,
    'boxDescription': description,
    'dateReceived': '2024-01-15',
    'retentionYears': 7
  })
);
```

3. **Record Collection with Signature**
```dart
// Capture signature as base64
String signatureBase64 = await captureSignature();

final response = await http.post(
  Uri.parse('$baseUrl/api/collections'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json'
  },
  body: jsonEncode({
    'clientId': clientId,
    'totalBoxes': 10,
    'dispatcherName': 'John Smith',
    'collectorName': 'Jane Doe',
    'dispatcherSignature': signatureBase64,
    'collectionDate': '2024-11-15'
  })
);
```

---

## 📈 What's Next

With boxes and collections complete, you can add:

1. **Retrievals** - Track box retrievals with signatures
2. **Deliveries** - Track item deliveries to clients
3. **Requests** - Client service requests (retrieval/destruction)
4. **Racking Labels** - Manage physical storage locations
5. **Reports** - Advanced reporting with PDF generation

---

**🎉 Box & Collection Management - Complete!**

All routes inline, no controllers needed. Just like auth and users! 🚀
