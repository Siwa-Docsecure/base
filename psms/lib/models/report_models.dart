// Single report models
class BoxReportItem {
  final String boxNumber;
  final String boxSize;
  final String? description;
  final String? datesRange;
  final int? dataYears;
  final int? destructionYear;
  final String status;
  final String? rackLabel;
  final String? rackLocation;
  final ClientInfo client;

  BoxReportItem.fromJson(Map<String, dynamic> json)
      : boxNumber = json['boxNumber'],
        boxSize = json['boxSize'] ?? 'A3',
        description = json['description'],
        datesRange = json['datesRange'],
        dataYears = json['dataYears'],
        destructionYear = json['destructionYear'],
        status = json['status'],
        rackLabel = json['rackLabel'],
        rackLocation = json['rackLocation'],
        client = ClientInfo.fromJson(json['client']);
}

class ClientInfo {
  final int clientId;
  final String clientName;
  final String clientCode;

  ClientInfo.fromJson(Map<String, dynamic> json)
      : clientId = json['clientId'],
        clientName = json['clientName'],
        clientCode = json['clientCode'];
}

class BoxReportResponse {
  final DateTime generatedAt;
  final Map<String, dynamic> filters;
  final List<BoxReportItem> boxes;

  BoxReportResponse.fromJson(Map<String, dynamic> json)
      : generatedAt = DateTime.parse(json['generatedAt']),
        filters = json['filters'],
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
      : totalBoxes = json['totalBoxes'],
        stored = json['stored'],
        retrieved = json['retrieved'],
        destroyed = json['destroyed'],
        pendingDestruction = json['pendingDestruction'];
}

class ClientReportData {
  final int clientId;
  final String clientName;
  final String clientCode;
  final List<BoxReportItem> boxes;
  final ClientReportSummary summary;

  ClientReportData.fromJson(Map<String, dynamic> json)
      : clientId = json['clientId'],
        clientName = json['clientName'],
        clientCode = json['clientCode'],
        boxes = (json['boxes'] as List)
            .map((item) => BoxReportItem.fromJson(item))
            .toList(),
        summary = ClientReportSummary.fromJson(json['summary']);
}

class BulkBoxReportResponse {
  final DateTime generatedAt;
  final Map<String, dynamic> filters;
  final Map<String, int> summary;
  final List<ClientReportData> clients;

  BulkBoxReportResponse.fromJson(Map<String, dynamic> json)
      : generatedAt = DateTime.parse(json['generatedAt']),
        filters = json['filters'],
        summary = Map<String, int>.from(json['summary']),
        clients = (json['clients'] as List)
            .map((item) => ClientReportData.fromJson(item))
            .toList();
}