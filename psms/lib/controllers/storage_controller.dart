// storage_controller.dart (Updated version)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/models/racking_label_model.dart';
import 'package:psms/models/storage_stats_model.dart';

class StorageController extends GetxController {
  static StorageController get instance => Get.find();

  // Reactive variables
  final RxList<RackingLabelModel> storageLocations = <RackingLabelModel>[].obs;
  final RxList<RackingLabelModel> availableLocations = <RackingLabelModel>[].obs;
  final Rx<RackingLabelModel?> selectedLocation = Rx<RackingLabelModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalLocations = 0.obs;

  // Filter variables
  final RxString searchQuery = ''.obs;
  final RxBool availableOnlyFilter = false.obs;
  final RxString sortBy = 'label_code'.obs;
  final RxString sortOrder = 'ASC'.obs;

  // Stats data
  final Rx<StorageStats?> storageStats = Rx<StorageStats?>(null);
  final Rx<StorageStatus?> storageStatus = Rx<StorageStatus?>(null);

  // Permission check methods
  bool get canManageStorage =>
      AuthController.instance.currentUser.value?.role == 'admin' ||
      AuthController.instance.currentUser.value?.role == 'staff';

  bool get canViewStats =>
      AuthController.instance.currentUser.value?.role == 'admin' ||
      AuthController.instance.currentUser.value?.role == 'staff';

  bool get canDeleteStorage =>
      AuthController.instance.currentUser.value?.role == 'admin';

  // Get auth headers
  Map<String, String> getAuthHeaders() {
    final authController = AuthController.instance;
    return authController.getAuthHeaders();
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  // Check if location is in use
  bool isLocationInUse(RackingLabelModel location) {
    return !location.isAvailable || (location.boxesCount ?? 0) > 0;
  }

  // Get location by ID from local list
  RackingLabelModel? getLocationById(int labelId) {
    try {
      return storageLocations.firstWhere((location) => location.labelId == labelId);
    } catch (e) {
      return null;
    }
  }

  // Format location display
  String formatLocationDisplay(RackingLabelModel location) {
    return '${location.labelCode} - ${location.locationDescription}';
  }

  // ============================================
  // STORAGE LOCATION CRUD OPERATIONS
  // ============================================

  // Get all storage locations with filtering
  Future<void> getAllLocations({
    int page = 1,
    int limit = 20,
    String? search,
    bool? isAvailable,
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
      if (isAvailable != null) params['is_available'] = isAvailable.toString();
      if (sortBy != null && sortBy.isNotEmpty) params['sort_by'] = sortBy;
      if (sortOrder != null && sortOrder.isNotEmpty) params['sort_order'] = sortOrder;

      final uri = Uri.parse('${ApiConstants.baseUrl}/storage/locations')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: getAuthHeaders());

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final data = responseData['data'];
          
          // Parse locations
          if (data['locations'] != null) {
            final locationsData = data['locations'] as List<dynamic>;
            storageLocations.value = locationsData
                .map((location) => RackingLabelModel.fromJson(location))
                .toList();
          }
          
          // Parse pagination
          if (data['pagination'] != null) {
            final pagination = data['pagination'] as Map<String, dynamic>;
            currentPage.value = pagination['page'] is String 
                ? int.tryParse(pagination['page'].toString()) ?? page 
                : (pagination['page'] as int? ?? page);
            totalPages.value = pagination['totalPages'] is String
                ? int.tryParse(pagination['totalPages'].toString()) ?? 1
                : (pagination['totalPages'] as int? ?? 1);
            totalLocations.value = pagination['total'] is String
                ? int.tryParse(pagination['total'].toString()) ?? 0
                : (pagination['total'] as int? ?? 0);
          }

          // Save filters
          if (search != null) searchQuery.value = search;
          if (isAvailable != null) availableOnlyFilter.value = isAvailable;
          if (sortBy != null) this.sortBy.value = sortBy;
          if (sortOrder != null) this.sortOrder.value = sortOrder;
        } else {
          errorMessage.value = responseData['message'] ?? 'Failed to load locations';
          Get.snackbar(
            'Error',
            responseData['message'] ?? 'Failed to load locations',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 401) {
        // Token expired, refresh and retry
        final refreshed = await AuthController.instance.refreshAccessToken();
        if (refreshed) {
          await getAllLocations(
            page: page,
            limit: limit,
            search: search,
            isAvailable: isAvailable,
            sortBy: sortBy,
            sortOrder: sortOrder,
          );
        } else {
          errorMessage.value = 'Session expired. Please login again.';
          Get.snackbar(
            'Session Expired',
            'Please login again',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to fetch locations';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to fetch locations',
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

  // Get available storage locations
  Future<void> getAvailableLocations() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final uri = Uri.parse('${ApiConstants.baseUrl}/storage/locations/available');

      final response = await http.get(uri, headers: getAuthHeaders());

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final locationsData = responseData['data'] as List<dynamic>;
          availableLocations.value = locationsData
              .map((location) {
                // For available locations endpoint, we don't get is_available field
                // So we assume it's true and set a default value
                final locationMap = location as Map<String, dynamic>;
                locationMap['is_available'] = 1; // Set to true
                locationMap['boxes_count'] = 0; // Set default boxes count
                return RackingLabelModel.fromJson(locationMap);
              })
              .toList();
        } else {
          errorMessage.value = responseData['message'] ?? 'Failed to load available locations';
          Get.snackbar(
            'Error',
            responseData['message'] ?? 'Failed to load available locations',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 401) {
        final refreshed = await AuthController.instance.refreshAccessToken();
        if (refreshed) {
          await getAvailableLocations();
        } else {
          errorMessage.value = 'Session expired. Please login again.';
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to fetch available locations';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to fetch available locations',
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

  // Get specific storage location by ID
  Future<RackingLabelModel?> getLocationDetails(int labelId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final uri = Uri.parse('${ApiConstants.baseUrl}/storage/locations/$labelId');

      final response = await http.get(uri, headers: getAuthHeaders());

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final locationData = responseData['data'] as Map<String, dynamic>;
          
          // Ensure is_available is converted properly
          if (locationData['is_available'] is int) {
            locationData['is_available'] = locationData['is_available'] == 1;
          }
          
          // Ensure boxes_count is an integer
          if (locationData['boxes_count'] != null && locationData['boxes_count'] is String) {
            locationData['boxes_count'] = int.tryParse(locationData['boxes_count'].toString());
          }
          
          final location = RackingLabelModel.fromJson(locationData);
          selectedLocation.value = location;
          return location;
        } else {
          errorMessage.value = responseData['message'] ?? 'Failed to load location details';
          Get.snackbar(
            'Error',
            responseData['message'] ?? 'Failed to load location details',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 401) {
        final refreshed = await AuthController.instance.refreshAccessToken();
        if (refreshed) {
          return await getLocationDetails(labelId);
        } else {
          errorMessage.value = 'Session expired. Please login again.';
          Get.snackbar(
            'Session Expired',
            'Please login again',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 404) {
        errorMessage.value = 'Storage location not found';
        Get.snackbar(
          'Error',
          'Storage location not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to fetch location details';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to fetch location details',
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

  // Create new storage location
  Future<bool> createLocation(CreateLocationRequest request) async {
    try {
      if (!canManageStorage) {
        errorMessage.value = 'You do not have permission to create storage locations';
        Get.snackbar(
          'Permission Denied',
          'You do not have permission to create storage locations',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      }

      // Validate request
      if (request.labelCode.trim().length < 3) {
        errorMessage.value = 'Label code must be at least 3 characters';
        Get.snackbar(
          'Validation Error',
          'Label code must be at least 3 characters',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      if (request.locationDescription.trim().length < 5) {
        errorMessage.value = 'Location description must be at least 5 characters';
        Get.snackbar(
          'Validation Error',
          'Location description must be at least 5 characters',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final uri = Uri.parse('${ApiConstants.baseUrl}/storage/locations');

      final response = await http.post(
        uri,
        headers: {
          ...getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Storage location created successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );

          // Refresh the locations list
          await getAllLocations(page: currentPage.value);
          // Refresh available locations
          await getAvailableLocations();
          return true;
        } else {
          errorMessage.value = responseData['message'] ?? 'Failed to create location';
          Get.snackbar(
            'Error',
            responseData['message'] ?? 'Failed to create location',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 401) {
        final refreshed = await AuthController.instance.refreshAccessToken();
        if (refreshed) {
          return await createLocation(request);
        } else {
          errorMessage.value = 'Session expired. Please login again.';
          Get.snackbar(
            'Session Expired',
            'Please login again',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 400) {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Validation failed';
        Get.snackbar(
          'Validation Error',
          errorResponse['message'] ?? 'Validation failed',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else if (response.statusCode == 409) {
        errorMessage.value = 'Label code already exists';
        Get.snackbar(
          'Error',
          'Label code already exists',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to create storage location';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to create storage location',
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

  // Update storage location
  Future<bool> updateLocation(int labelId, UpdateLocationRequest request) async {
    try {
      if (!canManageStorage) {
        errorMessage.value = 'You do not have permission to update storage locations';
        Get.snackbar(
          'Permission Denied',
          'You do not have permission to update storage locations',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      }

      // Validate request if fields are provided
      if (request.labelCode != null && request.labelCode!.trim().length < 3) {
        errorMessage.value = 'Label code must be at least 3 characters';
        Get.snackbar(
          'Validation Error',
          'Label code must be at least 3 characters',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      if (request.locationDescription != null && request.locationDescription!.trim().length < 5) {
        errorMessage.value = 'Location description must be at least 5 characters';
        Get.snackbar(
          'Validation Error',
          'Location description must be at least 5 characters',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final uri = Uri.parse('${ApiConstants.baseUrl}/storage/locations/$labelId');

      final response = await http.put(
        uri,
        headers: {
          ...getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Storage location updated successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          // Refresh the location details
          await getLocationDetails(labelId);
          // Refresh the locations list
          await getAllLocations(page: currentPage.value);
          // Refresh available locations
          await getAvailableLocations();
          return true;
        } else {
          errorMessage.value = responseData['message'] ?? 'Failed to update location';
          Get.snackbar(
            'Error',
            responseData['message'] ?? 'Failed to update location',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 401) {
        final refreshed = await AuthController.instance.refreshAccessToken();
        if (refreshed) {
          return await updateLocation(labelId, request);
        } else {
          errorMessage.value = 'Session expired. Please login again.';
          Get.snackbar(
            'Session Expired',
            'Please login again',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 404) {
        errorMessage.value = 'Storage location not found';
        Get.snackbar(
          'Error',
          'Storage location not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else if (response.statusCode == 409) {
        errorMessage.value = 'Label code already exists';
        Get.snackbar(
          'Error',
          'Label code already exists',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to update storage location';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to update storage location',
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

  // Delete storage location
  Future<bool> deleteLocation(int labelId) async {
    try {
      if (!canDeleteStorage) {
        errorMessage.value = 'Only admins can delete storage locations';
        Get.snackbar(
          'Permission Denied',
          'Only admins can delete storage locations',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final uri = Uri.parse('${ApiConstants.baseUrl}/storage/locations/$labelId');

      final response = await http.delete(uri, headers: getAuthHeaders());

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Storage location deleted successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          // Remove from local list
          storageLocations.removeWhere((location) => location.labelId == labelId);
          // Refresh the locations list
          await getAllLocations(page: currentPage.value);
          // Refresh available locations
          await getAvailableLocations();
          return true;
        } else {
          errorMessage.value = responseData['message'] ?? 'Failed to delete location';
          Get.snackbar(
            'Error',
            responseData['message'] ?? 'Failed to delete location',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 401) {
        final refreshed = await AuthController.instance.refreshAccessToken();
        if (refreshed) {
          return await deleteLocation(labelId);
        } else {
          errorMessage.value = 'Session expired. Please login again.';
          Get.snackbar(
            'Session Expired',
            'Please login again',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 404) {
        errorMessage.value = 'Storage location not found';
        Get.snackbar(
          'Error',
          'Storage location not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else if (response.statusCode == 400) {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Cannot delete location with boxes assigned';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Cannot delete location with boxes assigned',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to delete storage location';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to delete storage location',
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
  // STATISTICS & STATUS OPERATIONS
  // ============================================

  // Get storage statistics
  Future<StorageStats?> getStorageStatistics() async {
    try {
      if (!canViewStats) {
        errorMessage.value = 'You do not have permission to view storage statistics';
        Get.snackbar(
          'Permission Denied',
          'You do not have permission to view storage statistics',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return null;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final uri = Uri.parse('${ApiConstants.baseUrl}/storage/stats');

      final response = await http.get(uri, headers: getAuthHeaders());

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final data = responseData['data'] as Map<String, dynamic>;
          
          // Fix any int to bool conversions in the data
          if (data['utilization'] != null) {
            final utilizationList = data['utilization'] as List<dynamic>;
            for (var item in utilizationList) {
              final itemMap = item as Map<String, dynamic>;
              if (itemMap['is_available'] is int) {
                itemMap['is_available'] = itemMap['is_available'] == 1;
              }
            }
          }
          
          storageStats.value = StorageStats.fromJson(data);
          return storageStats.value;
        } else {
          errorMessage.value = responseData['message'] ?? 'Failed to load storage statistics';
          Get.snackbar(
            'Error',
            responseData['message'] ?? 'Failed to load storage statistics',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 401) {
        final refreshed = await AuthController.instance.refreshAccessToken();
        if (refreshed) {
          return await getStorageStatistics();
        } else {
          errorMessage.value = 'Session expired. Please login again.';
          Get.snackbar(
            'Session Expired',
            'Please login again',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to fetch storage statistics';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to fetch storage statistics',
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

  // Get storage system status
  Future<StorageStatus?> getStorageStatus() async {
    try {
      if (!canViewStats) {
        errorMessage.value = 'You do not have permission to view storage status';
        Get.snackbar(
          'Permission Denied',
          'You do not have permission to view storage status',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return null;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final uri = Uri.parse('${ApiConstants.baseUrl}/storage/status');

      final response = await http.get(uri, headers: getAuthHeaders());

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final data = responseData['data'] as Map<String, dynamic>;
          storageStatus.value = StorageStatus.fromJson(data);
          return storageStatus.value;
        } else {
          errorMessage.value = responseData['message'] ?? 'Failed to load storage status';
          Get.snackbar(
            'Error',
            responseData['message'] ?? 'Failed to load storage status',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 401) {
        final refreshed = await AuthController.instance.refreshAccessToken();
        if (refreshed) {
          return await getStorageStatus();
        } else {
          errorMessage.value = 'Session expired. Please login again.';
          Get.snackbar(
            'Session Expired',
            'Please login again',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to fetch storage status';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to fetch storage status',
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

  // ============================================
  // INITIALIZATION & UTILITY METHODS
  // ============================================

  // Initialize controller
  Future<void> initialize({bool forceRefresh = false}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Load data sequentially
      await getAllLocations();
      await getAvailableLocations();

      print('StorageController initialization complete');
    } catch (e) {
      errorMessage.value = 'Failed to initialize: $e';
      Get.snackbar(
        'Error',
        'Failed to load storage data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Clear filters
  void clearFilters() {
    searchQuery.value = '';
    availableOnlyFilter.value = false;
    sortBy.value = 'label_code';
    sortOrder.value = 'ASC';
  }

  // Load next page
  Future<void> loadNextPage() async {
    if (currentPage.value < totalPages.value) {
      await getAllLocations(
        page: currentPage.value + 1,
        search: searchQuery.value,
        isAvailable: availableOnlyFilter.value ? true : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );
    }
  }

  // Load previous page
  Future<void> loadPreviousPage() async {
    if (currentPage.value > 1) {
      await getAllLocations(
        page: currentPage.value - 1,
        search: searchQuery.value,
        isAvailable: availableOnlyFilter.value ? true : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );
    }
  }

  // Refresh all data
  Future<void> refreshData() async {
    await initialize(forceRefresh: true);
  }

  // Dispose controller
  @override
  void onClose() {
    storageLocations.clear();
    availableLocations.clear();
    selectedLocation.value = null;
    storageStats.value = null;
    storageStatus.value = null;
    super.onClose();
  }
}

// Request models for creating and updating storage locations
class CreateLocationRequest {
  final String labelCode;
  final String locationDescription;
  final bool isAvailable;

  CreateLocationRequest({
    required this.labelCode,
    required this.locationDescription,
    this.isAvailable = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'label_code': labelCode,
      'location_description': locationDescription,
      'is_available': isAvailable,
    };
  }
}

class UpdateLocationRequest {
  final String? labelCode;
  final String? locationDescription;
  final bool? isAvailable;

  UpdateLocationRequest({
    this.labelCode,
    this.locationDescription,
    this.isAvailable,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (labelCode != null) data['label_code'] = labelCode;
    if (locationDescription != null) data['location_description'] = locationDescription;
    if (isAvailable != null) data['is_available'] = isAvailable;
    return data;
  }
}