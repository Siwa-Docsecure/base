// storage_stats_model.dart
class StorageStats {
  final int totalLocations;
  final int availableLocations;
  final int occupiedLocations;
  final int totalBoxes;
  final int locationsInUse;
  final int boxesWithoutLocation;
  final List<LocationUtilization> utilization;
  final List<RecentActivity> recentActivities;

  StorageStats({
    required this.totalLocations,
    required this.availableLocations,
    required this.occupiedLocations,
    required this.totalBoxes,
    required this.locationsInUse,
    required this.boxesWithoutLocation,
    required this.utilization,
    required this.recentActivities,
  });

  factory StorageStats.fromJson(Map<String, dynamic> json) {
    return StorageStats(
      totalLocations: json['summary']['total_locations'] ?? 0,
      availableLocations: json['summary']['available_locations'] ?? 0,
      occupiedLocations: json['summary']['occupied_locations'] ?? 0,
      totalBoxes: json['summary']['total_boxes'] ?? 0,
      locationsInUse: json['summary']['locations_in_use'] ?? 0,
      boxesWithoutLocation: json['summary']['boxes_without_location'] ?? 0,
      utilization: (json['utilization'] as List<dynamic>?)
          ?.map((item) => LocationUtilization.fromJson(item))
          .toList() ?? [],
      recentActivities: (json['recent_activities'] as List<dynamic>?)
          ?.map((item) => RecentActivity.fromJson(item))
          .toList() ?? [],
    );
  }

  // Calculate utilization percentage
  double get utilizationPercentage {
    if (totalLocations == 0) return 0.0;
    return (occupiedLocations / totalLocations) * 100;
  }

  // Calculate availability percentage
  double get availabilityPercentage {
    if (totalLocations == 0) return 0.0;
    return (availableLocations / totalLocations) * 100;
  }

  // Calculate boxes per location
  double get averageBoxesPerLocation {
    if (locationsInUse == 0) return 0.0;
    return totalBoxes / locationsInUse;
  }
}

// storage_stats_model.dart
class LocationUtilization {
  final String labelCode;
  final String locationDescription;
  final bool isAvailable;
  final int boxCount;
  final String status;

  LocationUtilization({
    required this.labelCode,
    required this.locationDescription,
    required this.isAvailable,
    required this.boxCount,
    required this.status,
  });

  factory LocationUtilization.fromJson(Map<String, dynamic> json) {
    // Handle is_available conversion
    final isAvailable = json['is_available'] is bool
        ? json['is_available'] as bool
        : (json['is_available'] as int?) == 1;

    return LocationUtilization(
      labelCode: json['label_code'] ?? '',
      locationDescription: json['location_description'] ?? '',
      isAvailable: isAvailable,
      boxCount: json['box_count'] is int
          ? json['box_count'] as int
          : int.tryParse(json['box_count'].toString()) ?? 0,
      status: json['status'] ?? 'Unknown',
    );
  }
}

class RecentActivity {
  final String action;
  final String entityType;
  final int? entityId;
  final DateTime createdAt;

  RecentActivity({
    required this.action,
    required this.entityType,
    this.entityId,
    required this.createdAt,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      action: json['action'] ?? '',
      entityType: json['entity_type'] ?? '',
      entityId: json['entity_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class StorageStatus {
  final SystemStats system;
  final StorageDetailStats storage;
  final DateTime timestamp;

  StorageStatus({
    required this.system,
    required this.storage,
    required this.timestamp,
  });

  factory StorageStatus.fromJson(Map<String, dynamic> json) {
    return StorageStatus(
      system: SystemStats.fromJson(json['system']),
      storage: StorageDetailStats.fromJson(json['storage']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class SystemStats {
  final int totalBoxes;
  final int boxesStored;
  final int boxesRetrieved;
  final int boxesDestroyed;
  final int boxesPendingDestruction;
  final int totalClients;
  final int totalUsers;
  final int adminUsers;
  final int staffUsers;
  final int clientUsers;
  final int pendingRequests;
  final int todayCollections;
  final int todayRetrievals;
  final int todayDeliveries;

  SystemStats({
    required this.totalBoxes,
    required this.boxesStored,
    required this.boxesRetrieved,
    required this.boxesDestroyed,
    required this.boxesPendingDestruction,
    required this.totalClients,
    required this.totalUsers,
    required this.adminUsers,
    required this.staffUsers,
    required this.clientUsers,
    required this.pendingRequests,
    required this.todayCollections,
    required this.todayRetrievals,
    required this.todayDeliveries,
  });

  factory SystemStats.fromJson(Map<String, dynamic> json) {
    return SystemStats(
      totalBoxes: json['total_boxes'] ?? 0,
      boxesStored: json['boxes_stored'] ?? 0,
      boxesRetrieved: json['boxes_retrieved'] ?? 0,
      boxesDestroyed: json['boxes_destroyed'] ?? 0,
      boxesPendingDestruction: json['boxes_pending_destruction'] ?? 0,
      totalClients: json['total_clients'] ?? 0,
      totalUsers: json['total_users'] ?? 0,
      adminUsers: json['admin_users'] ?? 0,
      staffUsers: json['staff_users'] ?? 0,
      clientUsers: json['client_users'] ?? 0,
      pendingRequests: json['pending_requests'] ?? 0,
      todayCollections: json['today_collections'] ?? 0,
      todayRetrievals: json['today_retrievals'] ?? 0,
      todayDeliveries: json['today_deliveries'] ?? 0,
    );
  }
}

class StorageDetailStats {
  final int boxesStored;
  final int boxesRetrieved;
  final int boxesDestroyed;
  final int boxesPendingDestruction;
  final int boxesUnassigned;
  final int totalStorageLocations;

  StorageDetailStats({
    required this.boxesStored,
    required this.boxesRetrieved,
    required this.boxesDestroyed,
    required this.boxesPendingDestruction,
    required this.boxesUnassigned,
    required this.totalStorageLocations,
  });

  factory StorageDetailStats.fromJson(Map<String, dynamic> json) {
    return StorageDetailStats(
      boxesStored: json['boxes_stored'] ?? 0,
      boxesRetrieved: json['boxes_retrieved'] ?? 0,
      boxesDestroyed: json['boxes_destroyed'] ?? 0,
      boxesPendingDestruction: json['boxes_pending_destruction'] ?? 0,
      boxesUnassigned: json['boxes_unassigned'] ?? 0,
      totalStorageLocations: json['total_storage_locations'] ?? 0,
    );
  }
}