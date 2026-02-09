// box_model.dart
import 'dart:convert';

class BoxModel {
  final int boxId;
  final String boxNumber;
  final String description;
  final DateTime dateReceived;
  final int yearReceived;
  final int retentionYears;
  final int? destructionYear;
  final String status;
  final bool isPendingDestruction;
  final DateTime createdAt;
  final DateTime updatedAt;
  final BoxClient client;
  final BoxRackingLabel? rackingLabel;

  BoxModel({
    required this.boxId,
    required this.boxNumber,
    required this.description,
    required this.dateReceived,
    required this.yearReceived,
    required this.retentionYears,
    this.destructionYear,
    required this.status,
    required this.isPendingDestruction,
    required this.createdAt,
    required this.updatedAt,
    required this.client,
    this.rackingLabel,
  });

  factory BoxModel.fromJson(Map<String, dynamic> json) {
    return BoxModel(
      boxId: json['boxId'] ?? json['box_id'] ?? 0,
      boxNumber: json['boxNumber'] ?? json['box_number'] ?? '',
      description: json['description'] ?? json['box_description'] ?? '',
      dateReceived: json['dateReceived'] != null
          ? DateTime.parse(json['dateReceived'])
          : json['date_received'] != null
              ? DateTime.parse(json['date_received'])
              : DateTime.now(),
      yearReceived: json['yearReceived'] ?? json['year_received'] ?? 0,
      retentionYears: json['retentionYears'] ?? json['retention_years'] ?? 7,
      destructionYear: json['destructionYear'] ?? json['destruction_year'],
      status: json['status'] ?? 'stored',
      isPendingDestruction: json['isPendingDestruction'] ?? 
                           json['is_pending_destruction'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
      client: BoxClient.fromJson(json['client'] ?? {
        'clientId': json['client_id'] ?? 0,
        'clientName': json['client_name'] ?? '',
        'clientCode': json['client_code'] ?? '',
      }),
      rackingLabel: json['rackingLabel'] != null
          ? BoxRackingLabel.fromJson(json['rackingLabel'])
          : json['racking_label'] != null
              ? BoxRackingLabel.fromJson(json['racking_label'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'boxId': boxId,
      'boxNumber': boxNumber,
      'description': description,
      'dateReceived': dateReceived.toIso8601String(),
      'yearReceived': yearReceived,
      'retentionYears': retentionYears,
      'destructionYear': destructionYear,
      'status': status,
      'isPendingDestruction': isPendingDestruction,
      'client': client.toJson(),
      'rackingLabel': rackingLabel?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String toJsonString() => json.encode(toJson());
  
  factory BoxModel.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return BoxModel.fromJson(json);
  }

  // Helper methods
  bool get canBeRetrieved => status == 'stored';
  bool get canBeDestroyed => status == 'stored' && (isPendingDestruction || status == 'pending');
  bool get canBeStored => status == 'retrieved';
  
  String get statusDisplay {
    switch (status) {
      case 'stored':
        return 'In Storage';
      case 'retrieved':
        return 'Retrieved';
      case 'destroyed':
        return 'Destroyed';
      default:
        return status;
    }
  }
  
  String get statusColor {
    switch (status) {
      case 'stored':
        return '#4CAF50'; // Green
      case 'retrieved':
        return '#2196F3'; // Blue
      case 'destroyed':
        return '#F44336'; // Red
      default:
        return '#9E9E9E'; // Grey
    }
  }

  // Get box index from box number (extract after the client code)
  String get boxIndex {
    final parts = boxNumber.split('-');
    if (parts.length >= 3) {
      return parts.sublist(2).join('-'); // Return everything after client code
    }
    return boxNumber;
  }
}

class BoxClient {
  final int clientId;
  final String clientName;
  final String clientCode;

  BoxClient({
    required this.clientId,
    required this.clientName,
    required this.clientCode,
  });

  factory BoxClient.fromJson(Map<String, dynamic> json) {
    return BoxClient(
      clientId: json['clientId'] ?? json['client_id'] ?? 0,
      clientName: json['clientName'] ?? json['client_name'] ?? '',
      clientCode: json['clientCode'] ?? json['client_code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientCode': clientCode,
    };
  }
}

class BoxRackingLabel {
  final int labelId;
  final String labelCode;
  final String location;
  final bool isAvailable;

  BoxRackingLabel({
    required this.labelId,
    required this.labelCode,
    required this.location,
    required this.isAvailable,
  });

  factory BoxRackingLabel.fromJson(Map<String, dynamic> json) {
    return BoxRackingLabel(
      labelId: json['labelId'] ?? json['label_id'] ?? 0,
      labelCode: json['labelCode'] ?? json['label_code'] ?? '',
      location: json['location'] ?? json['location_description'] ?? '',
      isAvailable: json['isAvailable'] ?? json['is_available'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'labelId': labelId,
      'labelCode': labelCode,
      'location': location,
      'isAvailable': isAvailable,
    };
  }
}

// Request Models
class CreateBoxRequest {
  final int clientId;
  final String boxIndex; // Required field for custom indexing
  final int? rackingLabelId;
  final String boxDescription;
  final String dateReceived;
  final int retentionYears;

  CreateBoxRequest({
    required this.clientId,
    required this.boxIndex, // Now required
    this.rackingLabelId,
    required this.boxDescription,
    required this.dateReceived,
    this.retentionYears = 7,
  });

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'boxIndex': boxIndex, // Changed from boxNumber to boxIndex
      if (rackingLabelId != null) 'rackingLabelId': rackingLabelId,
      'boxDescription': boxDescription,
      'dateReceived': dateReceived,
      'retentionYears': retentionYears,
    };
  }
}

class UpdateBoxRequest {
  final String? boxDescription;
  final int? rackingLabelId;
  final int? retentionYears;

  UpdateBoxRequest({
    this.boxDescription,
    this.rackingLabelId,
    this.retentionYears,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (boxDescription != null) data['boxDescription'] = boxDescription;
    if (rackingLabelId != null) data['rackingLabelId'] = rackingLabelId;
    if (retentionYears != null) data['retentionYears'] = retentionYears;
    return data;
  }
}

class ChangeBoxStatusRequest {
  final String status;

  ChangeBoxStatusRequest({
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
    };
  }
}

// Individual box data for bulk creation
class BulkBoxData {
  final int clientId;
  final String boxIndex; // Required for each box in bulk
  final String boxDescription;
  final String dateReceived;
  final int retentionYears;
  final int? rackingLabelId;

  BulkBoxData({
    required this.clientId,
    required this.boxIndex,
    required this.boxDescription,
    required this.dateReceived,
    this.retentionYears = 7,
    this.rackingLabelId,
  });

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'boxIndex': boxIndex,
      'boxDescription': boxDescription,
      'dateReceived': dateReceived,
      'retentionYears': retentionYears,
      if (rackingLabelId != null) 'rackingLabelId': rackingLabelId,
    };
  }
}

class BulkCreateBoxRequest {
  final List<BulkBoxData> boxes;

  BulkCreateBoxRequest({
    required this.boxes,
  });

  Map<String, dynamic> toJson() {
    return {
      'boxes': boxes.map((box) => box.toJson()).toList(),
    };
  }
}

class BulkUpdateStatusRequest {
  final List<int> boxIds;
  final String status;

  BulkUpdateStatusRequest({
    required this.boxIds,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'boxIds': boxIds,
      'status': status,
    };
  }
}

// Response Models
class BoxesResponse {
  final String status;
  final String message;
  final BoxesData? data;

  BoxesResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory BoxesResponse.fromJson(Map<String, dynamic> json) {
    return BoxesResponse(
      status: json['status'] ?? 'error',
      message: json['message'] ?? '',
      data: json['data'] != null ? BoxesData.fromJson(json['data']) : null,
    );
  }
}

class BoxesData {
  final List<BoxModel> boxes;
  final Pagination? pagination;

  BoxesData({
    required this.boxes,
    this.pagination,
  });

  factory BoxesData.fromJson(Map<String, dynamic> json) {
    return BoxesData(
      boxes: (json['boxes'] as List<dynamic>)
          .map((box) => BoxModel.fromJson(box))
          .toList(),
      pagination: json['pagination'] != null 
          ? Pagination.fromJson(json['pagination'])
          : null,
    );
  }
}

class Pagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 50,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}

class BoxStats {
  final int totalBoxes;
  final int boxesStored;
  final int boxesRetrieved;
  final int boxesDestroyed;
  final int boxesPendingDestruction;
  final int totalClientsWithBoxes;

  BoxStats({
    required this.totalBoxes,
    required this.boxesStored,
    required this.boxesRetrieved,
    required this.boxesDestroyed,
    required this.boxesPendingDestruction,
    required this.totalClientsWithBoxes,
  });

  factory BoxStats.fromJson(Map<String, dynamic> json) {
    return BoxStats(
      totalBoxes: json['total_boxes'] ?? 0,
      boxesStored: json['boxes_stored'] ?? 0,
      boxesRetrieved: json['boxes_retrieved'] ?? 0,
      boxesDestroyed: json['boxes_destroyed'] ?? 0,
      boxesPendingDestruction: json['boxes_pending_destruction'] ?? 0,
      totalClientsWithBoxes: json['total_clients_with_boxes'] ?? 0,
    );
  }
}

// Helper class for generating full box number
class BoxNumberHelper {
  static String formatBoxNumber(String clientCode, String boxIndex) {
    return 'BOX-$clientCode-${boxIndex.toUpperCase()}';
  }
}