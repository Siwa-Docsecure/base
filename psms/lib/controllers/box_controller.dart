// box_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/models/box_model.dart';
import 'package:psms/models/client_model.dart';
import 'package:psms/models/racking_label_model.dart';

class BoxController extends GetxController {
  static BoxController get instance => Get.find();

  // Reactive variables
  final RxList<BoxModel> boxes = <BoxModel>[].obs;
  final RxList<BoxModel> pendingDestructionBoxes = <BoxModel>[].obs;
  final Rx<BoxModel?> selectedBox = Rx<BoxModel?>(null);
  final Rx<BoxStats?> boxStats = Rx<BoxStats?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalBoxes = 0.obs;

  // Filter variables
  final RxString searchQuery = ''.obs;
  final RxString statusFilter = ''.obs;
  final RxInt clientFilter = 0.obs;
  final RxBool pendingDestructionFilter = false.obs;
  final RxString sortBy = 'created_at'.obs;
  final RxString sortOrder = 'DESC'.obs;

  // Permission check methods
  bool get canCreateBoxes =>
      AuthController.instance.hasPermission('canCreateBoxes');
  bool get canEditBoxes =>
      AuthController.instance.hasPermission('canEditBoxes');
  bool get canDeleteBoxes =>
      AuthController.instance.hasPermission('canDeleteBoxes');

  // Add to BoxController class in box_controller.dart
  final RxList<ClientModel> clients = <ClientModel>[].obs;
  final RxList<RackingLabelModel> rackingLabels = <RackingLabelModel>[].obs;
  final RxList<RackingLabelModel> availableRackingLabels =
      <RackingLabelModel>[].obs;

  // Get auth headers
  Map<String, String> getAuthHeaders() {
    final authController = AuthController.instance;
    return authController.getAuthHeaders();
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  // Get client code by client ID
  // In BoxController class

  // Get client code by client ID
  String? getClientCode(int clientId) {
    try {
      if (clients.isEmpty) {
        print('Clients list is empty, cannot find client with ID: $clientId');
        return null;
      }

      // Find the client by ID
      final client = clients.firstWhere(
        (client) => client.clientId == clientId,
      );

      print(
        'Found client: ${client.clientName} with code: ${client.clientCode}',
      );
      return client.clientCode;
    } catch (e) {
      print('Client not found for ID: $clientId. Error: $e');
      return null;
    }
  }

  // Alternative method that handles the case if client is not in the list
  Future<String?> getClientCodeAsync(int clientId) async {
    // First check if client is in the loaded list
    if (clients.isNotEmpty) {
      try {
        final client = clients.firstWhere((c) => c.clientId == clientId);
        return client.clientCode;
      } catch (e) {
        // Client not in the loaded list, try to fetch it
        print('Client $clientId not in loaded list, trying to fetch...');
      }
    }

    // Try to fetch the specific client or reload clients
    try {
      await getClients(); // Reload the clients list

      if (clients.isEmpty) {
        print('Failed to load clients');
        return null;
      }

      final client = clients.firstWhere(
        (client) => client.clientId == clientId,
        orElse:
            () => ClientModel(
              clientId: 0,
              clientName: 'Unknown',
              clientCode: '',
              contactPerson: '',
              isActive: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
      );

      if (client.clientId == 0) {
        print('Client $clientId not found after reload');
        return null;
      }

      return client.clientCode;
    } catch (e) {
      print('Error fetching client code: $e');
      return null;
    }
  }

  // Format full box number from client code and box index
  String formatBoxNumber(String clientCode, String boxIndex) {
    return BoxNumberHelper.formatBoxNumber(clientCode, boxIndex);
  }

  // Validate box index
  // bool validateBoxIndex(String boxIndex) {
  //   if (boxIndex.trim().isEmpty) {
  //     errorMessage.value = 'Box index cannot be empty';
  //     return false;
  //   }
  //   return true;
  // }

  // ============================================
  // BOX CRUD OPERATIONS
  // ============================================

  // getClients method
  Future<void> getClients() async {
    try {
      print('Fetching clients...');

      // Try both endpoints - adjust based on your actual API
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}');
      print('Fetching from: $uri');

      final response = await http.get(uri, headers: getAuthHeaders());

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Response data: $responseData');

        if (responseData['status'] == 'success') {
          List<dynamic> clientsData;

          // Handle different response structures
          if (responseData['data'] is List) {
            clientsData = responseData['data'];
          } else if (responseData['data'] != null &&
              responseData['data']['clients'] != null) {
            clientsData = responseData['data']['clients'] as List<dynamic>;
          } else {
            clientsData = [];
          }

          print('Clients data found: ${clientsData.length} items');

          clients.value =
              clientsData
                  .map((client) => ClientModel.fromJson(client))
                  .toList();

          print('Clients loaded successfully: ${clients.length}');
        } else {
          print('API error: ${responseData['message']}');
          // Try alternative endpoint for active clients
          await _fetchClientsAlternative();
        }
      } else if (response.statusCode == 401) {
        // Token expired, refresh and retry
        await AuthController.instance.refreshAccessToken();
        await getClients();
      } else {
        print('HTTP error: ${response.statusCode}');
        await _fetchClientsAlternative();
      }
    } catch (e) {
      print('Error fetching clients: $e');
      errorMessage.value = 'Failed to load clients: $e';
    }
  }

  // Alternative method for fetching clients
  Future<void> _fetchClientsAlternative() async {
    try {
      print('Trying alternative endpoint...');

      // Try the clientsActive endpoint
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clientsActive}'),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Alternative response: $responseData');

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final clientsData = responseData['data'] as List<dynamic>;
          clients.value =
              clientsData
                  .map((client) => ClientModel.fromJson(client))
                  .toList();
          print('Alternative clients loaded: ${clients.length}');
        }
      }
    } catch (e) {
      print('Alternative fetch failed: $e');
    }
  }

  // Get all racking labels
  Future<void> getRackingLabels() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.rackingLabels}'),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final labelsData = responseData['data'] as List<dynamic>;
          rackingLabels.value =
              labelsData
                  .map((label) => RackingLabelModel.fromJson(label))
                  .toList();
        }
      }
    } catch (e) {
      print('Error fetching racking labels: $e');
    }
  }

  // Get available racking labels
  Future<void> getAvailableRackingLabels() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.availableRackingLabels}',
        ),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final labelsData = responseData['data'] as List<dynamic>;
          availableRackingLabels.value =
              labelsData
                  .map((label) => RackingLabelModel.fromJson(label))
                  .toList();
        }
      }
    } catch (e) {
      print('Error fetching available racking labels: $e');
    }
  }

  // Update initialize method to load clients and racking labels
  Future<void> initialize({bool forceRefresh = false}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      print('Initializing BoxController...');

      // Load data sequentially to avoid race conditions
      await getAllBoxes();
      print('Boxes loaded: ${boxes.length}');

      await getClients();
      print('Clients loaded: ${clients.length}');

      await getRackingLabels();
      print('Racking labels loaded: ${rackingLabels.length}');

      await getAvailableRackingLabels();
      print('Available racking labels: ${availableRackingLabels.length}');

      await getBoxStatistics();
      await getPendingDestructionBoxes();

      print('Initialization complete');
    } catch (e) {
      print('Initialize error: $e');
      errorMessage.value = 'Failed to initialize: $e';
      Get.snackbar(
        'Error',
        'Failed to load data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Get all boxes with filtering
  Future<void> getAllBoxes({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    int? clientId,
    bool? pendingDestruction,
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
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (clientId != null && clientId > 0)
        params['clientId'] = clientId.toString();
      if (pendingDestruction != null && pendingDestruction)
        params['pendingDestruction'] = 'true';
      if (sortBy != null && sortBy.isNotEmpty) params['sortBy'] = sortBy;
      if (sortOrder != null && sortOrder.isNotEmpty)
        params['sortOrder'] = sortOrder;

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.boxes}',
      ).replace(queryParameters: params);

      final response = await http.get(uri, headers: getAuthHeaders());

      if (response.statusCode == 200) {
        final boxResponse = BoxesResponse.fromJson(json.decode(response.body));

        if (boxResponse.status == 'success' && boxResponse.data != null) {
          boxes.value = boxResponse.data!.boxes;
          currentPage.value = boxResponse.data!.pagination?.page ?? page;
          totalPages.value = boxResponse.data!.pagination?.totalPages ?? 1;
          totalBoxes.value = boxResponse.data!.pagination?.total ?? 0;

          // Save filters
          if (search != null) searchQuery.value = search;
          if (status != null) statusFilter.value = status;
          if (clientId != null) clientFilter.value = clientId;
          if (pendingDestruction != null)
            pendingDestructionFilter.value = pendingDestruction;
          if (sortBy != null) this.sortBy.value = sortBy;
          if (sortOrder != null) this.sortOrder.value = sortOrder;
        } else {
          errorMessage.value = boxResponse.message;
          Get.snackbar(
            'Error',
            boxResponse.message,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value =
            errorResponse['message'] ?? 'Failed to fetch boxes';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to fetch boxes',
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

  // Get box by ID
  Future<BoxModel?> getBoxById(int boxId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.boxById(boxId.toString())}',
        ),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final box = BoxModel.fromJson(responseData['data']);
          selectedBox.value = box;
          return box;
        } else {
          errorMessage.value = responseData['message'];
          Get.snackbar(
            'Error',
            responseData['message'],
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to fetch box';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to fetch box',
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

  // Create box (UPDATED for custom box indexing)
  Future<bool> createBox(CreateBoxRequest request) async {
    try {
      if (!canCreateBoxes) {
        errorMessage.value = 'You do not have permission to create boxes';
        Get.snackbar(
          'Permission Denied',
          'You do not have permission to create boxes',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      }

      // Validate box index
      if (request.boxIndex.trim().isEmpty) {
        errorMessage.value = 'Box index is required';
        Get.snackbar(
          'Validation Error',
          'Box index is required',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      // Get client code to show in preview
      String? clientCode = getClientCode(request.clientId);

      // If client not found in loaded list, try to fetch it
      if (clientCode == null) {
        print('Client not found in loaded list, trying to fetch...');
        clientCode = await getClientCodeAsync(request.clientId);
      }

      if (clientCode == null || clientCode.isEmpty) {
        errorMessage.value = 'Client not found or client code is empty';
        Get.snackbar(
          'Error',
          'Client not found or client code is empty',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      // Show preview of box number
      final fullBoxNumber = BoxNumberHelper.formatBoxNumber(
        clientCode,
        request.boxIndex,
      );
      print('Creating box with number: $fullBoxNumber');

      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.boxes}'),
        headers: getAuthHeaders(),
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Box created successfully\nBox Number: $fullBoxNumber',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );

          // Refresh the boxes list
          await getAllBoxes(page: currentPage.value);
          return true;
        } else {
          errorMessage.value = responseData['message'];
          Get.snackbar(
            'Error',
            responseData['message'],
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to create box';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to create box',
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

  // Update box
  Future<bool> updateBox(int boxId, UpdateBoxRequest request) async {
    try {
      if (!canEditBoxes) {
        errorMessage.value = 'You do not have permission to edit boxes';
        Get.snackbar(
          'Permission Denied',
          'You do not have permission to edit boxes',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.put(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.boxById(boxId.toString())}',
        ),
        headers: getAuthHeaders(),
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Box updated successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          // Refresh the box
          await getBoxById(boxId);
          // Refresh the boxes list
          await getAllBoxes(page: currentPage.value);
          return true;
        } else {
          errorMessage.value = responseData['message'];
          Get.snackbar(
            'Error',
            responseData['message'],
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to update box';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to update box',
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

  // Change box status
  Future<bool> changeBoxStatus(int boxId, String status) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.patch(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.boxStatus(boxId.toString())}',
        ),
        headers: getAuthHeaders(),
        body: json.encode(ChangeBoxStatusRequest(status: status).toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Box status changed to ${status.capitalizeFirst}',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          // Refresh the box
          await getBoxById(boxId);
          // Refresh the boxes list
          await getAllBoxes(page: currentPage.value);
          // Refresh pending destruction boxes if applicable
          if (status == 'destroyed') {
            await getPendingDestructionBoxes();
          }
          return true;
        } else {
          errorMessage.value = responseData['message'];
          Get.snackbar(
            'Error',
            responseData['message'],
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value =
            errorResponse['message'] ?? 'Failed to change box status';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to change box status',
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

  // Delete box
  Future<bool> deleteBox(int boxId) async {
    try {
      if (!canDeleteBoxes) {
        errorMessage.value = 'You do not have permission to delete boxes';
        Get.snackbar(
          'Permission Denied',
          'You do not have permission to delete boxes',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.delete(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.boxById(boxId.toString())}',
        ),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Box deleted successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          // Remove from local list
          boxes.removeWhere((box) => box.boxId == boxId);
          // Refresh the boxes list
          await getAllBoxes(page: currentPage.value);
          return true;
        } else {
          errorMessage.value = responseData['message'];
          Get.snackbar(
            'Error',
            responseData['message'],
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to delete box';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to delete box',
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
  // QUERY & FILTER OPERATIONS
  // ============================================

  // Get box statistics
  Future<BoxStats?> getBoxStatistics() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.boxStats}'),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final stats = BoxStats.fromJson(responseData['data']);
          boxStats.value = stats;
          return stats;
        } else {
          errorMessage.value = responseData['message'];
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value =
            errorResponse['message'] ?? 'Failed to fetch statistics';
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
    } finally {
      isLoading.value = false;
    }
    return null;
  }

  // Get pending destruction boxes
  Future<void> getPendingDestructionBoxes() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.pendingDestruction}'),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final boxesData = responseData['data']['boxes'] as List<dynamic>;
          pendingDestructionBoxes.value =
              boxesData.map((box) => BoxModel.fromJson(box)).toList();
        } else {
          errorMessage.value = responseData['message'];
          Get.snackbar(
            'Error',
            responseData['message'],
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value =
            errorResponse['message'] ??
            'Failed to fetch pending destruction boxes';
        Get.snackbar(
          'Error',
          errorResponse['message'] ??
              'Failed to fetch pending destruction boxes',
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

  // Get boxes by client
  Future<void> getBoxesByClient(int clientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.boxesByClient(clientId.toString())}',
        ),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final boxesData = responseData['data']['boxes'] as List<dynamic>;
          boxes.value = boxesData.map((box) => BoxModel.fromJson(box)).toList();
        } else {
          errorMessage.value = responseData['message'];
          Get.snackbar(
            'Error',
            responseData['message'],
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value =
            errorResponse['message'] ?? 'Failed to fetch client boxes';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to fetch client boxes',
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
  // BULK OPERATIONS
  // ============================================

  // Bulk create boxes (UPDATED for custom box indexing)
  Future<Map<String, dynamic>> bulkCreateBoxes(
    BulkCreateBoxRequest request,
  ) async {
    try {
      if (!canCreateBoxes) {
        return {
          'success': false,
          'message': 'You do not have permission to create boxes',
        };
      }

      // Validate all box indices
      for (var box in request.boxes) {
        if (box.boxIndex.trim().isEmpty) {
          return {
            'success': false,
            'message': 'Box index cannot be empty for all boxes',
          };
        }
      }

      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bulkCreateBoxes}'),
        headers: getAuthHeaders(),
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Bulk box creation completed',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          // Refresh the boxes list
          await getAllBoxes(page: currentPage.value);

          return {
            'success': true,
            'data': responseData['data'],
            'message': responseData['message'],
          };
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value =
            errorResponse['message'] ?? 'Failed to bulk create boxes';
        return {
          'success': false,
          'message': errorResponse['message'] ?? 'Failed to bulk create boxes',
        };
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      return {'success': false, 'message': 'Connection error: $e'};
    } finally {
      isLoading.value = false;
    }
  }

  // Bulk update box status
  Future<bool> bulkUpdateBoxStatus(List<int> boxIds, String status) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bulkUpdateStatus}'),
        headers: getAuthHeaders(),
        body: json.encode(
          BulkUpdateStatusRequest(boxIds: boxIds, status: status).toJson(),
        ),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          Get.snackbar(
            'Success',
            '${boxIds.length} boxes updated to ${status.capitalizeFirst} status',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          // Refresh the boxes list
          await getAllBoxes(page: currentPage.value);
          // Refresh pending destruction boxes if status changed to destroyed
          if (status == 'destroyed') {
            await getPendingDestructionBoxes();
          }
          return true;
        } else {
          errorMessage.value = responseData['message'];
          Get.snackbar(
            'Error',
            responseData['message'],
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value =
            errorResponse['message'] ?? 'Failed to bulk update box status';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to bulk update box status',
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
  // HELPER METHODS
  // ============================================

  // Clear filters
  void clearFilters() {
    searchQuery.value = '';
    statusFilter.value = '';
    clientFilter.value = 0;
    pendingDestructionFilter.value = false;
    sortBy.value = 'created_at';
    sortOrder.value = 'DESC';
  }

  // Check if box can be edited
  bool canEditBox(BoxModel box) {
    if (!canEditBoxes) return false;
    // Additional business logic if needed
    return true;
  }

  // Check if box can be deleted
  bool canDeleteBox(BoxModel box) {
    if (!canDeleteBoxes) return false;
    // Additional business logic if needed
    return box.status != 'destroyed';
  }

  // Load next page
  Future<void> loadNextPage() async {
    if (currentPage.value < totalPages.value) {
      await getAllBoxes(
        page: currentPage.value + 1,
        search: searchQuery.value,
        status: statusFilter.value,
        clientId: clientFilter.value > 0 ? clientFilter.value : null,
        pendingDestruction: pendingDestructionFilter.value,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );
    }
  }

  // Load previous page
  Future<void> loadPreviousPage() async {
    if (currentPage.value > 1) {
      await getAllBoxes(
        page: currentPage.value - 1,
        search: searchQuery.value,
        status: statusFilter.value,
        clientId: clientFilter.value > 0 ? clientFilter.value : null,
        pendingDestruction: pendingDestructionFilter.value,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );
    }
  }

  // Dispose controller
  @override
  void onClose() {
    boxes.clear();
    pendingDestructionBoxes.clear();
    selectedBox.value = null;
    boxStats.value = null;
    super.onClose();
  }
}
