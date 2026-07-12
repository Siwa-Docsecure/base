// audit_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/models/audit_models.dart';

class AuditController extends GetxController {
  static AuditController get instance => Get.find();

  // ============================================
  // REACTIVE STATE
  // ============================================

  // Paginated log list
  final RxList<AuditLogEntry> logs   = <AuditLogEntry>[].obs;
  final RxInt currentPage            = 1.obs;
  final RxInt totalPages             = 1.obs;
  final RxInt totalEvents            = 0.obs;
  final RxInt pageSize               = 50.obs;
  final RxString sortOrder           = 'DESC'.obs;

  // Filter state (mirrors the query params)
  final RxString filterUserId        = ''.obs;
  final RxString filterAction        = ''.obs;
  final RxString filterEntityType    = ''.obs;
  final RxString filterEntityId      = ''.obs;
  final RxString filterIpAddress     = ''.obs;
  final RxString filterDateFrom      = ''.obs;
  final RxString filterDateTo        = ''.obs;
  final RxString filterSearch        = ''.obs;

  // Detail view
  final Rx<AuditLogDetail?> selectedEvent = Rx<AuditLogDetail?>(null);

  // Entity history
  final Rx<EntityAuditHistory?> entityHistory = Rx<EntityAuditHistory?>(null);

  // User activity
  final Rx<UserAuditActivity?> userActivity = Rx<UserAuditActivity?>(null);

  // Summary / aggregate
  final Rx<AuditSummary?> summary = Rx<AuditSummary?>(null);

  // Loading flags
  final RxBool isLoading         = false.obs;
  final RxBool isExporting       = false.obs;
  final RxString errorMessage    = ''.obs;

  // ============================================
  // AUTH HEADERS
  // ============================================

  Map<String, String> getAuthHeaders() =>
      AuthController.instance.getAuthHeaders();

  // ============================================
  // HELPER — active filter params map
  // ============================================

  Map<String, String> _activeFilters({int? page, int? limit}) {
    final params = <String, String>{};
    if (filterUserId.value.isNotEmpty)     params['userId']     = filterUserId.value;
    if (filterAction.value.isNotEmpty)     params['action']     = filterAction.value;
    if (filterEntityType.value.isNotEmpty) params['entityType'] = filterEntityType.value;
    if (filterEntityId.value.isNotEmpty)   params['entityId']   = filterEntityId.value;
    if (filterIpAddress.value.isNotEmpty)  params['ipAddress']  = filterIpAddress.value;
    if (filterDateFrom.value.isNotEmpty)   params['dateFrom']   = filterDateFrom.value;
    if (filterDateTo.value.isNotEmpty)     params['dateTo']     = filterDateTo.value;
    if (filterSearch.value.isNotEmpty)     params['search']     = filterSearch.value;
    params['sortOrder'] = sortOrder.value;
    params['page']      = (page  ?? currentPage.value).toString();
    params['limit']     = (limit ?? pageSize.value).toString();
    return params;
  }

  // ============================================
  // HELPER — standard GET with guard
  // ============================================

  Future<Map<String, dynamic>?> _get(String url,
      {Map<String, String>? queryParams}) async {
    if (isLoading.value) return null;
    isLoading.value    = true;
    errorMessage.value = '';

    try {
      final uri      = Uri.parse(url).replace(queryParameters: queryParams ?? {});
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
        final body = json.decode(response.body) as Map<String, dynamic>;
        final msg  = body['message'] as String? ?? 'HTTP ${response.statusCode}';
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
  // PAGINATED LOG LIST
  // ============================================

  Future<void> getLogs({
    int? page,
    bool refresh = true,
    String? userId,
    String? action,
    String? entityType,
    String? entityId,
    String? ipAddress,
    String? dateFrom,
    String? dateTo,
    String? search,
    String? sort,
  }) async {
    if (isLoading.value) return;

    // Sync filter state
    if (userId     != null) filterUserId.value     = userId;
    if (action     != null) filterAction.value     = action;
    if (entityType != null) filterEntityType.value = entityType;
    if (entityId   != null) filterEntityId.value   = entityId;
    if (ipAddress  != null) filterIpAddress.value  = ipAddress;
    if (dateFrom   != null) filterDateFrom.value   = dateFrom;
    if (dateTo     != null) filterDateTo.value     = dateTo;
    if (search     != null) filterSearch.value     = search;
    if (sort       != null) sortOrder.value        = sort;

    final effectivePage = page ?? (refresh ? 1 : currentPage.value);
    final params        = _activeFilters(page: effectivePage);

    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.audit}',
      queryParams: params,
    );

    if (data == null) return;

    final page_  = AuditLogPage.fromJson(data);
    if (refresh) {
      logs.value       = page_.logs;
      currentPage.value = effectivePage;
    } else {
      logs.addAll(page_.logs);
      currentPage.value = effectivePage;
    }

    totalPages.value  = page_.pagination.totalPages;
    totalEvents.value = page_.pagination.total;
    print('Audit logs loaded: ${logs.length} / ${totalEvents.value}');
  }

  Future<void> loadNextPage() async {
    if (currentPage.value >= totalPages.value || isLoading.value) return;
    await getLogs(page: currentPage.value + 1, refresh: true);
  }

  Future<void> loadPreviousPage() async {
    if (currentPage.value > 1 && !isLoading.value) {
      await getLogs(page: currentPage.value - 1, refresh: true);
    }
  }

  Future<void> _refreshCurrentPage() async {
    await getLogs(page: currentPage.value, refresh: true);
  }

  // ============================================
  // SINGLE EVENT DETAIL
  // ============================================

  Future<AuditLogDetail?> getEventDetail(int auditId) async {
    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.auditById(auditId.toString())}',
    );

    if (data != null) {
      final detail = AuditLogDetail.fromJson(data);
      selectedEvent.value = detail;
      return detail;
    }
    return null;
  }

  // ============================================
  // ENTITY HISTORY
  // ============================================

  Future<void> getEntityHistory(String entityType, int entityId) async {
    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.auditEntityHistory(entityType, entityId.toString())}',
    );

    if (data != null) {
      entityHistory.value = EntityAuditHistory.fromJson(data);
      print('Entity history loaded: ${entityHistory.value?.totalEvents} events');
    }
  }

  // ============================================
  // USER ACTIVITY
  // ============================================

  Future<void> getUserActivity(
    int userId, {
    String? dateFrom,
    String? dateTo,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (dateFrom != null && dateFrom.isNotEmpty) params['dateFrom'] = dateFrom;
    if (dateTo   != null && dateTo.isNotEmpty)   params['dateTo']   = dateTo;

    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.auditUserActivity(userId.toString())}',
      queryParams: params,
    );

    if (data != null) {
      userActivity.value = UserAuditActivity.fromJson(data);
    }
  }

  // ============================================
  // SUMMARY / AGGREGATE
  // ============================================

  Future<void> getSummary({String? dateFrom, String? dateTo}) async {
    final params = <String, String>{};
    if (dateFrom != null && dateFrom.isNotEmpty) params['dateFrom'] = dateFrom;
    if (dateTo   != null && dateTo.isNotEmpty)   params['dateTo']   = dateTo;

    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.auditSummary}',
      queryParams: params,
    );

    if (data != null) {
      summary.value = AuditSummary.fromJson(data);
      print('Audit summary loaded');
    }
  }

  // ============================================
  // EXPORT — CSV
  // ============================================

  Future<String?> exportCsv(AuditExportRequest request) async {
    if (isExporting.value) return null;
    isExporting.value  = true;
    errorMessage.value = '';

    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.auditExportCsv}',
      ).replace(queryParameters: request.toQueryParams());

      final response = await http.get(uri, headers: getAuthHeaders());

      if (response.statusCode == 200) {
        Get.snackbar('Export Ready', 'CSV export downloaded successfully',
            backgroundColor: Colors.green, colorText: Colors.white);
        return response.body; // raw CSV string — caller handles file save
      } else if (response.statusCode == 401) {
        await AuthController.instance.refreshAccessToken();
        return exportCsv(request);
      } else {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final msg  = body['message'] as String? ?? 'Export failed';
        errorMessage.value = msg;
        Get.snackbar('Export Failed', msg,
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isExporting.value = false;
    }
    return null;
  }

  // ============================================
  // EXPORT — JSON
  // ============================================

  Future<Map<String, dynamic>?> exportJson(AuditExportRequest request) async {
    if (isExporting.value) return null;
    isExporting.value  = true;
    errorMessage.value = '';

    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.auditExportJson}',
      ).replace(queryParameters: request.toQueryParams());

      final response = await http.get(uri, headers: getAuthHeaders());

      if (response.statusCode == 200) {
        Get.snackbar('Export Ready', 'JSON export downloaded successfully',
            backgroundColor: Colors.green, colorText: Colors.white);
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        await AuthController.instance.refreshAccessToken();
        return exportJson(request);
      } else {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final msg  = body['message'] as String? ?? 'Export failed';
        errorMessage.value = msg;
        Get.snackbar('Export Failed', msg,
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isExporting.value = false;
    }
    return null;
  }

  // ============================================
  // FILTER HELPERS
  // ============================================

  void clearFilters() {
    filterUserId.value     = '';
    filterAction.value     = '';
    filterEntityType.value = '';
    filterEntityId.value   = '';
    filterIpAddress.value  = '';
    filterDateFrom.value   = '';
    filterDateTo.value     = '';
    filterSearch.value     = '';
    sortOrder.value        = 'DESC';
  }

  Future<void> applyFilters({
    String? userId,
    String? action,
    String? entityType,
    String? entityId,
    String? ipAddress,
    String? dateFrom,
    String? dateTo,
    String? search,
    String? sort,
  }) async {
    await getLogs(
      page:       1,
      refresh:    true,
      userId:     userId,
      action:     action,
      entityType: entityType,
      entityId:   entityId,
      ipAddress:  ipAddress,
      dateFrom:   dateFrom,
      dateTo:     dateTo,
      search:     search,
      sort:       sort,
    );
  }

  // ============================================
  // CLEANUP
  // ============================================

  void clearAll() {
    logs.clear();
    selectedEvent.value  = null;
    entityHistory.value  = null;
    userActivity.value   = null;
    summary.value        = null;
    currentPage.value    = 1;
    totalPages.value     = 1;
    totalEvents.value    = 0;
    errorMessage.value   = '';
    clearFilters();
  }

  @override
  void onClose() {
    clearAll();
    super.onClose();
  }
}