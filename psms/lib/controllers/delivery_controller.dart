// delivery_controller.dart
//
// Add these entries to lib/constants/api_constants.dart:
//   static const String deliveries          = '/api/deliveries';
//   static const String deliveryStats       = '/api/deliveries/stats';
//   static const String deliveryRecent      = '/api/deliveries/recent';
//   static const String deliveryReportSummary   = '/api/deliveries/reports/summary';
//   static const String deliveryReportByClient  = '/api/deliveries/reports/by-client';
//   static const String deliveryReportByItem    = '/api/deliveries/reports/by-item';
//   static String deliveryById(String id)       => '/api/deliveries/$id';
//   static String deliveryByClient(String id)   => '/api/deliveries/client/$id';
//   static String deliverySignature(String id)  => '/api/deliveries/$id/signature';
//   static String deliveryPdf(String id)        => '/api/deliveries/$id/pdf';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/models/client_model.dart';
import 'package:psms/models/delivery_model.dart';

class DeliveryController extends GetxController {
  static DeliveryController get instance => Get.find();

  // ============================================
  // REACTIVE STATE
  // ============================================

  final RxList<DeliveryModel> deliveries = <DeliveryModel>[].obs;
  final RxList<RecentDelivery> recentDeliveries = <RecentDelivery>[].obs;
  final RxList<ClientModel> clients = <ClientModel>[].obs;
  final Rx<DeliveryModel?> selectedDelivery = Rx<DeliveryModel?>(null);
  final Rx<DeliveryStats?> deliveryStats = Rx<DeliveryStats?>(null);

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Pagination
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalDeliveries = 0.obs;
  final RxInt pageSize = 20.obs;

  // Active filter state — always kept in sync with the last getAllDeliveries call
  // so that loadNextPage / loadPreviousPage / _refreshCurrentPage replay correctly.
  final RxString searchQuery = ''.obs;
  final RxInt clientFilter = 0.obs;
  final RxString startDateFilter = ''.obs;
  final RxString endDateFilter = ''.obs;
  final RxString sortBy = 'delivery_date'.obs;
  final RxString sortOrder = 'DESC'.obs;

  // Report data
  final RxList<DeliverySummaryReport> summaryReport =
      <DeliverySummaryReport>[].obs;
  final RxList<DeliveryByClientReport> byClientReport =
      <DeliveryByClientReport>[].obs;
  final RxList<DeliveryByItemReport> byItemReport =
      <DeliveryByItemReport>[].obs;

  // ============================================
  // PERMISSIONS
  // ============================================

  bool get canCreateDeliveries =>
      AuthController.instance.hasPermission('canCreateDeliveries');
  bool get canDeleteDeliveries =>
      AuthController.instance.hasPermission('canDeleteDeliveries');

  // ============================================
  // AUTH HEADERS
  // ============================================

  Map<String, String> getAuthHeaders() =>
      AuthController.instance.getAuthHeaders();

  // ============================================
  // INITIALIZATION
  // ============================================

  /// Do NOT set isLoading = true here. getAllDeliveries() has its own guard —
  /// setting it true first causes getAllDeliveries to return immediately.
  Future<void> initialize() async {
    try {
      errorMessage.value = '';
      await getAllDeliveries();
      await getClients();
      await getDeliveryStatistics();
      await getRecentDeliveries();
    } catch (e) {
      errorMessage.value = 'Failed to initialize: $e';
      Get.snackbar('Error', 'Failed to load delivery data: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // ============================================
  // CLIENT LOOKUP (for form dropdowns)
  // ============================================

  Future<void> getClients() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clients}'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final raw = data['data'] is List
              ? data['data'] as List<dynamic>
              : (data['data']?['clients'] as List<dynamic>? ?? []);
          clients.value =
              raw.map((e) => ClientModel.fromJson(e as Map<String, dynamic>)).toList();
        }
      } else if (response.statusCode == 401) {
        await AuthController.instance.refreshAccessToken();
        await getClients();
      }
    } catch (e) {
      print('Error fetching clients for delivery form: $e');
    }
  }

  // ============================================
  // GET ALL DELIVERIES  (GET /api/deliveries)
  // ============================================

  Future<void> getAllDeliveries({
    int? page,
    int? limit,
    String? search,
    int? clientId,
    String? startDate,
    String? endDate,
    String? sortByField,
    String? sortOrderValue,
    bool refresh = true,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final effectivePage = page ?? (refresh ? 1 : currentPage.value);
      final effectiveLimit = limit ?? pageSize.value;

      final params = <String, String>{
        'page': effectivePage.toString(),
        'limit': effectiveLimit.toString(),
      };
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (clientId != null && clientId > 0)
        params['clientId'] = clientId.toString();
      if (startDate != null && startDate.isNotEmpty)
        params['startDate'] = startDate;
      if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
      if (sortByField != null && sortByField.isNotEmpty)
        params['sortBy'] = sortByField;
      if (sortOrderValue != null && sortOrderValue.isNotEmpty)
        params['sortOrder'] = sortOrderValue;

      final uri =
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deliveries}')
              .replace(queryParameters: params);

      final response = await http.get(uri, headers: getAuthHeaders());

      if (response.statusCode == 200) {
        final deliveryResponse =
            DeliveriesResponse.fromJson(json.decode(response.body));

        if (deliveryResponse.status == 'success' &&
            deliveryResponse.data != null) {
          final newDeliveries = deliveryResponse.data!.deliveries;

          if (refresh) {
            deliveries.value = newDeliveries;
            currentPage.value = effectivePage;
          } else {
            deliveries.addAll(newDeliveries);
            currentPage.value = effectivePage;
          }

          totalPages.value =
              deliveryResponse.data!.pagination?.totalPages ?? 1;
          totalDeliveries.value =
              deliveryResponse.data!.pagination?.total ?? 0;

          // Always sync filter state so pagination helpers replay correctly.
          // null → "no filter" → clear the stored value.
          searchQuery.value = search ?? '';
          clientFilter.value = clientId ?? 0;
          startDateFilter.value = startDate ?? '';
          endDateFilter.value = endDate ?? '';
          if (sortByField != null) sortBy.value = sortByField;
          if (sortOrderValue != null) sortOrder.value = sortOrderValue;
        } else {
          errorMessage.value = deliveryResponse.message;
          Get.snackbar('Error', deliveryResponse.message,
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      } else {
        final err = json.decode(response.body);
        errorMessage.value = err['message'] ?? 'Failed to fetch deliveries';
        Get.snackbar('Error', errorMessage.value,
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // PAGINATION HELPERS
  // ============================================

  /// Replays all active filters on the current page — called after any mutation.
  Future<void> refreshCurrentPage() async {
    await getAllDeliveries(
      page: currentPage.value,
      search: searchQuery.value.isNotEmpty ? searchQuery.value : null,
      clientId: clientFilter.value > 0 ? clientFilter.value : null,
      startDate: startDateFilter.value.isNotEmpty ? startDateFilter.value : null,
      endDate: endDateFilter.value.isNotEmpty ? endDateFilter.value : null,
      sortByField: sortBy.value,
      sortOrderValue: sortOrder.value,
      refresh: true,
    );
  }

  Future<void> loadNextPage() async {
    if (currentPage.value >= totalPages.value || isLoading.value) return;
    await getAllDeliveries(
      page: currentPage.value + 1,
      search: searchQuery.value.isNotEmpty ? searchQuery.value : null,
      clientId: clientFilter.value > 0 ? clientFilter.value : null,
      startDate: startDateFilter.value.isNotEmpty ? startDateFilter.value : null,
      endDate: endDateFilter.value.isNotEmpty ? endDateFilter.value : null,
      sortByField: sortBy.value,
      sortOrderValue: sortOrder.value,
      refresh: true, // replace — consistent with explicit page buttons
    );
  }

  Future<void> loadPreviousPage() async {
    if (currentPage.value <= 1 || isLoading.value) return;
    await getAllDeliveries(
      page: currentPage.value - 1,
      search: searchQuery.value.isNotEmpty ? searchQuery.value : null,
      clientId: clientFilter.value > 0 ? clientFilter.value : null,
      startDate: startDateFilter.value.isNotEmpty ? startDateFilter.value : null,
      endDate: endDateFilter.value.isNotEmpty ? endDateFilter.value : null,
      sortByField: sortBy.value,
      sortOrderValue: sortOrder.value,
      refresh: true,
    );
  }

  // ============================================
  // GET SINGLE DELIVERY  (GET /api/deliveries/:deliveryId)
  // ============================================

  Future<DeliveryModel?> getDeliveryById(int deliveryId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.get(
        Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.deliveryById(deliveryId.toString())}'),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final delivery =
              DeliveryModel.fromJson(data['data'] as Map<String, dynamic>);
          selectedDelivery.value = delivery;
          return delivery;
        } else {
          errorMessage.value = data['message'] ?? 'Delivery not found';
          Get.snackbar('Error', errorMessage.value,
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      } else {
        final err = json.decode(response.body);
        errorMessage.value = err['message'] ?? 'Failed to fetch delivery';
        Get.snackbar('Error', errorMessage.value,
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
  // GET BY CLIENT  (GET /api/deliveries/client/:clientId)
  // ============================================

  Future<ClientDeliveriesData?> getDeliveriesByClient(int clientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.get(
        Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.deliveryByClient(clientId.toString())}'),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return ClientDeliveriesData.fromJson(
              data['data'] as Map<String, dynamic>);
        }
      } else if (response.statusCode == 401) {
        await AuthController.instance.refreshAccessToken();
        return await getDeliveriesByClient(clientId);
      } else {
        final err = json.decode(response.body);
        errorMessage.value = err['message'] ?? 'Failed to fetch client deliveries';
        Get.snackbar('Error', errorMessage.value,
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
  // RECENT DELIVERIES  (GET /api/deliveries/recent)
  // ============================================

  Future<void> getRecentDeliveries({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse(
                '${ApiConstants.baseUrl}${ApiConstants.deliveryRecent}')
            .replace(queryParameters: {'limit': limit.toString()}),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final raw = data['data'] as List<dynamic>;
          recentDeliveries.value = raw
              .map((e) => RecentDelivery.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      print('Error fetching recent deliveries: $e');
    }
  }

  // ============================================
  // STATISTICS  (GET /api/deliveries/stats)
  // ============================================

  Future<DeliveryStats?> getDeliveryStatistics() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deliveryStats}'),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final stats =
              DeliveryStats.fromJson(data['data'] as Map<String, dynamic>);
          deliveryStats.value = stats;
          return stats;
        }
      } else {
        final err = json.decode(response.body);
        errorMessage.value = err['message'] ?? 'Failed to fetch statistics';
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
    }
    return null;
  }

  // ============================================
  // CREATE  (POST /api/deliveries)
  // ============================================

  Future<bool> createDelivery(CreateDeliveryRequest request) async {
    if (!canCreateDeliveries) {
      Get.snackbar(
          'Permission Denied', 'You do not have permission to create deliveries',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deliveries}'),
        headers: getAuthHeaders(),
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Delivery created successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          await refreshCurrentPage();
          await getRecentDeliveries();
          return true;
        } else {
          errorMessage.value = data['message'] ?? 'Failed to create delivery';
          Get.snackbar('Error', errorMessage.value,
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      } else {
        final err = json.decode(response.body);
        errorMessage.value = err['message'] ?? 'Failed to create delivery';
        Get.snackbar('Error', errorMessage.value,
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // ============================================
  // UPDATE  (PUT /api/deliveries/:deliveryId)
  // ============================================

  Future<bool> updateDelivery(
      int deliveryId, UpdateDeliveryRequest request) async {
    if (!canCreateDeliveries) {
      Get.snackbar(
          'Permission Denied', 'You do not have permission to edit deliveries',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.put(
        Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.deliveryById(deliveryId.toString())}'),
        headers: getAuthHeaders(),
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          Get.snackbar('Success', 'Delivery updated successfully',
              backgroundColor: Colors.green, colorText: Colors.white);
          await getDeliveryById(deliveryId);
          await refreshCurrentPage();
          return true;
        } else {
          errorMessage.value = data['message'] ?? 'Failed to update delivery';
          Get.snackbar('Error', errorMessage.value,
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      } else {
        final err = json.decode(response.body);
        errorMessage.value = err['message'] ?? 'Failed to update delivery';
        Get.snackbar('Error', errorMessage.value,
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // ============================================
  // UPDATE SIGNATURE  (PATCH /api/deliveries/:deliveryId/signature)
  // ============================================

  Future<bool> updateSignature(int deliveryId, String signature) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.patch(
        Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.deliverySignature(deliveryId.toString())}'),
        headers: getAuthHeaders(),
        body: json.encode({'receiverSignature': signature}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Refresh full list first so Signed chip updates in table
          await refreshCurrentPage();
          // Then fetch individual record to update selectedDelivery detail view
          await getDeliveryById(deliveryId);
          Get.snackbar('Success', 'Signature saved successfully',
              backgroundColor: Colors.green, colorText: Colors.white);
          return true;
        } else {
          errorMessage.value = data['message'] ?? 'Failed to update signature';
          Get.snackbar('Error', errorMessage.value,
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      } else {
        final err = json.decode(response.body);
        errorMessage.value = err['message'] ?? 'Failed to update signature';
        Get.snackbar('Error', errorMessage.value,
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // ============================================
  // UPDATE PDF PATH  (PATCH /api/deliveries/:deliveryId/pdf)
  // ============================================

  Future<bool> updatePdfPath(int deliveryId, String pdfPath) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.patch(
        Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.deliveryPdf(deliveryId.toString())}'),
        headers: getAuthHeaders(),
        body: json.encode({'pdfPath': pdfPath}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          Get.snackbar('Success', 'PDF path updated successfully',
              backgroundColor: Colors.green, colorText: Colors.white);
          await refreshCurrentPage();
          return true;
        } else {
          errorMessage.value = data['message'] ?? 'Failed to update PDF path';
          Get.snackbar('Error', errorMessage.value,
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      } else {
        final err = json.decode(response.body);
        errorMessage.value = err['message'] ?? 'Failed to update PDF path';
        Get.snackbar('Error', errorMessage.value,
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // ============================================
  // DELETE  (DELETE /api/deliveries/:deliveryId)
  // ============================================

  Future<bool> deleteDelivery(int deliveryId) async {
    if (!canDeleteDeliveries) {
      Get.snackbar(
          'Permission Denied', 'You do not have permission to delete deliveries',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.delete(
        Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.deliveryById(deliveryId.toString())}'),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          Get.snackbar('Success', 'Delivery deleted successfully',
              backgroundColor: Colors.green, colorText: Colors.white);
          deliveries.removeWhere((d) => d.deliveryId == deliveryId);
          await refreshCurrentPage();
          return true;
        } else {
          errorMessage.value = data['message'] ?? 'Failed to delete delivery';
          Get.snackbar('Error', errorMessage.value,
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      } else {
        final err = json.decode(response.body);
        errorMessage.value = err['message'] ?? 'Failed to delete delivery';
        Get.snackbar('Error', errorMessage.value,
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // ============================================
  // REPORTS
  // ============================================

  /// GET /api/deliveries/reports/summary
  Future<void> getReportSummary({
    String? startDate,
    String? endDate,
    int? clientId,
  }) async {
    try {
      isLoading.value = true;
      final params = <String, String>{};
      if (startDate != null && startDate.isNotEmpty)
        params['startDate'] = startDate;
      if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
      if (clientId != null && clientId > 0)
        params['clientId'] = clientId.toString();

      final uri = Uri.parse(
              '${ApiConstants.baseUrl}${ApiConstants.deliveryReportSummary}')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: getAuthHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final raw = data['data'] as List<dynamic>;
          summaryReport.value = raw
              .map((e) =>
                  DeliverySummaryReport.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// GET /api/deliveries/reports/by-client
  Future<void> getReportByClient({String? startDate, String? endDate}) async {
    try {
      isLoading.value = true;
      final params = <String, String>{};
      if (startDate != null && startDate.isNotEmpty)
        params['startDate'] = startDate;
      if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;

      final uri = Uri.parse(
              '${ApiConstants.baseUrl}${ApiConstants.deliveryReportByClient}')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: getAuthHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final raw = data['data'] as List<dynamic>;
          byClientReport.value = raw
              .map((e) =>
                  DeliveryByClientReport.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// GET /api/deliveries/reports/by-item
  Future<void> getReportByItem({String? startDate, String? endDate}) async {
    try {
      isLoading.value = true;
      final params = <String, String>{};
      if (startDate != null && startDate.isNotEmpty)
        params['startDate'] = startDate;
      if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;

      final uri = Uri.parse(
              '${ApiConstants.baseUrl}${ApiConstants.deliveryReportByItem}')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: getAuthHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final raw = data['data'] as List<dynamic>;
          byItemReport.value = raw
              .map((e) =>
                  DeliveryByItemReport.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // CLEANUP
  // ============================================

  @override
  void onClose() {
    deliveries.clear();
    recentDeliveries.clear();
    selectedDelivery.value = null;
    deliveryStats.value = null;
    super.onClose();
  }
}