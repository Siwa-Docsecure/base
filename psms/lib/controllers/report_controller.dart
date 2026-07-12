// report_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/models/report_models_module.dart';

class ReportController extends GetxController {
  static ReportController get instance => Get.find();

  // ============================================
  // REACTIVE STATE
  // ============================================

  // Box report
  final Rx<BoxReportData?> boxReport             = Rx<BoxReportData?>(null);
  final Rx<GroupedBoxReportData?> groupedBoxReport = Rx<GroupedBoxReportData?>(null);

  // Pending destruction
  final Rx<PendingDestructionData?> pendingDestruction = Rx<PendingDestructionData?>(null);

  // Collections report
  final Rx<CollectionReportData?> collectionReport = Rx<CollectionReportData?>(null);

  // Retrievals report
  final Rx<RetrievalReportData?> retrievalReport = Rx<RetrievalReportData?>(null);

  // Deliveries report
  final Rx<DeliveryReportData?> deliveryReport = Rx<DeliveryReportData?>(null);

  // Requests report
  final Rx<RequestReportData?> requestReport = Rx<RequestReportData?>(null);

  // Client activity
  final Rx<ClientActivityData?> clientActivity = Rx<ClientActivityData?>(null);

  // Storage utilisation
  final Rx<StorageUtilisationData?> storageUtilisation = Rx<StorageUtilisationData?>(null);

  // Shared state
  final RxBool isLoading      = false.obs;
  final RxString errorMessage = ''.obs;

  // ============================================
  // AUTH HEADERS
  // ============================================

  Map<String, String> getAuthHeaders() =>
      AuthController.instance.getAuthHeaders();

  // ============================================
  // HELPER — build query string from nullable params
  // ============================================

  Map<String, String> _buildParams(Map<String, dynamic> source) {
    final params = <String, String>{};
    for (final entry in source.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String  && value.isEmpty) continue;
      if (value is int     && value <= 0)    continue;
      if (value is List    && value.isEmpty) continue;
      if (value is bool) {
        if (value) params[entry.key] = 'true';
        continue;
      }
      if (value is List) {
        params[entry.key] = value.join(',');
        continue;
      }
      params[entry.key] = value.toString();
    }
    return params;
  }

  // ============================================
  // HELPER — standard GET with loading + error
  // ============================================

  Future<Map<String, dynamic>?> _get(String url,
      {Map<String, String>? queryParams}) async {
    if (isLoading.value) return null;
    isLoading.value  = true;
    errorMessage.value = '';

    try {
      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: getAuthHeaders());

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'success' && body['data'] != null) {
          return body['data'] as Map<String, dynamic>;
        }
        final msg = body['message'] as String? ?? 'Request failed';
        errorMessage.value = msg;
        Get.snackbar('Error', msg,
            backgroundColor: Colors.red, colorText: Colors.white);
      } else if (response.statusCode == 401) {
        await AuthController.instance.refreshAccessToken();
        return _get(url, queryParams: queryParams);
      } else {
        final body     = json.decode(response.body) as Map<String, dynamic>;
        final msg      = body['message'] as String? ?? 'HTTP ${response.statusCode}';
        errorMessage.value = msg;
        Get.snackbar('Error', msg,
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
    return null;
  }

  // ============================================
  // BOX REPORTS
  // ============================================

  /// Flat box report. Pass [grouped: true] for grouped-by-client variant.
  Future<void> getBoxReport({
    List<int>? clientIds,
    String? status,
    int? rackingLabelId,
    String? search,
    String? dateFrom,
    String? dateTo,
    int? destructionYearFrom,
    int? destructionYearTo,
    int? retentionYears,
    bool? pendingDestruction,
    bool grouped = false,
    bool includeStats = true,
  }) async {
    final params = _buildParams({
      'clientIds':           clientIds,
      'status':              status,
      'rackingLabelId':      rackingLabelId,
      'search':              search,
      'dateFrom':            dateFrom,
      'dateTo':              dateTo,
      'destructionYearFrom': destructionYearFrom,
      'destructionYearTo':   destructionYearTo,
      'retentionYears':      retentionYears,
      'pendingDestruction':  pendingDestruction,
      'grouped':             grouped ? 'true' : null,
      if (!includeStats) 'includeStats': 'false',
    });

    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.reportBoxes}',
      queryParams: params,
    );

    if (data == null) return;

    if (grouped) {
      groupedBoxReport.value = GroupedBoxReportData.fromJson(data);
    } else {
      boxReport.value = BoxReportData.fromJson(data);
    }
  }

  /// Pending destruction report.
  Future<void> getPendingDestructionReport({int? clientId}) async {
    final params = _buildParams({'clientId': clientId});

    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.reportBoxesPendingDestruction}',
      queryParams: params,
    );

    if (data != null) {
      pendingDestruction.value = PendingDestructionData.fromJson(data);
    }
  }

  // ============================================
  // COLLECTIONS REPORT
  // ============================================

  Future<void> getCollectionsReport({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    int? createdBy,
    bool includeStats = true,
  }) async {
    final params = _buildParams({
      'clientId':   clientId,
      'dateFrom':   dateFrom,
      'dateTo':     dateTo,
      'createdBy':  createdBy,
      if (!includeStats) 'includeStats': 'false',
    });

    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.reportCollections}',
      queryParams: params,
    );

    if (data != null) {
      collectionReport.value = CollectionReportData.fromJson(data);
    }
  }

  // ============================================
  // RETRIEVALS REPORT
  // ============================================

  Future<void> getRetrievalsReport({
    int? clientId,
    String? status,
    String? dateFrom,
    String? dateTo,
    int? boxId,
    bool includeStats = true,
  }) async {
    final params = _buildParams({
      'clientId':   clientId,
      'status':     status,
      'dateFrom':   dateFrom,
      'dateTo':     dateTo,
      'boxId':      boxId,
      if (!includeStats) 'includeStats': 'false',
    });

    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.reportRetrievals}',
      queryParams: params,
    );

    if (data != null) {
      retrievalReport.value = RetrievalReportData.fromJson(data);
    }
  }

  // ============================================
  // DELIVERIES REPORT
  // ============================================

  Future<void> getDeliveriesReport({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    String? itemName,
    bool includeStats = true,
  }) async {
    final params = _buildParams({
      'clientId': clientId,
      'dateFrom': dateFrom,
      'dateTo':   dateTo,
      'itemName': itemName,
      if (!includeStats) 'includeStats': 'false',
    });

    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.reportDeliveries}',
      queryParams: params,
    );

    if (data != null) {
      deliveryReport.value = DeliveryReportData.fromJson(data);
    }
  }

  // ============================================
  // REQUESTS REPORT
  // ============================================

  Future<void> getRequestsReport({
    int? clientId,
    String? requestType,
    String? status,
    String? dateFrom,
    String? dateTo,
    bool includeStats = true,
  }) async {
    final params = _buildParams({
      'clientId':    clientId,
      'requestType': requestType,
      'status':      status,
      'dateFrom':    dateFrom,
      'dateTo':      dateTo,
      if (!includeStats) 'includeStats': 'false',
    });

    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.reportRequests}',
      queryParams: params,
    );

    if (data != null) {
      requestReport.value = RequestReportData.fromJson(data);
    }
  }

  // ============================================
  // CLIENT ACTIVITY REPORT
  // ============================================

  Future<void> getClientActivityReport(int clientId) async {
    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.reportClientActivity(clientId.toString())}',
    );

    if (data != null) {
      clientActivity.value = ClientActivityData.fromJson(data);
    }
  }

  // ============================================
  // STORAGE UTILISATION REPORT
  // ============================================

  Future<void> getStorageUtilisationReport() async {
    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.reportStorageUtilisation}',
    );

    if (data != null) {
      storageUtilisation.value = StorageUtilisationData.fromJson(data);
    }
  }

  // ============================================
  // CONVENIENCE HELPERS
  // ============================================

  /// Clear all cached report data (e.g. when navigating away)
  void clearAll() {
    boxReport.value            = null;
    groupedBoxReport.value     = null;
    pendingDestruction.value   = null;
    collectionReport.value     = null;
    retrievalReport.value      = null;
    deliveryReport.value       = null;
    requestReport.value        = null;
    requestReport.value        = null;
    clientActivity.value       = null;
    storageUtilisation.value   = null;
    errorMessage.value         = '';
  }

  @override
  void onClose() {
    clearAll();
    super.onClose();
  }
}