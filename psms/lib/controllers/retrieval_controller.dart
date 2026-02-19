import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/models/client_model.dart';
import 'package:psms/models/retrieval_model.dart';

class RetrievalController extends GetxController {
  static RetrievalController get instance => Get.find();

  // ============================================
  // REACTIVE VARIABLES
  // ============================================

  final RxList<RetrievalModel> retrievals = <RetrievalModel>[].obs;
  final RxList<RetrievalModel> recentRetrievals = <RetrievalModel>[].obs;
  final RxList<RetrievalModel> pendingRetrievals = <RetrievalModel>[].obs;
  final RxList<RetrievalModel> myPendingRetrievals = <RetrievalModel>[].obs;
  final RxList<RetrievalModel> clientRetrievals = <RetrievalModel>[].obs;
  final RxList<RetrievalModel> boxRetrievals = <RetrievalModel>[].obs;
  final Rx<RetrievalModel?> selectedRetrieval = Rx<RetrievalModel?>(null);
  final Rx<RetrievalStats?> retrievalStats = Rx<RetrievalStats?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalRetrievals = 0.obs;

  // Filter variables
  final RxString searchQuery = ''.obs;
  final RxInt clientFilter = 0.obs;
  final RxInt boxFilter = 0.obs;
  final RxString startDateFilter = ''.obs;
  final RxString endDateFilter = ''.obs;
  final RxString sortBy = 'retrieval_date'.obs;
  final RxString sortOrder = 'DESC'.obs;

  // Clients list for dropdowns
  final RxList<ClientModel> clients = <ClientModel>[].obs;

  // Report data
  final RxList<RetrievalSummary> summaryReport = <RetrievalSummary>[].obs;
  final RxList<ClientRetrievalReport> clientReport =
      <ClientRetrievalReport>[].obs;

  // ============================================
  // PERMISSION CHECKS
  // ============================================

  bool get canCreateRetrievals =>
      AuthController.instance.hasPermission('canCreateRetrievals');
  bool get canEditRetrievals =>
      AuthController.instance.hasPermission('canCreateRetrievals');
  bool get canDeleteRetrievals =>
      AuthController.instance.currentUser.value?.role == 'admin';
  bool get canSignRetrievals =>
      AuthController.instance.hasPermission('canSignRetrievals');
  bool get isClient =>
      AuthController.instance.currentUser.value?.role == 'client';

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Get authenticated headers
  Map<String, String> getAuthHeaders() {
    return AuthController.instance.getAuthHeaders();
  }

  /// Safely parse JSON response
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

  /// Make API call with comprehensive error handling
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

      print('Initializing RetrievalController...');

      // Load data sequentially
      await getAllRetrievals();
      print('Retrievals loaded: ${retrievals.length}');

      await getRetrievalStatistics();
      print('Statistics loaded');

      await getRecentRetrievals();
      print('Recent retrievals loaded: ${recentRetrievals.length}');

      // If client, load their pending retrievals
      if (isClient) {
        await getMyPendingRetrievals();
        print('My pending retrievals loaded: ${myPendingRetrievals.length}');
      } else {
        await getPendingRetrievals();
        print('Pending retrievals loaded: ${pendingRetrievals.length}');
      }

      await getClients();
      print('Clients loaded: ${clients.length}');

      print('Initialization complete');
    } catch (e) {
      print('Initialize error: $e');
      errorMessage.value = 'Failed to initialize: $e';
      Get.snackbar(
        'Error',
        'Failed to load retrieval data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Get all clients for dropdown/filters
  Future<void> getClients() async {
    try {
      final result = await _makeApiCall(
        apiCall: () => http.get(
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
  // RETRIEVAL CRUD OPERATIONS
  // ============================================

  /// Get all retrievals with filtering and pagination
  Future<void> getAllRetrievals({
    int page = 1,
    int limit = 50,
    String? search,
    int? clientId,
    int? boxId,
    String? startDate,
    String? endDate,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (search != null && search.isNotEmpty) params['search'] = search;
      if (clientId != null && clientId > 0) {
        params['clientId'] = clientId.toString();
      }
      if (boxId != null && boxId > 0) params['boxId'] = boxId.toString();
      if (startDate != null && startDate.isNotEmpty) {
        params['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
      if (sortBy != null && sortBy.isNotEmpty) params['sortBy'] = sortBy;
      if (sortOrder != null && sortOrder.isNotEmpty) {
        params['sortOrder'] = sortOrder;
      }

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.retrievals}',
      ).replace(queryParameters: params);

      final result = await _makeApiCall(
        apiCall: () => http.get(uri, headers: getAuthHeaders()),
        errorMessagePrefix: 'Failed to fetch retrievals',
      );

      if (result['success'] && result['data'] != null) {
        final data = result['data'];

        // Parse retrievals
        final retrievalsData = data['retrievals'] as List<dynamic>;
        retrievals.value =
            retrievalsData.map((ret) => RetrievalModel.fromJson(ret)).toList();

        // Parse pagination
        if (data['pagination'] != null) {
          currentPage.value = data['pagination']['page'] ?? 1;
          totalPages.value = data['pagination']['totalPages'] ?? 1;
          totalRetrievals.value = data['pagination']['total'] ?? 0;
        }
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

  /// Get retrieval by ID
  Future<void> getRetrievalById(int retrievalId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall: () => http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.retrievalById(retrievalId.toString())}',
          ),
          headers: getAuthHeaders(),
        ),
        errorMessagePrefix: 'Failed to fetch retrieval',
      );

      if (result['success'] && result['data'] != null) {
        selectedRetrieval.value = RetrievalModel.fromJson(result['data']);
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

  /// Create new retrieval
  Future<bool> createRetrieval(CreateRetrievalRequest request) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall: () => http.post(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.retrievals}'),
          headers: {
            ...getAuthHeaders(),
            'Content-Type': 'application/json',
          },
          body: json.encode(request.toJson()),
        ),
        errorMessagePrefix: 'Failed to create retrieval',
      );

      if (result['success']) {
        Get.snackbar(
          'Success',
          result['message'],
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        await getAllRetrievals(); // Refresh list
        await getPendingRetrievals(); // Refresh pending list
        return true;
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete retrieval (Admin only)
  Future<bool> deleteRetrieval(int retrievalId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall: () => http.delete(
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.retrievalById(retrievalId.toString())}',
          ),
          headers: getAuthHeaders(),
        ),
        errorMessagePrefix: 'Failed to delete retrieval',
      );

      if (result['success']) {
        Get.snackbar(
          'Success',
          result['message'],
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        retrievals.removeWhere((ret) => ret.retrievalId == retrievalId);
        return true;
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // STATISTICS & SPECIAL RETRIEVALS
  // ============================================

  /// Get retrieval statistics
  Future<void> getRetrievalStatistics() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall: () => http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.retrievalStats}',
          ),
          headers: getAuthHeaders(),
        ),
        errorMessagePrefix: 'Failed to fetch statistics',
      );

      if (result['success'] && result['data'] != null) {
        retrievalStats.value = RetrievalStats.fromJson(result['data']);
      } else {
        errorMessage.value = result['message'];
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Get recent retrievals
  Future<void> getRecentRetrievals({int limit = 10}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final params = {'limit': limit.toString()};
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.recentRetrievals}',
      ).replace(queryParameters: params);

      final result = await _makeApiCall(
        apiCall: () => http.get(uri, headers: getAuthHeaders()),
        errorMessagePrefix: 'Failed to fetch recent retrievals',
      );

      if (result['success'] && result['data'] != null) {
        final retrievalsData = result['data'] as List<dynamic>;
        recentRetrievals.value =
            retrievalsData.map((ret) => RetrievalModel.fromJson(ret)).toList();
      } else {
        errorMessage.value = result['message'];
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Get pending retrievals (awaiting client signature) - Admin/Staff view
  Future<void> getPendingRetrievals({int? clientId, int limit = 50}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final params = {'limit': limit.toString()};
      if (clientId != null && clientId > 0) {
        params['clientId'] = clientId.toString();
      }

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.pendingRetrievals}',
      ).replace(queryParameters: params);

      final result = await _makeApiCall(
        apiCall: () => http.get(uri, headers: getAuthHeaders()),
        errorMessagePrefix: 'Failed to fetch pending retrievals',
      );

      if (result['success'] && result['data'] != null) {
        final data = result['data'];

        // Handle different response structures
        List<dynamic> retrievalsData;
        if (data is List) {
          retrievalsData = data;
        } else if (data['retrievals'] != null) {
          retrievalsData = data['retrievals'] as List<dynamic>;
        } else {
          retrievalsData = [];
        }

        pendingRetrievals.value =
            retrievalsData.map((ret) => RetrievalModel.fromJson(ret)).toList();
      } else {
        errorMessage.value = result['message'];
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Get my pending retrievals (Client view - awaiting their signature)
  Future<void> getMyPendingRetrievals() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall: () => http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.myPendingRetrievals}',
          ),
          headers: getAuthHeaders(),
        ),
        errorMessagePrefix: 'Failed to fetch my pending retrievals',
      );

      if (result['success'] && result['data'] != null) {
        final data = result['data'];

        // Handle different response structures
        List<dynamic> retrievalsData;
        if (data is List) {
          retrievalsData = data;
        } else if (data['retrievals'] != null) {
          retrievalsData = data['retrievals'] as List<dynamic>;
        } else {
          retrievalsData = [];
        }

        myPendingRetrievals.value =
            retrievalsData.map((ret) => RetrievalModel.fromJson(ret)).toList();
      } else {
        errorMessage.value = result['message'];
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Get retrievals by client
  Future<void> getRetrievalsByClient(int clientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall: () => http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.retrievalsByClient(clientId.toString())}',
          ),
          headers: getAuthHeaders(),
        ),
        errorMessagePrefix: 'Failed to fetch client retrievals',
      );

      if (result['success'] && result['data'] != null) {
        // Handle different response structures
        List<dynamic> retrievalsData;
        if (result['data'] is List) {
          retrievalsData = result['data'];
        } else if (result['data']['retrievals'] != null) {
          retrievalsData = result['data']['retrievals'] as List<dynamic>;
        } else {
          retrievalsData = [];
        }

        clientRetrievals.value =
            retrievalsData.map((ret) => RetrievalModel.fromJson(ret)).toList();
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

  /// Get retrievals by box (retrieval history for a specific box)
  Future<void> getRetrievalsByBox(int boxId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall: () => http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.retrievalsByBox(boxId.toString())}',
          ),
          headers: getAuthHeaders(),
        ),
        errorMessagePrefix: 'Failed to fetch box retrievals',
      );

      if (result['success'] && result['data'] != null) {
        // Handle different response structures
        List<dynamic> retrievalsData;
        if (result['data'] is List) {
          retrievalsData = result['data'];
        } else if (result['data']['retrievals'] != null) {
          retrievalsData = result['data']['retrievals'] as List<dynamic>;
        } else {
          retrievalsData = [];
        }

        boxRetrievals.value =
            retrievalsData.map((ret) => RetrievalModel.fromJson(ret)).toList();
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
  // SIGNATURE OPERATIONS
  // ============================================

  /// Update retrieval signatures (client or staff)
  /// Note: Client signature triggers box status change to 'retrieved'
  Future<bool> updateSignatures({
    required int retrievalId,
    String? clientSignature,
    String? staffSignature,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final requestBody = <String, dynamic>{};
      if (clientSignature != null) {
        requestBody['clientSignature'] = clientSignature;
      }
      if (staffSignature != null) {
        requestBody['staffSignature'] = staffSignature;
      }

      final result = await _makeApiCall(
        apiCall: () => http.patch(
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.retrievalSignatures(retrievalId.toString())}',
          ),
          headers: {
            ...getAuthHeaders(),
            'Content-Type': 'application/json',
          },
          body: json.encode(requestBody),
        ),
        errorMessagePrefix: 'Failed to update signatures',
      );

      if (result['success']) {
        Get.snackbar(
          'Success',
          result['message'],
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        
        // Refresh data
        await getRetrievalById(retrievalId);
        await getAllRetrievals();
        if (isClient) {
          await getMyPendingRetrievals();
        } else {
          await getPendingRetrievals();
        }
        
        return true;
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update PDF path for retrieval
  Future<bool> updatePdfPath(int retrievalId, String pdfPath) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall: () => http.patch(
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.retrievalPdf(retrievalId.toString())}',
          ),
          headers: {
            ...getAuthHeaders(),
            'Content-Type': 'application/json',
          },
          body: json.encode({'pdfPath': pdfPath}),
        ),
        errorMessagePrefix: 'Failed to update PDF path',
      );

      if (result['success']) {
        Get.snackbar(
          'Success',
          result['message'],
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Manually mark box as retrieved (override/manual process)
  /// Normally done via client signature, this is for exceptional cases
  Future<bool> markBoxAsRetrieved(int boxId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _makeApiCall(
        apiCall: () => http.patch(
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.markBoxRetrieved(boxId.toString())}',
          ),
          headers: getAuthHeaders(),
        ),
        errorMessagePrefix: 'Failed to mark box as retrieved',
      );

      if (result['success']) {
        Get.snackbar(
          'Success',
          result['message'],
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } else {
        errorMessage.value = result['message'];
        Get.snackbar(
          'Error',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // REPORTING OPERATIONS
  // ============================================

  /// Get summary report by date range
  Future<void> getSummaryReport({
    String? startDate,
    String? endDate,
    int? clientId,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final params = <String, String>{};
      if (startDate != null && startDate.isNotEmpty) {
        params['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
      if (clientId != null && clientId > 0) {
        params['clientId'] = clientId.toString();
      }

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.retrievalSummaryReport}',
      ).replace(queryParameters: params);

      final result = await _makeApiCall(
        apiCall: () => http.get(uri, headers: getAuthHeaders()),
        errorMessagePrefix: 'Failed to fetch summary report',
      );

      if (result['success'] && result['data'] != null) {
        final reportData = result['data'] as List<dynamic>;
        summaryReport.value =
            reportData.map((item) => RetrievalSummary.fromJson(item)).toList();
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

  /// Get by-client report
  Future<void> getByClientReport({String? startDate, String? endDate}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final params = <String, String>{};
      if (startDate != null && startDate.isNotEmpty) {
        params['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.retrievalByClientReport}',
      ).replace(queryParameters: params);

      final result = await _makeApiCall(
        apiCall: () => http.get(uri, headers: getAuthHeaders()),
        errorMessagePrefix: 'Failed to fetch client report',
      );

      if (result['success'] && result['data'] != null) {
        final reportData = result['data'] as List<dynamic>;
        clientReport.value = reportData
            .map((item) => ClientRetrievalReport.fromJson(item))
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
  // UTILITY METHODS
  // ============================================

  /// Clear all filters
  void clearFilters() {
    searchQuery.value = '';
    clientFilter.value = 0;
    boxFilter.value = 0;
    startDateFilter.value = '';
    endDateFilter.value = '';
    sortBy.value = 'retrieval_date';
    sortOrder.value = 'DESC';
  }

  /// Load next page
  Future<void> loadNextPage() async {
    if (currentPage.value < totalPages.value) {
      await getAllRetrievals(
        page: currentPage.value + 1,
        search: searchQuery.value,
        clientId: clientFilter.value > 0 ? clientFilter.value : null,
        boxId: boxFilter.value > 0 ? boxFilter.value : null,
        startDate:
            startDateFilter.value.isNotEmpty ? startDateFilter.value : null,
        endDate: endDateFilter.value.isNotEmpty ? endDateFilter.value : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );
    }
  }

  /// Load previous page
  Future<void> loadPreviousPage() async {
    if (currentPage.value > 1) {
      await getAllRetrievals(
        page: currentPage.value - 1,
        search: searchQuery.value,
        clientId: clientFilter.value > 0 ? clientFilter.value : null,
        boxId: boxFilter.value > 0 ? boxFilter.value : null,
        startDate:
            startDateFilter.value.isNotEmpty ? startDateFilter.value : null,
        endDate: endDateFilter.value.isNotEmpty ? endDateFilter.value : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );
    }
  }

  /// Get client name by ID
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

  /// Check if retrieval has signatures
  bool hasSignatures(RetrievalModel retrieval) {
    return retrieval.hasClientSignature || retrieval.hasStaffSignature;
  }

  /// Check if retrieval is complete (has client signature)
  bool isRetrievalComplete(RetrievalModel retrieval) {
    return retrieval.isComplete;
  }

  /// Check if retrieval has PDF
  bool hasPdf(RetrievalModel retrieval) {
    return retrieval.pdfPath != null && retrieval.pdfPath!.isNotEmpty;
  }

  /// Check if retrieval is pending client signature
  bool isPendingClientSignature(RetrievalModel retrieval) {
    return !retrieval.hasClientSignature;
  }

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
    selectedRetrieval.value = null;
    retrievalStats.value = null;
    summaryReport.clear();
    clientReport.clear();
    clients.clear();
    super.onClose();
  }
}