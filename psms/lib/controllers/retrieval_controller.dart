import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/models/box_model.dart';
import 'package:psms/models/client_model.dart';
import 'package:psms/models/retrieval_model.dart';

class RetrievalController extends GetxController {
  static RetrievalController get instance => Get.find();

  // ============================================
  // REACTIVE STATE
  // ============================================

  final RxList<RetrievalModel> retrievals          = <RetrievalModel>[].obs;
  final RxList<RetrievalModel> recentRetrievals    = <RetrievalModel>[].obs;
  final RxList<RetrievalModel> pendingRetrievals   = <RetrievalModel>[].obs;
  final RxList<RetrievalModel> myPendingRetrievals = <RetrievalModel>[].obs;
  final RxList<RetrievalModel> clientRetrievals    = <RetrievalModel>[].obs;
  final RxList<RetrievalModel> boxRetrievals       = <RetrievalModel>[].obs;
  final Rx<RetrievalModel?>    selectedRetrieval   = Rx<RetrievalModel?>(null);
  final Rx<RetrievalStats?>    retrievalStats      = Rx<RetrievalStats?>(null);

  final RxList<ClientModel> clients           = <ClientModel>[].obs;
  final RxList<BoxModel>    clientStoredBoxes = <BoxModel>[].obs;
  /// Tracks the real active-clients total from the API pagination,
  /// so the stat card shows the correct number regardless of page size.
  final RxInt               activeClientsCount = 0.obs;
  /// Boxes selected in the "New Retrieval" dialog (multi-select).
  final RxList<BoxModel>    selectedBoxes     = <BoxModel>[].obs;

  final RxBool   isLoading      = false.obs;
  final RxBool   loadingBoxes   = false.obs;
  final RxString errorMessage   = ''.obs;
  final RxInt    currentPage    = 1.obs;
  final RxInt    totalPages     = 1.obs;
  final RxInt    totalRetrievals = 0.obs;

  // Filters
  final RxString searchQuery     = ''.obs;
  final RxInt    clientFilter    = 0.obs;
  final RxInt    boxFilter       = 0.obs;
  final RxString startDateFilter = ''.obs;
  final RxString endDateFilter   = ''.obs;
  final RxString sortBy          = 'retrieval_date'.obs;
  final RxString sortOrder       = 'DESC'.obs;

  // Reports
  final RxList<RetrievalSummary>      summaryReport = <RetrievalSummary>[].obs;
  final RxList<ClientRetrievalReport> clientReport  = <ClientRetrievalReport>[].obs;

  // ============================================
  // PERMISSIONS
  // ============================================

  bool get canCreateRetrievals => AuthController.instance.hasPermission('canCreateRetrievals');
  bool get canEditRetrievals   => AuthController.instance.hasPermission('canCreateRetrievals');
  bool get canDeleteRetrievals => AuthController.instance.currentUser.value?.role == 'admin';
  bool get canSignRetrievals   => AuthController.instance.hasPermission('canSignRetrievals');
  bool get isClient            => AuthController.instance.currentUser.value?.role == 'client';

  // ============================================
  // BOX MULTI-SELECTION (dialog helpers)
  // ============================================

  void toggleBoxSelection(BoxModel box) {
    final idx = selectedBoxes.indexWhere((b) => b.boxId == box.boxId);
    idx >= 0 ? selectedBoxes.removeAt(idx) : selectedBoxes.add(box);
  }

  bool isBoxSelected(BoxModel box) => selectedBoxes.any((b) => b.boxId == box.boxId);
  void clearSelectedBoxes()        => selectedBoxes.clear();

  // ============================================
  // INTERNAL HELPERS
  // ============================================

  Map<String, String> getAuthHeaders() => AuthController.instance.getAuthHeaders();

  dynamic _parseJson(String body) {
    try {
      return json.decode(body);
    } catch (e) {
      debugPrint('JSON parse error: $e — ${body.substring(0, min(200, body.length))}');
      return null;
    }
  }

  Future<Map<String, dynamic>> _call({
    required Future<http.Response> Function() request,
    required String errorPrefix,
  }) async {
    try {
      var response = await request();

      if (response.statusCode == 401) {
        final refreshed = await AuthController.instance.refreshAccessToken();
        if (refreshed) response = await request();
        if (response.statusCode == 401) {
          return {'success': false, 'message': 'Authentication failed. Please login again.'};
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _parseJson(response.body);
        if (data == null) return {'success': false, 'message': 'Invalid server response.'};
        if (data['status'] == 'success') {
          return {'success': true, 'data': data['data'], 'message': data['message'] ?? 'OK'};
        }
        return {'success': false, 'message': data['message'] ?? 'Operation failed.'};
      }
      if (response.statusCode == 404) return {'success': false, 'message': 'Resource not found.'};
      if (response.statusCode >= 500) return {'success': false, 'message': 'Server error. Try again later.'};

      try {
        final err = json.decode(response.body);
        return {'success': false, 'message': err['message'] ?? 'HTTP ${response.statusCode}'};
      } catch (_) {
        return {'success': false, 'message': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('$errorPrefix error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  void _snackError(String msg)   =>
      Get.snackbar('Error',   msg, backgroundColor: Colors.red,   colorText: Colors.white);
  void _snackSuccess(String msg) =>
      Get.snackbar('Success', msg, backgroundColor: Colors.green, colorText: Colors.white);

  /// Normalises the varied list-vs-object response shapes the API returns.
  List<RetrievalModel> _parseRetrievalList(dynamic data) {
    final List<dynamic> list = data is List ? data : (data['retrievals'] as List? ?? []);
    return list.map((r) => RetrievalModel.fromJson(r)).toList();
  }

  // ============================================
  // INITIALIZATION
  // ============================================

  Future<void> initialize({bool forceRefresh = false}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await Future.wait([
        getAllRetrievals(),
        getRetrievalStatistics(),
        getRecentRetrievals(),
        getClients(),
        isClient ? getMyPendingRetrievals() : getPendingRetrievals(),
      ]);
    } catch (e) {
      errorMessage.value = 'Failed to initialize: $e';
      _snackError('Failed to load retrieval data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // CLIENTS & BOXES
  // ============================================

  Future<void> getClients() async {
    final result = await _call(
      request: () => http.get(
        // limit=500 fetches all clients in one shot for the dropdown.
        // The pagination totalItems is stored separately as activeClientsCount
        // so the stat card is accurate even if the list is ever paginated.
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}')
            .replace(queryParameters: {'limit': '500', 'includeInactive': 'false'}),
        headers: getAuthHeaders(),
      ),
      errorPrefix: 'getClients',
    );
    if (result['success'] && result['data'] != null) {
      final raw  = result['data'];
      final list = raw is List ? raw : (raw['clients'] as List? ?? []);
      clients.value = list.map((c) => ClientModel.fromJson(c)).toList();

      // Prefer pagination.totalItems (authoritative active-client count from DB).
      // Fall back to the list length if pagination is absent.
      final pagination = raw is Map ? raw['pagination'] : null;
      activeClientsCount.value =
          (pagination?['totalItems'] as int?) ?? clients.length;
    } else {
      errorMessage.value = result['message'];
    }
  }

  Future<void> getClientStoredBoxes(int clientId) async {
    try {
      loadingBoxes.value = true;
      clientStoredBoxes.clear();
      clearSelectedBoxes(); // reset selection whenever the client changes

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.boxes}')
          .replace(queryParameters: {
        'clientId': '$clientId',
        'status':   'stored',
        'limit':    '1000',
      });

      final result = await _call(
        request: () => http.get(uri, headers: getAuthHeaders()),
        errorPrefix: 'getClientStoredBoxes',
      );

      if (result['success'] && result['data'] != null) {
        clientStoredBoxes.value = (result['data']['boxes'] as List)
            .map((b) => BoxModel.fromJson(b))
            .toList();
      } else {
        errorMessage.value = result['message'];
        _snackError(result['message']);
      }
    } finally {
      loadingBoxes.value = false;
    }
  }

  // ============================================
  // RETRIEVAL READS
  // ============================================

  Future<void> getAllRetrievals({
    int page = 1, int limit = 50,
    String? search, int? clientId, int? boxId,
    String? startDate, String? endDate,
    String? sortBy, String? sortOrder,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final params = <String, String>{'page': '$page', 'limit': '$limit'};
      if (search?.isNotEmpty == true)     params['search']    = search!;
      if ((clientId ?? 0) > 0)           params['clientId']  = '$clientId';
      if ((boxId ?? 0) > 0)              params['boxId']     = '$boxId';
      if (startDate?.isNotEmpty == true)  params['startDate'] = startDate!;
      if (endDate?.isNotEmpty == true)    params['endDate']   = endDate!;
      if (sortBy?.isNotEmpty == true)     params['sortBy']    = sortBy!;
      if (sortOrder?.isNotEmpty == true)  params['sortOrder'] = sortOrder!;

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievals}')
          .replace(queryParameters: params);

      final result = await _call(
        request: () => http.get(uri, headers: getAuthHeaders()),
        errorPrefix: 'getAllRetrievals',
      );

      if (result['success'] && result['data'] != null) {
        final data = result['data'];
        retrievals.value = _parseRetrievalList(data);
        final p = data['pagination'];
        if (p != null) {
          currentPage.value     = p['page']       ?? 1;
          totalPages.value      = p['totalPages'] ?? 1;
          totalRetrievals.value = p['total']      ?? 0;
        }
      } else {
        errorMessage.value = result['message'];
        _snackError(result['message']);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getRetrievalById(int retrievalId) async {
    try {
      isLoading.value = true;
      final result = await _call(
        request: () => http.get(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievalById(retrievalId.toString())}'),
          headers: getAuthHeaders(),
        ),
        errorPrefix: 'getRetrievalById',
      );
      if (result['success'] && result['data'] != null) {
        selectedRetrieval.value = RetrievalModel.fromJson(result['data']);
      } else {
        errorMessage.value = result['message'];
        _snackError(result['message']);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getRecentRetrievals({int limit = 10}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.recentRetrievals}')
        .replace(queryParameters: {'limit': '$limit'});
    final result = await _call(
      request: () => http.get(uri, headers: getAuthHeaders()),
      errorPrefix: 'getRecentRetrievals',
    );
    if (result['success'] && result['data'] != null) {
      recentRetrievals.value = _parseRetrievalList(result['data']);
    }
  }

  Future<void> getPendingRetrievals({int? clientId, int limit = 50}) async {
    final params = {'limit': '$limit'};
    if ((clientId ?? 0) > 0) params['clientId'] = '$clientId';
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.pendingRetrievals}')
        .replace(queryParameters: params);
    final result = await _call(
      request: () => http.get(uri, headers: getAuthHeaders()),
      errorPrefix: 'getPendingRetrievals',
    );
    if (result['success'] && result['data'] != null) {
      pendingRetrievals.value = _parseRetrievalList(result['data']);
    }
  }

  Future<void> getMyPendingRetrievals() async {
    final result = await _call(
      request: () => http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myPendingRetrievals}'),
        headers: getAuthHeaders(),
      ),
      errorPrefix: 'getMyPendingRetrievals',
    );
    if (result['success'] && result['data'] != null) {
      myPendingRetrievals.value = _parseRetrievalList(result['data']);
    }
  }

  Future<void> getRetrievalsByClient(int clientId) async {
    try {
      isLoading.value = true;
      final result = await _call(
        request: () => http.get(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievalsByClient(clientId.toString())}'),
          headers: getAuthHeaders(),
        ),
        errorPrefix: 'getRetrievalsByClient',
      );
      if (result['success'] && result['data'] != null) {
        clientRetrievals.value = _parseRetrievalList(result['data']);
      } else {
        errorMessage.value = result['message'];
        _snackError(result['message']);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getRetrievalsByBox(int boxId) async {
    try {
      isLoading.value = true;
      final result = await _call(
        request: () => http.get(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievalsByBox(boxId.toString())}'),
          headers: getAuthHeaders(),
        ),
        errorPrefix: 'getRetrievalsByBox',
      );
      if (result['success'] && result['data'] != null) {
        boxRetrievals.value = _parseRetrievalList(result['data']);
      } else {
        errorMessage.value = result['message'];
        _snackError(result['message']);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getRetrievalStatistics() async {
    final result = await _call(
      request: () => http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievalStats}'),
        headers: getAuthHeaders(),
      ),
      errorPrefix: 'getRetrievalStatistics',
    );
    if (result['success'] && result['data'] != null) {
      retrievalStats.value = RetrievalStats.fromJson(result['data']);
    }
  }

  // ============================================
  // RETRIEVAL WRITES
  // ============================================

  /// Creates a single retrieval.
  Future<bool> createRetrieval(CreateRetrievalRequest request) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final result = await _call(
        request: () => http.post(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievals}'),
          headers: {...getAuthHeaders(), 'Content-Type': 'application/json'},
          body: json.encode(request.toJson()),
        ),
        errorPrefix: 'createRetrieval',
      );
      if (result['success']) {
        _snackSuccess(result['message']);
        await Future.wait([getAllRetrievals(), getPendingRetrievals()]);
        return true;
      }
      errorMessage.value = result['message'];
      _snackError(result['message']);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Creates one retrieval per box in [selectedBoxes]. Returns success count.
  Future<int> createRetrievalsForSelectedBoxes({
    required int    clientId,
    required String retrievalDate,
    required String retrievedBy,
    required String reason,
    String? clientSignature,
    String? staffSignature,
  }) async {
    if (selectedBoxes.isEmpty) return 0;

    isLoading.value = true;
    int successCount = 0;
    final failedBoxes = <String>[];

    for (final box in List.of(selectedBoxes)) {
      final result = await _call(
        request: () => http.post(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievals}'),
          headers: {...getAuthHeaders(), 'Content-Type': 'application/json'},
          body: json.encode(CreateRetrievalRequest(
            clientId:        clientId,
            boxId:           box.boxId,
            retrievalDate:   retrievalDate,
            retrievedBy:     retrievedBy,
            reason:          reason,
            staffSignature:  staffSignature,
          ).toJson()),
        ),
        errorPrefix: 'createRetrieval box ${box.boxNumber}',
      );
      result['success'] ? successCount++ : failedBoxes.add(box.boxNumber);
    }

    isLoading.value = false;

    if (successCount > 0) await Future.wait([getAllRetrievals(), getPendingRetrievals()]);
    if (failedBoxes.isNotEmpty) {
      Get.snackbar(
        'Partial Failure',
        'Could not create retrievals for: ${failedBoxes.join(', ')}',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
    return successCount;
  }

  Future<bool> deleteRetrieval(int retrievalId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final result = await _call(
        request: () => http.delete(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievalById(retrievalId.toString())}'),
          headers: getAuthHeaders(),
        ),
        errorPrefix: 'deleteRetrieval',
      );
      if (result['success']) {
        _snackSuccess(result['message']);
        retrievals.removeWhere((r) => r.retrievalId == retrievalId);
        return true;
      }
      errorMessage.value = result['message'];
      _snackError(result['message']);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // STATUS OPERATIONS
  // ============================================

  /// Patches the retrieval status on the server and updates all in-memory lists
  /// immediately so the UI reflects the change without a full reload.
  /// Endpoint: PATCH /api/retrievals/:id/status   body: { "status": "..." }
  Future<bool> updateRetrievalStatus(int retrievalId, String status) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _call(
        request: () => http.patch(
          // Use the dedicated /status sub-route, not the base /:id route.
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.retrievalById(retrievalId.toString())}/status',
          ),
          headers: {...getAuthHeaders(), 'Content-Type': 'application/json'},
          body: json.encode({'status': status}),
        ),
        errorPrefix: 'updateRetrievalStatus',
      );

      if (result['success']) {
        // Patch every in-memory list that may contain this retrieval.
        for (final list in [
          retrievals, pendingRetrievals, recentRetrievals,
          clientRetrievals, boxRetrievals, myPendingRetrievals,
        ]) {
          final idx = list.indexWhere((r) => r.retrievalId == retrievalId);
          if (idx >= 0) list[idx] = list[idx].copyWith(status: status);
        }
        if (selectedRetrieval.value?.retrievalId == retrievalId) {
          selectedRetrieval.value =
              selectedRetrieval.value!.copyWith(status: status);
        }
        _snackSuccess('Status updated to ${status.toUpperCase()}');
        return true;
      }

      errorMessage.value = result['message'];
      _snackError(result['message']);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // SIGNATURE & PDF OPERATIONS
  // ============================================

  Future<bool> updateSignatures({
    required int retrievalId,
    String? clientSignature,
    String? staffSignature,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final body = <String, dynamic>{};
      if (clientSignature != null) body['clientSignature'] = clientSignature;
      if (staffSignature  != null) body['staffSignature']  = staffSignature;

      final result = await _call(
        request: () => http.patch(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievalSignatures(retrievalId.toString())}'),
          headers: {...getAuthHeaders(), 'Content-Type': 'application/json'},
          body: json.encode(body),
        ),
        errorPrefix: 'updateSignatures',
      );

      if (result['success']) {
        _snackSuccess(result['message']);
        await Future.wait([
          getRetrievalById(retrievalId),
          getAllRetrievals(),
          isClient ? getMyPendingRetrievals() : getPendingRetrievals(),
        ]);
        return true;
      }
      errorMessage.value = result['message'];
      _snackError(result['message']);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updatePdfPath(int retrievalId, String pdfPath) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final result = await _call(
        request: () => http.patch(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievalPdf(retrievalId.toString())}'),
          headers: {...getAuthHeaders(), 'Content-Type': 'application/json'},
          body: json.encode({'pdfPath': pdfPath}),
        ),
        errorPrefix: 'updatePdfPath',
      );
      if (result['success']) { _snackSuccess(result['message']); return true; }
      errorMessage.value = result['message'];
      _snackError(result['message']);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> markBoxAsRetrieved(int boxId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final result = await _call(
        request: () => http.patch(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.markBoxRetrieved(boxId.toString())}'),
          headers: getAuthHeaders(),
        ),
        errorPrefix: 'markBoxAsRetrieved',
      );
      if (result['success']) { _snackSuccess(result['message']); return true; }
      errorMessage.value = result['message'];
      _snackError(result['message']);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // REPORTS
  // ============================================

  Future<void> getSummaryReport({String? startDate, String? endDate, int? clientId}) async {
    try {
      isLoading.value = true;
      final params = <String, String>{};
      if (startDate?.isNotEmpty == true) params['startDate'] = startDate!;
      if (endDate?.isNotEmpty == true)   params['endDate']   = endDate!;
      if ((clientId ?? 0) > 0)          params['clientId']  = '$clientId';

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievalSummaryReport}')
          .replace(queryParameters: params);
      final result = await _call(
        request: () => http.get(uri, headers: getAuthHeaders()),
        errorPrefix: 'getSummaryReport',
      );
      if (result['success'] && result['data'] != null) {
        summaryReport.value =
            (result['data'] as List).map((i) => RetrievalSummary.fromJson(i)).toList();
      } else {
        errorMessage.value = result['message'];
        _snackError(result['message']);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getByClientReport({String? startDate, String? endDate}) async {
    try {
      isLoading.value = true;
      final params = <String, String>{};
      if (startDate?.isNotEmpty == true) params['startDate'] = startDate!;
      if (endDate?.isNotEmpty == true)   params['endDate']   = endDate!;

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievalByClientReport}')
          .replace(queryParameters: params);
      final result = await _call(
        request: () => http.get(uri, headers: getAuthHeaders()),
        errorPrefix: 'getByClientReport',
      );
      if (result['success'] && result['data'] != null) {
        clientReport.value =
            (result['data'] as List).map((i) => ClientRetrievalReport.fromJson(i)).toList();
      } else {
        errorMessage.value = result['message'];
        _snackError(result['message']);
      }
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // PAGINATION & FILTERS
  // ============================================

  Future<void> loadNextPage() async {
    if (currentPage.value < totalPages.value) {
      await getAllRetrievals(
        page:      currentPage.value + 1,
        search:    searchQuery.value.isNotEmpty     ? searchQuery.value     : null,
        clientId:  clientFilter.value > 0           ? clientFilter.value    : null,
        boxId:     boxFilter.value > 0              ? boxFilter.value       : null,
        startDate: startDateFilter.value.isNotEmpty ? startDateFilter.value : null,
        endDate:   endDateFilter.value.isNotEmpty   ? endDateFilter.value   : null,
        sortBy:    sortBy.value,
        sortOrder: sortOrder.value,
      );
    }
  }

  Future<void> loadPreviousPage() async {
    if (currentPage.value > 1) {
      await getAllRetrievals(
        page:      currentPage.value - 1,
        search:    searchQuery.value.isNotEmpty     ? searchQuery.value     : null,
        clientId:  clientFilter.value > 0           ? clientFilter.value    : null,
        boxId:     boxFilter.value > 0              ? boxFilter.value       : null,
        startDate: startDateFilter.value.isNotEmpty ? startDateFilter.value : null,
        endDate:   endDateFilter.value.isNotEmpty   ? endDateFilter.value   : null,
        sortBy:    sortBy.value,
        sortOrder: sortOrder.value,
      );
    }
  }

  void clearFilters() {
    searchQuery.value     = '';
    clientFilter.value    = 0;
    boxFilter.value       = 0;
    startDateFilter.value = '';
    endDateFilter.value   = '';
    sortBy.value          = 'retrieval_date';
    sortOrder.value       = 'DESC';
  }

  // ============================================
  // UTILITY
  // ============================================

  String getClientName(int clientId) {
    try { return clients.firstWhere((c) => c.clientId == clientId).clientName; }
    catch (_) { return 'Unknown Client'; }
  }

  bool hasSignatures(RetrievalModel r)            => r.hasClientSignature || r.hasStaffSignature;
  bool isRetrievalComplete(RetrievalModel r)      => r.isComplete;
  bool hasPdf(RetrievalModel r)                   => r.pdfPath != null && r.pdfPath!.isNotEmpty;
  bool isPendingClientSignature(RetrievalModel r) => !r.hasClientSignature;

  // ============================================
  // CLEANUP
  // ============================================

  @override
  void onClose() {
    retrievals.clear();
    recentRetrievals.clear();
    pendingRetrievals.clear();
    myPendingRetrievals.clear();
    clientRetrievals.clear();
    boxRetrievals.clear();
    selectedBoxes.clear();
    selectedRetrieval.value  = null;
    retrievalStats.value     = null;
    activeClientsCount.value = 0;
    summaryReport.clear();
    clientReport.clear();
    clients.clear();
    super.onClose();
  }
}