# PSMS Retrieval Management - Complete API Guide

## Table of Contents
- [Overview](#overview)
- [Signature Workflow](#signature-workflow)
- [Complete Endpoint List](#complete-endpoint-list)
- [Detailed Endpoint Documentation](#detailed-endpoint-documentation)
- [Workflow Examples](#workflow-examples)
- [Response Formats](#response-formats)
- [Error Handling](#error-handling)
- [Integration Examples](#integration-examples)

---

## Overview

The Retrieval Management system handles the complete workflow for retrieving stored boxes from the document storage facility. The system implements a signature-based workflow where:

1. Staff creates a retrieval record
2. Box remains 'stored' until client signs
3. Client signature marks retrieval as complete
4. Box status automatically changes to 'retrieved'

### Key Features
- ✅ Digital signature workflow (client + staff)
- ✅ Automatic box status management
- ✅ Transaction-safe operations
- ✅ Role-based access control
- ✅ Comprehensive audit logging
- ✅ PDF receipt tracking
- ✅ Filtering and pagination
- ✅ Real-time statistics

---

## Signature Workflow

### The Complete Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. CREATE RETRIEVAL                                         │
│    POST /api/retrievals                                     │
│    - Staff creates retrieval record                         │
│    - Box status: 'stored' (unchanged)                       │
│    - Retrieval status: Pending client signature             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. CLIENT SIGNS                                             │
│    PATCH /api/retrievals/:id/signatures                     │
│    - Client adds base64 signature                           │
│    - Box status: 'stored' → 'retrieved' (AUTOMATIC)        │
│    - Retrieval status: Complete                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. TRANSACTION COMPLETE                                     │
│    - Both updates succeed or rollback together              │
│    - Audit logs created for both actions                    │
│    - Box marked as retrieved in system                      │
└─────────────────────────────────────────────────────────────┘
```

### Important Notes

- **Client signature triggers box status change** - This is the key action that marks a box as retrieved
- **Staff signature is optional** - Does not affect box status
- **Transaction safety** - Both signature update and box status change happen atomically
- **Only 'stored' boxes** - Status only changes if box is currently 'stored'

---

## Complete Endpoint List

### Retrieval Operations
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | `/api/retrievals` | Admin, Staff | Get all retrievals with filtering |
| GET | `/api/retrievals/stats` | Admin, Staff | Get retrieval statistics |
| GET | `/api/retrievals/recent` | Admin, Staff | Get recent retrievals |
| GET | `/api/retrievals/pending` | Admin, Staff | Get retrievals pending signature |
| GET | `/api/retrievals/pending/my` | Client | Get my pending retrievals |
| GET | `/api/retrievals/client/:clientId` | Admin, Staff, Client* | Get client's retrievals |
| GET | `/api/retrievals/box/:boxId` | Admin, Staff | Get box's retrieval history |
| GET | `/api/retrievals/:retrievalId` | Admin, Staff, Client* | Get single retrieval |
| POST | `/api/retrievals` | Admin, Staff** | Create new retrieval |
| PATCH | `/api/retrievals/:id/signatures` | Admin, Staff, Client*** | Update signatures |
| PATCH | `/api/retrievals/:id/pdf` | Admin, Staff | Update PDF path |
| PATCH | `/api/retrievals/box/:boxId/mark-retrieved` | Admin, Staff | Manual status override |
| DELETE | `/api/retrievals/:retrievalId` | Admin | Delete retrieval |

### Reporting
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | `/api/retrievals/reports/summary` | Admin, Staff | Daily summary report |
| GET | `/api/retrievals/reports/by-client` | Admin, Staff | Client-grouped report |

**Access Notes:**
- `*` Client can only access own retrievals
- `**` Requires `canCreateRetrievals` permission
- `***` Client can only update client signature on own retrievals

---

## Detailed Endpoint Documentation

### 1. Get All Retrievals

**Endpoint:** `GET /api/retrievals`  
**Access:** Admin, Staff  
**Description:** Get all retrievals with comprehensive filtering and pagination

#### Query Parameters
```
clientId       - Filter by client ID
boxId          - Filter by box ID
startDate      - Filter by date range (start)
endDate        - Filter by date range (end)
search         - Search in retrieved_by, reason, client name, box number
page           - Page number (default: 1)
limit          - Items per page (default: 50)
sortBy         - Sort field: retrieval_date, created_at (default: retrieval_date)
sortOrder      - Sort order: ASC, DESC (default: DESC)
```

#### Request Example
```http
GET /api/retrievals?clientId=1&startDate=2025-01-01&page=1&limit=20
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": {
    "retrievals": [
      {
        "retrievalId": 123,
        "client": {
          "clientId": 1,
          "clientName": "ACME Corporation",
          "clientCode": "ACME",
          "contactPerson": "John Doe"
        },
        "box": {
          "boxId": 5,
          "boxNumber": "BOX-ACME-0005",
          "boxDescription": "Financial Records 2024"
        },
        "retrievalDate": "2025-02-11",
        "retrievedBy": "Jane Smith",
        "reason": "Annual audit requirements",
        "hasClientSignature": true,
        "hasStaffSignature": true,
        "isComplete": true,
        "clientSignature": "data:image/png;base64,iVBORw0KG...",
        "staffSignature": "data:image/png;base64,iVBORw0KG...",
        "pdfPath": "/receipts/retrieval_123.pdf",
        "createdBy": {
          "userId": 2,
          "username": "staff1"
        },
        "createdAt": "2025-02-11T10:30:00.000Z"
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

### 2. Get Retrieval Statistics

**Endpoint:** `GET /api/retrievals/stats`  
**Access:** Admin, Staff  
**Description:** Get comprehensive retrieval statistics

#### Request Example
```http
GET /api/retrievals/stats
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": {
    "total_retrievals": 150,
    "clients_with_retrievals": 25,
    "unique_boxes_retrieved": 145,
    "today_retrievals": 5,
    "this_week_retrievals": 18,
    "this_month_retrievals": 42
  }
}
```

---

### 3. Get Recent Retrievals

**Endpoint:** `GET /api/retrievals/recent`  
**Access:** Admin, Staff  
**Description:** Get most recent retrievals

#### Query Parameters
```
limit - Number of retrievals to return (default: 10, max: 50)
```

#### Request Example
```http
GET /api/retrievals/recent?limit=10
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": [
    {
      "retrievalId": 123,
      "clientName": "ACME Corporation",
      "clientCode": "ACME",
      "boxNumber": "BOX-ACME-0005",
      "retrievalDate": "2025-02-11",
      "retrievedBy": "Jane Smith",
      "createdBy": "staff1"
    }
  ]
}
```

---

### 4. Get Pending Retrievals (All)

**Endpoint:** `GET /api/retrievals/pending`  
**Access:** Admin, Staff  
**Description:** Get all retrievals awaiting client signature

#### Query Parameters
```
clientId - Filter by client (optional)
limit    - Max results (default: 50)
```

#### Request Example
```http
GET /api/retrievals/pending?clientId=1
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": {
    "retrievals": [
      {
        "retrievalId": 124,
        "client": {
          "clientId": 1,
          "clientName": "ACME Corporation",
          "clientCode": "ACME",
          "contactPerson": "John Doe"
        },
        "box": {
          "boxId": 6,
          "boxNumber": "BOX-ACME-0006",
          "boxDescription": "HR Records 2024"
        },
        "retrievalDate": "2025-02-12",
        "retrievedBy": "Jane Smith",
        "reason": "Employee verification",
        "hasStaffSignature": true,
        "awaitingClientSignature": true,
        "createdBy": "staff1",
        "createdAt": "2025-02-12T09:00:00.000Z"
      }
    ],
    "total": 3
  }
}
```

---

### 5. Get My Pending Retrievals

**Endpoint:** `GET /api/retrievals/pending/my`  
**Access:** Client  
**Description:** Get retrievals awaiting my signature

#### Request Example
```http
GET /api/retrievals/pending/my
Authorization: Bearer {{client_token}}
```

#### Response Example
```json
{
  "status": "success",
  "message": "You have 2 retrieval(s) awaiting your signature",
  "data": {
    "retrievals": [
      {
        "retrievalId": 124,
        "box": {
          "boxId": 6,
          "boxNumber": "BOX-ACME-0006",
          "boxDescription": "HR Records 2024"
        },
        "retrievalDate": "2025-02-12",
        "retrievedBy": "Jane Smith",
        "reason": "Employee verification",
        "hasStaffSignature": true,
        "awaitingClientSignature": true,
        "createdBy": "staff1",
        "createdAt": "2025-02-12T09:00:00.000Z"
      }
    ],
    "total": 2
  }
}
```

---

### 6. Get Client's Retrievals

**Endpoint:** `GET /api/retrievals/client/:clientId`  
**Access:** Admin, Staff, Client (own only)  
**Description:** Get all retrievals for a specific client

#### Request Example
```http
GET /api/retrievals/client/1
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": [
    {
      "retrievalId": 123,
      "box": {
        "boxId": 5,
        "boxNumber": "BOX-ACME-0005",
        "boxDescription": "Financial Records 2024"
      },
      "retrievalDate": "2025-02-11",
      "retrievedBy": "Jane Smith",
      "reason": "Annual audit",
      "hasClientSignature": true,
      "hasStaffSignature": true,
      "isComplete": true,
      "clientSignature": "data:image/png;base64,...",
      "staffSignature": "data:image/png;base64,...",
      "pdfPath": "/receipts/retrieval_123.pdf",
      "createdBy": "staff1",
      "createdAt": "2025-02-11T10:30:00.000Z"
    }
  ]
}
```

---

### 7. Get Box's Retrieval History

**Endpoint:** `GET /api/retrievals/box/:boxId`  
**Access:** Admin, Staff  
**Description:** Get all retrievals for a specific box

#### Request Example
```http
GET /api/retrievals/box/5
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": [
    {
      "retrievalId": 123,
      "client": {
        "clientId": 1,
        "clientName": "ACME Corporation",
        "clientCode": "ACME"
      },
      "retrievalDate": "2025-02-11",
      "retrievedBy": "Jane Smith",
      "reason": "Annual audit",
      "hasClientSignature": true,
      "hasStaffSignature": true,
      "isComplete": true,
      "clientSignature": "data:image/png;base64,...",
      "staffSignature": "data:image/png;base64,...",
      "pdfPath": "/receipts/retrieval_123.pdf",
      "createdBy": "staff1",
      "createdAt": "2025-02-11T10:30:00.000Z"
    }
  ]
}
```

---

### 8. Get Single Retrieval

**Endpoint:** `GET /api/retrievals/:retrievalId`  
**Access:** Admin, Staff, Client (own only)  
**Description:** Get detailed information about a single retrieval

#### Request Example
```http
GET /api/retrievals/123
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": {
    "retrievalId": 123,
    "client": {
      "clientId": 1,
      "clientName": "ACME Corporation",
      "clientCode": "ACME",
      "contactPerson": "John Doe",
      "email": "contact@acme.com"
    },
    "box": {
      "boxId": 5,
      "boxNumber": "BOX-ACME-0005",
      "boxDescription": "Financial Records 2024"
    },
    "retrievalDate": "2025-02-11",
    "retrievedBy": "Jane Smith",
    "reason": "Annual audit requirements",
    "hasClientSignature": true,
    "hasStaffSignature": true,
    "isComplete": true,
    "clientSignature": "data:image/png;base64,...",
    "staffSignature": "data:image/png;base64,...",
    "pdfPath": "/receipts/retrieval_123.pdf",
    "createdBy": {
      "userId": 2,
      "username": "staff1"
    },
    "createdAt": "2025-02-11T10:30:00.000Z"
  }
}
```

---

### 9. Create Retrieval

**Endpoint:** `POST /api/retrievals`  
**Access:** Admin, Staff (with `canCreateRetrievals` permission)  
**Description:** Create new retrieval record

#### Request Body
```json
{
  "clientId": 1,
  "boxId": 5,
  "retrievalDate": "2025-02-11",
  "retrievedBy": "Jane Smith",
  "reason": "Annual audit requirements",
  "staffSignature": "data:image/png;base64,..."  // Optional
}
```

#### Request Example
```http
POST /api/retrievals
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "clientId": 1,
  "boxId": 5,
  "retrievalDate": "2025-02-11",
  "retrievedBy": "Jane Smith",
  "reason": "Annual audit requirements"
}
```

#### Response Example
```json
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

#### Validations
- Client must exist
- Box must exist and belong to client
- Box status must be 'stored' (not 'retrieved' or 'destroyed')
- Box remains 'stored' until client signs

---

### 10. Update Signatures (KEY ENDPOINT)

**Endpoint:** `PATCH /api/retrievals/:retrievalId/signatures`  
**Access:** Admin, Staff, Client (for client signature only)  
**Description:** Add/update signatures - CLIENT SIGNATURE MARKS BOX AS RETRIEVED

#### Request Body
```json
{
  "clientSignature": "data:image/png;base64,...",  // Optional
  "staffSignature": "data:image/png;base64,..."    // Optional (Admin/Staff only)
}
```

#### Client Signing Example
```http
PATCH /api/retrievals/124/signatures
Authorization: Bearer {{client_token}}
Content-Type: application/json

{
  "clientSignature": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgA..."
}
```

#### Response Example
```json
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

#### Staff Signing Example
```http
PATCH /api/retrievals/124/signatures
Authorization: Bearer {{staff_token}}
Content-Type: application/json

{
  "staffSignature": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgA..."
}
```

#### Response Example (Staff)
```json
{
  "status": "success",
  "message": "Signatures updated successfully",
  "data": {
    "retrievalId": 124,
    "boxId": 5,
    "boxNumber": "BOX-ACME-0005",
    "retrievalCompleted": false,
    "boxStatusChanged": false,
    "boxStatus": "stored"
  }
}
```

#### Important Notes
- **Client signature** → Box status changes to 'retrieved' (AUTOMATIC)
- **Staff signature** → No box status change
- Transaction-safe: Both updates succeed or rollback
- Only updates box status if currently 'stored'
- Clients can only add client signature
- Staff can add either signature

---

### 11. Update PDF Path

**Endpoint:** `PATCH /api/retrievals/:retrievalId/pdf`  
**Access:** Admin, Staff  
**Description:** Update retrieval PDF receipt path

#### Request Body
```json
{
  "pdfPath": "/receipts/retrieval_124.pdf"
}
```

#### Request Example
```http
PATCH /api/retrievals/124/pdf
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "pdfPath": "/receipts/retrieval_124.pdf"
}
```

#### Response Example
```json
{
  "status": "success",
  "message": "PDF path updated successfully",
  "data": {
    "pdfPath": "/receipts/retrieval_124.pdf"
  }
}
```

---

### 12. Mark Box as Retrieved (Manual Override)

**Endpoint:** `PATCH /api/retrievals/box/:boxId/mark-retrieved`  
**Access:** Admin, Staff  
**Description:** Manually mark box as retrieved (bypasses signature workflow)

#### Request Example
```http
PATCH /api/retrievals/box/5/mark-retrieved
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "message": "Box manually marked as retrieved successfully",
  "data": {
    "boxId": 5,
    "boxNumber": "BOX-ACME-0005",
    "oldStatus": "stored",
    "newStatus": "retrieved",
    "note": "Manual override - normally done via client signature on retrieval"
  }
}
```

#### Use Case
Use only for exceptional cases where signature workflow cannot be completed. Creates audit log noting manual override.

---

### 13. Delete Retrieval

**Endpoint:** `DELETE /api/retrievals/:retrievalId`  
**Access:** Admin only  
**Description:** Permanently delete a retrieval record

#### Request Example
```http
DELETE /api/retrievals/123
Authorization: Bearer {{admin_token}}
```

#### Response Example
```json
{
  "status": "success",
  "message": "Retrieval deleted successfully"
}
```

---

### 14. Get Summary Report

**Endpoint:** `GET /api/retrievals/reports/summary`  
**Access:** Admin, Staff  
**Description:** Get daily retrieval summary

#### Query Parameters
```
startDate  - Start date (YYYY-MM-DD)
endDate    - End date (YYYY-MM-DD)
clientId   - Filter by client (optional)
```

#### Request Example
```http
GET /api/retrievals/reports/summary?startDate=2025-02-01&endDate=2025-02-28
Authorization: Bearer {{token}}
```

#### Response Example
```json
{
  "status": "success",
  "data": [
    {
      "date": "2025-02-11",
      "retrieval_count": 5,
      "unique_clients": 3,
      "unique_boxes": 5
    },
    {
      "date": "2025-02-10",
      "retrieval_count": 3,
      "unique_clients": 2,
      "unique_boxes": 3
    }
  ]
}
```

---

### 15. Get Client Report

**Endpoint:** `GET /api/retrievals/reports/by-client`  
**Access:** Admin, Staff  
**Description:** Get retrievals grouped by client

#### Query Parameters
```
startDate  - Start date (YYYY-MM-DD)
endDate    - End date (YYYY-MM-DD)
```

#### Request Example
```http
GET /api/retrievals/reports/by-client?startDate=2025-01-01
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
      "retrieval_count": 45,
      "boxes_retrieved": 42,
      "last_retrieval_date": "2025-02-11"
    }
  ]
}
```

---

## Workflow Examples

### Complete Retrieval Workflow

#### Step 1: Staff Creates Retrieval
```http
POST /api/retrievals
Authorization: Bearer {{staff_token}}

{
  "clientId": 1,
  "boxId": 5,
  "retrievalDate": "2025-02-11",
  "retrievedBy": "Jane Smith",
  "reason": "Annual audit requirements",
  "staffSignature": "data:image/png;base64,..."
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
**Box Status:** 'stored' (unchanged)

#### Step 2: Client Checks Pending Retrievals
```http
GET /api/retrievals/pending/my
Authorization: Bearer {{client_token}}

Response:
{
  "status": "success",
  "message": "You have 1 retrieval(s) awaiting your signature",
  "data": {
    "retrievals": [
      {
        "retrievalId": 124,
        "box": {...},
        "retrievalDate": "2025-02-11",
        "retrievedBy": "Jane Smith",
        "reason": "Annual audit requirements",
        "hasStaffSignature": true,
        "awaitingClientSignature": true
      }
    ],
    "total": 1
  }
}
```

#### Step 3: Client Signs (Completes Retrieval)
```http
PATCH /api/retrievals/124/signatures
Authorization: Bearer {{client_token}}

{
  "clientSignature": "data:image/png;base64,iVBORw0KG..."
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
**Box Status:** 'retrieved' ✅ (AUTOMATIC)

#### Step 4: Verify Retrieval Complete
```http
GET /api/retrievals/124
Authorization: Bearer {{token}}

Response:
{
  "status": "success",
  "data": {
    "retrievalId": 124,
    "isComplete": true,
    "hasClientSignature": true,
    "hasStaffSignature": true,
    ...
  }
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
  "message": "Error description",
  "code": "ERROR_CODE"
}
```

---

## Error Handling

### Common Errors

#### Box Not Found
```json
{
  "status": "error",
  "message": "Box not found"
}
```

#### Box Already Retrieved
```json
{
  "status": "error",
  "message": "Box has already been retrieved"
}
```

#### Box Belongs to Different Client
```json
{
  "status": "error",
  "message": "Box does not belong to this client"
}
```

#### Unauthorized Access
```json
{
  "status": "error",
  "message": "You can only access your own retrievals"
}
```

#### Client Trying to Add Staff Signature
```json
{
  "status": "error",
  "message": "Only staff can provide staff signature"
}
```

---

## Integration Examples

### Flutter Integration

```dart
import 'package:signature/signature.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RetrievalService {
  final String baseUrl = 'http://localhost:3000/api';
  final String token;

  RetrievalService(this.token);

  // Get pending retrievals for client
  Future<List<Retrieval>> getPendingRetrievals() async {
    final response = await http.get(
      Uri.parse('$baseUrl/retrievals/pending/my'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data']['retrievals'] as List)
          .map((json) => Retrieval.fromJson(json))
          .toList();
    }
    throw Exception('Failed to load pending retrievals');
  }

  // Sign retrieval with signature pad
  Future<void> signRetrieval(int retrievalId, SignatureController controller) async {
    // Get signature as bytes
    final signature = await controller.toPngBytes();
    if (signature == null) throw Exception('No signature provided');

    // Convert to base64
    final base64Signature = base64Encode(signature);
    final signatureData = 'data:image/png;base64,$base64Signature';

    // Send to API
    final response = await http.patch(
      Uri.parse('$baseUrl/retrievals/$retrievalId/signatures'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'clientSignature': signatureData,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Retrieval signed successfully!');
      print('Box status: ${data['data']['boxStatus']}');
    } else {
      throw Exception('Failed to sign retrieval');
    }
  }

  // Get retrieval history for client
  Future<List<Retrieval>> getMyRetrievals() async {
    final response = await http.get(
      Uri.parse('$baseUrl/retrievals/client/1'), // Replace with actual clientId
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List)
          .map((json) => Retrieval.fromJson(json))
          .toList();
    }
    throw Exception('Failed to load retrievals');
  }
}

// Model class
class Retrieval {
  final int retrievalId;
  final String boxNumber;
  final String retrievalDate;
  final String retrievedBy;
  final String? reason;
  final bool hasClientSignature;
  final bool hasStaffSignature;
  final bool isComplete;

  Retrieval({
    required this.retrievalId,
    required this.boxNumber,
    required this.retrievalDate,
    required this.retrievedBy,
    this.reason,
    required this.hasClientSignature,
    required this.hasStaffSignature,
    required this.isComplete,
  });

  factory Retrieval.fromJson(Map<String, dynamic> json) {
    return Retrieval(
      retrievalId: json['retrievalId'],
      boxNumber: json['box']['boxNumber'],
      retrievalDate: json['retrievalDate'],
      retrievedBy: json['retrievedBy'],
      reason: json['reason'],
      hasClientSignature: json['hasClientSignature'],
      hasStaffSignature: json['hasStaffSignature'],
      isComplete: json['isComplete'],
    );
  }
}
```

### UI Example - Pending Signature Screen

```dart
class PendingSignatureScreen extends StatefulWidget {
  @override
  _PendingSignatureScreenState createState() => _PendingSignatureScreenState();
}

class _PendingSignatureScreenState extends State<PendingSignatureScreen> {
  late Future<List<Retrieval>> _pendingRetrievals;
  final RetrievalService _retrievalService = RetrievalService(token);

  @override
  void initState() {
    super.initState();
    _pendingRetrievals = _retrievalService.getPendingRetrievals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pending Signatures')),
      body: FutureBuilder<List<Retrieval>>(
        future: _pendingRetrievals,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final retrievals = snapshot.data!;
            
            if (retrievals.isEmpty) {
              return Center(child: Text('No pending signatures'));
            }

            return ListView.builder(
              itemCount: retrievals.length,
              itemBuilder: (context, index) {
                final retrieval = retrievals[index];
                return Card(
                  child: ListTile(
                    title: Text('Box: ${retrieval.boxNumber}'),
                    subtitle: Text(
                      'Retrieved by: ${retrieval.retrievedBy}\n'
                      'Date: ${retrieval.retrievalDate}\n'
                      'Reason: ${retrieval.reason ?? 'N/A'}'
                    ),
                    trailing: Icon(
                      retrieval.hasStaffSignature 
                        ? Icons.check_circle 
                        : Icons.pending,
                      color: retrieval.hasStaffSignature 
                        ? Colors.green 
                        : Colors.orange,
                    ),
                    onTap: () => _showSignatureDialog(retrieval),
                  ),
                );
              },
            );
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  void _showSignatureDialog(Retrieval retrieval) {
    final SignatureController controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Retrieval'),
        content: SizedBox(
          height: 300,
          child: Column(
            children: [
              Text('Box: ${retrieval.boxNumber}'),
              SizedBox(height: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Signature(
                    controller: controller,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => controller.clear(),
            child: Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _retrievalService.signRetrieval(
                  retrieval.retrievalId,
                  controller,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Retrieval signed successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {
                  _pendingRetrievals = _retrievalService.getPendingRetrievals();
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Failed to sign: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Sign'),
          ),
        ],
      ),
    );
  }
}
```

---

## Best Practices

### 1. Creating Retrievals
- Always include `retrievedBy` and `reason` for audit purposes
- Staff should add their signature at creation if physically present
- Client signature should be added after physical box handoff
- Verify box belongs to client before creating retrieval

### 2. Client Signing
- Use GET /pending/my to show clients what needs signing
- Verify physical receipt of box before signing
- Signature marks legal acceptance of retrieval
- Display clear confirmation after signing

### 3. Display
- Use `isComplete` flag for UI state
- Display base64 signatures in image tags
- Show pending signature count to clients on login/dashboard
- Clearly indicate when box has been retrieved

### 4. Error Handling
- Always handle API errors gracefully
- Show user-friendly error messages
- Retry failed signature uploads
- Log errors for debugging

### 5. Security
- Always verify user can access retrieval before showing details
- Clients should only see their own retrievals
- Use proper authentication tokens
- Validate all inputs

---

## Quick Reference

### Box Status Changes
| Action | Box Status Before | Box Status After |
|--------|------------------|------------------|
| Create retrieval | stored | stored (unchanged) |
| Staff signs | stored | stored (unchanged) |
| Client signs | stored | **retrieved** ✅ |
| Manual override | stored | retrieved |

### Signature Properties
| Property | Description | When Set |
|----------|-------------|----------|
| `hasClientSignature` | Boolean - client has signed | When client signature added |
| `hasStaffSignature` | Boolean - staff has signed | When staff signature added |
| `isComplete` | Boolean - retrieval complete | When client has signed |
| `clientSignature` | Base64 image data | When client signs |
| `staffSignature` | Base64 image data | When staff signs |

### Status Flags
```javascript
{
  "hasClientSignature": true,    // Client has signed
  "hasStaffSignature": true,     // Staff has signed
  "isComplete": true,             // Retrieval is complete (client signed)
  "awaitingClientSignature": false  // Still needs client signature
}
```

---

## Support

For additional help or questions:
- Check the Postman collection for working examples
- Review the signature workflow section
- Test with the provided endpoints
- Verify authentication tokens are valid

---

**Last Updated:** February 11, 2025  
**API Version:** 1.0  
**Base URL:** `http://localhost:3000/api`
