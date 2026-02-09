// lib/controllers/client_management_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/models/client_model.dart';

class ClientManagementController extends GetxController {
  final AuthController _authController = Get.find<AuthController>();

  // Observable variables
  final RxBool isLoading = false.obs;
  final RxBool isSearching = false.obs;
  final RxList<ClientModel> clients = <ClientModel>[].obs;
  final RxString searchQuery = ''.obs;
  final RxString sortBy = 'created_at'.obs;
  final RxString sortOrder = 'DESC'.obs;
  final RxBool includeInactive = false.obs;
  final RxString filterStatus = 'all'.obs; // all, active, inactive

  // View mode - 'table' or 'grid'
  final RxString viewMode = 'table'.obs;

  // Bulk selection
  final RxBool isBulkSelectMode = false.obs;
  final RxList<int> selectedClientIds = <int>[].obs;

  // Pagination
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalItems = 0.obs;
  final RxInt itemsPerPage = 20.obs;

  // Statistics
  final RxMap<String, dynamic> stats = <String, dynamic>{}.obs;

  // Selected client
  final Rx<ClientModel?> selectedClient = Rx<ClientModel?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchClients();
    fetchStats();
  }

  // Toggle view mode
  void toggleViewMode() {
    viewMode.value = viewMode.value == 'table' ? 'grid' : 'table';
  }

  // Toggle bulk select mode
  void toggleBulkSelectMode() {
    isBulkSelectMode.value = !isBulkSelectMode.value;
    if (!isBulkSelectMode.value) {
      selectedClientIds.clear();
    }
  }

  // Toggle client selection
  void toggleClientSelection(int clientId) {
    if (selectedClientIds.contains(clientId)) {
      selectedClientIds.remove(clientId);
    } else {
      selectedClientIds.add(clientId);
    }
  }

  // Select all clients
  void selectAllClients() {
    selectedClientIds.clear();
    selectedClientIds.addAll(clients.map((c) => c.clientId));
  }

  // Clear selection
  void clearSelection() {
    selectedClientIds.clear();
  }

  // Fetch stats
  Future<void> fetchStats() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}/statistics'),
        headers: _authController.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          stats.value = data['data'];
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch stats: $e');
    }
  }

  // Fetch all clients
  Future<void> fetchClients({bool showLoading = true}) async {
    try {
      if (showLoading) isLoading.value = true;

      final queryParams = {
        'page': currentPage.value.toString(),
        'limit': itemsPerPage.value.toString(),
        'sortBy': sortBy.value,
        'sortOrder': sortOrder.value,
        if (searchQuery.value.isNotEmpty) 'search': searchQuery.value,
        if (filterStatus.value != 'all') 
          'isActive': (filterStatus.value == 'active').toString(),
        'includeInactive': includeInactive.value.toString(),
      };

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _authController.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final clientsList = (data['data']['clients'] as List)
              .map((json) => ClientModel.fromJson(json))
              .toList();
          
          clients.value = clientsList;
          
          // Update pagination
          final pagination = data['data']['pagination'];
          currentPage.value = pagination['currentPage'];
          totalPages.value = pagination['totalPages'];
          totalItems.value = pagination['totalItems'];
          itemsPerPage.value = pagination['itemsPerPage'];
        }
      } else if (response.statusCode == 401) {
        await _authController.refreshAccessToken();
        return fetchClients(showLoading: false);
      } else {
        throw Exception('Failed to fetch clients');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to fetch clients: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Search clients
  void searchClients(String query) {
    searchQuery.value = query;
    currentPage.value = 1;
    fetchClients();
  }

  // Filter clients
  void filterClients(String status) {
    filterStatus.value = status;
    currentPage.value = 1;
    fetchClients();
  }

  // Sort clients
  void sortClients(String field) {
    if (sortBy.value == field) {
      sortOrder.value = sortOrder.value == 'ASC' ? 'DESC' : 'ASC';
    } else {
      sortBy.value = field;
      sortOrder.value = 'ASC';
    }
    fetchClients();
  }

  // Change page
  void changePage(int page) {
    if (page >= 1 && page <= totalPages.value) {
      currentPage.value = page;
      fetchClients();
    }
  }

  // Get client by ID
  Future<ClientModel?> getClientById(int clientId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}/$clientId'),
        headers: _authController.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return ClientModel.fromJson(data['data']);
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to fetch client details: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    return null;
  }

  // Create client
  Future<bool> createClient(Map<String, dynamic> clientData) async {
    try {
      isLoading.value = true;

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}'),
        headers: _authController.getAuthHeaders(),
        body: json.encode(clientData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Client created successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          await fetchClients(showLoading: false);
          await fetchStats();
          return true;
        }
      } else {
        final error = json.decode(response.body);
        Get.snackbar(
          'Error',
          error['message'] ?? 'Failed to create client',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create client: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // Update client
  Future<bool> updateClient(int clientId, Map<String, dynamic> clientData) async {
    try {
      isLoading.value = true;

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}/$clientId'),
        headers: _authController.getAuthHeaders(),
        body: json.encode(clientData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Client updated successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          await fetchClients(showLoading: false);
          await fetchStats();
          return true;
        }
      } else {
        final error = json.decode(response.body);
        Get.snackbar(
          'Error',
          error['message'] ?? 'Failed to update client',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update client: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // Delete client (soft delete)
  Future<bool> deleteClient(int clientId) async {
    try {
      isLoading.value = true;

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}/$clientId'),
        headers: _authController.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Client deleted successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          await fetchClients(showLoading: false);
          await fetchStats();
          return true;
        }
      } else {
        final error = json.decode(response.body);
        Get.snackbar(
          'Error',
          error['message'] ?? 'Failed to delete client',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete client: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // Activate client
  Future<bool> activateClient(int clientId) async {
    try {
      isLoading.value = true;

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}/$clientId/activate'),
        headers: _authController.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Client activated successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          await fetchClients(showLoading: false);
          await fetchStats();
          return true;
        }
      } else {
        final error = json.decode(response.body);
        Get.snackbar(
          'Error',
          error['message'] ?? 'Failed to activate client',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to activate client: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // Bulk activate
  Future<void> bulkActivateClients() async {
    if (selectedClientIds.isEmpty) return;

    try {
      isLoading.value = true;
      for (final clientId in selectedClientIds) {
        await activateClient(clientId);
      }
      clearSelection();
      toggleBulkSelectMode();
    } finally {
      isLoading.value = false;
    }
  }

  // Bulk deactivate
  Future<void> bulkDeactivateClients() async {
    if (selectedClientIds.isEmpty) return;

    try {
      isLoading.value = true;
      for (final clientId in selectedClientIds) {
        await deleteClient(clientId);
      }
      clearSelection();
      toggleBulkSelectMode();
    } finally {
      isLoading.value = false;
    }
  }

  // Get client statistics
  Future<Map<String, dynamic>?> getClientStatistics(int clientId) async {
    try {
      final url = '${ApiConstants.baseUrl}${ApiConstants.clients}/$clientId/statistics';
      print('Fetching statistics from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _authController.getAuthHeaders(),
      );

      print('Statistics response status: ${response.statusCode}');
      print('Statistics response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Parsed statistics data: $data');
        
        if (data['status'] == 'success') {
          final apiData = data['data'] as Map<String, dynamic>;
          print('API data extracted: $apiData');
          
          // Transform the API response to match what the dialog expects
          final transformedData = {
            'totalBoxes': apiData['boxes']?['total'] ?? 0,
            'totalUsers': apiData['users']?['total'] ?? 0,
            'storagePercentage': _calculateStoragePercentage(apiData['boxes']?['total'] ?? 0),
            'boxesByStatus': {
              'stored': apiData['boxes']?['stored'] ?? 0,
              'retrieved': apiData['boxes']?['retrieved'] ?? 0,
              'destroyed': apiData['boxes']?['destroyed'] ?? 0,
            },
            'boxesPendingDestruction': apiData['boxes']?['pendingDestruction'] ?? 0,
            'recentActivity': {
              'collections': apiData['activities']?['collections']?['last30Days'] ?? 0,
              'retrievals': apiData['activities']?['retrievals']?['last30Days'] ?? 0,
              'deliveries': apiData['activities']?['deliveries']?['last30Days'] ?? 0,
            },
            'availableLocations': 0, // Not in API response, set to 0
            'occupiedLocations': 0,  // Not in API response, set to 0
            'oldestBox': 'N/A',      // Not in API response
            'newestBox': 'N/A',      // Not in API response
          };
          
          print('Transformed data: $transformedData');
          return transformedData;
        } else {
          print('API returned non-success status: ${data['status']}');
          throw Exception('API returned error status: ${data['message'] ?? 'Unknown error'}');
        }
      } else if (response.statusCode == 401) {
        // Token expired, refresh and retry
        await _authController.refreshToken();
        return await getClientStatistics(clientId); // Retry
      } else {
        print('HTTP error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load statistics (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('Exception in getClientStatistics: $e');
      Get.snackbar(
        'Error',
        'Failed to fetch statistics: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      rethrow; // Re-throw so the dialog can handle it
    }
  }
  
  // Helper method to calculate storage percentage
  double _calculateStoragePercentage(int totalBoxes) {
    // You can customize this calculation based on your business logic
    // For example, if you have a maximum capacity
    const maxCapacity = 100; // Adjust based on your needs
    if (maxCapacity > 0) {
      return (totalBoxes / maxCapacity * 100).clamp(0.0, 100.0);
    }
    return 0.0;
  }

  // Refresh data
  Future<void> refreshClients() async {
    currentPage.value = 1;
    await fetchClients();
    await fetchStats();
  }
}