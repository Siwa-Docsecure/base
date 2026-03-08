// lib/models/retrieval_model.dart

import 'dart:convert';
import 'dart:typed_data'; // <-- ADDED for signature decoding

/// Main model for retrieval records
class RetrievalModel {
  final int? retrievalId;
  final String retrievalNumber;
  final String clientName;
  final String clientIdNumber;
  final String clientContact;
  final String itemDescription;
  final String retrievalReason;
  final String status;
  final String requestedBy;
  final String? approvedBy;
  final String? collectedBy;
  final DateTime requestDate;
  final DateTime? approvalDate;
  final DateTime? collectionDate;
  final String? notes;
  final String? rejectionReason;
  final String? clientSignature;
  final String? staffSignature;
  final String? pdfUrl;
  final List<RetrievalItemModel>? items;
  final List<RetrievalDocumentModel>? documents;
  final List<RetrievalHistoryModel>? history;

  RetrievalModel({
    this.retrievalId,
    required this.retrievalNumber,
    required this.clientName,
    required this.clientIdNumber,
    required this.clientContact,
    required this.itemDescription,
    required this.retrievalReason,
    required this.status,
    required this.requestedBy,
    this.approvedBy,
    this.collectedBy,
    required this.requestDate,
    this.approvalDate,
    this.collectionDate,
    this.notes,
    this.rejectionReason,
    this.clientSignature,
    this.staffSignature,
    this.pdfUrl,
    this.items,
    this.documents,
    this.history,
  });

  // Computed getters
  bool get hasClientSignature => clientSignature != null && clientSignature!.isNotEmpty;
  
  bool get hasStaffSignature => staffSignature != null && staffSignature!.isNotEmpty;
  
  bool get isComplete => status.toLowerCase() == 'completed' || status.toLowerCase() == 'collected';
  
  String? get pdfPath => pdfUrl;

  // ========== NEW: Signature helper methods ==========
  /// Returns decoded client signature bytes for display in Image.memory
  Uint8List? getClientSignatureBytes() => _decodeBase64Image(clientSignature);

  /// Returns decoded staff signature bytes for display in Image.memory
  Uint8List? getStaffSignatureBytes() => _decodeBase64Image(staffSignature);

  /// Decodes a base64 string, removing any data URI prefix if present.
  Uint8List? _decodeBase64Image(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      // Remove data URI prefix (e.g., "data:image/png;base64,")
      String clean = base64String.contains('base64,')
          ? base64String.split('base64,').last
          : base64String;
      clean = clean.trim();
      return base64Decode(clean);
    } catch (e) {
      print('Error decoding signature: $e');
      return null;
    }
  }
  // ===================================================

  factory RetrievalModel.fromJson(Map<String, dynamic> json) {
  // Extract nested client data if present
  final clientData = json['client'] as Map<String, dynamic>?;
  final boxData = json['box'] as Map<String, dynamic>?;

  return RetrievalModel(
    retrievalId: json['retrievalId'] ?? json['id'],
    retrievalNumber: json['retrievalNumber'] ?? '',
    clientName: clientData?['clientName'] ?? json['clientName'] ?? '',
    // Map backend's clientCode to clientIdNumber, and contactPerson to clientContact
    clientIdNumber: clientData?['clientCode'] ?? json['clientIdNumber'] ?? '',
    clientContact: clientData?['contactPerson'] ?? json['clientContact'] ?? '',
    itemDescription: json['itemDescription'] ?? '',
    retrievalReason: json['reason'] ?? json['retrievalReason'] ?? '',
    status: json['status'] ?? 'pending',
    requestedBy: json['retrievedBy'] ?? json['requestedBy'] ?? '',
    approvedBy: json['approvedBy'],
    collectedBy: json['collectedBy'],
    requestDate: json['retrievalDate'] != null
        ? DateTime.parse(json['retrievalDate'])
        : (json['requestDate'] != null ? DateTime.parse(json['requestDate']) : DateTime.now()),
    approvalDate: json['approvalDate'] != null ? DateTime.parse(json['approvalDate']) : null,
    collectionDate: json['collectionDate'] != null ? DateTime.parse(json['collectionDate']) : null,
    notes: json['notes'] ?? json['reason'],
    rejectionReason: json['rejectionReason'],
    clientSignature: json['clientSignature'],
    staffSignature: json['staffSignature'],
    pdfUrl: json['pdfPath'] ?? json['pdfUrl'],
    items: json['items'] != null
        ? (json['items'] as List).map((i) => RetrievalItemModel.fromJson(i)).toList()
        : null,
    documents: json['documents'] != null
        ? (json['documents'] as List).map((d) => RetrievalDocumentModel.fromJson(d)).toList()
        : null,
    history: json['history'] != null
        ? (json['history'] as List).map((h) => RetrievalHistoryModel.fromJson(h)).toList()
        : null,
  );
}

  Map<String, dynamic> toJson() {
    return {
      if (retrievalId != null) 'retrievalId': retrievalId,
      'retrievalNumber': retrievalNumber,
      'clientName': clientName,
      'clientIdNumber': clientIdNumber,
      'clientContact': clientContact,
      'itemDescription': itemDescription,
      'retrievalReason': retrievalReason,
      'status': status,
      'requestedBy': requestedBy,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (collectedBy != null) 'collectedBy': collectedBy,
      'requestDate': requestDate.toIso8601String(),
      if (approvalDate != null) 'approvalDate': approvalDate!.toIso8601String(),
      if (collectionDate != null) 'collectionDate': collectionDate!.toIso8601String(),
      if (notes != null) 'notes': notes,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (clientSignature != null) 'clientSignature': clientSignature,
      if (staffSignature != null) 'staffSignature': staffSignature,
      if (pdfUrl != null) 'pdfUrl': pdfUrl,
      if (items != null) 'items': items!.map((i) => i.toJson()).toList(),
      if (documents != null) 'documents': documents!.map((d) => d.toJson()).toList(),
      if (history != null) 'history': history!.map((h) => h.toJson()).toList(),
    };
  }

  // Copy with method for easy updates
  RetrievalModel copyWith({
    int? retrievalId,
    String? retrievalNumber,
    String? clientName,
    String? clientIdNumber,
    String? clientContact,
    String? itemDescription,
    String? retrievalReason,
    String? status,
    String? requestedBy,
    String? approvedBy,
    String? collectedBy,
    DateTime? requestDate,
    DateTime? approvalDate,
    DateTime? collectionDate,
    String? notes,
    String? rejectionReason,
    String? clientSignature,
    String? staffSignature,
    String? pdfUrl,
    List<RetrievalItemModel>? items,
    List<RetrievalDocumentModel>? documents,
    List<RetrievalHistoryModel>? history,
  }) {
    return RetrievalModel(
      retrievalId: retrievalId ?? this.retrievalId,
      retrievalNumber: retrievalNumber ?? this.retrievalNumber,
      clientName: clientName ?? this.clientName,
      clientIdNumber: clientIdNumber ?? this.clientIdNumber,
      clientContact: clientContact ?? this.clientContact,
      itemDescription: itemDescription ?? this.itemDescription,
      retrievalReason: retrievalReason ?? this.retrievalReason,
      status: status ?? this.status,
      requestedBy: requestedBy ?? this.requestedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      collectedBy: collectedBy ?? this.collectedBy,
      requestDate: requestDate ?? this.requestDate,
      approvalDate: approvalDate ?? this.approvalDate,
      collectionDate: collectionDate ?? this.collectionDate,
      notes: notes ?? this.notes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      clientSignature: clientSignature ?? this.clientSignature,
      staffSignature: staffSignature ?? this.staffSignature,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      items: items ?? this.items,
      documents: documents ?? this.documents,
      history: history ?? this.history,
    );
  }
}

/// Model for creating a new retrieval request
class CreateRetrievalRequest {
  final int clientId;
  final int boxId;
  final String retrievalDate; // Format: YYYY-MM-DD
  final String? retrievedBy;
  final String? reason;
  final String? staffSignature;

  CreateRetrievalRequest({
    required this.clientId,
    required this.boxId,
    required this.retrievalDate,
    this.retrievedBy,
    this.reason,
    this.staffSignature,
  });

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'boxId': boxId,
      'retrievalDate': retrievalDate,
      if (retrievedBy != null) 'retrievedBy': retrievedBy,
      if (reason != null) 'reason': reason,
      if (staffSignature != null) 'staffSignature': staffSignature,
    };
  }
}

/// Model for retrieval item request
class RetrievalItemRequest {
  final String itemName;
  final String itemCategory;
  final int quantity;
  final String? serialNumber;

  RetrievalItemRequest({
    required this.itemName,
    required this.itemCategory,
    required this.quantity,
    this.serialNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'itemCategory': itemCategory,
      'quantity': quantity,
      if (serialNumber != null) 'serialNumber': serialNumber,
    };
  }

  factory RetrievalItemRequest.fromJson(Map<String, dynamic> json) {
    return RetrievalItemRequest(
      itemName: json['itemName'] ?? '',
      itemCategory: json['itemCategory'] ?? '',
      quantity: json['quantity'] ?? 1,
      serialNumber: json['serialNumber'],
    );
  }
}

/// Model for retrieval items
class RetrievalItemModel {
  final int? itemId;
  final String itemName;
  final String itemCategory;
  final int quantity;
  final String? serialNumber;
  final String? condition;

  RetrievalItemModel({
    this.itemId,
    required this.itemName,
    required this.itemCategory,
    required this.quantity,
    this.serialNumber,
    this.condition,
  });

  factory RetrievalItemModel.fromJson(Map<String, dynamic> json) {
    return RetrievalItemModel(
      itemId: json['itemId'] ?? json['id'],
      itemName: json['itemName'] ?? '',
      itemCategory: json['itemCategory'] ?? '',
      quantity: json['quantity'] ?? 1,
      serialNumber: json['serialNumber'],
      condition: json['condition'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (itemId != null) 'itemId': itemId,
      'itemName': itemName,
      'itemCategory': itemCategory,
      'quantity': quantity,
      if (serialNumber != null) 'serialNumber': serialNumber,
      if (condition != null) 'condition': condition,
    };
  }
}

/// Model for retrieval documents
class RetrievalDocumentModel {
  final int? documentId;
  final String documentName;
  final String documentType;
  final String documentUrl;
  final DateTime uploadedDate;
  final String uploadedBy;

  RetrievalDocumentModel({
    this.documentId,
    required this.documentName,
    required this.documentType,
    required this.documentUrl,
    required this.uploadedDate,
    required this.uploadedBy,
  });

  factory RetrievalDocumentModel.fromJson(Map<String, dynamic> json) {
    return RetrievalDocumentModel(
      documentId: json['documentId'] ?? json['id'],
      documentName: json['documentName'] ?? '',
      documentType: json['documentType'] ?? '',
      documentUrl: json['documentUrl'] ?? '',
      uploadedDate: json['uploadedDate'] != null 
          ? DateTime.parse(json['uploadedDate']) 
          : DateTime.now(),
      uploadedBy: json['uploadedBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (documentId != null) 'documentId': documentId,
      'documentName': documentName,
      'documentType': documentType,
      'documentUrl': documentUrl,
      'uploadedDate': uploadedDate.toIso8601String(),
      'uploadedBy': uploadedBy,
    };
  }
}

/// Model for retrieval history/audit trail
class RetrievalHistoryModel {
  final int? historyId;
  final String action;
  final String performedBy;
  final DateTime timestamp;
  final String? comments;
  final String? previousStatus;
  final String? newStatus;

  RetrievalHistoryModel({
    this.historyId,
    required this.action,
    required this.performedBy,
    required this.timestamp,
    this.comments,
    this.previousStatus,
    this.newStatus,
  });

  factory RetrievalHistoryModel.fromJson(Map<String, dynamic> json) {
    return RetrievalHistoryModel(
      historyId: json['historyId'] ?? json['id'],
      action: json['action'] ?? '',
      performedBy: json['performedBy'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      comments: json['comments'],
      previousStatus: json['previousStatus'],
      newStatus: json['newStatus'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (historyId != null) 'historyId': historyId,
      'action': action,
      'performedBy': performedBy,
      'timestamp': timestamp.toIso8601String(),
      if (comments != null) 'comments': comments,
      if (previousStatus != null) 'previousStatus': previousStatus,
      if (newStatus != null) 'newStatus': newStatus,
    };
  }
}

/// Model for retrieval statistics
class RetrievalStats {
  final int totalRetrievals;
  final int pendingRetrievals;
  final int approvedRetrievals;
  final int rejectedRetrievals;
  final int completedRetrievals;
  final Map<String, int>? retrievalsByCategory;
  final Map<String, int>? retrievalsByStatus;
  final Map<String, int>? retrievalsByMonth;
  final List<TopClientModel>? topClients;

  RetrievalStats({
    required this.totalRetrievals,
    required this.pendingRetrievals,
    required this.approvedRetrievals,
    required this.rejectedRetrievals,
    required this.completedRetrievals,
    this.retrievalsByCategory,
    this.retrievalsByStatus,
    this.retrievalsByMonth,
    this.topClients,
  });

  factory RetrievalStats.fromJson(Map<String, dynamic> json) {
    return RetrievalStats(
      totalRetrievals: json['totalRetrievals'] ?? 0,
      pendingRetrievals: json['pendingRetrievals'] ?? 0,
      approvedRetrievals: json['approvedRetrievals'] ?? 0,
      rejectedRetrievals: json['rejectedRetrievals'] ?? 0,
      completedRetrievals: json['completedRetrievals'] ?? 0,
      retrievalsByCategory: json['retrievalsByCategory'] != null
          ? Map<String, int>.from(json['retrievalsByCategory'])
          : null,
      retrievalsByStatus: json['retrievalsByStatus'] != null
          ? Map<String, int>.from(json['retrievalsByStatus'])
          : null,
      retrievalsByMonth: json['retrievalsByMonth'] != null
          ? Map<String, int>.from(json['retrievalsByMonth'])
          : null,
      topClients: json['topClients'] != null
          ? (json['topClients'] as List)
              .map((client) => TopClientModel.fromJson(client))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRetrievals': totalRetrievals,
      'pendingRetrievals': pendingRetrievals,
      'approvedRetrievals': approvedRetrievals,
      'rejectedRetrievals': rejectedRetrievals,
      'completedRetrievals': completedRetrievals,
      if (retrievalsByCategory != null) 'retrievalsByCategory': retrievalsByCategory,
      if (retrievalsByStatus != null) 'retrievalsByStatus': retrievalsByStatus,
      if (retrievalsByMonth != null) 'retrievalsByMonth': retrievalsByMonth,
      if (topClients != null) 'topClients': topClients!.map((c) => c.toJson()).toList(),
    };
  }
}

/// Model for top clients
class TopClientModel {
  final String clientName;
  final String clientIdNumber;
  final int retrievalCount;

  TopClientModel({
    required this.clientName,
    required this.clientIdNumber,
    required this.retrievalCount,
  });

  factory TopClientModel.fromJson(Map<String, dynamic> json) {
    return TopClientModel(
      clientName: json['clientName'] ?? '',
      clientIdNumber: json['clientIdNumber'] ?? '',
      retrievalCount: json['retrievalCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientName': clientName,
      'clientIdNumber': clientIdNumber,
      'retrievalCount': retrievalCount,
    };
  }
}

/// Model for retrieval summary
class RetrievalSummary {
  final String retrievalNumber;
  final String clientName;
  final String status;
  final DateTime requestDate;
  final int itemCount;
  final String itemDescription;

  RetrievalSummary({
    required this.retrievalNumber,
    required this.clientName,
    required this.status,
    required this.requestDate,
    required this.itemCount,
    required this.itemDescription,
  });

  factory RetrievalSummary.fromJson(Map<String, dynamic> json) {
    return RetrievalSummary(
      retrievalNumber: json['retrievalNumber'] ?? '',
      clientName: json['clientName'] ?? '',
      status: json['status'] ?? '',
      requestDate: json['requestDate'] != null 
          ? DateTime.parse(json['requestDate']) 
          : DateTime.now(),
      itemCount: json['itemCount'] ?? 0,
      itemDescription: json['itemDescription'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'retrievalNumber': retrievalNumber,
      'clientName': clientName,
      'status': status,
      'requestDate': requestDate.toIso8601String(),
      'itemCount': itemCount,
      'itemDescription': itemDescription,
    };
  }
}

/// Model for client retrieval report
class ClientRetrievalReport {
  final String clientName;
  final String clientIdNumber;
  final String clientContact;
  final int totalRetrievals;
  final int pendingRetrievals;
  final int approvedRetrievals;
  final int completedRetrievals;
  final List<RetrievalSummary> recentRetrievals;
  final DateTime? lastRetrievalDate;

  ClientRetrievalReport({
    required this.clientName,
    required this.clientIdNumber,
    required this.clientContact,
    required this.totalRetrievals,
    required this.pendingRetrievals,
    required this.approvedRetrievals,
    required this.completedRetrievals,
    required this.recentRetrievals,
    this.lastRetrievalDate,
  });

  factory ClientRetrievalReport.fromJson(Map<String, dynamic> json) {
    return ClientRetrievalReport(
      clientName: json['clientName'] ?? '',
      clientIdNumber: json['clientIdNumber'] ?? '',
      clientContact: json['clientContact'] ?? '',
      totalRetrievals: json['totalRetrievals'] ?? 0,
      pendingRetrievals: json['pendingRetrievals'] ?? 0,
      approvedRetrievals: json['approvedRetrievals'] ?? 0,
      completedRetrievals: json['completedRetrievals'] ?? 0,
      recentRetrievals: json['recentRetrievals'] != null
          ? (json['recentRetrievals'] as List)
              .map((r) => RetrievalSummary.fromJson(r))
              .toList()
          : [],
      lastRetrievalDate: json['lastRetrievalDate'] != null 
          ? DateTime.parse(json['lastRetrievalDate']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientName': clientName,
      'clientIdNumber': clientIdNumber,
      'clientContact': clientContact,
      'totalRetrievals': totalRetrievals,
      'pendingRetrievals': pendingRetrievals,
      'approvedRetrievals': approvedRetrievals,
      'completedRetrievals': completedRetrievals,
      'recentRetrievals': recentRetrievals.map((r) => r.toJson()).toList(),
      if (lastRetrievalDate != null) 'lastRetrievalDate': lastRetrievalDate!.toIso8601String(),
    };
  }
}

/// Generic API response wrapper
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? totalRecords;
  final int? currentPage;
  final int? totalPages;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.totalRecords,
    this.currentPage,
    this.totalPages,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null && fromJsonT != null 
          ? fromJsonT(json['data']) 
          : json['data'],
      totalRecords: json['totalRecords'],
      currentPage: json['currentPage'],
      totalPages: json['totalPages'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (data != null) 'data': data,
      if (totalRecords != null) 'totalRecords': totalRecords,
      if (currentPage != null) 'currentPage': currentPage,
      if (totalPages != null) 'totalPages': totalPages,
    };
  }
}