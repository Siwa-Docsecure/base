// report_models.dart

// Single report models
class BoxReportItem {
  final String boxNumber;
  final String? boxSize;
  final String? description;
  final String? dataYears;
  final String? dateRange;
  final String? boxImage;
  final DateTime? dateReceived;
  final int? yearReceived;
  final int? retentionYears;
  final int? destructionYear;
  final String status;
  final String? rackLabel;
  final String? rackLocation;
  final ClientInfo client;

  BoxReportItem.fromJson(Map<String, dynamic> json)
      : boxNumber = json['boxNumber'] ?? json['box_number'] ?? '',
        boxSize = json['boxSize'] ?? json['box_size'],
        description = json['description'] ?? json['box_description'],
        dataYears = json['dataYears'] ?? json['data_years'],
        dateRange = json['dateRange'] ?? json['date_range'],
        boxImage = json['boxImage'] ?? json['box_image'],
        dateReceived = json['dateReceived'] != null
            ? DateTime.parse(json['dateReceived'])
            : json['date_received'] != null
                ? DateTime.parse(json['date_received'])
                : null,
        yearReceived = json['yearReceived'] ?? json['year_received'],
        retentionYears = json['retentionYears'] ?? json['retention_years'],
        destructionYear = json['destructionYear'] ?? json['destruction_year'],
        status = json['status'] ?? 'stored',
        rackLabel = json['rackLabel'] ?? json['rack_label'],
        rackLocation = json['rackLocation'] ?? json['rack_location'],
        client = ClientInfo.fromJson(json['client'] ?? {});
}

class ClientInfo {
  final int clientId;
  final String clientName;
  final String clientCode;

  ClientInfo.fromJson(Map<String, dynamic> json)
      : clientId = json['clientId'] ?? json['client_id'] ?? 0,
        clientName = json['clientName'] ?? json['client_name'] ?? '',
        clientCode = json['clientCode'] ?? json['client_code'] ?? '';
}

class BoxReportSummary {
  final int totalBoxes;
  final Map<String, int> statusCounts; // stored, retrieved, destroyed
  final int pendingDestruction;
  final int uniqueClients;

  BoxReportSummary.fromJson(Map<String, dynamic> json)
      : totalBoxes = json['totalBoxes'] ?? 0,
        statusCounts = Map<String, int>.from(json['statusCounts'] ?? {}),
        pendingDestruction = json['pendingDestruction'] ?? 0,
        uniqueClients = json['uniqueClients'] ?? 0;
}

class BoxReportResponse {
  final DateTime generatedAt;
  final Map<String, dynamic> filters;
  final BoxReportSummary? summary;
  final List<BoxReportItem> boxes;

  BoxReportResponse.fromJson(Map<String, dynamic> json)
      : generatedAt = DateTime.parse(json['generatedAt']),
        filters = json['filters'] ?? {},
        summary = json['summary'] != null
            ? BoxReportSummary.fromJson(json['summary'])
            : null,
        boxes = (json['boxes'] as List)
            .map((item) => BoxReportItem.fromJson(item))
            .toList();
}

// Bulk report models
class ClientReportSummary {
  final int totalBoxes;
  final int stored;
  final int retrieved;
  final int destroyed;
  final int pendingDestruction;

  ClientReportSummary.fromJson(Map<String, dynamic> json)
      : totalBoxes = json['totalBoxes'] ?? 0,
        stored = json['stored'] ?? 0,
        retrieved = json['retrieved'] ?? 0,
        destroyed = json['destroyed'] ?? 0,
        pendingDestruction = json['pendingDestruction'] ?? 0;
}

class ClientReportData {
  final int clientId;
  final String clientName;
  final String clientCode;
  final List<BoxReportItem> boxes;
  final ClientReportSummary summary;

  ClientReportData.fromJson(Map<String, dynamic> json)
      : clientId = json['clientId'] ?? 0,
        clientName = json['clientName'] ?? '',
        clientCode = json['clientCode'] ?? '',
        boxes = (json['boxes'] as List)
            .map((item) => BoxReportItem.fromJson(item))
            .toList(),
        summary = ClientReportSummary.fromJson(json['summary'] ?? {});
}

class OverallSummary {
  final int totalBoxes;
  final int totalClients;
  final Map<String, int> statusCounts; // stored, retrieved, destroyed
  final int pendingDestruction;

  OverallSummary.fromJson(Map<String, dynamic> json)
      : totalBoxes = json['totalBoxes'] ?? 0,
        totalClients = json['totalClients'] ?? 0,
        statusCounts = Map<String, int>.from(json['statusCounts'] ?? {}),
        pendingDestruction = json['pendingDestruction'] ?? 0;
}

class BulkBoxReportResponse {
  final DateTime generatedAt;
  final Map<String, dynamic> filters;
  final OverallSummary? summary;
  final List<ClientReportData> clients;

  BulkBoxReportResponse.fromJson(Map<String, dynamic> json)
      : generatedAt = DateTime.parse(json['generatedAt']),
        filters = json['filters'] ?? {},
        summary = json['summary'] != null
            ? OverallSummary.fromJson(json['summary'])
            : null,
        clients = (json['clients'] as List)
            .map((item) => ClientReportData.fromJson(item))
            .toList();
}