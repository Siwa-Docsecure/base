// delivery_model.dart

// ============================================
// EMBEDDED MODELS
// ============================================

class DeliveryClientInfo {
  final int clientId;
  final String clientName;
  final String clientCode;
  final String? contactPerson;
  final String? email;
  final String? phone;

  const DeliveryClientInfo({
    required this.clientId,
    required this.clientName,
    required this.clientCode,
    this.contactPerson,
    this.email,
    this.phone,
  });

  factory DeliveryClientInfo.fromJson(Map<String, dynamic> json) {
    return DeliveryClientInfo(
      clientId: json['clientId'] as int? ?? 0,
      clientName: json['clientName'] as String? ?? '',
      clientCode: json['clientCode'] as String? ?? '',
      contactPerson: json['contactPerson'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'clientName': clientName,
        'clientCode': clientCode,
        if (contactPerson != null) 'contactPerson': contactPerson,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
      };
}

class DeliveryCreatedBy {
  final int userId;
  final String username;
  final String? email;

  const DeliveryCreatedBy({
    required this.userId,
    required this.username,
    this.email,
  });

  factory DeliveryCreatedBy.fromJson(Map<String, dynamic> json) {
    return DeliveryCreatedBy(
      userId: json['userId'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

// ============================================
// MAIN DELIVERY MODEL
// GET /api/deliveries  &  GET /api/deliveries/:deliveryId
// ============================================

class DeliveryModel {
  final int deliveryId;
  final DeliveryClientInfo client;
  final String itemName;
  final int quantity;
  final DateTime deliveryDate;
  final String receiverName;
  final String? receiverSignature;
  final String? acknowledgementStatement;
  final String? pdfPath;
  final DeliveryCreatedBy createdBy;
  final DateTime createdAt;

  const DeliveryModel({
    required this.deliveryId,
    required this.client,
    required this.itemName,
    required this.quantity,
    required this.deliveryDate,
    required this.receiverName,
    this.receiverSignature,
    this.acknowledgementStatement,
    this.pdfPath,
    required this.createdBy,
    required this.createdAt,
  });

  bool get hasSignature =>
      receiverSignature != null && receiverSignature!.isNotEmpty;
  bool get hasPdf => pdfPath != null && pdfPath!.isNotEmpty;

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    return DeliveryModel(
      deliveryId: json['deliveryId'] as int? ?? 0,
      client: DeliveryClientInfo.fromJson(
        json['client'] as Map<String, dynamic>? ?? {},
      ),
      itemName: json['itemName'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      deliveryDate: _parseDate(json['deliveryDate']),
      receiverName: json['receiverName'] as String? ?? '',
      receiverSignature: json['receiverSignature'] as String?,
      acknowledgementStatement: json['acknowledgementStatement'] as String?,
      pdfPath: json['pdfPath'] as String?,
      createdBy: DeliveryCreatedBy.fromJson(
        json['createdBy'] as Map<String, dynamic>? ?? {},
      ),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}

// ============================================
// PAGINATION & LIST RESPONSE
// ============================================

class DeliveryPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const DeliveryPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory DeliveryPagination.fromJson(Map<String, dynamic> json) {
    return DeliveryPagination(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class DeliveriesData {
  final List<DeliveryModel> deliveries;
  final DeliveryPagination? pagination;

  const DeliveriesData({required this.deliveries, this.pagination});

  factory DeliveriesData.fromJson(Map<String, dynamic> json) {
    final rawList = json['deliveries'] as List<dynamic>? ?? [];
    return DeliveriesData(
      deliveries: rawList
          .map((e) => DeliveryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: json['pagination'] != null
          ? DeliveryPagination.fromJson(
              json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DeliveriesResponse {
  final String status;
  final String message;
  final DeliveriesData? data;

  const DeliveriesResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory DeliveriesResponse.fromJson(Map<String, dynamic> json) {
    return DeliveriesResponse(
      status: json['status'] as String? ?? '',
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? DeliveriesData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ============================================
// STATISTICS
// GET /api/deliveries/stats
// ============================================

class DeliveryStats {
  final int totalDeliveries;
  final int totalItemsDelivered;
  final int clientsWithDeliveries;
  final int todayDeliveries;
  final int thisWeekDeliveries;
  final int thisMonthDeliveries;
  final int uniqueItems;

  const DeliveryStats({
    required this.totalDeliveries,
    required this.totalItemsDelivered,
    required this.clientsWithDeliveries,
    required this.todayDeliveries,
    required this.thisWeekDeliveries,
    required this.thisMonthDeliveries,
    required this.uniqueItems,
  });

  factory DeliveryStats.fromJson(Map<String, dynamic> json) {
    return DeliveryStats(
      totalDeliveries: _toInt(json['total_deliveries']),
      totalItemsDelivered: _toInt(json['total_items_delivered']),
      clientsWithDeliveries: _toInt(json['clients_with_deliveries']),
      todayDeliveries: _toInt(json['today_deliveries']),
      thisWeekDeliveries: _toInt(json['this_week_deliveries']),
      thisMonthDeliveries: _toInt(json['this_month_deliveries']),
      uniqueItems: _toInt(json['unique_items']),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ============================================
// RECENT DELIVERIES
// GET /api/deliveries/recent
// ============================================

class RecentDelivery {
  final int deliveryId;
  final String clientName;
  final String clientCode;
  final String itemName;
  final int quantity;
  final DateTime deliveryDate;
  final String createdBy;

  const RecentDelivery({
    required this.deliveryId,
    required this.clientName,
    required this.clientCode,
    required this.itemName,
    required this.quantity,
    required this.deliveryDate,
    required this.createdBy,
  });

  factory RecentDelivery.fromJson(Map<String, dynamic> json) {
    return RecentDelivery(
      deliveryId: json['deliveryId'] as int? ?? 0,
      clientName: json['clientName'] as String? ?? '',
      clientCode: json['clientCode'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      deliveryDate: DeliveryModel._parseDate(json['deliveryDate']),
      createdBy: json['createdBy'] as String? ?? '',
    );
  }
}

// ============================================
// CLIENT DELIVERIES
// GET /api/deliveries/client/:clientId
// ============================================

class ClientDeliveriesData {
  final int clientId;
  final int count;
  final List<DeliveryModel> deliveries;

  const ClientDeliveriesData({
    required this.clientId,
    required this.count,
    required this.deliveries,
  });

  factory ClientDeliveriesData.fromJson(Map<String, dynamic> json) {
    final rawList = json['deliveries'] as List<dynamic>? ?? [];
    return ClientDeliveriesData(
      clientId: json['clientId'] as int? ?? 0,
      count: json['count'] as int? ?? 0,
      deliveries: rawList
          .map((e) => DeliveryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ============================================
// REPORT MODELS
// GET /api/deliveries/reports/summary
// GET /api/deliveries/reports/by-client
// GET /api/deliveries/reports/by-item
// ============================================

class DeliverySummaryReport {
  final String date;
  final int deliveryCount;
  final int totalItems;
  final int uniqueClients;
  final int uniqueItems;

  const DeliverySummaryReport({
    required this.date,
    required this.deliveryCount,
    required this.totalItems,
    required this.uniqueClients,
    required this.uniqueItems,
  });

  factory DeliverySummaryReport.fromJson(Map<String, dynamic> json) {
    return DeliverySummaryReport(
      date: json['date'] as String? ?? '',
      deliveryCount: DeliveryStats._toInt(json['delivery_count']),
      totalItems: DeliveryStats._toInt(json['total_items']),
      uniqueClients: DeliveryStats._toInt(json['unique_clients']),
      uniqueItems: DeliveryStats._toInt(json['unique_items']),
    );
  }
}

class DeliveryByClientReport {
  final int clientId;
  final String clientName;
  final String clientCode;
  final int deliveryCount;
  final int totalItemsDelivered;
  final DateTime? lastDeliveryDate;

  const DeliveryByClientReport({
    required this.clientId,
    required this.clientName,
    required this.clientCode,
    required this.deliveryCount,
    required this.totalItemsDelivered,
    this.lastDeliveryDate,
  });

  factory DeliveryByClientReport.fromJson(Map<String, dynamic> json) {
    return DeliveryByClientReport(
      clientId: DeliveryStats._toInt(json['client_id']),
      clientName: json['client_name'] as String? ?? '',
      clientCode: json['client_code'] as String? ?? '',
      deliveryCount: DeliveryStats._toInt(json['delivery_count']),
      totalItemsDelivered: DeliveryStats._toInt(json['total_items_delivered']),
      lastDeliveryDate: json['last_delivery_date'] != null
          ? DateTime.tryParse(json['last_delivery_date'].toString())
          : null,
    );
  }
}

class DeliveryByItemReport {
  final String itemName;
  final int deliveryCount;
  final int totalQuantity;
  final int clientsCount;
  final DateTime? lastDelivered;

  const DeliveryByItemReport({
    required this.itemName,
    required this.deliveryCount,
    required this.totalQuantity,
    required this.clientsCount,
    this.lastDelivered,
  });

  factory DeliveryByItemReport.fromJson(Map<String, dynamic> json) {
    return DeliveryByItemReport(
      itemName: json['item_name'] as String? ?? '',
      deliveryCount: DeliveryStats._toInt(json['delivery_count']),
      totalQuantity: DeliveryStats._toInt(json['total_quantity']),
      clientsCount: DeliveryStats._toInt(json['clients_count']),
      lastDelivered: json['last_delivered'] != null
          ? DateTime.tryParse(json['last_delivered'].toString())
          : null,
    );
  }
}

// ============================================
// REQUEST MODELS
// POST /api/deliveries
// PUT  /api/deliveries/:deliveryId
// ============================================

class CreateDeliveryRequest {
  final int clientId;
  final String itemName;
  final int quantity;
  final String deliveryDate; // ISO date string yyyy-MM-dd
  final String receiverName;
  final String? receiverSignature;
  final String? acknowledgementStatement;

  const CreateDeliveryRequest({
    required this.clientId,
    required this.itemName,
    required this.quantity,
    required this.deliveryDate,
    required this.receiverName,
    this.receiverSignature,
    this.acknowledgementStatement,
  });

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'itemName': itemName,
        'quantity': quantity,
        'deliveryDate': deliveryDate,
        'receiverName': receiverName,
        if (receiverSignature != null && receiverSignature!.isNotEmpty)
          'receiverSignature': receiverSignature,
        if (acknowledgementStatement != null &&
            acknowledgementStatement!.isNotEmpty)
          'acknowledgementStatement': acknowledgementStatement,
      };
}

class UpdateDeliveryRequest {
  final String? itemName;
  final int? quantity;
  final String? deliveryDate;
  final String? receiverName;
  final String? acknowledgementStatement;

  const UpdateDeliveryRequest({
    this.itemName,
    this.quantity,
    this.deliveryDate,
    this.receiverName,
    this.acknowledgementStatement,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (itemName != null) map['itemName'] = itemName;
    if (quantity != null) map['quantity'] = quantity;
    if (deliveryDate != null) map['deliveryDate'] = deliveryDate;
    if (receiverName != null) map['receiverName'] = receiverName;
    if (acknowledgementStatement != null)
      map['acknowledgementStatement'] = acknowledgementStatement;
    return map;
  }
}
