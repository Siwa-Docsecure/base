// dashboard_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/models/dashboard_models.dart';

class DashboardController extends GetxController {
  static DashboardController get instance => Get.find();

  // ============================================
  // REACTIVE STATE
  // ============================================

  final Rx<DashboardOverview?> overview              = Rx<DashboardOverview?>(null);
  final RxList<ActivityFeedEvent> activityFeed       = <ActivityFeedEvent>[].obs;
  final RxList<ClientBoxStatusBreakdown> boxByStatus = <ClientBoxStatusBreakdown>[].obs;
  final RxList<MonthlyTrendPoint> monthlyTrend       = <MonthlyTrendPoint>[].obs;
  final RxList<DestructionCalendarEntry> destructionCalendar = <DestructionCalendarEntry>[].obs;
  final Rx<DashboardPermissions?> permissions        = Rx<DashboardPermissions?>(null);
  final RxList<DailyStatsSnapshot> dailySnapshots    = <DailyStatsSnapshot>[].obs;

  final RxBool isLoading              = false.obs;
  final RxBool isActivityFeedLoading  = false.obs;
  final RxString errorMessage         = ''.obs;

  // ============================================
  // AUTH HEADERS
  // ============================================

  Map<String, String> getAuthHeaders() =>
      AuthController.instance.getAuthHeaders();

  // ============================================
  // INITIALISE — load everything the dashboard needs
  // ============================================

  Future<void> initialize() async {
    try {
      errorMessage.value = '';
      print('Initializing DashboardController...');

      // Load in parallel where possible
      await Future.wait([
        getOverview(),
        getPermissions(),
      ]);

      // Secondary data — non-blocking for the initial render
      await Future.wait([
        getBoxByStatus(),
        getDestructionCalendar(),
        getMonthlyTrend(),
      ]);

      print('DashboardController initialized');
    } catch (e) {
      print('DashboardController initialize error: $e');
      errorMessage.value = 'Failed to initialize dashboard: $e';
      Get.snackbar('Error', 'Failed to load dashboard: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // ============================================
  // HELPER — standard GET
  // ============================================

  Future<Map<String, dynamic>?> _get(String url,
      {Map<String, String>? queryParams, bool useActivityLoader = false}) async {
    final loader = useActivityLoader ? isActivityFeedLoading : isLoading;
    if (loader.value) return null;

    loader.value       = true;
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
        return _get(url, queryParams: queryParams,
            useActivityLoader: useActivityLoader);
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
      loader.value = false;
    }
    return null;
  }

  // ============================================
  // OVERVIEW
  // ============================================

  Future<void> getOverview() async {
    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardOverview}',
    );

    if (data != null) {
      overview.value = DashboardOverview.fromJson(data);
      print('Dashboard overview loaded');
    }
  }

  // ============================================
  // ACTIVITY FEED
  // ============================================

  Future<void> getActivityFeed({
    int limit = 20,
    String? entityType,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (entityType != null && entityType.isNotEmpty) {
      params['entityType'] = entityType;
    }

    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardActivityFeed}',
      queryParams: params,
      useActivityLoader: true,
    );

    if (data != null) {
      final events = data['events'] as List<dynamic>? ?? [];
      activityFeed.value = events
          .map((e) => ActivityFeedEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      print('Activity feed loaded: ${activityFeed.length} events');
    }
  }

  // ============================================
  // BOXES BY STATUS (per client)
  // ============================================

  Future<void> getBoxByStatus() async {
    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardBoxesByStatus}',
    );

    if (data != null) {
      final clients = data['clients'] as List<dynamic>? ?? [];
      boxByStatus.value = clients
          .map((e) =>
              ClientBoxStatusBreakdown.fromJson(e as Map<String, dynamic>))
          .toList();
      print('Box by status loaded: ${boxByStatus.length} clients');
    }
  }

  // ============================================
  // MONTHLY TREND
  // ============================================

  Future<void> getMonthlyTrend({int months = 12}) async {
    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardMonthlyTrend}',
      queryParams: {'months': months.toString()},
    );

    if (data != null) {
      final raw = data['months'] as List<dynamic>? ?? [];
      monthlyTrend.value = raw
          .map((e) => MonthlyTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList();
      print('Monthly trend loaded: ${monthlyTrend.length} months');
    }
  }

  // ============================================
  // DESTRUCTION CALENDAR
  // ============================================

  Future<void> getDestructionCalendar() async {
    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardDestructionCalendar}',
    );

    if (data != null) {
      final raw = data['calendar'] as List<dynamic>? ?? [];
      destructionCalendar.value = raw
          .map((e) =>
              DestructionCalendarEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      print('Destruction calendar loaded: ${destructionCalendar.length} entries');
    }
  }

  // ============================================
  // PERMISSIONS / CONTROLS
  // ============================================

  Future<void> getPermissions() async {
    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardControls}',
    );

    if (data != null && data['permissions'] != null) {
      permissions.value = DashboardPermissions.fromJson(
          data['permissions'] as Map<String, dynamic>);
      print('Dashboard permissions loaded');
    }
  }

  // ============================================
  // DAILY STATS SNAPSHOTS
  // ============================================

  Future<void> getDailyStats({int days = 30}) async {
    final data = await _get(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardDailyStats}',
      queryParams: {'days': days.toString()},
    );

    if (data != null) {
      final raw = data['snapshots'] as List<dynamic>? ?? [];
      dailySnapshots.value = raw
          .map((e) => DailyStatsSnapshot.fromJson(e as Map<String, dynamic>))
          .toList();
      print('Daily stats loaded: ${dailySnapshots.length} snapshots');
    }
  }

  // ============================================
  // CONVENIENCE GETTERS (null-safe shortcuts)
  // ============================================

  int get totalBoxes    => overview.value?.boxes.total            ?? 0;
  int get storedBoxes   => overview.value?.boxes.stored           ?? 0;
  int get pendingDest   => overview.value?.boxes.pendingDestruction ?? 0;
  int get pendingReqs   => overview.value?.activity.pendingRequests ?? 0;

  bool get canViewReports => permissions.value?.canViewReports ?? false;
  bool get canManageUsers => permissions.value?.canManageUsers ?? false;

  // ============================================
  // REFRESH
  // ============================================

  Future<void> refresh() async {
    await Future.wait([
      getOverview(),
      getActivityFeed(),
    ]);
  }

  // ============================================
  // CLEANUP
  // ============================================

  void clearAll() {
    overview.value          = null;
    activityFeed.clear();
    boxByStatus.clear();
    monthlyTrend.clear();
    destructionCalendar.clear();
    permissions.value       = null;
    dailySnapshots.clear();
    errorMessage.value      = '';
  }

  @override
  void onClose() {
    clearAll();
    super.onClose();
  }
}