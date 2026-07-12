# PSMS Request Management - Complete API Guide

## Table of Contents
- [Overview](#overview)
- [Request Types](#request-types)
- [Request Status Flow](#request-status-flow)
- [Complete Endpoint List](#complete-endpoint-list)
- [Detailed Endpoint Documentation](#detailed-endpoint-documentation)
- [Workflow Examples](#workflow-examples)
- [Response Formats](#response-formats)
- [Error Handling](#error-handling)
- [Integration Examples](#integration-examples)

---

## Overview

The Request Management system allows clients to submit service requests (retrieval, collection, destruction, delivery) which are then processed by admin/staff. The system provides complete tracking from request submission through completion.

### Key Features
- ✅ Four request types: retrieval, collection, destruction, delivery
- ✅ Status tracking: pending → approved → completed
- ✅ Client self-service request submission
- ✅ Bulk operations for staff efficiency
- ✅ Role-based access control
- ✅ Comprehensive audit logging
- ✅ Filtering and pagination
- ✅ Detailed reporting

---

## Request Types

### 1. **Retrieval Request**
Request to retrieve a stored box from the facility.
- **Requires:** Box ID (specific box to retrieve)
- **Common Use:** Client needs documents for audit, legal case, reference

### 2. **Collection Request**
Request for staff to collect boxes from client location.
- **Optional:** Box ID (can request collection without specifying boxes)
- **Common Use:** Client has new documents to store

### 3. **Destruction Request**
Request to destroy a box whose retention period has expired.
- **Requires:** Box ID (specific box to destroy)
- **Common Use:** Retention period expired, client wants to free up storage

### 4. **Delivery Request**
Request for staff to deliver boxes to client location.
- **Optional:** Box ID
- **Common Use:** Client needs documents delivered to remote location

---

## Request Status Flow

```
┌─────────────┐
│   pending   │  ← Request created by client
└──────┬──────┘
       │
       ├────→ ┌─────────────┐
       │      │  cancelled  │  ← Client/Staff cancels
       │      └─────────────┘
       ↓
┌─────────────┐
│  approved   │  ← Staff approves request
└──────┬──────┘
       │
       ├────→ ┌─────────────┐
       │      │  cancelled  │  ← Staff cancels
       │      └─────────────┘
       ↓
┌─────────────┐
│  completed  │  ← Staff marks as done
└─────────────┘
```

### Status Definitions

- **pending**: Request submitted, awaiting staff approval
- **approved**: Request approved by staff, awaiting completion
- **completed**: Request has been fulfilled
- **cancelled**: Request was cancelled (by client or staff)

### Status Transition Rules

| From | To | Who Can Do It |
|------|----|--------------| 
| pending | approved | Staff, Admin |
| pending | completed | Staff, Admin |
| pending | cancelled | Client (own), Staff, Admin |
| approved | completed | Staff, Admin |
| approved | cancelled | Staff, Admin |
| completed | *locked* | Cannot change |
| cancelled | *locked* | Cannot change |

---

## Complete Endpoint List

### Request Operations
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | `/api/requests` | Admin, Staff | Get all requests with filtering |
| GET | `/api/requests/stats` | Admin, Staff | Get request statistics |
| GET | `/api/requests/pending` | Admin, Staff | Get all pending requests |
| GET | `/api/requests/my` | Client | Get my requests |
| GET | `/api/requests/my/pending` | Client | Get my pending requests |
| GET | `/api/requests/client/:clientId` | Admin, Staff, Client* | Get client's requests |
| GET | `/api/requests/:requestId` | Admin, Staff, Client* | Get single request |
| POST | `/api/requests` | Client, Admin, Staff | Create new request |
| PATCH | `/api/requests/:requestId` | Admin, Staff, Client** | Update request details |
| PATCH | `/api/requests/:requestId/status` | Admin, Staff | Update request status |
| PATCH | `/api/requests/bulk/approve` | Admin, Staff | Bulk approve requests |
| PATCH | `/api/requests/bulk/complete` | Admin, Staff | Bulk complete requests |
| DELETE | `/api/requests/:requestId` | Admin, Client*** | Delete/cancel request |

### Reporting
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | `/api/requests/reports/summary` | Admin, Staff | Daily summary report |
| GET | `/api/requests/reports/by-client` | Admin, Staff | Client-grouped report |
| GET | `/api/requests/reports/by-type` | Admin, Staff | Type-grouped report |

**Access Notes:**
- `*` Client can only access own requests
- `**` Client can only update own pending requests
- `***` Admin deletes permanently, Client cancels (sets status to cancelled)

---

## Detailed Endpoint Documentation

### 1. Get All Requests

**Endpoint:** `GET /api/requests`  
**Access:** Admin, Staff  
**Description:** Get all requests with comprehensive filtering and pagination

#### Query Parameters
```
clientId       - Filter by client ID
requestType    - Filter by type: retrieval, collection, destruction, delivery
status         - Filter by status: pending, approved, completed, cancelled
boxId          - Filter by box ID
startDate      - Filter by date range (start)
endDate        - Filter by date range (end)
search         - Search in details, client name, box number
page           - Page number (default: 1)
limit          - Items per page (default: 50)
sortBy         - Sort field: requested_date, status, request_type, created_at, updated_at
sortOrder      - Sort order: ASC, DESC (default: DESC)
```

#### Request Example
```http
GET /api/requests?status=pending&requestType=retrieval&page=1&limit=20
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": {
    "requests": [
      {
        "requestId": 45,
        "client": {
          "clientId": 1,
          "clientName": "ACME Corporation",
          "clientCode": "ACME",
          "contactPerson": "John Doe",
          "email": "contact@acme.com"
        },
        "requestType": "retrieval",
        "box": {
          "boxId": 5,
          "boxNumber": "BOX-ACME-0005",
          "boxDescription": "Financial Records 2024"
        },
        "details": "Needed for annual audit",
        "status": "pending",
        "requestedDate": "2025-02-15",
        "completedDate": null,
        "createdAt": "2025-02-11T10:00:00.000Z",
        "updatedAt": "2025-02-11T10:00:00.000Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 45,
      "totalPages": 3
    }
  }
}
```

---

### 2. Get Request Statistics

**Endpoint:** `GET /api/requests/stats`  
**Access:** Admin, Staff  
**Description:** Get comprehensive request statistics

#### Request Example
```http
GET /api/requests/stats
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": {
    "total_requests": 250,
    "pending_requests": 25,
    "approved_requests": 10,
    "completed_requests": 200,
    "cancelled_requests": 15,
    "retrieval_requests": 120,
    "collection_requests": 60,
    "destruction_requests": 45,
    "delivery_requests": 25,
    "clients_with_requests": 35,
    "today_requests": 5,
    "this_week_requests": 18,
    "this_month_requests": 42
  }
}
```

---

### 3. Get Pending Requests (All)

**Endpoint:** `GET /api/requests/pending`  
**Access:** Admin, Staff  
**Description:** Get all pending requests awaiting approval

#### Query Parameters
```
requestType - Filter by type (optional)
clientId    - Filter by client (optional)
limit       - Max results (default: 50)
```

#### Request Example
```http
GET /api/requests/pending?requestType=retrieval&limit=20
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": {
    "requests": [
      {
        "requestId": 45,
        "client": {
          "clientId": 1,
          "clientName": "ACME Corporation",
          "clientCode": "ACME",
          "contactPerson": "John Doe"
        },
        "requestType": "retrieval",
        "box": {
          "boxId": 5,
          "boxNumber": "BOX-ACME-0005",
          "boxDescription": "Financial Records 2024"
        },
        "details": "Needed for annual audit",
        "requestedDate": "2025-02-15",
        "createdAt": "2025-02-11T10:00:00.000Z"
      }
    ],
    "total": 3
  }
}
```

---

### 4. Get My Requests

**Endpoint:** `GET /api/requests/my`  
**Access:** Client  
**Description:** Get all my requests with filtering

#### Query Parameters
```
requestType - Filter by type (optional)
status      - Filter by status (optional)
page        - Page number (default: 1)
limit       - Items per page (default: 50)
```

#### Request Example
```http
GET /api/requests/my?status=pending&page=1
Authorization: Bearer {{client_token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": {
    "requests": [
      {
        "requestId": 45,
        "requestType": "retrieval",
        "box": {
          "boxId": 5,
          "boxNumber": "BOX-ACME-0005",
          "boxDescription": "Financial Records 2024"
        },
        "details": "Needed for annual audit",
        "status": "pending",
        "requestedDate": "2025-02-15",
        "completedDate": null,
        "createdAt": "2025-02-11T10:00:00.000Z",
        "updatedAt": "2025-02-11T10:00:00.000Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "total": 10,
      "totalPages": 1
    }
  }
}
```

---

### 5. Get My Pending Requests

**Endpoint:** `GET /api/requests/my/pending`  
**Access:** Client  
**Description:** Get my pending requests awaiting approval

#### Request Example
```http
GET /api/requests/my/pending
Authorization: Bearer {{client_token}}
```

#### Response Example
```json
{
  "status": "success",
  "message": "You have 3 pending request(s)",
  "data": {
    "requests": [
      {
        "requestId": 45,
        "requestType": "retrieval",
        "box": {
          "boxId": 5,
          "boxNumber": "BOX-ACME-0005",
          "boxDescription": "Financial Records 2024"
        },
        "details": "Needed for annual audit",
        "requestedDate": "2025-02-15",
        "createdAt": "2025-02-11T10:00:00.000Z"
      }
    ],
    "total": 3
  }
}
```

---

### 6. Get Client's Requests

**Endpoint:** `GET /api/requests/client/:clientId`  
**Access:** Admin, Staff, Client (own only)  
**Description:** Get all requests for a specific client

#### Request Example
```http
GET /api/requests/client/1
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": [
    {
      "requestId": 45,
      "requestType": "retrieval",
      "box": {
        "boxId": 5,
        "boxNumber": "BOX-ACME-0005",
        "boxDescription": "Financial Records 2024"
      },
      "details": "Needed for annual audit",
      "status": "pending",
      "requestedDate": "2025-02-15",
      "completedDate": null,
      "createdAt": "2025-02-11T10:00:00.000Z",
      "updatedAt": "2025-02-11T10:00:00.000Z"
    }
  ]
}
```

---

### 7. Get Single Request

**Endpoint:** `GET /api/requests/:requestId`  
**Access:** Admin, Staff, Client (own only)  
**Description:** Get detailed information about a single request

#### Request Example
```http
GET /api/requests/45
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": {
    "requestId": 45,
    "client": {
      "clientId": 1,
      "clientName": "ACME Corporation",
      "clientCode": "ACME",
      "contactPerson": "John Doe",
      "email": "contact@acme.com"
    },
    "requestType": "retrieval",
    "box": {
      "boxId": 5,
      "boxNumber": "BOX-ACME-0005",
      "boxDescription": "Financial Records 2024",
      "status": "stored"
    },
    "details": "Needed for annual audit",
    "status": "pending",
    "requestedDate": "2025-02-15",
    "completedDate": null,
    "createdAt": "2025-02-11T10:00:00.000Z",
    "updatedAt": "2025-02-11T10:00:00.000Z"
  }
}
```

---

### 8. Create Request

**Endpoint:** `POST /api/requests`  
**Access:** Client, Admin, Staff  
**Description:** Create new service request

#### Request Body
```json
{
  "requestType": "retrieval",          // retrieval, collection, destruction, delivery
  "boxId": 5,                          // Required for retrieval/destruction, optional for collection/delivery
  "details": "Needed for annual audit", // Optional additional details
  "requestedDate": "2025-02-15"        // Date service is requested
}
```

**Note:** Clients automatically use their own `clientId`. Admin/Staff can specify `clientId` in the body.

#### Request Examples

**Retrieval Request (Client)**
```http
POST /api/requests
Authorization: Bearer {{client_token}}
Content-Type: application/json

{
  "requestType": "retrieval",
  "boxId": 5,
  "details": "Needed for annual audit",
  "requestedDate": "2025-02-15"
}
```

**Collection Request (Client)**
```http
POST /api/requests
Authorization: Bearer {{client_token}}
Content-Type: application/json

{
  "requestType": "collection",
  "details": "10 boxes of office documents from 2024",
  "requestedDate": "2025-02-20"
}
```

**Destruction Request (Client)**
```http
POST /api/requests
Authorization: Bearer {{client_token}}
Content-Type: application/json

{
  "requestType": "destruction",
  "boxId": 11,
  "details": "Retention period expired (2018 + 7 years)",
  "requestedDate": "2025-03-01"
}
```

#### Response Example
```json
{
  "status": "success",
  "message": "Request created successfully",
  "data": {
    "requestId": 45,
    "requestType": "retrieval",
    "status": "pending"
  }
}
```

#### Validations
- Request type must be valid: retrieval, collection, destruction, delivery
- `boxId` **required** for retrieval and destruction requests
- `boxId` **optional** for collection and delivery requests
- Box must exist and belong to client
- Box status validated:
  - Cannot request retrieval of already-retrieved boxes
  - Cannot request destruction of already-destroyed boxes

---

### 9. Update Request Details

**Endpoint:** `PATCH /api/requests/:requestId`  
**Access:** Admin, Staff, Client (own pending requests only)  
**Description:** Update request details and requested date

#### Request Body
```json
{
  "details": "Updated details here",
  "requestedDate": "2025-02-20"
}
```

#### Request Example
```http
PATCH /api/requests/45
Authorization: Bearer {{client_token}}
Content-Type: application/json

{
  "details": "Updated: Needed urgently for compliance audit",
  "requestedDate": "2025-02-18"
}
```

#### Response Example
```json
{
  "status": "success",
  "message": "Request updated successfully"
}
```

#### Rules
- Clients can only update their own requests
- Clients can only update **pending** requests
- Staff/Admin can update any pending/approved request
- Cannot update completed or cancelled requests

---

### 10. Update Request Status

**Endpoint:** `PATCH /api/requests/:requestId/status`  
**Access:** Admin, Staff  
**Description:** Approve, complete, or cancel requests

#### Request Body
```json
{
  "status": "approved",                 // pending, approved, completed, cancelled
  "completedDate": "2025-02-15"        // Optional, auto-set if marking completed
}
```

#### Approve Request Example
```http
PATCH /api/requests/45/status
Authorization: Bearer {{staff_token}}
Content-Type: application/json

{
  "status": "approved"
}
```

#### Response Example (Approve)
```json
{
  "status": "success",
  "message": "Request approved successfully",
  "data": {
    "requestId": 45,
    "oldStatus": "pending",
    "newStatus": "approved",
    "requestType": "retrieval"
  }
}
```

#### Complete Request Example
```http
PATCH /api/requests/45/status
Authorization: Bearer {{staff_token}}
Content-Type: application/json

{
  "status": "completed",
  "completedDate": "2025-02-15"
}
```

#### Response Example (Complete)
```json
{
  "status": "success",
  "message": "Request completed successfully",
  "data": {
    "requestId": 45,
    "oldStatus": "approved",
    "newStatus": "completed",
    "requestType": "retrieval"
  }
}
```

#### Cancel Request Example
```http
PATCH /api/requests/45/status
Authorization: Bearer {{staff_token}}
Content-Type: application/json

{
  "status": "cancelled"
}
```

#### Validations
- Cannot update completed or cancelled requests
- Valid status transitions only
- Auto-sets `completedDate` when marking as completed

---

### 11. Bulk Approve Requests

**Endpoint:** `PATCH /api/requests/bulk/approve`  
**Access:** Admin, Staff  
**Description:** Approve multiple pending requests at once

#### Request Body
```json
{
  "requestIds": [45, 46, 47, 48]
}
```

#### Request Example
```http
PATCH /api/requests/bulk/approve
Authorization: Bearer {{staff_token}}
Content-Type: application/json

{
  "requestIds": [45, 46, 47, 48]
}
```

#### Response Example
```json
{
  "status": "success",
  "message": "4 requests approved successfully"
}
```

#### Notes
- Only approves **pending** requests
- Skips requests that are already approved/completed/cancelled
- All operations in single transaction

---

### 12. Bulk Complete Requests

**Endpoint:** `PATCH /api/requests/bulk/complete`  
**Access:** Admin, Staff  
**Description:** Complete multiple approved requests at once

#### Request Body
```json
{
  "requestIds": [45, 46, 47, 48],
  "completedDate": "2025-02-15"       // Optional, defaults to today
}
```

#### Request Example
```http
PATCH /api/requests/bulk/complete
Authorization: Bearer {{staff_token}}
Content-Type: application/json

{
  "requestIds": [45, 46, 47, 48],
  "completedDate": "2025-02-15"
}
```

#### Response Example
```json
{
  "status": "success",
  "message": "4 requests completed successfully"
}
```

#### Notes
- Completes **pending** or **approved** requests
- Auto-sets `completedDate` if not provided
- Skips already completed/cancelled requests

---

### 13. Delete/Cancel Request

**Endpoint:** `DELETE /api/requests/:requestId`  
**Access:** Admin (delete), Client (cancel own pending)  
**Description:** Delete or cancel a request

#### Request Example (Client Cancel)
```http
DELETE /api/requests/45
Authorization: Bearer {{client_token}}
```

#### Response Example (Client)
```json
{
  "status": "success",
  "message": "Request cancelled successfully"
}
```

#### Request Example (Admin Delete)
```http
DELETE /api/requests/45
Authorization: Bearer {{admin_token}}
```

#### Response Example (Admin)
```json
{
  "status": "success",
  "message": "Request deleted successfully"
}
```

#### Rules
- **Clients**: Can only cancel own **pending** requests (sets status to 'cancelled')
- **Admin**: Can permanently delete any request
- **Staff**: Cannot delete requests

---

### 14. Get Summary Report

**Endpoint:** `GET /api/requests/reports/summary`  
**Access:** Admin, Staff  
**Description:** Get daily request summary by date range

#### Query Parameters
```
startDate   - Start date (YYYY-MM-DD)
endDate     - End date (YYYY-MM-DD)
clientId    - Filter by client (optional)
requestType - Filter by type (optional)
```

#### Request Example
```http
GET /api/requests/reports/summary?startDate=2025-02-01&endDate=2025-02-28
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": [
    {
      "date": "2025-02-11",
      "request_count": 5,
      "unique_clients": 3,
      "pending_count": 2,
      "approved_count": 1,
      "completed_count": 2,
      "cancelled_count": 0
    },
    {
      "date": "2025-02-10",
      "request_count": 3,
      "unique_clients": 2,
      "pending_count": 0,
      "approved_count": 0,
      "completed_count": 3,
      "cancelled_count": 0
    }
  ]
}
```

---

### 15. Get Client Report

**Endpoint:** `GET /api/requests/reports/by-client`  
**Access:** Admin, Staff  
**Description:** Get requests grouped by client

#### Query Parameters
```
startDate   - Start date (YYYY-MM-DD)
endDate     - End date (YYYY-MM-DD)
requestType - Filter by type (optional)
```

#### Request Example
```http
GET /api/requests/reports/by-client?startDate=2025-01-01
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": [
    {
      "client_id": 1,
      "client_name": "ACME Corporation",
      "client_code": "ACME",
      "total_requests": 45,
      "pending_requests": 5,
      "completed_requests": 38,
      "last_request_date": "2025-02-11"
    }
  ]
}
```

---

### 16. Get Type Report

**Endpoint:** `GET /api/requests/reports/by-type`  
**Access:** Admin, Staff  
**Description:** Get requests grouped by type

#### Query Parameters
```
startDate - Start date (YYYY-MM-DD)
endDate   - End date (YYYY-MM-DD)
```

#### Request Example
```http
GET /api/requests/reports/by-type?startDate=2025-01-01&endDate=2025-02-28
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": [
    {
      "request_type": "retrieval",
      "total_requests": 120,
      "pending_count": 10,
      "approved_count": 5,
      "completed_count": 100,
      "cancelled_count": 5,
      "unique_clients": 25
    },
    {
      "request_type": "collection",
      "total_requests": 60,
      "pending_count": 5,
      "approved_count": 3,
      "completed_count": 50,
      "cancelled_count": 2,
      "unique_clients": 18
    }
  ]
}
```

---

## Workflow Examples

### Complete Retrieval Request Workflow

#### Step 1: Client Creates Request
```http
POST /api/requests
Authorization: Bearer {{client_token}}

{
  "requestType": "retrieval",
  "boxId": 5,
  "details": "Needed for annual audit",
  "requestedDate": "2025-02-20"
}

Response:
{
  "status": "success",
  "message": "Request created successfully",
  "data": {
    "requestId": 45,
    "requestType": "retrieval",
    "status": "pending"
  }
}
```

#### Step 2: Client Checks Status
```http
GET /api/requests/my/pending
Authorization: Bearer {{client_token}}

Response:
{
  "status": "success",
  "message": "You have 1 pending request(s)",
  "data": {
    "requests": [
      {
        "requestId": 45,
        "requestType": "retrieval",
        "box": {...},
        "details": "Needed for annual audit",
        "requestedDate": "2025-02-20",
        "createdAt": "2025-02-11T10:00:00.000Z"
      }
    ],
    "total": 1
  }
}
```

#### Step 3: Staff Approves Request
```http
PATCH /api/requests/45/status
Authorization: Bearer {{staff_token}}

{
  "status": "approved"
}

Response:
{
  "status": "success",
  "message": "Request approved successfully",
  "data": {
    "requestId": 45,
    "oldStatus": "pending",
    "newStatus": "approved",
    "requestType": "retrieval"
  }
}
```

#### Step 4: Staff Creates Retrieval
```http
POST /api/retrievals
Authorization: Bearer {{staff_token}}

{
  "clientId": 1,
  "boxId": 5,
  "retrievalDate": "2025-02-20",
  "retrievedBy": "Jane Smith",
  "reason": "Annual audit - per request #45"
}

Response:
{
  "status": "success",
  "message": "Retrieval created successfully. Awaiting client signature to complete.",
  "data": {
    "retrievalId": 124,
    "boxId": 5,
    "boxNumber": "BOX-ACME-0005",
    "requiresClientSignature": true
  }
}
```

#### Step 5: Client Signs Retrieval
```http
PATCH /api/retrievals/124/signatures
Authorization: Bearer {{client_token}}

{
  "clientSignature": "data:image/png;base64,..."
}

Response:
{
  "status": "success",
  "message": "Signatures updated successfully. Retrieval completed and box marked as retrieved.",
  "data": {
    "retrievalId": 124,
    "boxId": 5,
    "boxNumber": "BOX-ACME-0005",
    "retrievalCompleted": true,
    "boxStatusChanged": true,
    "boxStatus": "retrieved"
  }
}
```

#### Step 6: Staff Completes Request
```http
PATCH /api/requests/45/status
Authorization: Bearer {{staff_token}}

{
  "status": "completed",
  "completedDate": "2025-02-20"
}

Response:
{
  "status": "success",
  "message": "Request completed successfully",
  "data": {
    "requestId": 45,
    "oldStatus": "approved",
    "newStatus": "completed",
    "requestType": "retrieval"
  }
}
```

---

### Collection Request Workflow

#### Step 1: Client Requests Collection
```http
POST /api/requests
Authorization: Bearer {{client_token}}

{
  "requestType": "collection",
  "details": "10 boxes of office documents from 2024",
  "requestedDate": "2025-02-25"
}

Response:
{
  "status": "success",
  "message": "Request created successfully",
  "data": {
    "requestId": 46,
    "requestType": "collection",
    "status": "pending"
  }
}
```

#### Step 2: Staff Approves
```http
PATCH /api/requests/46/status
Authorization: Bearer {{staff_token}}

{
  "status": "approved"
}
```

#### Step 3: Staff Performs Collection
```http
POST /api/collections
Authorization: Bearer {{staff_token}}

{
  "clientId": 1,
  "totalBoxes": 10,
  "boxDescription": "Office documents 2024",
  "collectionDate": "2025-02-25",
  "dispatcherName": "ACME Warehouse",
  "collectorName": "Jane Smith"
}
```

#### Step 4: Staff Completes Request
```http
PATCH /api/requests/46/status
Authorization: Bearer {{staff_token}}

{
  "status": "completed",
  "completedDate": "2025-02-25"
}
```

---

### Destruction Request Workflow

#### Step 1: Client Requests Destruction
```http
POST /api/requests
Authorization: Bearer {{client_token}}

{
  "requestType": "destruction",
  "boxId": 11,
  "details": "Retention period expired (2018 + 7 years)",
  "requestedDate": "2025-03-01"
}
```

#### Step 2: Staff Approves
```http
PATCH /api/requests/47/status
Authorization: Bearer {{staff_token}}

{
  "status": "approved"
}
```

#### Step 3: Staff Updates Box Status
```http
PATCH /api/boxes/11
Authorization: Bearer {{staff_token}}

{
  "status": "destroyed"
}
```

#### Step 4: Staff Completes Request
```http
PATCH /api/requests/47/status
Authorization: Bearer {{staff_token}}

{
  "status": "completed",
  "completedDate": "2025-03-01"
}
```

---

## Response Formats

### Success Response
```json
{
  "status": "success",
  "message": "Operation completed successfully",
  "data": { ... }
}
```

### Error Response
```json
{
  "status": "error",
  "message": "Error description"
}
```

---

## Error Handling

### Common Errors

#### Invalid Request Type
```json
{
  "status": "error",
  "message": "Valid request type is required (retrieval, collection, destruction, delivery)"
}
```

#### Missing Box ID
```json
{
  "status": "error",
  "message": "Box ID is required for retrieval requests"
}
```

#### Box Doesn't Belong to Client
```json
{
  "status": "error",
  "message": "Box does not belong to this client"
}
```

#### Box Already Retrieved
```json
{
  "status": "error",
  "message": "Box has already been retrieved"
}
```

#### Cannot Update Completed Request
```json
{
  "status": "error",
  "message": "Cannot update completed request"
}
```

#### Unauthorized Access
```json
{
  "status": "error",
  "message": "You can only access your own requests"
}
```

#### Client Updating Non-Pending
```json
{
  "status": "error",
  "message": "You can only update pending requests"
}
```

---

## Integration Examples

### Flutter Integration

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class RequestService {
  final String baseUrl = 'http://localhost:3000/api';
  final String token;

  RequestService(this.token);

  // Create request
  Future<Response> createRequest({
    required String requestType,
    int? boxId,
    String? details,
    required String requestedDate,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/requests'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'requestType': requestType,
        if (boxId != null) 'boxId': boxId,
        if (details != null) 'details': details,
        'requestedDate': requestedDate,
      }),
    );

    if (response.statusCode == 201) {
      return Response.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to create request');
  }

  // Get my pending requests
  Future<List<Request>> getMyPendingRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/requests/my/pending'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data']['requests'] as List)
          .map((json) => Request.fromJson(json))
          .toList();
    }
    throw Exception('Failed to load pending requests');
  }

  // Get all my requests
  Future<List<Request>> getMyRequests({
    String? requestType,
    String? status,
    int page = 1,
  }) async {
    String url = '$baseUrl/requests/my?page=$page';
    if (requestType != null) url += '&requestType=$requestType';
    if (status != null) url += '&status=$status';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data']['requests'] as List)
          .map((json) => Request.fromJson(json))
          .toList();
    }
    throw Exception('Failed to load requests');
  }

  // Update request
  Future<void> updateRequest(int requestId, {
    String? details,
    String? requestedDate,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/requests/$requestId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        if (details != null) 'details': details,
        if (requestedDate != null) 'requestedDate': requestedDate,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update request');
    }
  }

  // Cancel request
  Future<void> cancelRequest(int requestId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/requests/$requestId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to cancel request');
    }
  }

  // For Staff: Approve request
  Future<void> approveRequest(int requestId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/requests/$requestId/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'status': 'approved',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to approve request');
    }
  }

  // For Staff: Complete request
  Future<void> completeRequest(int requestId, {String? completedDate}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/requests/$requestId/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'status': 'completed',
        if (completedDate != null) 'completedDate': completedDate,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to complete request');
    }
  }

  // For Staff: Bulk approve
  Future<void> bulkApprove(List<int> requestIds) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/requests/bulk/approve'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'requestIds': requestIds,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to bulk approve requests');
    }
  }
}

// Model classes
class Request {
  final int requestId;
  final String requestType;
  final Box? box;
  final String? details;
  final String status;
  final String requestedDate;
  final String? completedDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Request({
    required this.requestId,
    required this.requestType,
    this.box,
    this.details,
    required this.status,
    required this.requestedDate,
    this.completedDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      requestId: json['requestId'],
      requestType: json['requestType'],
      box: json['box'] != null ? Box.fromJson(json['box']) : null,
      details: json['details'],
      status: json['status'],
      requestedDate: json['requestedDate'],
      completedDate: json['completedDate'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class Box {
  final int boxId;
  final String boxNumber;
  final String boxDescription;

  Box({
    required this.boxId,
    required this.boxNumber,
    required this.boxDescription,
  });

  factory Box.fromJson(Map<String, dynamic> json) {
    return Box(
      boxId: json['boxId'],
      boxNumber: json['boxNumber'],
      boxDescription: json['boxDescription'],
    );
  }
}

class Response {
  final String status;
  final String message;
  final Map<String, dynamic>? data;

  Response({
    required this.status,
    required this.message,
    this.data,
  });

  factory Response.fromJson(Map<String, dynamic> json) {
    return Response(
      status: json['status'],
      message: json['message'],
      data: json['data'],
    );
  }
}
```

### UI Example - Create Request Screen

```dart
class CreateRequestScreen extends StatefulWidget {
  @override
  _CreateRequestScreenState createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final RequestService _requestService = RequestService(token);
  
  String _requestType = 'retrieval';
  int? _selectedBoxId;
  String _details = '';
  DateTime _requestedDate = DateTime.now();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Request')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Request Type Dropdown
            DropdownButtonFormField<String>(
              value: _requestType,
              decoration: InputDecoration(labelText: 'Request Type'),
              items: [
                DropdownMenuItem(value: 'retrieval', child: Text('Retrieval')),
                DropdownMenuItem(value: 'collection', child: Text('Collection')),
                DropdownMenuItem(value: 'destruction', child: Text('Destruction')),
                DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
              ],
              onChanged: (value) {
                setState(() {
                  _requestType = value!;
                });
              },
            ),
            SizedBox(height: 16),

            // Box Selection (if retrieval or destruction)
            if (_requestType == 'retrieval' || _requestType == 'destruction')
              BoxSelectionField(
                onChanged: (boxId) {
                  setState(() {
                    _selectedBoxId = boxId;
                  });
                },
              ),
            SizedBox(height: 16),

            // Details
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Details',
                hintText: 'Reason for request',
              ),
              maxLines: 3,
              onChanged: (value) {
                _details = value;
              },
            ),
            SizedBox(height: 16),

            // Requested Date
            ListTile(
              title: Text('Requested Date'),
              subtitle: Text(_requestedDate.toString().split(' ')[0]),
              trailing: Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _requestedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                );
                if (date != null) {
                  setState(() {
                    _requestedDate = date;
                  });
                }
              },
            ),
            SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitRequest,
              child: _isLoading 
                ? CircularProgressIndicator()
                : Text('Submit Request'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate box selection for retrieval/destruction
    if ((_requestType == 'retrieval' || _requestType == 'destruction') && 
        _selectedBoxId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a box for ${_requestType}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _requestService.createRequest(
        requestType: _requestType,
        boxId: _selectedBoxId,
        details: _details.isNotEmpty ? _details : null,
        requestedDate: _requestedDate.toString().split(' ')[0],
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Request created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to create request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

### UI Example - Pending Requests Screen

```dart
class PendingRequestsScreen extends StatefulWidget {
  @override
  _PendingRequestsScreenState createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  late Future<List<Request>> _pendingRequests;
  final RequestService _requestService = RequestService(token);

  @override
  void initState() {
    super.initState();
    _pendingRequests = _requestService.getMyPendingRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pending Requests')),
      body: FutureBuilder<List<Request>>(
        future: _pendingRequests,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final requests = snapshot.data!;
            
            if (requests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 64, color: Colors.green),
                    SizedBox(height: 16),
                    Text('No pending requests'),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: _getRequestIcon(request.requestType),
                    title: Text(
                      request.requestType.toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (request.box != null)
                          Text('Box: ${request.box!.boxNumber}'),
                        Text('Requested: ${request.requestedDate}'),
                        if (request.details != null)
                          Text(
                            request.details!,
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Text('Edit'),
                          value: 'edit',
                        ),
                        PopupMenuItem(
                          child: Text('Cancel', style: TextStyle(color: Colors.red)),
                          value: 'cancel',
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editRequest(request);
                        } else if (value == 'cancel') {
                          _cancelRequest(request);
                        }
                      },
                    ),
                    onTap: () => _showRequestDetails(request),
                  ),
                );
              },
            );
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateRequestScreen()),
          ).then((_) {
            setState(() {
              _pendingRequests = _requestService.getMyPendingRequests();
            });
          });
        },
      ),
    );
  }

  Widget _getRequestIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'retrieval':
        icon = Icons.exit_to_app;
        color = Colors.blue;
        break;
      case 'collection':
        icon = Icons.input;
        color = Colors.green;
        break;
      case 'destruction':
        icon = Icons.delete;
        color = Colors.red;
        break;
      case 'delivery':
        icon = Icons.local_shipping;
        color = Colors.orange;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color),
    );
  }

  void _showRequestDetails(Request request) {
    // Navigate to details screen
  }

  void _editRequest(Request request) {
    // Navigate to edit screen
  }

  void _cancelRequest(Request request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Request'),
        content: Text('Are you sure you want to cancel this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _requestService.cancelRequest(request.requestId);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Request cancelled'),
                    backgroundColor: Colors.orange,
                  ),
                );
                setState(() {
                  _pendingRequests = _requestService.getMyPendingRequests();
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to cancel: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Yes, Cancel'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}
```

---

## Best Practices

### 1. Creating Requests
- Always provide meaningful details for audit purposes
- Use realistic requested dates
- For retrieval/destruction, always specify boxId
- Verify box belongs to you before requesting

### 2. Processing Requests (Staff)
- Review requests promptly
- Approve requests before starting work
- Link request IDs in related records (retrievals, collections, etc.)
- Mark as completed after actual fulfillment
- Use bulk operations for efficiency

### 3. Client Communication
- Show pending request count on dashboard
- Send notifications on status changes
- Allow clients to track request history
- Provide clear status indicators

### 4. Reporting
- Monitor pending requests regularly
- Track completion times
- Analyze request patterns by client/type
- Use reports for resource planning

### 5. Security
- Always verify user can access request
- Clients should only see their own requests
- Use proper authentication tokens
- Validate all inputs

---

## Quick Reference

### Request Types
| Type | Box ID Required | Use Case |
|------|----------------|----------|
| retrieval | ✅ Yes | Retrieve specific box |
| collection | ❌ No | Collect new boxes from client |
| destruction | ✅ Yes | Destroy specific box |
| delivery | ❌ No | Deliver boxes to client |

### Status Flow
```
pending → approved → completed
   ↓
cancelled
```

### Who Can Do What
| Action | Client | Staff | Admin |
|--------|--------|-------|-------|
| Create | ✅ | ✅ | ✅ |
| View own | ✅ | - | - |
| View all | - | ✅ | ✅ |
| Update details | ✅ (pending only) | ✅ | ✅ |
| Change status | - | ✅ | ✅ |
| Bulk approve | - | ✅ | ✅ |
| Cancel | ✅ (pending only) | ✅ | ✅ |
| Delete | - | - | ✅ |

---

## Database Schema Note

To support the 'delivery' request type, update your schema:

```sql
ALTER TABLE requests 
MODIFY COLUMN request_type 
ENUM('retrieval', 'destruction', 'collection', 'delivery') NOT NULL;
```

---

## Support

For additional help or questions:
- Check the Postman collection for working examples
- Review the workflow examples section
- Test with the provided endpoints
- Verify authentication tokens are valid

---

**Last Updated:** February 11, 2025  
**API Version:** 1.0  
**Base URL:** `http://localhost:3000/api`
