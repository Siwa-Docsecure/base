// dashboard_models.dart

// ─────────────────────────────────────────────────────────────────────────────
// SAFE PARSING HELPERS
// MySQL2 driver can return numerics as String, int, or double depending on
// column type and query context. These helpers normalise all three.
// ─────────────────────────────────────────────────────────────────────────────

int _toInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

bool _toBool(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is int)  return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return fallback;
}

String _toStr(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

// ============================================
// OVERVIEW
// ============================================

class DashboardBoxStats {
  final int total;
  final int stored;
  final int retrieved;
  final int destroyed;
  final int pendingDestruction;

  DashboardBoxStats({
    required this.total,
    required this.stored,
    required this.retrieved,
    required this.destroyed,
    required this.pendingDestruction,
  });

  factory DashboardBoxStats.fromJson(Map<String, dynamic> json) =>
      DashboardBoxStats(
        total:              _toInt(json['total']),
        stored:             _toInt(json['stored']),
        retrieved:          _toInt(json['retrieved']),
        destroyed:          _toInt(json['destroyed']),
        pendingDestruction: _toInt(json['pendingDestruction']),
      );
}

class DashboardActivityStats {
  final int collectionsToday;
  final int retrievalsToday;
  final int deliveriesToday;
  final int pendingRequests;

  DashboardActivityStats({
    required this.collectionsToday,
    required this.retrievalsToday,
    required this.deliveriesToday,
    required this.pendingRequests,
  });

  factory DashboardActivityStats.fromJson(Map<String, dynamic> json) =>
      DashboardActivityStats(
        collectionsToday: _toInt(json['collectionsToday']),
        retrievalsToday:  _toInt(json['retrievalsToday']),
        deliveriesToday:  _toInt(json['deliveriesToday']),
        pendingRequests:  _toInt(json['pendingRequests']),
      );
}

class DashboardUsersByRole {
  final int admin;
  final int staff;
  final int client;

  DashboardUsersByRole({required this.admin, required this.staff, required this.client});

  factory DashboardUsersByRole.fromJson(Map<String, dynamic> json) =>
      DashboardUsersByRole(
        admin:  _toInt(json['admin']),
        staff:  _toInt(json['staff']),
        client: _toInt(json['client']),
      );
}

class DashboardSystemStats {
  final int totalClients;
  final int totalUsers;
  final DashboardUsersByRole usersByRole;

  DashboardSystemStats({
    required this.totalClients,
    required this.totalUsers,
    required this.usersByRole,
  });

  factory DashboardSystemStats.fromJson(Map<String, dynamic> json) =>
      DashboardSystemStats(
        totalClients: _toInt(json['totalClients']),
        totalUsers:   _toInt(json['totalUsers']),
        usersByRole:  DashboardUsersByRole.fromJson(
            (json['usersByRole'] as Map<String, dynamic>?) ?? {}),
      );
}

class DashboardTrendDay {
  final String day;
  final int boxesAdded;

  DashboardTrendDay({required this.day, required this.boxesAdded});

  factory DashboardTrendDay.fromJson(Map<String, dynamic> json) =>
      DashboardTrendDay(
        day:        _toStr(json['day']),
        boxesAdded: _toInt(json['boxesAdded']),
      );
}

class DashboardOverview {
  final DashboardBoxStats boxes;
  final DashboardActivityStats activity;
  final DashboardSystemStats? systemStats;
  final List<DashboardTrendDay> trend7Days;

  DashboardOverview({
    required this.boxes,
    required this.activity,
    this.systemStats,
    required this.trend7Days,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> json) =>
      DashboardOverview(
        boxes:    DashboardBoxStats.fromJson(json['boxes'] as Map<String, dynamic>),
        activity: DashboardActivityStats.fromJson(json['activity'] as Map<String, dynamic>),
        systemStats: json['systemStats'] != null
            ? DashboardSystemStats.fromJson(json['systemStats'] as Map<String, dynamic>)
            : null,
        trend7Days: (json['trend7Days'] as List<dynamic>? ?? [])
            .map((e) => DashboardTrendDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ============================================
// ACTIVITY FEED
// ============================================

class ActivityFeedUser {
  final String username;
  final String role;

  ActivityFeedUser({required this.username, required this.role});

  factory ActivityFeedUser.fromJson(Map<String, dynamic> json) =>
      ActivityFeedUser(
        username: _toStr(json['username']),
        role:     _toStr(json['role']),
      );
}

class ActivityFeedEvent {
  final int auditId;
  final String action;
  final String entityType;
  final int? entityId;
  final String? ipAddress;
  final String timestamp;
  final ActivityFeedUser? user;

  ActivityFeedEvent({
    required this.auditId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.ipAddress,
    required this.timestamp,
    this.user,
  });

  factory ActivityFeedEvent.fromJson(Map<String, dynamic> json) =>
      ActivityFeedEvent(
        auditId:    _toInt(json['auditId']),
        action:     _toStr(json['action']),
        entityType: _toStr(json['entityType']),
        entityId:   json['entityId'] != null ? _toInt(json['entityId']) : null,
        ipAddress:  json['ipAddress']?.toString(),
        timestamp:  _toStr(json['timestamp']),
        user: json['user'] != null
            ? ActivityFeedUser.fromJson(json['user'] as Map<String, dynamic>)
            : null,
      );
}

// ============================================
// BOXES BY STATUS (per-client breakdown)
// ============================================

class ClientBoxStatusBreakdown {
  final int clientId;
  final String clientName;
  final String clientCode;
  final int stored;
  final int retrieved;
  final int destroyed;
  final int total;

  ClientBoxStatusBreakdown({
    required this.clientId,
    required this.clientName,
    required this.clientCode,
    required this.stored,
    required this.retrieved,
    required this.destroyed,
    required this.total,
  });

  factory ClientBoxStatusBreakdown.fromJson(Map<String, dynamic> json) =>
      ClientBoxStatusBreakdown(
        clientId:   _toInt(json['clientId']),
        clientName: _toStr(json['clientName']),
        clientCode: _toStr(json['clientCode']),
        stored:     _toInt(json['stored']),
        retrieved:  _toInt(json['retrieved']),
        destroyed:  _toInt(json['destroyed']),
        total:      _toInt(json['total']),
      );
}

// ============================================
// MONTHLY TREND
// ============================================

class MonthlyTrendPoint {
  final String month;
  final int collections;
  final int retrievals;
  final int deliveries;

  MonthlyTrendPoint({
    required this.month,
    required this.collections,
    required this.retrievals,
    required this.deliveries,
  });

  factory MonthlyTrendPoint.fromJson(Map<String, dynamic> json) =>
      MonthlyTrendPoint(
        month:       _toStr(json['month']),
        collections: _toInt(json['collections']),
        retrievals:  _toInt(json['retrievals']),
        deliveries:  _toInt(json['deliveries']),
      );
}

// ============================================
// DESTRUCTION CALENDAR
// ============================================

class DestructionCalendarEntry {
  final int destructionYear;
  final int boxCount;
  final int overdueCount;
  final bool isOverdue;

  DestructionCalendarEntry({
    required this.destructionYear,
    required this.boxCount,
    required this.overdueCount,
    required this.isOverdue,
  });

  factory DestructionCalendarEntry.fromJson(Map<String, dynamic> json) =>
      DestructionCalendarEntry(
        destructionYear: _toInt(json['destructionYear']),
        boxCount:        _toInt(json['boxCount']),
        overdueCount:    _toInt(json['overdueCount']),
        isOverdue:       _toBool(json['isOverdue']),
      );
}

// ============================================
// DASHBOARD CONTROLS (permissions)
// ============================================

class DashboardPermissions {
  final bool canCreateBoxes;
  final bool canEditBoxes;
  final bool canDeleteBoxes;
  final bool canCreateCollections;
  final bool canCreateRetrievals;
  final bool canCreateDeliveries;
  final bool canViewReports;
  final bool canManageUsers;

  DashboardPermissions({
    required this.canCreateBoxes,
    required this.canEditBoxes,
    required this.canDeleteBoxes,
    required this.canCreateCollections,
    required this.canCreateRetrievals,
    required this.canCreateDeliveries,
    required this.canViewReports,
    required this.canManageUsers,
  });

  factory DashboardPermissions.fromJson(Map<String, dynamic> json) =>
      DashboardPermissions(
        canCreateBoxes:       _toBool(json['canCreateBoxes']),
        canEditBoxes:         _toBool(json['canEditBoxes']),
        canDeleteBoxes:       _toBool(json['canDeleteBoxes']),
        canCreateCollections: _toBool(json['canCreateCollections']),
        canCreateRetrievals:  _toBool(json['canCreateRetrievals']),
        canCreateDeliveries:  _toBool(json['canCreateDeliveries']),
        canViewReports:       _toBool(json['canViewReports']),
        canManageUsers:       _toBool(json['canManageUsers']),
      );
}

// ============================================
// DAILY STATS SNAPSHOT
// ============================================

class DailyStatsSnapshot {
  final String statDate;
  final int totalBoxes;
  final int totalClients;
  final int boxesStored;
  final int boxesRetrieved;
  final int boxesDestroyed;
  final int collectionsCount;
  final int retrievalsCount;
  final int deliveriesCount;
  final int activeUsers;

  DailyStatsSnapshot({
    required this.statDate,
    required this.totalBoxes,
    required this.totalClients,
    required this.boxesStored,
    required this.boxesRetrieved,
    required this.boxesDestroyed,
    required this.collectionsCount,
    required this.retrievalsCount,
    required this.deliveriesCount,
    required this.activeUsers,
  });

  factory DailyStatsSnapshot.fromJson(Map<String, dynamic> json) =>
      DailyStatsSnapshot(
        statDate:         _toStr(json['stat_date']),
        totalBoxes:       _toInt(json['total_boxes']),
        totalClients:     _toInt(json['total_clients']),
        boxesStored:      _toInt(json['boxes_stored']),
        boxesRetrieved:   _toInt(json['boxes_retrieved']),
        boxesDestroyed:   _toInt(json['boxes_destroyed']),
        collectionsCount: _toInt(json['collections_count']),
        retrievalsCount:  _toInt(json['retrievals_count']),
        deliveriesCount:  _toInt(json['deliveries_count']),
        activeUsers:      _toInt(json['active_users']),
      );
}