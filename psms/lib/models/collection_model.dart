import 'dart:convert';
import 'dart:typed_data';

class CollectionModel {
  final int collectionId;
  final CollectionClient client;
  final int totalBoxes;
  final String? boxDescription;
  final String dispatcherName;
  final String collectorName;
  final String? dispatcherSignature;
  final String? collectorSignature;
  final DateTime collectionDate;
  final String? pdfPath;
  final CollectionUser createdBy;
  final DateTime createdAt;

  CollectionModel({
    required this.collectionId,
    required this.client,
    required this.totalBoxes,
    this.boxDescription,
    required this.dispatcherName,
    required this.collectorName,
    this.dispatcherSignature,
    this.collectorSignature,
    required this.collectionDate,
    this.pdfPath,
    required this.createdBy,
    required this.createdAt,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse date with timezone handling
    DateTime parseDate(String? dateStr) {
      if (dateStr == null) {
        return DateTime.now();
      }
      try {
        return DateTime.parse(dateStr).toLocal();
      } catch (e) {
        print('Error parsing date $dateStr: $e');
        return DateTime.now();
      }
    }

    // Helper to check if signature exists and is not empty
    String? parseSignature(dynamic sig) {
      if (sig == null) {
        return null;
      }
      if (sig is String && sig.isNotEmpty) {
        return sig;
      }
      return null;
    }

    return CollectionModel(
      collectionId: json['collectionId'] ?? json['collection_id'] ?? 0,
      client: CollectionClient.fromJson(json['client'] ?? {
        'clientId': json['client_id'] ?? 0,
        'clientName': json['client_name'] ?? '',
        'clientCode': json['client_code'] ?? '',
      }),
      totalBoxes: json['totalBoxes'] ?? json['total_boxes'] ?? 0,
      boxDescription: json['boxDescription'] ?? json['box_description'],
      dispatcherName: json['dispatcherName'] ?? json['dispatcher_name'] ?? '',
      collectorName: json['collectorName'] ?? json['collector_name'] ?? '',
      dispatcherSignature: parseSignature(json['dispatcherSignature'] ?? json['dispatcher_signature']),
      collectorSignature: parseSignature(json['collectorSignature'] ?? json['collector_signature']),
      collectionDate: parseDate(json['collectionDate'] ?? json['collection_date']),
      pdfPath: json['pdfPath'] ?? json['pdf_path'],
      createdBy: CollectionUser.fromJson(json['createdBy'] ?? {
        'userId': json['created_by'] ?? 0,
        'username': json['created_by_username'] ?? '',
      }),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collectionId': collectionId,
      'client': client.toJson(),
      'totalBoxes': totalBoxes,
      'boxDescription': boxDescription,
      'dispatcherName': dispatcherName,
      'collectorName': collectorName,
      'dispatcherSignature': dispatcherSignature,
      'collectorSignature': collectorSignature,
      'collectionDate': collectionDate.toIso8601String(),
      'pdfPath': pdfPath,
      'createdBy': createdBy.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Helper method to decode and display signatures
  Uint8List? getDispatcherSignatureBytes() {
    return _decodeBase64Image(dispatcherSignature);
  }

  Uint8List? getCollectorSignatureBytes() {
    return _decodeBase64Image(collectorSignature);
  }

  Uint8List? _decodeBase64Image(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return null;
    }
    
    try {
      // Clean the base64 string (remove data URI prefix if present)
      String cleanBase64 = base64String;
      
      // Check if it's a data URI (starts with data:image)
      if (cleanBase64.contains('base64,')) {
        // Remove the data URI prefix
        cleanBase64 = cleanBase64.split('base64,').last;
      }
      
      // Remove any whitespace
      cleanBase64 = cleanBase64.trim();
      
      return base64Decode(cleanBase64);
    } catch (e) {
      print('Error decoding base64 image: $e');
      return null;
    }
  }
}

class CollectionClient {
  final int clientId;
  final String clientName;
  final String clientCode;
  final String? contactPerson;
  final String? email;
  final String? phone;

  CollectionClient({
    required this.clientId,
    required this.clientName,
    required this.clientCode,
    this.contactPerson,
    this.email,
    this.phone,
  });

  factory CollectionClient.fromJson(Map<String, dynamic> json) {
    return CollectionClient(
      clientId: json['clientId'] ?? json['client_id'] ?? 0,
      clientName: json['clientName'] ?? json['client_name'] ?? '',
      clientCode: json['clientCode'] ?? json['client_code'] ?? '',
      contactPerson: json['contactPerson'] ?? json['contact_person'],
      email: json['email'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientCode': clientCode,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
    };
  }
}

class CollectionUser {
  final int userId;
  final String username;
  final String? email;

  CollectionUser({
    required this.userId,
    required this.username,
    this.email,
  });

  factory CollectionUser.fromJson(Map<String, dynamic> json) {
    return CollectionUser(
      userId: json['userId'] ?? json['user_id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
    };
  }
}

// Request Models (keep these the same)
class CreateCollectionRequest {
  final int clientId;
  final int totalBoxes;
  final String? boxDescription;
  final String dispatcherName;
  final String collectorName;
  final String? dispatcherSignature;
  final String? collectorSignature;
  final String collectionDate;

  CreateCollectionRequest({
    required this.clientId,
    required this.totalBoxes,
    this.boxDescription,
    required this.dispatcherName,
    required this.collectorName,
    this.dispatcherSignature,
    this.collectorSignature,
    required this.collectionDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'totalBoxes': totalBoxes,
      if (boxDescription != null) 'boxDescription': boxDescription,
      'dispatcherName': dispatcherName,
      'collectorName': collectorName,
      if (dispatcherSignature != null) 'dispatcherSignature': dispatcherSignature,
      if (collectorSignature != null) 'collectorSignature': collectorSignature,
      'collectionDate': collectionDate,
    };
  }
}


class UpdateCollectionRequest {
  final int? totalBoxes;
  final String? boxDescription;
  final String? dispatcherName;
  final String? collectorName;
  final String? dispatcherSignature;
  final String? collectorSignature;
  final String? collectionDate;

  UpdateCollectionRequest({
    this.totalBoxes,
    this.boxDescription,
    this.dispatcherName,
    this.collectorName,
    this.dispatcherSignature,
    this.collectorSignature,
    this.collectionDate,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (totalBoxes != null) data['totalBoxes'] = totalBoxes;
    if (boxDescription != null) data['boxDescription'] = boxDescription;
    if (dispatcherName != null) data['dispatcherName'] = dispatcherName;
    if (collectorName != null) data['collectorName'] = collectorName;
    if (dispatcherSignature != null) data['dispatcherSignature'] = dispatcherSignature;
    if (collectorSignature != null) data['collectorSignature'] = collectorSignature;
    if (collectionDate != null) data['collectionDate'] = collectionDate;
    return data;
  }
}

class UpdateSignaturesRequest {
  final String? dispatcherSignature;
  final String? collectorSignature;

  UpdateSignaturesRequest({
    this.dispatcherSignature,
    this.collectorSignature,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (dispatcherSignature != null) data['dispatcherSignature'] = dispatcherSignature;
    if (collectorSignature != null) data['collectorSignature'] = collectorSignature;
    return data;
  }
}

class UpdatePdfRequest {
  final String pdfPath;

  UpdatePdfRequest({
    required this.pdfPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'pdfPath': pdfPath,
    };
  }
}

// Statistics Models
class CollectionStats {
  final int totalCollections;
  final int totalBoxesCollected;
  final int clientsWithCollections;
  final int todayCollections;
  final int thisWeekCollections;
  final int thisMonthCollections;

  CollectionStats({
    required this.totalCollections,
    required this.totalBoxesCollected,
    required this.clientsWithCollections,
    required this.todayCollections,
    required this.thisWeekCollections,
    required this.thisMonthCollections,
  });

  factory CollectionStats.fromJson(Map<String, dynamic> json) {
    return CollectionStats(
      totalCollections: json['total_collections'] ?? 0,
      totalBoxesCollected: json['total_boxes_collected'] ?? 0,
      clientsWithCollections: json['clients_with_collections'] ?? 0,
      todayCollections: json['today_collections'] ?? 0,
      thisWeekCollections: json['this_week_collections'] ?? 0,
      thisMonthCollections: json['this_month_collections'] ?? 0,
    );
  }
}

// Report Models
class CollectionSummary {
  final String date;
  final int collectionCount;
  final String totalBoxes;
  final int uniqueClients;

  CollectionSummary({
    required this.date,
    required this.collectionCount,
    required this.totalBoxes,
    required this.uniqueClients,
  });

  factory CollectionSummary.fromJson(Map<String, dynamic> json) {
    return CollectionSummary(
      date: json['date'] ?? '',
      collectionCount: json['collection_count'] ?? 0,
      totalBoxes: json['total_boxes'] ?? '0',
      uniqueClients: json['unique_clients'] ?? 0,
    );
  }
}

class ClientCollectionReport {
  final int clientId;
  final String clientName;
  final String clientCode;
  final int collectionCount;
  final String totalBoxesCollected;
  final String lastCollectionDate;

  ClientCollectionReport({
    required this.clientId,
    required this.clientName,
    required this.clientCode,
    required this.collectionCount,
    required this.totalBoxesCollected,
    required this.lastCollectionDate,
  });

  factory ClientCollectionReport.fromJson(Map<String, dynamic> json) {
    return ClientCollectionReport(
      clientId: json['client_id'] ?? 0,
      clientName: json['client_name'] ?? '',
      clientCode: json['client_code'] ?? '',
      collectionCount: json['collection_count'] ?? 0,
      totalBoxesCollected: json['total_boxes_collected'] ?? '0',
      lastCollectionDate: json['last_collection_date'] ?? '',
    );
  }
}