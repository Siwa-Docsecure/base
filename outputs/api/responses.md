{{base_url}}/api/storage/locations?page=1&limit=10&is_available=true

response:
{
    "status": "success",
    "data": {
        "locations": [
            {
                "label_id": 1,
                "label_code": "RACK-A-01",
                "location_description": "Warehouse A - Section 1 - Level 1",
                "is_available": 1,
                "boxes_count": 1,
                "created_at": "2025-11-18T11:11:04.000Z",
                "updated_at": "2025-11-18T11:11:04.000Z"
            },
            {
                "label_id": 2,
                "label_code": "RACK-A-02",
                "location_description": "Warehouse A - Section 1 - Level 2",
                "is_available": 1,
                "boxes_count": 1,
                "created_at": "2025-11-18T11:11:04.000Z",
                "updated_at": "2025-11-18T11:11:04.000Z"
            },
            {
                "label_id": 3,
                "label_code": "RACK-A-03",
                "location_description": "Warehouse A - Section 1 - Level 3",
                "is_available": 1,
                "boxes_count": 1,
                "created_at": "2025-11-18T11:11:04.000Z",
                "updated_at": "2025-11-18T11:11:04.000Z"
            },
            {
                "label_id": 4,
                "label_code": "RACK-A-04",
                "location_description": "Warehouse A - Section 2 - Level 1",
                "is_available": 1,
                "boxes_count": 1,
                "created_at": "2025-11-18T11:11:04.000Z",
                "updated_at": "2025-11-18T11:11:04.000Z"
            },
            {
                "label_id": 5,
                "label_code": "RACK-A-05",
                "location_description": "Warehouse A - Section 2 - Level 2",
                "is_available": 1,
                "boxes_count": 1,
                "created_at": "2025-11-18T11:11:04.000Z",
                "updated_at": "2025-11-18T11:11:04.000Z"
            },
            {
                "label_id": 6,
                "label_code": "RACK-B-01",
                "location_description": "Warehouse B - Section 1 - Level 1",
                "is_available": 1,
                "boxes_count": 1,
                "created_at": "2025-11-18T11:11:04.000Z",
                "updated_at": "2025-11-18T11:11:04.000Z"
            },
            {
                "label_id": 7,
                "label_code": "RACK-B-02",
                "location_description": "Warehouse B - Section 1 - Level 2",
                "is_available": 1,
                "boxes_count": 1,
                "created_at": "2025-11-18T11:11:04.000Z",
                "updated_at": "2025-11-18T11:11:04.000Z"
            },
            {
                "label_id": 8,
                "label_code": "RACK-B-03",
                "location_description": "Warehouse B - Section 2 - Level 1",
                "is_available": 1,
                "boxes_count": 1,
                "created_at": "2025-11-18T11:11:04.000Z",
                "updated_at": "2025-11-18T11:11:04.000Z"
            },
            {
                "label_id": 9,
                "label_code": "RACK-B-04",
                "location_description": "Warehouse B - Section 2 - Level 2",
                "is_available": 1,
                "boxes_count": 1,
                "created_at": "2025-11-18T11:11:04.000Z",
                "updated_at": "2025-11-18T11:11:04.000Z"
            },
            {
                "label_id": 10,
                "label_code": "RACK-B-05",
                "location_description": "Warehouse B - Section 3 - Level 1",
                "is_available": 1,
                "boxes_count": 1,
                "created_at": "2025-11-18T11:11:04.000Z",
                "updated_at": "2025-11-18T11:11:04.000Z"
            }
        ],
        "pagination": {
            "page": 1,
            "limit": 10,
            "total": 15,
            "totalPages": 2
        }
    }
}


{{base_url}}/api/storage/locations/available

response:
{
    "status": "success",
    "data": [
        {
            "label_id": 1,
            "label_code": "RACK-A-01",
            "location_description": "Warehouse A - Section 1 - Level 1",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 2,
            "label_code": "RACK-A-02",
            "location_description": "Warehouse A - Section 1 - Level 2",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 3,
            "label_code": "RACK-A-03",
            "location_description": "Warehouse A - Section 1 - Level 3",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 4,
            "label_code": "RACK-A-04",
            "location_description": "Warehouse A - Section 2 - Level 1",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 5,
            "label_code": "RACK-A-05",
            "location_description": "Warehouse A - Section 2 - Level 2",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 6,
            "label_code": "RACK-B-01",
            "location_description": "Warehouse B - Section 1 - Level 1",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 7,
            "label_code": "RACK-B-02",
            "location_description": "Warehouse B - Section 1 - Level 2",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 8,
            "label_code": "RACK-B-03",
            "location_description": "Warehouse B - Section 2 - Level 1",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 9,
            "label_code": "RACK-B-04",
            "location_description": "Warehouse B - Section 2 - Level 2",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 10,
            "label_code": "RACK-B-05",
            "location_description": "Warehouse B - Section 3 - Level 1",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 11,
            "label_code": "RACK-C-01",
            "location_description": "Warehouse C - Section 1 - Level 1",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 12,
            "label_code": "RACK-C-02",
            "location_description": "Warehouse C - Section 1 - Level 2",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 13,
            "label_code": "RACK-C-03",
            "location_description": "Warehouse C - Section 2 - Level 1",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 14,
            "label_code": "RACK-C-04",
            "location_description": "Warehouse C - Section 2 - Level 2",
            "created_at": "2025-11-18T11:11:04.000Z"
        },
        {
            "label_id": 15,
            "label_code": "RACK-C-05",
            "location_description": "Warehouse C - Section 3 - Level 1",
            "created_at": "2025-11-18T11:11:04.000Z"
        }
    ]
}

{{base_url}}/api/storage/locations/1

{
    "status": "success",
    "data": {
        "label_id": 1,
        "label_code": "RACK-A-01",
        "location_description": "Warehouse A - Section 1 - Level 1",
        "is_available": 1,
        "created_at": "2025-11-18T11:11:04.000Z",
        "updated_at": "2025-11-18T11:11:04.000Z",
        "boxes_count": 1,
        "box_numbers": "BOX-001-2024",
        "client_names": "Acme Corporation",
        "boxes": [
            {
                "box_id": 1,
                "box_number": "BOX-001-2024",
                "box_description": "Financial Records 2024 - Q1 to Q4",
                "status": "retrieved",
                "client_name": "Acme Corporation",
                "client_code": "CLI-001"
            }
        ]
    }
}


{{base_url}}/api/storage/locations [post]
 body:
 {
  "label_code": "RACK-D-012",
  "location_description": "Warehouse D - Section 1 - Level 1",
  "is_available": true
}

response:
{
    "status": "success",
    "message": "Storage location created successfully",
    "data": {
        "label_id": 17,
        "label_code": "RACK-D-01",
        "location_description": "Warehouse D - Section 1 - Level 1",
        "is_available": 1,
        "created_at": "2026-01-20T22:46:50.000Z",
        "updated_at": "2026-01-20T22:46:50.000Z"
    }
}


{{base_url}}/api/storage/locations/1 [put]
{
  "location_description": "Warehouse A - Section 1 - Level 1 (Updated)",
  "is_available": false
}

{
    "status": "success",
    "message": "Storage location updated successfully",
    "data": {
        "label_id": 1,
        "label_code": "RACK-A-01",
        "location_description": "Warehouse A - Section 1 - Level 1 (Updated)",
        "is_available": 0,
        "created_at": "2025-11-18T11:11:04.000Z",
        "updated_at": "2026-01-20T22:47:39.000Z"
    }
}


