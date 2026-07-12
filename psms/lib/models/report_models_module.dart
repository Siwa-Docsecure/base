// report_models.dart

// ============================================
// SHARED MINI-MODELS (embedded in report rows)
// ============================================

class ReportClient {
  final int clientId;
  final String clientName;
  final String clientCode;

  ReportClient({
    required this.clientId,
    required this.clientName,
    required this.clientCode,
  });

  factory ReportClient.fromJson(Map<String, dynamic> json) => ReportClient(
        clientId:   json['clientId']   as int,
        clientName: json['clientName'] as String,
        clientCode: json['clientCode'] as String,
      );
}

// ============================================
// BOX REPORT
// ============================================

class ReportBoxItem {
  final int boxId;
  final String boxNumber;
  final String? description;
  final String boxSize;
  final String? dataYears;
  final String? dateRange;
  final String? boxImage;
  final String? dateReceived;
  final int? yearReceived;
  final int? retentionYears;
  final int? destructionYear;
  final String status;
  final bool isPendingDestruction;
  final String? rackLabel;
  final String? rackLocation;
  final ReportClient client;

  ReportBoxItem({
    required this.boxId,
    required this.boxNumber,
    this.description,
    required this.boxSize,
    this.dataYears,
    this.dateRange,
    this.boxImage,
    this.dateReceived,
    this.yearReceived,
    this.retentionYears,
    this.destructionYear,
    required this.status,
    required this.isPendingDestruction,
    this.rackLabel,
    this.rackLocation,
    required this.client,
  });

  factory ReportBoxItem.fromJson(Map<String, dynamic> json) => ReportBoxItem(
        boxId:               json['boxId']               as int,
        boxNumber:           json['boxNumber']           as String,
        description:         json['description']         as String?,
        boxSize:             json['boxSize']             as String? ?? 'A3',
        dataYears:           json['dataYears']           as String?,
        dateRange:           json['dateRange']           as String?,
        boxImage:            json['boxImage']            as String?,
        dateReceived:        json['dateReceived']        as String?,
        yearReceived:        json['yearReceived']        as int?,
        retentionYears:      json['retentionYears']      as int?,
        destructionYear:     json['destructionYear']     as int?,
        status:              json['status']              as String,
        isPendingDestruction: json['isPendingDestruction'] as bool? ?? false,
        rackLabel:           json['rackLabel']           as String?,
        rackLocation:        json['rackLocation']        as String?,
        client:              ReportClient.fromJson(json['client'] as Map<String, dynamic>),
      );
}

class BoxReportSummary {
  final int totalBoxes;
  final int uniqueClients;
  final int stored;
  final int retrieved;
  final int destroyed;
  final int pendingDestruction;

  BoxReportSummary({
    required this.totalBoxes,
    required this.uniqueClients,
    required this.stored,
    required this.retrieved,
    required this.destroyed,
    required this.pendingDestruction,
  });

  factory BoxReportSummary.fromJson(Map<String, dynamic> json) {
    final statusCounts = json['statusCounts'] as Map<String, dynamic>? ?? {};
    return BoxReportSummary(
      totalBoxes:         json['totalBoxes']         as int? ?? 0,
      uniqueClients:      json['uniqueClients']      as int? ?? 0,
      stored:             statusCounts['stored']     as int? ?? 0,
      retrieved:          statusCounts['retrieved']  as int? ?? 0,
      destroyed:          statusCounts['destroyed']  as int? ?? 0,
      pendingDestruction: json['pendingDestruction'] as int? ?? 0,
    );
  }
}

/// Flat (ungrouped) box report
class BoxReportData {
  final List<ReportBoxItem> boxes;
  final BoxReportSummary? summary;

  BoxReportData({required this.boxes, this.summary});

  factory BoxReportData.fromJson(Map<String, dynamic> json) => BoxReportData(
        boxes:   (json['boxes'] as List<dynamic>)
            .map((e) => ReportBoxItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: json['summary'] != null
            ? BoxReportSummary.fromJson(json['summary'] as Map<String, dynamic>)
            : null,
      );
}

/// Client entry inside a grouped box report
class BoxReportClientGroup {
  final int clientId;
  final String clientName;
  final String clientCode;
  final List<ReportBoxItem> boxes;
  final BoxReportSummary summary;

  BoxReportClientGroup({
    required this.clientId,
    required this.clientName,
    required this.clientCode,
    required this.boxes,
    required this.summary,
  });

  factory BoxReportClientGroup.fromJson(Map<String, dynamic> json) =>
      BoxReportClientGroup(
        clientId:   json['clientId']   as int,
        clientName: json['clientName'] as String,
        clientCode: json['clientCode'] as String,
        boxes: (json['boxes'] as List<dynamic>)
            .map((e) => ReportBoxItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: BoxReportSummary.fromJson(json['summary'] as Map<String, dynamic>),
      );
}

/// Grouped box report
class GroupedBoxReportData {
  final List<BoxReportClientGroup> clients;
  final BoxReportSummary? summary;

  GroupedBoxReportData({required this.clients, this.summary});

  factory GroupedBoxReportData.fromJson(Map<String, dynamic> json) =>
      GroupedBoxReportData(
        clients: (json['clients'] as List<dynamic>)
            .map((e) => BoxReportClientGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: json['summary'] != null
            ? BoxReportSummary.fromJson(json['summary'] as Map<String, dynamic>)
            : null,
      );
}

// ============================================
// COLLECTIONS REPORT
// ============================================

class ReportCollectionItem {
  final int collectionId;
  final int totalBoxes;
  final String? boxDescription;
  final String dispatcherName;
  final String collectorName;
  final String collectionDate;
  final String? pdfPath;
  final String createdAt;
  final String? createdBy;
  final ReportClient client;

  ReportCollectionItem({
    required this.collectionId,
    required this.totalBoxes,
    this.boxDescription,
    required this.dispatcherName,
    required this.collectorName,
    required this.collectionDate,
    this.pdfPath,
    required this.createdAt,
    this.createdBy,
    required this.client,
  });

  factory ReportCollectionItem.fromJson(Map<String, dynamic> json) =>
      ReportCollectionItem(
        collectionId:    json['collectionId']    as int,
        totalBoxes:      json['totalBoxes']      as int,
        boxDescription:  json['boxDescription']  as String?,
        dispatcherName:  json['dispatcherName']  as String,
        collectorName:   json['collectorName']   as String,
        collectionDate:  json['collectionDate']  as String,
        pdfPath:         json['pdfPath']         as String?,
        createdAt:       json['createdAt']       as String,
        createdBy:       json['createdBy']       as String?,
        client:          ReportClient.fromJson(json['client'] as Map<String, dynamic>),
      );
}

class CollectionReportSummary {
  final int totalCollections;
  final int totalBoxesCollected;
  final int uniqueClients;

  CollectionReportSummary({
    required this.totalCollections,
    required this.totalBoxesCollected,
    required this.uniqueClients,
  });

  factory CollectionReportSummary.fromJson(Map<String, dynamic> json) =>
      CollectionReportSummary(
        totalCollections:    json['totalCollections']    as int? ?? 0,
        totalBoxesCollected: json['totalBoxesCollected'] as int? ?? 0,
        uniqueClients:       json['uniqueClients']       as int? ?? 0,
      );
}

class CollectionReportData {
  final List<ReportCollectionItem> collections;
  final CollectionReportSummary? summary;

  CollectionReportData({required this.collections, this.summary});

  factory CollectionReportData.fromJson(Map<String, dynamic> json) =>
      CollectionReportData(
        collections: (json['collections'] as List<dynamic>)
            .map((e) => ReportCollectionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: json['summary'] != null
            ? CollectionReportSummary.fromJson(json['summary'] as Map<String, dynamic>)
            : null,
      );
}

// ============================================
// RETRIEVALS REPORT
// ============================================

class ReportRetrievalBox {
  final int boxId;
  final String boxNumber;
  final String? boxDescription;
  final String? currentStatus;

  ReportRetrievalBox({
    required this.boxId,
    required this.boxNumber,
    this.boxDescription,
    this.currentStatus,
  });

  factory ReportRetrievalBox.fromJson(Map<String, dynamic> json) =>
      ReportRetrievalBox(
        boxId:          json['boxId']          as int,
        boxNumber:      json['boxNumber']      as String,
        boxDescription: json['boxDescription'] as String?,
        currentStatus:  json['currentStatus']  as String?,
      );
}

class ReportRetrievalSignatures {
  final bool clientSigned;
  final bool staffSigned;

  ReportRetrievalSignatures({required this.clientSigned, required this.staffSigned});

  factory ReportRetrievalSignatures.fromJson(Map<String, dynamic> json) =>
      ReportRetrievalSignatures(
        clientSigned: json['clientSigned'] as bool? ?? false,
        staffSigned:  json['staffSigned']  as bool? ?? false,
      );
}

class ReportRetrievalItem {
  final int retrievalId;
  final String retrievalDate;
  final String? retrievedBy;
  final String? reason;
  final String status;
  final String? pdfPath;
  final String createdAt;
  final String? createdBy;
  final ReportRetrievalSignatures signatures;
  final ReportRetrievalBox box;
  final ReportClient client;

  ReportRetrievalItem({
    required this.retrievalId,
    required this.retrievalDate,
    this.retrievedBy,
    this.reason,
    required this.status,
    this.pdfPath,
    required this.createdAt,
    this.createdBy,
    required this.signatures,
    required this.box,
    required this.client,
  });

  factory ReportRetrievalItem.fromJson(Map<String, dynamic> json) =>
      ReportRetrievalItem(
        retrievalId:   json['retrievalId']   as int,
        retrievalDate: json['retrievalDate'] as String,
        retrievedBy:   json['retrievedBy']   as String?,
        reason:        json['reason']        as String?,
        status:        json['status']        as String,
        pdfPath:       json['pdfPath']       as String?,
        createdAt:     json['createdAt']     as String,
        createdBy:     json['createdBy']     as String?,
        signatures:    ReportRetrievalSignatures.fromJson(json['signatures'] as Map<String, dynamic>),
        box:           ReportRetrievalBox.fromJson(json['box'] as Map<String, dynamic>),
        client:        ReportClient.fromJson(json['client'] as Map<String, dynamic>),
      );
}

class RetrievalReportSummary {
  final int totalRetrievals;
  final int uniqueClients;
  final int uniqueBoxes;
  final int pending;
  final int completed;
  final int retrieved;

  RetrievalReportSummary({
    required this.totalRetrievals,
    required this.uniqueClients,
    required this.uniqueBoxes,
    required this.pending,
    required this.completed,
    required this.retrieved,
  });

  factory RetrievalReportSummary.fromJson(Map<String, dynamic> json) {
    final sc = json['statusCounts'] as Map<String, dynamic>? ?? {};
    return RetrievalReportSummary(
      totalRetrievals: json['totalRetrievals'] as int? ?? 0,
      uniqueClients:   json['uniqueClients']   as int? ?? 0,
      uniqueBoxes:     json['uniqueBoxes']     as int? ?? 0,
      pending:         sc['pending']           as int? ?? 0,
      completed:       sc['completed']         as int? ?? 0,
      retrieved:       sc['retrieved']         as int? ?? 0,
    );
  }
}

class RetrievalReportData {
  final List<ReportRetrievalItem> retrievals;
  final RetrievalReportSummary? summary;

  RetrievalReportData({required this.retrievals, this.summary});

  factory RetrievalReportData.fromJson(Map<String, dynamic> json) =>
      RetrievalReportData(
        retrievals: (json['retrievals'] as List<dynamic>)
            .map((e) => ReportRetrievalItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: json['summary'] != null
            ? RetrievalReportSummary.fromJson(json['summary'] as Map<String, dynamic>)
            : null,
      );
}

// ============================================
// DELIVERIES REPORT
// ============================================

class ReportDeliveryItem {
  final int deliveryId;
  final String itemName;
  final int quantity;
  final String deliveryDate;
  final String receiverName;
  final String? acknowledgementStatement;
  final String? pdfPath;
  final String createdAt;
  final String? createdBy;
  final bool receiverSigned;
  final ReportClient client;

  ReportDeliveryItem({
    required this.deliveryId,
    required this.itemName,
    required this.quantity,
    required this.deliveryDate,
    required this.receiverName,
    this.acknowledgementStatement,
    this.pdfPath,
    required this.createdAt,
    this.createdBy,
    required this.receiverSigned,
    required this.client,
  });

  factory ReportDeliveryItem.fromJson(Map<String, dynamic> json) =>
      ReportDeliveryItem(
        deliveryId:               json['deliveryId']               as int,
        itemName:                 json['itemName']                 as String,
        quantity:                 json['quantity']                 as int,
        deliveryDate:             json['deliveryDate']             as String,
        receiverName:             json['receiverName']             as String,
        acknowledgementStatement: json['acknowledgementStatement'] as String?,
        pdfPath:                  json['pdfPath']                  as String?,
        createdAt:                json['createdAt']                as String,
        createdBy:                json['createdBy']                as String?,
        receiverSigned:           json['receiverSigned']           as bool? ?? false,
        client:                   ReportClient.fromJson(json['client'] as Map<String, dynamic>),
      );
}

class DeliveryReportSummary {
  final int totalDeliveries;
  final int totalQuantity;
  final int uniqueClients;

  DeliveryReportSummary({
    required this.totalDeliveries,
    required this.totalQuantity,
    required this.uniqueClients,
  });

  factory DeliveryReportSummary.fromJson(Map<String, dynamic> json) =>
      DeliveryReportSummary(
        totalDeliveries: json['totalDeliveries'] as int? ?? 0,
        totalQuantity:   json['totalQuantity']   as int? ?? 0,
        uniqueClients:   json['uniqueClients']   as int? ?? 0,
      );
}

class DeliveryReportData {
  final List<ReportDeliveryItem> deliveries;
  final DeliveryReportSummary? summary;

  DeliveryReportData({required this.deliveries, this.summary});

  factory DeliveryReportData.fromJson(Map<String, dynamic> json) =>
      DeliveryReportData(
        deliveries: (json['deliveries'] as List<dynamic>)
            .map((e) => ReportDeliveryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: json['summary'] != null
            ? DeliveryReportSummary.fromJson(json['summary'] as Map<String, dynamic>)
            : null,
      );
}

// ============================================
// REQUESTS REPORT
// ============================================

class ReportRequestItem {
  final int requestId;
  final String requestType;
  final String? details;
  final String status;
  final String requestedDate;
  final String? completedDate;
  final String createdAt;
  final String? boxNumber;
  final ReportClient client;

  ReportRequestItem({
    required this.requestId,
    required this.requestType,
    this.details,
    required this.status,
    required this.requestedDate,
    this.completedDate,
    required this.createdAt,
    this.boxNumber,
    required this.client,
  });

  factory ReportRequestItem.fromJson(Map<String, dynamic> json) =>
      ReportRequestItem(
        requestId:     json['requestId']     as int,
        requestType:   json['requestType']   as String,
        details:       json['details']       as String?,
        status:        json['status']        as String,
        requestedDate: json['requestedDate'] as String,
        completedDate: json['completedDate'] as String?,
        createdAt:     json['createdAt']     as String,
        boxNumber:     json['boxNumber']     as String?,
        client:        ReportClient.fromJson(json['client'] as Map<String, dynamic>),
      );
}

class RequestReportSummary {
  final int totalRequests;
  final int uniqueClients;
  final Map<String, int> byStatus;
  final Map<String, int> byType;

  RequestReportSummary({
    required this.totalRequests,
    required this.uniqueClients,
    required this.byStatus,
    required this.byType,
  });

  factory RequestReportSummary.fromJson(Map<String, dynamic> json) =>
      RequestReportSummary(
        totalRequests: json['totalRequests'] as int? ?? 0,
        uniqueClients: json['uniqueClients'] as int? ?? 0,
        byStatus: (json['byStatus'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as int)),
        byType: (json['byType'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as int)),
      );
}

class RequestReportData {
  final List<ReportRequestItem> requests;
  final RequestReportSummary? summary;

  RequestReportData({required this.requests, this.summary});

  factory RequestReportData.fromJson(Map<String, dynamic> json) =>
      RequestReportData(
        requests: (json['requests'] as List<dynamic>)
            .map((e) => ReportRequestItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: json['summary'] != null
            ? RequestReportSummary.fromJson(json['summary'] as Map<String, dynamic>)
            : null,
      );
}

// ============================================
// PENDING DESTRUCTION REPORT
// ============================================

class PendingDestructionItem {
  final int boxId;
  final String boxNumber;
  final String? description;
  final String boxSize;
  final String? dataYears;
  final String? dateRange;
  final int? yearReceived;
  final int? retentionYears;
  final int? destructionYear;
  final int? yearsOverdue;
  final String? rackLabel;
  final String? rackLocation;
  final ReportClient client;

  PendingDestructionItem({
    required this.boxId,
    required this.boxNumber,
    this.description,
    required this.boxSize,
    this.dataYears,
    this.dateRange,
    this.yearReceived,
    this.retentionYears,
    this.destructionYear,
    this.yearsOverdue,
    this.rackLabel,
    this.rackLocation,
    required this.client,
  });

  factory PendingDestructionItem.fromJson(Map<String, dynamic> json) =>
      PendingDestructionItem(
        boxId:           json['boxId']           as int,
        boxNumber:       json['boxNumber']       as String,
        description:     json['description']     as String?,
        boxSize:         json['boxSize']         as String? ?? 'A3',
        dataYears:       json['dataYears']       as String?,
        dateRange:       json['dateRange']       as String?,
        yearReceived:    json['yearReceived']    as int?,
        retentionYears:  json['retentionYears']  as int?,
        destructionYear: json['destructionYear'] as int?,
        yearsOverdue:    json['yearsOverdue']    as int?,
        rackLabel:       json['rackLabel']       as String?,
        rackLocation:    json['rackLocation']    as String?,
        client:          ReportClient.fromJson(json['client'] as Map<String, dynamic>),
      );
}

class PendingDestructionData {
  final int count;
  final List<PendingDestructionItem> boxes;

  PendingDestructionData({required this.count, required this.boxes});

  factory PendingDestructionData.fromJson(Map<String, dynamic> json) =>
      PendingDestructionData(
        count: json['count'] as int? ?? 0,
        boxes: (json['boxes'] as List<dynamic>)
            .map((e) => PendingDestructionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ============================================
// STORAGE UTILISATION REPORT
// ============================================

class RackUtilisationItem {
  final int labelId;
  final String labelCode;
  final String location;
  final bool isAvailable;
  final int boxesStored;

  RackUtilisationItem({
    required this.labelId,
    required this.labelCode,
    required this.location,
    required this.isAvailable,
    required this.boxesStored,
  });

  factory RackUtilisationItem.fromJson(Map<String, dynamic> json) =>
      RackUtilisationItem(
        labelId:     json['labelId']     as int,
        labelCode:   json['labelCode']   as String,
        location:    json['location']    as String,
        isAvailable: json['isAvailable'] as bool? ?? false,
        boxesStored: json['boxesStored'] as int? ?? 0,
      );
}

class StorageUtilisationSummary {
  final int totalRacks;
  final int occupiedRacks;
  final int availableRacks;

  StorageUtilisationSummary({
    required this.totalRacks,
    required this.occupiedRacks,
    required this.availableRacks,
  });

  factory StorageUtilisationSummary.fromJson(Map<String, dynamic> json) =>
      StorageUtilisationSummary(
        totalRacks:     json['totalRacks']     as int? ?? 0,
        occupiedRacks:  json['occupiedRacks']  as int? ?? 0,
        availableRacks: json['availableRacks'] as int? ?? 0,
      );
}

class StorageUtilisationData {
  final StorageUtilisationSummary summary;
  final List<RackUtilisationItem> racks;

  StorageUtilisationData({required this.summary, required this.racks});

  factory StorageUtilisationData.fromJson(Map<String, dynamic> json) =>
      StorageUtilisationData(
        summary: StorageUtilisationSummary.fromJson(json['summary'] as Map<String, dynamic>),
        racks: (json['racks'] as List<dynamic>)
            .map((e) => RackUtilisationItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ============================================
// CLIENT ACTIVITY REPORT
// ============================================

class ClientActivityClient {
  final int clientId;
  final String clientName;
  final String clientCode;
  final String? contactPerson;
  final String? email;
  final String? phone;

  ClientActivityClient({
    required this.clientId,
    required this.clientName,
    required this.clientCode,
    this.contactPerson,
    this.email,
    this.phone,
  });

  factory ClientActivityClient.fromJson(Map<String, dynamic> json) =>
      ClientActivityClient(
        clientId:      json['clientId']      as int,
        clientName:    json['clientName']    as String,
        clientCode:    json['clientCode']    as String,
        contactPerson: json['contactPerson'] as String?,
        email:         json['email']         as String?,
        phone:         json['phone']         as String?,
      );
}

class ClientBoxSummary {
  final int total;
  final int stored;
  final int retrieved;
  final int destroyed;
  final int pendingDestruction;

  ClientBoxSummary({
    required this.total,
    required this.stored,
    required this.retrieved,
    required this.destroyed,
    required this.pendingDestruction,
  });

  factory ClientBoxSummary.fromJson(Map<String, dynamic> json) =>
      ClientBoxSummary(
        total:              json['total']              as int? ?? 0,
        stored:             json['stored']             as int? ?? 0,
        retrieved:          json['retrieved']          as int? ?? 0,
        destroyed:          json['destroyed']          as int? ?? 0,
        pendingDestruction: json['pendingDestruction'] as int? ?? 0,
      );
}

class ClientActivityData {
  final ClientActivityClient client;
  final ClientBoxSummary boxSummary;
  final int totalCollections;
  final int totalRetrievals;
  final int totalDeliveries;
  final int totalRequests;

  ClientActivityData({
    required this.client,
    required this.boxSummary,
    required this.totalCollections,
    required this.totalRetrievals,
    required this.totalDeliveries,
    required this.totalRequests,
  });

  factory ClientActivityData.fromJson(Map<String, dynamic> json) {
    final boxes       = json['boxes']       as Map<String, dynamic>? ?? {};
    final collections = json['collections'] as Map<String, dynamic>? ?? {};
    final retrievals  = json['retrievals']  as Map<String, dynamic>? ?? {};
    final deliveries  = json['deliveries']  as Map<String, dynamic>? ?? {};
    final requests    = json['requests']    as Map<String, dynamic>? ?? {};

    return ClientActivityData(
      client:            ClientActivityClient.fromJson(json['client'] as Map<String, dynamic>),
      boxSummary:        ClientBoxSummary.fromJson(boxes['summary'] as Map<String, dynamic>? ?? {}),
      totalCollections:  collections['total'] as int? ?? 0,
      totalRetrievals:   retrievals['total']  as int? ?? 0,
      totalDeliveries:   deliveries['total']  as int? ?? 0,
      totalRequests:     requests['total']    as int? ?? 0,
    );
  }
}