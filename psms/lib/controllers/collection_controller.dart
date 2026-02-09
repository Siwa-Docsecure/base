// Updated collection_controller.dart with better error handling
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

  // Reactive variables
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

  // Filter variables
  final RxString searchQuery = ''.obs;
  final RxInt clientFilter = 0.obs;
  final RxString startDateFilter = ''.obs;
  final RxString endDateFilter = ''.obs;
  final RxString sortBy = 'collection_date'.obs;
  final RxString sortOrder = 'DESC'.obs;

  // Clients list for dropdowns
  final RxList<ClientModel> clients = <ClientModel>[].obs;

  // Report data
  final RxList<CollectionSummary> summaryReport = <CollectionSummary>[].obs;
  final RxList<ClientCollectionReport> clientReport =
      <ClientCollectionReport>[].obs;

  // Permission check methods
  bool get canCreateCollections =>
      AuthController.instance.hasPermission('canCreateCollections');
  bool get canEditCollections =>
      AuthController.instance.hasPermission('canCreateCollections');
  bool get canDeleteCollections =>
      AuthController.instance.currentUser.value?.role == 'admin';

  // Get auth headers
  Map<String, String> getAuthHeaders() {
    final authController = AuthController.instance;
    return authController.getAuthHeaders();
  }

  // Helper method to get collection endpoint
  String getCollectionEndpoint(String endpoint) {
    return '${ApiConstants.baseUrl}/collections$endpoint';
  }

  // Helper method to safely parse JSON response
  dynamic _parseJsonResponse(String responseBody) {
    try {
      return json.decode(responseBody);
    } catch (e) {
      print('JSON Parse Error: $e');
      print(
        'Response body: ${responseBody.substring(0, min(200, responseBody.length))}',
      );
      return null;
    }
  }

  // Helper method to make API calls with better error handling
  Future<Map<String, dynamic>> _makeApiCall({
    required Future<http.Response> Function() apiCall,
    required String errorMessagePrefix,
  }) async {
    try {
      final response = await apiCall();
      print('API Response Status: ${response.statusCode}');
      print(
        'API Response Body: ${response.body.substring(0, min(200, response.body.length))}...',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = _parseJsonResponse(response.body);

        if (responseData == null) {
          return {
            'success': false,
            'message': 'Invalid server response format',
          };
        }

        if (responseData['status'] == 'success') {
          return {
            'success': true,
            'data': responseData['data'],
            'message': responseData['message'] ?? 'Operation successful',
          };
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'Operation failed',
          };
        }
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final authController = AuthController.instance;
        final refreshSuccess = await authController.refreshAccessToken();

        if (refreshSuccess) {
          // Retry the API call with new token
          final retryResponse = await apiCall();
          final retryData = _parseJsonResponse(retryResponse.body);

          if (retryResponse.statusCode == 200 ||
              retryResponse.statusCode == 201) {
            if (retryData != null && retryData['status'] == 'success') {
              return {
                'success': true,
                'data': retryData['data'],
                'message': retryData['message'] ?? 'Operation successful',
              };
            }
          }
        }

        return {
          'success': false,
          'message': 'Authentication failed. Please login again.',
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Resource not found'};
      } else if (response.statusCode >= 500) {
        return {
          'success': false,
          'message': 'Server error. Please try again later.',
        };
      } else {
        try {
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'message':
                errorData['message'] ??
                'Request failed with status ${response.statusCode}',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Request failed with status ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('API Call Error: $e');
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // ============================================
  // INITIALIZATION & DATA LOADING
  // ============================================

  Future<void> initialize({bool forceRefresh = false}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      print('Initializing CollectionController...');

      // Load data sequentially
      await getAllCollections();
      print('Collections loaded: ${collections.length}');

      await getCollectionStatistics();
      print('Statistics loaded');

      await getRecentCollections();
      print('Recent collections loaded: ${recentCollections.length}');

      await getClients();
      print('Clients loaded: ${clients.length}');

      print('Initialization complete');
    } catch (e) {
      print('Initialize error: $e');
      errorMessage.value = 'Failed to initialize: $e';
      Get.snackbar(
        'Error',
        'Failed to load collection data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Get all clients
  Future<void> getClients() async {
    try {
      final result = await _makeApiCall(
        apiCall:
            () => http.get(
              Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}'),
              headers: getAuthHeaders(),
            ),
        errorMessagePrefix: 'Failed to fetch clients',
      );

      if (result['success'] && result['data'] != null) {
        List<dynamic> clientsData;

        // Handle different response structures
        if (result['data'] is List) {
          clientsData = result['data'];
        } else if (result['data']['clients'] != null) {
          clientsData = result['data']['clients'] as List<dynamic>;
        } else {
          clientsData = [];
        }

        clients.value =
            clientsData.map((client) => ClientModel.fromJson(client)).toList();
      } else {
        errorMessage.value = result['message'];
      }
    } catch (e) {
      print('Error fetching clients: $e');
      errorMessage.value = 'Failed to load clients: $e';
    }
  }

  // ============================================
  // COLLECTION CRUD OPERATIONS (UPDATED)
  // ============================================

  Future<void> getAllCollections({
  int page = 1,
  int limit = 20,
  String? search,
  int? clientId,
  String? startDate,
  String? endDate,
  String? sortBy,
  String? sortOrder,
}) async {
  try {
    isLoading.value = true;
    errorMessage.value = '';

    // Build query parameters
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) params['search'] = search;
    if (clientId != null && clientId > 0) params['clientId'] = clientId.toString();
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    if (sortBy != null && sortBy.isNotEmpty) params['sortBy'] = sortBy;
    if (sortOrder != null && sortOrder.isNotEmpty) params['sortOrder'] = sortOrder;

    final uri = Uri.parse(getCollectionEndpoint('')).replace(queryParameters: params);

    final result = await _makeApiCall(
      apiCall: () => http.get(uri, headers: getAuthHeaders()),
      errorMessagePrefix: 'Failed to fetch collections',
    );

    if (result['success'] && result['data'] != null) {
      final collectionsData = result['data']['collections'] as List<dynamic>;
      
      // Debug: Check if signature data is included
      print('=== DEBUG: Collections Response ===');
      print('Total collections: ${collectionsData.length}');
      if (collectionsData.isNotEmpty) {
        final first = collectionsData.first;
        print('First collection:');
        print('- Has dispatcherSignature: ${first['dispatcherSignature'] != null || first['dispatcher_signature'] != null}');
        print('- Has collectorSignature: ${first['collectorSignature'] != null || first['collector_signature'] != null}');
        
        if (first['dispatcherSignature'] != null) {
          print('- dispatcherSignature type: ${first['dispatcherSignature'].runtimeType}');
        }
        if (first['dispatcher_signature'] != null) {
          print('- dispatcher_signature type: ${first['dispatcher_signature'].runtimeType}');
        }
      }
      print('=== END DEBUG ===');
      
      collections.value = collectionsData.map((col) => CollectionModel.fromJson(col)).toList();
      
      // Debug: Check parsed models
      print('=== DEBUG: Parsed Models ===');
      if (collections.isNotEmpty) {
        final firstModel = collections.first;
        print('First parsed model:');
        print('- dispatcherSignature: ${firstModel.dispatcherSignature != null}');
        print('- collectorSignature: ${firstModel.collectorSignature != null}');
        if (firstModel.dispatcherSignature != null) {
          print('- dispatcherSignature length: ${firstModel.dispatcherSignature!.length}');
        }
      }
      print('=== END DEBUG ===');
      
      currentPage.value = result['data']['pagination']['page'] ?? page;
      totalPages.value = result['data']['pagination']['totalPages'] ?? 1;
      totalCollections.value = result['data']['pagination']['total'] ?? 0;

      // Save filters
      if (search != null) searchQuery.value = search;
      if (clientId != null) clientFilter.value = clientId;
      if (startDate != null) startDateFilter.value = startDate;
      if (endDate != null) endDateFilter.value = endDate;
      if (sortBy != null) this.sortBy.value = sortBy;
      if (sortOrder != null) this.sortOrder.value = sortOrder;
    } else {
      errorMessage.value = result['message'];
      Get.snackbar(
        'Error',
        result['message'],
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  } catch (e) {
    errorMessage.value = 'Connection error: $e';
    Get.snackbar(
      'Error',
      'Connection error: $e',
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  } finally {
    isLoading.value = false;
  }
}
  // Get collection by ID with better signature handling
  Future<CollectionModel?> getCollectionById(int collectionId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall:
            () => http.get(
              Uri.parse(getCollectionEndpoint('/$collectionId')),
              headers: getAuthHeaders(),
            ),
        errorMessagePrefix: 'Failed to fetch collection',
      );

      if (result['success'] && result['data'] != null) {
        final collectionData = result['data'];

        // Debug: Check what we received
        print('=== Collection Details Debug ===');
        print('Collection ID: $collectionId');
        print(
          'Has dispatcherSignature: ${collectionData['dispatcherSignature'] != null}',
        );
        print(
          'Has collectorSignature: ${collectionData['collectorSignature'] != null}',
        );

        if (collectionData['dispatcherSignature'] != null) {
          final sig = collectionData['dispatcherSignature'];
          print('Dispatcher signature type: ${sig.runtimeType}');
          print('Dispatcher signature length: ${sig.length}');
          print(
            'First 50 chars: ${sig.length > 50 ? sig.substring(0, 50) : sig}',
          );
        }

        if (collectionData['collectorSignature'] != null) {
          final sig = collectionData['collectorSignature'];
          print('Collector signature type: ${sig.runtimeType}');
          print('Collector signature length: ${sig.length}');
          print(
            'First 50 chars: ${sig.length > 50 ? sig.substring(0, 50) : sig}',
          );
        }
        print('=== End Debug ===');

        final collection = CollectionModel.fromJson(collectionData);
        selectedCollection.value = collection;
        return collection;
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
    return null;
  }
  
  // Create collection
  Future<bool> createCollection(CreateCollectionRequest request) async {
    try {
      if (!canCreateCollections) {
        errorMessage.value = 'You do not have permission to create collections';
        Get.snackbar(
          'Permission Denied',
          'You do not have permission to create collections',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      }

      // Validate required fields
      if (request.clientId == 0 ||
          request.totalBoxes < 1 ||
          request.dispatcherName.isEmpty ||
          request.collectorName.isEmpty ||
          request.collectionDate.isEmpty) {
        errorMessage.value = 'Please fill all required fields';
        Get.snackbar(
          'Validation Error',
          'Client, total boxes, dispatcher, collector, and date are required',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall:
            () => http.post(
              Uri.parse(getCollectionEndpoint('')),
              headers: {
                ...getAuthHeaders(),
                'Content-Type': 'application/json',
              },
              body: json.encode(request.toJson()),
            ),
        errorMessagePrefix: 'Failed to create collection',
      );

      if (result['success']) {
        Get.snackbar(
          'Success',
          'Collection created successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );

        // Refresh the collections list
        await getAllCollections(page: currentPage.value);
        await getCollectionStatistics();
        await getRecentCollections();

        return true;
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // Update collection
  Future<bool> updateCollection(
    int collectionId,
    UpdateCollectionRequest request,
  ) async {
    try {
      if (!canEditCollections) {
        errorMessage.value = 'You do not have permission to edit collections';
        Get.snackbar(
          'Permission Denied',
          'You do not have permission to edit collections',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall:
            () => http.put(
              Uri.parse(getCollectionEndpoint('/$collectionId')),
              headers: {
                ...getAuthHeaders(),
                'Content-Type': 'application/json',
              },
              body: json.encode(request.toJson()),
            ),
        errorMessagePrefix: 'Failed to update collection',
      );

      if (result['success']) {
        Get.snackbar(
          'Success',
          'Collection updated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Refresh the collection
        await getCollectionById(collectionId);
        // Refresh the collections list
        await getAllCollections(page: currentPage.value);
        return true;
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // Delete collection
  Future<bool> deleteCollection(int collectionId) async {
    try {
      if (!canDeleteCollections) {
        errorMessage.value = 'Only administrators can delete collections';
        Get.snackbar(
          'Permission Denied',
          'Only administrators can delete collections',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall:
            () => http.delete(
              Uri.parse(getCollectionEndpoint('/$collectionId')),
              headers: getAuthHeaders(),
            ),
        errorMessagePrefix: 'Failed to delete collection',
      );

      if (result['success']) {
        Get.snackbar(
          'Success',
          'Collection deleted successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Remove from local list
        collections.removeWhere((col) => col.collectionId == collectionId);
        // Refresh the collections list
        await getAllCollections(page: currentPage.value);
        await getCollectionStatistics();
        await getRecentCollections();

        return true;
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // ============================================
  // QUERY & STATISTICS OPERATIONS (UPDATED)
  // ============================================

  // Get collection statistics
  Future<CollectionStats?> getCollectionStatistics() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall:
            () => http.get(
              Uri.parse(getCollectionEndpoint('/stats')),
              headers: getAuthHeaders(),
            ),
        errorMessagePrefix: 'Failed to fetch statistics',
      );

      if (result['success'] && result['data'] != null) {
        final stats = CollectionStats.fromJson(result['data']);
        collectionStats.value = stats;
        return stats;
      } else {
        errorMessage.value = result['message'];
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
    } finally {
      isLoading.value = false;
    }
    return null;
  }

  // Get recent collections
  Future<void> getRecentCollections({int limit = 10}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final uri = Uri.parse(
        getCollectionEndpoint('/recent'),
      ).replace(queryParameters: {'limit': limit.toString()});

      final result = await _makeApiCall(
        apiCall: () => http.get(uri, headers: getAuthHeaders()),
        errorMessagePrefix: 'Failed to fetch recent collections',
      );

      if (result['success'] && result['data'] != null) {
        final collectionsData = result['data'] as List<dynamic>;
        recentCollections.value =
            collectionsData
                .map((col) => CollectionModel.fromJson(col))
                .toList();
      } else {
        errorMessage.value = result['message'];
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // Get collections by client
  Future<void> getCollectionsByClient(int clientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall:
            () => http.get(
              Uri.parse(getCollectionEndpoint('/client/$clientId')),
              headers: getAuthHeaders(),
            ),
        errorMessagePrefix: 'Failed to fetch client collections',
      );

      if (result['success'] && result['data'] != null) {
        final collectionsData = result['data']['collections'] as List<dynamic>;
        clientCollections.value =
            collectionsData
                .map((col) => CollectionModel.fromJson(col))
                .toList();
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // REPORTING OPERATIONS (UPDATED)
  // ============================================

  // Get summary report
  Future<void> getSummaryReport({
    String? startDate,
    String? endDate,
    int? clientId,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final params = <String, String>{};
      if (startDate != null && startDate.isNotEmpty)
        params['startDate'] = startDate;
      if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
      if (clientId != null && clientId > 0)
        params['clientId'] = clientId.toString();

      final uri = Uri.parse(
        getCollectionEndpoint('/reports/summary'),
      ).replace(queryParameters: params);

      final result = await _makeApiCall(
        apiCall: () => http.get(uri, headers: getAuthHeaders()),
        errorMessagePrefix: 'Failed to fetch summary report',
      );

      if (result['success'] && result['data'] != null) {
        final reportData = result['data'] as List<dynamic>;
        summaryReport.value =
            reportData.map((item) => CollectionSummary.fromJson(item)).toList();
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Get by-client report
  Future<void> getByClientReport({String? startDate, String? endDate}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final params = <String, String>{};
      if (startDate != null && startDate.isNotEmpty)
        params['startDate'] = startDate;
      if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;

      final uri = Uri.parse(
        getCollectionEndpoint('/reports/by-client'),
      ).replace(queryParameters: params);

      final result = await _makeApiCall(
        apiCall: () => http.get(uri, headers: getAuthHeaders()),
        errorMessagePrefix: 'Failed to fetch client report',
      );

      if (result['success'] && result['data'] != null) {
        final reportData = result['data'] as List<dynamic>;
        clientReport.value =
            reportData
                .map((item) => ClientCollectionReport.fromJson(item))
                .toList();
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  // Clear filters
  void clearFilters() {
    searchQuery.value = '';
    clientFilter.value = 0;
    startDateFilter.value = '';
    endDateFilter.value = '';
    sortBy.value = 'collection_date';
    sortOrder.value = 'DESC';
  }

  // Load next page
  Future<void> loadNextPage() async {
    if (currentPage.value < totalPages.value) {
      await getAllCollections(
        page: currentPage.value + 1,
        search: searchQuery.value,
        clientId: clientFilter.value > 0 ? clientFilter.value : null,
        startDate:
            startDateFilter.value.isNotEmpty ? startDateFilter.value : null,
        endDate: endDateFilter.value.isNotEmpty ? endDateFilter.value : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );
    }
  }

  // Load previous page
  Future<void> loadPreviousPage() async {
    if (currentPage.value > 1) {
      await getAllCollections(
        page: currentPage.value - 1,
        search: searchQuery.value,
        clientId: clientFilter.value > 0 ? clientFilter.value : null,
        startDate:
            startDateFilter.value.isNotEmpty ? startDateFilter.value : null,
        endDate: endDateFilter.value.isNotEmpty ? endDateFilter.value : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );
    }
  }

  // Get client name by ID
  String getClientName(int clientId) {
    try {
      final client = clients.firstWhere(
        (client) => client.clientId == clientId,
      );
      return client.clientName;
    } catch (e) {
      return 'Unknown Client';
    }
  }

  // Check if collection has signatures
  bool hasSignatures(CollectionModel collection) {
    return (collection.dispatcherSignature != null &&
            collection.dispatcherSignature!.isNotEmpty) ||
        (collection.collectorSignature != null &&
            collection.collectorSignature!.isNotEmpty);
  }

  // Check if collection has PDF
  bool hasPdf(CollectionModel collection) {
    return collection.pdfPath != null && collection.pdfPath!.isNotEmpty;
  }

  // Dispose controller
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
