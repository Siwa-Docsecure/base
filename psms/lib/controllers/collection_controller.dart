// collection_controller.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/models/client_model.dart';
import 'package:psms/models/collection_model.dart';

class CollectionController extends GetxController {
  static CollectionController get instance => Get.find();

  final RxList<CollectionModel> collections = <CollectionModel>[].obs;
  final RxList<CollectionModel> recentCollections = <CollectionModel>[].obs;
  final RxList<CollectionModel> clientCollections = <CollectionModel>[].obs;
  final Rx<CollectionModel?> selectedCollection = Rx<CollectionModel?>(null);
  final Rx<CollectionStats?> collectionStats = Rx<CollectionStats?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalCollections = 0.obs;

  final RxString searchQuery = ''.obs;
  final RxInt clientFilter = 0.obs;
  final RxString startDateFilter = ''.obs;
  final RxString endDateFilter = ''.obs;
  final RxString sortBy = 'collection_date'.obs;
  final RxString sortOrder = 'DESC'.obs;

  final RxList<ClientModel> clients = <ClientModel>[].obs;
  final RxList<CollectionSummary> summaryReport = <CollectionSummary>[].obs;
  final RxList<ClientCollectionReport> clientReport =
      <ClientCollectionReport>[].obs;

  // ── Permissions ──────────────────────────────────────────────────────────
  bool get canCreateCollections =>
      AuthController.instance.hasPermission('canCreateCollections');
  bool get canEditCollections =>
      AuthController.instance.hasPermission('canCreateCollections');
  bool get canDeleteCollections =>
      AuthController.instance.currentUser.value?.role == 'admin';

  Map<String, String> getAuthHeaders() =>
      AuthController.instance.getAuthHeaders();
  String _endpoint(String path) => '${ApiConstants.baseUrl}/collections$path';

  // ── Type-safe int parser ─────────────────────────────────────────────────
  // mysql2 may serialize BigInt or SUM()/COUNT() results as String when the
  // value travels through JSON.  This helper handles String, int, double, and
  // null so CollectionStats.fromJson / pagination parsing never throws.
  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    // BigInt via dart:ffi is unlikely in HTTP JSON, but just in case
    return fallback;
  }

  // Normalises a raw stats map so all fields are int regardless of JSON type.
  static Map<String, dynamic> _normaliseStats(Map<String, dynamic> raw) => {
        'totalCollections': _safeInt(raw['total_collections']),
        'totalBoxesCollected': _safeInt(raw['total_boxes_collected']),
        'clientsWithCollections': _safeInt(raw['clients_with_collections']),
        'todayCollections': _safeInt(raw['today_collections']),
        'thisWeekCollections': _safeInt(raw['this_week_collections']),
        'thisMonthCollections': _safeInt(raw['this_month_collections']),
      };

  // ── JSON / HTTP helpers ──────────────────────────────────────────────────
  dynamic _parseJson(String body) {
    try {
      return json.decode(body);
    } catch (e) {
      debugPrint(
          'JSON parse error: $e\n${body.substring(0, min(200, body.length))}');
      return null;
    }
  }

  Future<Map<String, dynamic>> _call({
    required Future<http.Response> Function() request,
    required String tag,
  }) async {
    try {
      final res = await request();
      debugPrint(
          '[$tag] ${res.statusCode}: ${res.body.substring(0, min(300, res.body.length))}');

      if (res.statusCode == 401) {
        final refreshed = await AuthController.instance.refreshAccessToken();
        if (refreshed) return _call(request: request, tag: tag);
        return {
          'success': false,
          'message': 'Session expired. Please log in again.'
        };
      }

      final data = _parseJson(res.body);
      if (data == null)
        return {'success': false, 'message': 'Invalid server response'};

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (data['status'] == 'success') {
          return {
            'success': true,
            'data': data['data'],
            'message': data['message'] ?? 'OK'
          };
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Operation failed'
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Error ${res.statusCode}'
      };
    } catch (e) {
      debugPrint('[$tag] error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  void _snack(String title, String msg, {Color bg = Colors.red}) =>
      Get.snackbar(title, msg,
          backgroundColor: bg,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);

  // ── Initialisation ───────────────────────────────────────────────────────
  Future<void> initialize() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await Future.wait([
        getAllCollections(),
        getClients(),
      ]);
      // Stats in background — failure should not block the page
      getCollectionStatistics();
      getRecentCollections();
    } catch (e) {
      errorMessage.value = 'Failed to initialise: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getClients() async {
    try {
      final result = await _call(
        request: () => http.get(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}'),
          headers: getAuthHeaders(),
        ),
        tag: 'getClients',
      );
      if (result['success'] && result['data'] != null) {
        final raw = result['data'];
        final list = raw is List ? raw : (raw['clients'] as List? ?? []);
        clients.value = list.map((c) => ClientModel.fromJson(c)).toList();
      }
    } catch (e) {
      debugPrint('getClients error: $e');
    }
  }

  // ── Collections CRUD ────────────────────────────────────────────────────
  Future<void> getAllCollections({
    int page = 1,
    int limit = 20,
    String? search,
    int? clientId,
    String? startDate,
    String? endDate,
    String? sortByParam,
    String? sortOrderParam,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (search?.isNotEmpty == true) params['search'] = search!;
      if (clientId != null && clientId > 0)
        params['clientId'] = clientId.toString();
      if (startDate?.isNotEmpty == true) params['startDate'] = startDate!;
      if (endDate?.isNotEmpty == true) params['endDate'] = endDate!;
      if (sortByParam?.isNotEmpty == true) params['sortBy'] = sortByParam!;
      if (sortOrderParam?.isNotEmpty == true)
        params['sortOrder'] = sortOrderParam!;

      final uri = Uri.parse(_endpoint('')).replace(queryParameters: params);
      final result = await _call(
        request: () => http.get(uri, headers: getAuthHeaders()),
        tag: 'getAllCollections',
      );

      if (result['success'] && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        final cols = data['collections'] as List<dynamic>;
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        collections.value =
            cols.map((c) => CollectionModel.fromJson(c)).toList();

        // _safeInt handles String-encoded pagination values
        currentPage.value = _safeInt(pagination['page'], page);
        totalPages.value = _safeInt(pagination['totalPages'], 1);
        totalCollections.value = _safeInt(pagination['total'], 0);

        if (search != null) searchQuery.value = search;
        if (clientId != null) clientFilter.value = clientId;
        if (startDate != null) startDateFilter.value = startDate;
        if (endDate != null) endDateFilter.value = endDate;
        if (sortByParam != null) sortBy.value = sortByParam;
        if (sortOrderParam != null) sortOrder.value = sortOrderParam;
      } else {
        errorMessage.value = result['message'];
        _snack('Error', result['message']);
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      _snack('Error', 'Connection error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<CollectionModel?> getCollectionById(int id) async {
    try {
      isLoading.value = true;
      final result = await _call(
        request: () =>
            http.get(Uri.parse(_endpoint('/$id')), headers: getAuthHeaders()),
        tag: 'getCollectionById',
      );
      if (result['success'] && result['data'] != null) {
        final col = CollectionModel.fromJson(result['data']);
        selectedCollection.value = col;
        return col;
      }
      _snack('Error', result['message']);
    } catch (e) {
      _snack('Error', 'Connection error: $e');
    } finally {
      isLoading.value = false;
    }
    return null;
  }

  Future<bool> createCollection(CreateCollectionRequest request) async {
    if (!canCreateCollections) {
      _snack('Permission Denied',
          'You do not have permission to create collections',
          bg: Colors.orange);
      return false;
    }
    try {
      isLoading.value = true;
      final result = await _call(
        request: () => http.post(
          Uri.parse(_endpoint('')),
          headers: {...getAuthHeaders(), 'Content-Type': 'application/json'},
          body: json.encode(request.toJson()),
        ),
        tag: 'createCollection',
      );
      if (result['success']) {
        await getAllCollections(page: 1);
        unawaited(getCollectionStatistics());
        _snack('Success', result['message'], bg: Colors.green);
        return true;
      }
      _snack('Error', result['message']);
    } catch (e) {
      _snack('Error', 'Connection error: $e');
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  Future<bool> updateCollection(int id, UpdateCollectionRequest request) async {
    try {
      isLoading.value = true;
      final result = await _call(
        request: () => http.put(
          Uri.parse(_endpoint('/$id')),
          headers: {...getAuthHeaders(), 'Content-Type': 'application/json'},
          body: json.encode(request.toJson()),
        ),
        tag: 'updateCollection',
      );
      if (result['success']) {
        await getAllCollections(page: currentPage.value);
        unawaited(getCollectionStatistics());
        _snack('Success', result['message'], bg: Colors.green);
        return true;
      }
      _snack('Error', result['message']);
    } catch (e) {
      _snack('Error', 'Connection error: $e');
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  Future<bool> deleteCollection(int id) async {
    try {
      isLoading.value = true;
      final result = await _call(
        request: () => http.delete(Uri.parse(_endpoint('/$id')),
            headers: getAuthHeaders()),
        tag: 'deleteCollection',
      );
      if (result['success']) {
        collections.removeWhere((c) => c.collectionId == id);
        await getAllCollections(page: currentPage.value);
        unawaited(getCollectionStatistics());
        _snack('Success', result['message'], bg: Colors.green);
        return true;
      }
      _snack('Error', result['message']);
    } catch (e) {
      _snack('Error', 'Connection error: $e');
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // ── Statistics ───────────────────────────────────────────────────────────
  // Direct HTTP call — bypasses _call() wrapper so we can log the raw body
  // and apply _normaliseStats() before handing to CollectionStats.fromJson.
  Future<CollectionStats?> getCollectionStatistics() async {
    try {
      final res = await http.get(
        Uri.parse(_endpoint('/stats')),
        headers: getAuthHeaders(),
      );
      debugPrint('[getCollectionStatistics] ${res.statusCode}: ${res.body}');

      if (res.statusCode == 401) {
        final ok = await AuthController.instance.refreshAccessToken();
        if (ok) return getCollectionStatistics();
        return null;
      }
      if (res.statusCode != 200) return null;

      final body = _parseJson(res.body);
      if (body == null || body['status'] != 'success') return null;

      final rawData = body['data'] as Map<dynamic, dynamic>;
      final typedData = rawData.cast<String, dynamic>();

      // Manually create stats using _safeInt (handles String, int, null)
      final stats = CollectionStats(
        totalCollections: _safeInt(typedData['total_collections']),
        totalBoxesCollected: _safeInt(typedData['total_boxes_collected']),
        clientsWithCollections: _safeInt(typedData['clients_with_collections']),
        todayCollections: _safeInt(typedData['today_collections']),
        thisWeekCollections: _safeInt(typedData['this_week_collections']),
        thisMonthCollections: _safeInt(typedData['this_month_collections']),
      );
      collectionStats.value = stats;
      return stats;
    } catch (e) {
      debugPrint('getCollectionStatistics error: $e');
      return null;
    }
  }

  // ── Recent collections ───────────────────────────────────────────────────
  Future<void> getRecentCollections({int limit = 10}) async {
    try {
      final uri = Uri.parse(_endpoint('/recent'))
          .replace(queryParameters: {'limit': limit.toString()});
      final res = await http.get(uri, headers: getAuthHeaders());

      if (res.statusCode == 401) {
        final refreshed = await AuthController.instance.refreshAccessToken();
        if (refreshed) return getRecentCollections(limit: limit);
      }

      if (res.statusCode != 200) {
        debugPrint('getRecentCollections failed: ${res.statusCode}');
        return;
      }

      final data = _parseJson(res.body);
      if (data == null) return;

      List collectionsList = [];
      if (data['status'] == 'success') {
        // Try to extract from data['data']
        if (data['data'] is List) {
          collectionsList = data['data'];
        } else if (data['data'] is Map && data['data']['collections'] is List) {
          collectionsList = data['data']['collections'];
        } else if (data['collections'] is List) {
          collectionsList = data['collections'];
        }
      } else if (data is List) {
        // In case the API returns a direct list
        collectionsList = data;
      }

      recentCollections.value = collectionsList
          .where((item) => item is Map<String, dynamic>)
          .map((item) => CollectionModel.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('getRecentCollections error: $e');
    }
  }

  Future<void> getCollectionsByClient(int clientId) async {
    try {
      isLoading.value = true;
      final result = await _call(
        request: () => http.get(
          Uri.parse(_endpoint('/client/$clientId')),
          headers: getAuthHeaders(),
        ),
        tag: 'getCollectionsByClient',
      );
      if (result['success'] && result['data'] != null) {
        clientCollections.value = (result['data']['collections'] as List)
            .map((c) => CollectionModel.fromJson(c))
            .toList();
      } else {
        _snack('Error', result['message']);
      }
    } catch (e) {
      _snack('Error', 'Connection error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Reports ──────────────────────────────────────────────────────────────
  Future<void> getSummaryReport(
      {String? startDate, String? endDate, int? clientId}) async {
    try {
      isLoading.value = true;
      final params = <String, String>{};
      if (startDate?.isNotEmpty == true) params['startDate'] = startDate!;
      if (endDate?.isNotEmpty == true) params['endDate'] = endDate!;
      if (clientId != null && clientId > 0)
        params['clientId'] = clientId.toString();

      final uri = Uri.parse(_endpoint('/reports/summary'))
          .replace(queryParameters: params);
      final result = await _call(
        request: () => http.get(uri, headers: getAuthHeaders()),
        tag: 'getSummaryReport',
      );
      if (result['success'] && result['data'] != null) {
        summaryReport.value = (result['data'] as List)
            .map((i) => CollectionSummary.fromJson(i))
            .toList();
      } else {
        _snack('Error', result['message']);
      }
    } catch (e) {
      _snack('Error', 'Connection error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getByClientReport({String? startDate, String? endDate}) async {
    try {
      isLoading.value = true;
      final params = <String, String>{};
      if (startDate?.isNotEmpty == true) params['startDate'] = startDate!;
      if (endDate?.isNotEmpty == true) params['endDate'] = endDate!;

      final uri = Uri.parse(_endpoint('/reports/by-client'))
          .replace(queryParameters: params);
      final result = await _call(
        request: () => http.get(uri, headers: getAuthHeaders()),
        tag: 'getByClientReport',
      );
      if (result['success'] && result['data'] != null) {
        clientReport.value = (result['data'] as List)
            .map((i) => ClientCollectionReport.fromJson(i))
            .toList();
      } else {
        _snack('Error', result['message']);
      }
    } catch (e) {
      _snack('Error', 'Connection error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Pagination helpers ───────────────────────────────────────────────────
  void clearFilters() {
    searchQuery.value = '';
    clientFilter.value = 0;
    startDateFilter.value = '';
    endDateFilter.value = '';
    sortBy.value = 'collection_date';
    sortOrder.value = 'DESC';
  }

  Future<void> loadNextPage({int limit = 20}) async {
    if (currentPage.value < totalPages.value) {
      await getAllCollections(
        page: currentPage.value + 1,
        limit: limit,
        search: searchQuery.value.isNotEmpty ? searchQuery.value : null,
        clientId: clientFilter.value > 0 ? clientFilter.value : null,
        startDate:
            startDateFilter.value.isNotEmpty ? startDateFilter.value : null,
        endDate: endDateFilter.value.isNotEmpty ? endDateFilter.value : null,
        sortByParam: sortBy.value,
        sortOrderParam: sortOrder.value,
      );
    }
  }

  Future<void> loadPreviousPage({int limit = 20}) async {
    if (currentPage.value > 1) {
      await getAllCollections(
        page: currentPage.value - 1,
        limit: limit,
        search: searchQuery.value.isNotEmpty ? searchQuery.value : null,
        clientId: clientFilter.value > 0 ? clientFilter.value : null,
        startDate:
            startDateFilter.value.isNotEmpty ? startDateFilter.value : null,
        endDate: endDateFilter.value.isNotEmpty ? endDateFilter.value : null,
        sortByParam: sortBy.value,
        sortOrderParam: sortOrder.value,
      );
    }
  }

  // ── Misc helpers ─────────────────────────────────────────────────────────
  String getClientName(int id) {
    try {
      return clients.firstWhere((c) => c.clientId == id).clientName;
    } catch (_) {
      return 'Unknown Client';
    }
  }

  bool hasSignatures(CollectionModel c) =>
      (c.dispatcherSignature?.isNotEmpty ?? false) ||
      (c.collectorSignature?.isNotEmpty ?? false);

  bool hasPdf(CollectionModel c) => c.pdfPath?.isNotEmpty ?? false;

  @override
  void onClose() {
    collections.clear();
    recentCollections.clear();
    clientCollections.clear();
    selectedCollection.value = null;
    collectionStats.value = null;
    summaryReport.clear();
    clientReport.clear();
    clients.clear();
    super.onClose();
  }
}

// Dart doesn't have a built-in unawaited() before Dart 3 in some SDKs
void unawaited(Future<dynamic> _) {}
