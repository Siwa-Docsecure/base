// storage_management_page.dart
import 'dart:ui';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:get/get.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/storage_controller.dart';
import 'package:psms/models/racking_label_model.dart';
import 'package:psms/models/storage_stats_model.dart';
import 'package:psms/utils/responsive_helper.dart';

import 'widgets/loading_indicator.dart';
import 'widgets/search_bar.dart';

class StorageManagementPage extends StatefulWidget {
  const StorageManagementPage({super.key});

  @override
  State<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends State<StorageManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StorageController storageController = Get.put(StorageController());
  final RxBool _statsLoaded = false.obs;
  final RxBool _statusLoaded = false.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    // Initialize only the first tab data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      storageController.initialize();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;
    
    final currentIndex = _tabController.index;
    
    // Load data only when tab is selected
    if (currentIndex == 2 && !_statsLoaded.value) {
      _loadStatistics();
    } else if (currentIndex == 3 && !_statusLoaded.value) {
      _loadStatus();
    }
  }

  Future<void> _loadStatistics() async {
    if (!_statsLoaded.value) {
      await storageController.getStorageStatistics();
      _statsLoaded.value = true;
    }
  }

  Future<void> _loadStatus() async {
    if (!_statusLoaded.value) {
      await storageController.getStorageStatus();
      _statusLoaded.value = true;
    }
  }

  Future<void> _refreshCurrentTab() async {
    final currentIndex = _tabController.index;
    
    switch (currentIndex) {
      case 0:
        await storageController.getAllLocations(
          page: 1,
          search: storageController.searchQuery.value.isNotEmpty 
              ? storageController.searchQuery.value 
              : null,
          isAvailable: storageController.availableOnlyFilter.value ? true : null,
          sortBy: storageController.sortBy.value,
          sortOrder: storageController.sortOrder.value,
        );
        break;
      case 1:
        await storageController.getAvailableLocations();
        break;
      case 2:
        await storageController.getStorageStatistics();
        break;
      case 3:
        await storageController.getStorageStatus();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.1),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black.withOpacity(0.1),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.1),
            ),
          ),
        ),
        title: Text(
          'Storage Management',
          style: ResponsiveHelper.isMobile(context) 
              ? AppTypography.h5(fontWeight: FontWeight.w600)
              : AppTypography.h4(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCurrentTab,
            tooltip: 'Refresh Current Tab',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          isScrollable: ResponsiveHelper.isMobile(context),
          tabs: [
            Tab(
              icon: Icon(Icons.storage, size: ResponsiveHelper.isMobile(context) ? 20 : 24),
              text: 'Locations',
            ),
            Tab(
              icon: Icon(Icons.check_circle, size: ResponsiveHelper.isMobile(context) ? 20 : 24),
              text: 'Available',
            ),
            Tab(
              icon: Icon(Icons.analytics, size: ResponsiveHelper.isMobile(context) ? 20 : 24),
              text: 'Statistics',
            ),
            Tab(
              icon: Icon(Icons.health_and_safety, size: ResponsiveHelper.isMobile(context) ? 20 : 24),
              text: 'Status',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLocationsTab(),
          _buildAvailableTab(),
          _buildStatisticsTab(),
          _buildStatusTab(),
        ],
      ),
      floatingActionButton: Obx(() {
        if (storageController.canManageStorage && _tabController.index == 0) {
          return FloatingActionButton(
            onPressed: () => _showCreateDialog(),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          );
        }
        return const SizedBox.shrink();
      }),
    );
  }

  // ============================================
  // TAB 1: All Storage Locations
  // ============================================

  Widget _buildLocationsTab() {
    return Column(
      children: [
        // Search and Filter Section with glass effect
        Container(
          margin: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: AppBorderRadius.large,
            border: Border.all(
              color: AppColors.border.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: AppBorderRadius.large,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 12 : AppSizes.spacing16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SearchBar(
                            hintText: 'Search by label code or description...',
                            onSearch: (value) {
                              storageController.getAllLocations(
                                page: 1,
                                search: value.isNotEmpty ? value : null,
                                isAvailable: storageController.availableOnlyFilter.value ? true : null,
                                sortBy: storageController.sortBy.value,
                                sortOrder: storageController.sortOrder.value,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: AppSizes.spacing12),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            storageController.getAllLocations(
                              page: 1,
                              search: storageController.searchQuery.value.isNotEmpty 
                                  ? storageController.searchQuery.value 
                                  : null,
                              isAvailable: storageController.availableOnlyFilter.value ? true : null,
                              sortBy: value,
                              sortOrder: storageController.sortOrder.value,
                            );
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'label_code', child: Text('Sort by Label Code')),
                            const PopupMenuItem(value: 'location_description', child: Text('Sort by Description')),
                            const PopupMenuItem(value: 'is_available', child: Text('Sort by Availability')),
                            const PopupMenuItem(value: 'created_at', child: Text('Sort by Date Created')),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: AppBorderRadius.medium,
                              border: Border.all(color: AppColors.border.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sort, size: 20),
                                if (!ResponsiveHelper.isMobile(context)) ...[
                                  const SizedBox(width: 4),
                                  Obx(() => Text(
                                    storageController.sortBy.value == 'label_code' ? 'Label Code' :
                                    storageController.sortBy.value == 'location_description' ? 'Description' :
                                    storageController.sortBy.value == 'is_available' ? 'Availability' : 'Date',
                                    style: AppTypography.bodyText(),
                                  )),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spacing12),
                    Row(
                      children: [
                        Obx(() => FilterChip(
                          label: const Text('Available Only'),
                          selected: storageController.availableOnlyFilter.value,
                          onSelected: (selected) {
                            storageController.availableOnlyFilter.value = selected;
                            storageController.getAllLocations(
                              page: 1,
                              search: storageController.searchQuery.value.isNotEmpty 
                                  ? storageController.searchQuery.value 
                                  : null,
                              isAvailable: selected ? true : null,
                              sortBy: storageController.sortBy.value,
                              sortOrder: storageController.sortOrder.value,
                            );
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                        )),
                        const Spacer(),
                        Obx(() => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: AppBorderRadius.small,
                          ),
                          child: Text(
                            '${storageController.storageLocations.length} of ${storageController.totalLocations.value} locations',
                            style: AppTypography.bodyText(
                              weight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spacing8),
        Expanded(
          child: _buildLocationsList(),
        ),
        _buildPaginationControls(),
      ],
    );
  }

  Widget _buildLocationsList() {
    return Obx(() {
      if (storageController.isLoading.value && storageController.storageLocations.isEmpty) {
        return const LoadingIndicator(message: 'Loading storage locations...');
      }

      if (storageController.storageLocations.isEmpty) {
        return Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.large,
              color: Colors.black.withOpacity(0.1),
              border: Border.all(
                color: AppColors.border.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: AppBorderRadius.large,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storage_outlined, size: 64, color: AppColors.textLight),
                    const SizedBox(height: 16),
                    Text(
                      storageController.searchQuery.value.isEmpty 
                          ? 'No storage locations found' 
                          : 'No matching locations found',
                      style: AppTypography.bodyText(color: AppColors.textMedium),
                    ),
                    if (storageController.searchQuery.value.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          storageController.clearFilters();
                          storageController.getAllLocations(page: 1);
                        },
                        child: const Text('Clear filters'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => storageController.getAllLocations(
          page: storageController.currentPage.value,
          search: storageController.searchQuery.value.isNotEmpty 
              ? storageController.searchQuery.value 
              : null,
          isAvailable: storageController.availableOnlyFilter.value ? true : null,
          sortBy: storageController.sortBy.value,
          sortOrder: storageController.sortOrder.value,
        ),
        child: ResponsiveHelper.isDesktop(context) || ResponsiveHelper.isTablet(context)
            ? GridView.builder(
                padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 12 : 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveHelper.isDesktop(context) ? 2 : 1,
                  childAspectRatio: ResponsiveHelper.isDesktop(context) ? 3 : 2.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: storageController.storageLocations.length,
                itemBuilder: (context, index) {
                  final location = storageController.storageLocations[index];
                  return _buildLocationCard(location);
                },
              )
            : ListView.builder(
                itemCount: storageController.storageLocations.length,
                padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 12 : 16),
                itemBuilder: (context, index) {
                  final location = storageController.storageLocations[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildLocationCard(location),
                  );
                },
              ),
      );
    });
  }

  Widget _buildLocationCard(RackingLabelModel location) {
    final isAvailable = location.isAvailable;
    final statusColor = isAvailable ? AppColors.success : AppColors.danger;

    return GestureDetector(
      onTap: () => _showLocationDetails(location),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: AppBorderRadius.large,
          border: Border.all(
            color: statusColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: AppBorderRadius.large,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        location.isAvailable ? Icons.check_circle : Icons.circle,
                        color: statusColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            location.labelCode,
                            style: AppTypography.h5(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            location.locationDescription,
                            style: AppTypography.bodyText(color: AppColors.textMedium),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  location.isAvailable ? 'Available' : 'Occupied',
                                  style: AppTypography.bodyText(
                                    color: statusColor,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.inventory_2_outlined, 
                                   size: 14, 
                                   color: AppColors.textLight),
                              const SizedBox(width: 4),
                              Text(
                                '${location.boxesCount ?? 0} boxes',
                                style: AppTypography.bodyText(weight: FontWeight.w300),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (storageController.canManageStorage)
                      PopupMenuButton<String>(
                        onSelected: (value) => _handleLocationAction(value, location),
                        icon: Icon(Icons.more_vert, color: AppColors.textLight),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, size: 18),
                                SizedBox(width: 12),
                                Text('View Details'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 12),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          if (location.isAvailable && (location.boxesCount ?? 0) == 0)
                            const PopupMenuItem(
                              value: 'delete', 
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 12),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                        ],
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () => _showLocationDetails(location),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildPaginationControls() {
    return Obx(() => Container(
      padding: AppEdgeInsets.allMedium,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        border: Border(
          top: BorderSide(
            color: AppColors.border.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: storageController.currentPage.value > 1 
                    ? () => storageController.loadPreviousPage() 
                    : null,
                color: storageController.currentPage.value > 1
                    ? AppColors.primary
                    : AppColors.textLight,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: AppBorderRadius.medium,
                ),
                child: Text(
                  'Page ${storageController.currentPage.value} of ${storageController.totalPages.value}',
                  style: AppTypography.bodyText(
                    weight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: storageController.currentPage.value < storageController.totalPages.value
                    ? () => storageController.loadNextPage()
                    : null,
                color: storageController.currentPage.value < storageController.totalPages.value
                    ? AppColors.primary
                    : AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    ));
  }

  // ============================================
  // TAB 2: Available Locations
  // ============================================

  Widget _buildAvailableTab() {
    return Column(
      children: [
        Container(
          margin: AppEdgeInsets.allMedium,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: AppBorderRadius.medium,
            color: Colors.black.withOpacity(0.1),
            border: Border.all(
              color: AppColors.info.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: AppBorderRadius.medium,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These are storage locations currently available for new boxes',
                      style: AppTypography.bodyText(color: AppColors.textMedium),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (storageController.isLoading.value && storageController.availableLocations.isEmpty) {
              return const LoadingIndicator(message: 'Loading available locations...');
            }

            if (storageController.availableLocations.isEmpty) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    borderRadius: AppBorderRadius.large,
                    color: Colors.black.withOpacity(0.1),
                    border: Border.all(
                      color: AppColors.border.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: AppBorderRadius.large,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_turned_in, size: 64, color: AppColors.textLight),
                          const SizedBox(height: 16),
                          Text(
                            'No available storage locations',
                            style: AppTypography.bodyText(color: AppColors.textMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => storageController.getAvailableLocations(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: storageController.availableLocations.length,
                itemBuilder: (context, index) {
                  final location = storageController.availableLocations[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: AppBorderRadius.large,
                      color: Colors.black.withOpacity(0.1),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: AppBorderRadius.large,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.success.withOpacity(0.15),
                            child: Icon(Icons.check, color: AppColors.success),
                          ),
                          title: Text(
                            location.labelCode,
                            style: AppTypography.h5(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            location.locationDescription,
                            style: AppTypography.bodyText(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppColors.success,
                          ),
                          onTap: () => _showLocationDetails(location),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  // ============================================
  // TAB 3: Statistics
  // ============================================

  Widget _buildStatisticsTab() {
    return Obx(() {
      if (storageController.isLoading.value && storageController.storageStats.value == null) {
        return const LoadingIndicator(message: 'Loading statistics...');
      }

      if (storageController.storageStats.value == null) {
        return Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.large,
              color: Colors.black.withOpacity(0.1),
              border: Border.all(
                color: AppColors.danger.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: AppBorderRadius.large,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load statistics',
                      style: AppTypography.bodyText(color: AppColors.danger),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => storageController.getStorageStatistics(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final stats = storageController.storageStats.value!;
      return SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 12 : AppSizes.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Text(
              'Storage Overview',
              style: ResponsiveHelper.isMobile(context) 
                  ? AppTypography.h5(fontWeight: FontWeight.w600)
                  : AppTypography.h4(color: Colors.white),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : (ResponsiveHelper.isTablet(context) ? 3 : 3),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: ResponsiveHelper.isMobile(context) ? 1.3 : 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(
                  'Total Locations',
                  stats.totalLocations.toString(),
                  Icons.storage,
                  AppColors.primary,
                ),
                _buildStatCard(
                  'Available',
                  stats.availableLocations.toString(),
                  Icons.check_circle,
                  AppColors.success,
                ),
                _buildStatCard(
                  'Occupied',
                  stats.occupiedLocations.toString(),
                  Icons.do_not_disturb,
                  AppColors.danger,
                ),
                _buildStatCard(
                  'Locations in Use',
                  stats.locationsInUse.toString(),
                  Icons.inventory,
                  AppColors.warning,
                ),
                _buildStatCard(
                  'Total Boxes',
                  stats.totalBoxes.toString(),
                  Icons.inventory_2,
                  AppColors.info,
                ),
                _buildStatCard(
                  'Boxes Without Location',
                  stats.boxesWithoutLocation.toString(),
                  Icons.warning,
                  AppColors.purple,
                ),
              ],
            ),

            // Utilization Chart
            const SizedBox(height: 24),
            Text(
              'Location Utilization',
              style: ResponsiveHelper.isMobile(context) 
                  ? AppTypography.h5(fontWeight: FontWeight.w600)
                  : AppTypography.h4(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: AppBorderRadius.large,
                color: Colors.black.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppBorderRadius.large,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: AppEdgeInsets.allMedium,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Label Code', style: AppTypography.bodyText(weight: FontWeight.w600)),
                            Text('Box Count', style: AppTypography.bodyText(weight: FontWeight.w600)),
                            Text('Status', style: AppTypography.bodyText(weight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (stats.utilization.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No utilization data available',
                              style: AppTypography.bodyText(color: AppColors.textLight),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ...stats.utilization.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.labelCode,
                                    style: AppTypography.bodyText(),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.boxCount.toString(),
                                    style: AppTypography.bodyText(),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (item.status == 'Available' ? AppColors.success : AppColors.danger)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.status,
                                      style: AppTypography.bodyText(
                                        color: item.status == 'Available' ? AppColors.success : AppColors.danger,
                                        weight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Recent Activities
            const SizedBox(height: 24),
            Text(
              'Recent Activities',
              style: ResponsiveHelper.isMobile(context) 
                  ? AppTypography.h5(fontWeight: FontWeight.w600)
                  : AppTypography.h4(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: AppBorderRadius.large,
                color: Colors.black.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppBorderRadius.large,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: AppEdgeInsets.allMedium,
                    child: Column(
                      children: [
                        if (stats.recentActivities.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No recent activities',
                              style: AppTypography.bodyText(color: AppColors.textLight),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ...stats.recentActivities.map((activity) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getActivityColor(activity.action).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getActivityIcon(activity.action),
                                color: _getActivityColor(activity.action),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              '${activity.action} - ${activity.entityType}',
                              style: AppTypography.bodyText(),
                            ),
                            subtitle: Text(
                              activity.createdAt.toLocal().toString(),
                              style: AppTypography.bodyText(weight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: AppBorderRadius.large,
        color: Colors.black.withOpacity(0.1),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppBorderRadius.large,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 12),
              Text(
                value,
                style: AppTypography.h5(fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTypography.bodyText(weight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // TAB 4: System Status
  // ============================================

  Widget _buildStatusTab() {
    return Obx(() {
      if (storageController.isLoading.value && storageController.storageStatus.value == null) {
        return const LoadingIndicator(message: 'Loading system status...');
      }

      if (storageController.storageStatus.value == null) {
        return Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.large,
              color: Colors.black.withOpacity(0.1),
              border: Border.all(
                color: AppColors.danger.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: AppBorderRadius.large,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load system status',
                      style: AppTypography.bodyText(color: AppColors.danger),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => storageController.getStorageStatus(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final status = storageController.storageStatus.value!;
      return SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 12 : AppSizes.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System Overview
            Text(
              'System Status',
              style: ResponsiveHelper.isMobile(context) 
                  ? AppTypography.h5(fontWeight: FontWeight.w600)
                  : AppTypography.h4(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${status.timestamp.toLocal()}',
              style: AppTypography.bodyText(weight: FontWeight.w600),
            ),
            const SizedBox(height: 24),

            // Storage Status
            Text(
              'Storage Status',
              style: AppTypography.h5(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: AppBorderRadius.large,
                color: Colors.black.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppBorderRadius.large,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: AppEdgeInsets.allMedium,
                    child: Column(
                      children: [
                        _buildStatusRow('Total Storage Locations', status.storage.totalStorageLocations.toString()),
                        _buildStatusRow('Boxes Stored', status.storage.boxesStored.toString()),
                        _buildStatusRow('Boxes Retrieved', status.storage.boxesRetrieved.toString()),
                        _buildStatusRow('Boxes Destroyed', status.storage.boxesDestroyed.toString()),
                        _buildStatusRow('Boxes Pending Destruction', status.storage.boxesPendingDestruction.toString()),
                        _buildStatusRow('Boxes Unassigned', status.storage.boxesUnassigned.toString()),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // System Stats
            Text(
              'System Overview',
              style: AppTypography.h5(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: AppBorderRadius.large,
                color: Colors.black.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppBorderRadius.large,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: AppEdgeInsets.allMedium,
                    child: Column(
                      children: [
                        _buildStatusRow('Total Boxes', status.system.totalBoxes.toString()),
                        _buildStatusRow('Total Clients', status.system.totalClients.toString()),
                        _buildStatusRow('Total Users', status.system.totalUsers.toString()),
                        _buildStatusRow('Admin Users', status.system.adminUsers.toString()),
                        _buildStatusRow('Staff Users', status.system.staffUsers.toString()),
                        _buildStatusRow('Client Users', status.system.clientUsers.toString()),
                        _buildStatusRow('Pending Requests', status.system.pendingRequests.toString()),
                        _buildStatusRow("Today's Collections", status.system.todayCollections.toString()),
                        _buildStatusRow("Today's Retrievals", status.system.todayRetrievals.toString()),
                        _buildStatusRow("Today's Deliveries", status.system.todayDeliveries.toString()),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Health Status
            Container(
              decoration: BoxDecoration(
                borderRadius: AppBorderRadius.large,
                color: Colors.black.withOpacity(0.1),
              ),
              child: ClipRRect(
                borderRadius: AppBorderRadius.large,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          _getHealthStatusIcon(status.system, status.storage),
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getHealthStatusTitle(status.system, status.storage),
                                style: AppTypography.h5(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getHealthStatusMessage(status.system, status.storage),
                                style: AppTypography.bodyText(color: Colors.black.withOpacity(0.1)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyText()),
          Text(
            value,
            style: AppTypography.bodyText(weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  Future<void> _showCreateDialog() async {
    final labelCodeController = TextEditingController();
    final descriptionController = TextEditingController();

    await Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        backgroundColor: Colors.black.withOpacity(0.1),
        title: ClipRRect(
          borderRadius: AppBorderRadius.large,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const Text('Create Storage Location'),
          ),
        ),
        content: ClipRRect(
          borderRadius: AppBorderRadius.large,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Label Code*',
                      hintText: 'e.g., RACK-D-01 (min. 3 chars)',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Location Description*',
                      hintText: 'e.g., Warehouse D - Section 1 - Level 1 (min. 5 chars)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (labelCodeController.text.trim().length < 3) {
                Get.snackbar('Error', 'Label code must be at least 3 characters');
                return;
              }
              if (descriptionController.text.trim().length < 5) {
                Get.snackbar('Error', 'Location description must be at least 5 characters');
                return;
              }

              final success = await storageController.createLocation(
                CreateLocationRequest(
                  labelCode: labelCodeController.text.trim(),
                  locationDescription: descriptionController.text.trim(),
                ),
              );

              if (success && mounted) {
                Get.back();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(RackingLabelModel location) async {
    final labelCodeController = TextEditingController(text: location.labelCode);
    final descriptionController = TextEditingController(text: location.locationDescription);
    final isAvailable = location.isAvailable.obs;

    await Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        backgroundColor: Colors.black.withOpacity(0.1),
        title: ClipRRect(
          borderRadius: AppBorderRadius.large,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Text('Edit ${location.labelCode}'),
          ),
        ),
        content: ClipRRect(
          borderRadius: AppBorderRadius.large,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Label Code (min. 3 chars)',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Location Description (min. 5 chars)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Obx(() => CheckboxListTile(
                    title: const Text('Available for new boxes'),
                    value: isAvailable.value,
                    onChanged: (value) => isAvailable.value = value!,
                  )),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (labelCodeController.text.trim().isNotEmpty && 
                  labelCodeController.text.trim().length < 3) {
                Get.snackbar('Error', 'Label code must be at least 3 characters');
                return;
              }
              if (descriptionController.text.trim().isNotEmpty && 
                  descriptionController.text.trim().length < 5) {
                Get.snackbar('Error', 'Location description must be at least 5 characters');
                return;
              }

              final success = await storageController.updateLocation(
                location.labelId,
                UpdateLocationRequest(
                  labelCode: labelCodeController.text.trim(),
                  locationDescription: descriptionController.text.trim(),
                  isAvailable: isAvailable.value,
                ),
              );

              if (success && mounted) {
                Get.back();
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationDetails(RackingLabelModel location) async {
    // First load the details
    final detailedLocation = await storageController.getLocationDetails(location.labelId);
    if (detailedLocation == null) return;

    await Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        backgroundColor: Colors.black.withOpacity(0.1),
        content: ClipRRect(
          borderRadius: AppBorderRadius.large,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: ResponsiveHelper.isMobile(Get.context!) ? double.maxFinite : 500,
              constraints: BoxConstraints(
                maxHeight: ResponsiveHelper.isMobile(Get.context!) ? 600 : 700,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Storage Location Details', style: AppTypography.h4(color: Colors.white)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Get.back(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Location Info
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (detailedLocation.isAvailable ? AppColors.success : AppColors.danger)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          detailedLocation.isAvailable ? Icons.check_circle : Icons.circle,
                          color: detailedLocation.isAvailable ? AppColors.success : AppColors.danger,
                          size: 28,
                        ),
                      ),
                      title: Text(detailedLocation.labelCode, style: AppTypography.h5(fontWeight: FontWeight.w600)),
                      subtitle: Text('Status: ${detailedLocation.isAvailable ? 'Available' : 'Occupied'}'),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: AppBorderRadius.medium,
                        border: Border.all(
                          color: AppColors.border.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Description', style: AppTypography.bodyText(weight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(detailedLocation.locationDescription, style: AppTypography.bodyText()),
                          const SizedBox(height: 16),
                          Text('Box Count', style: AppTypography.bodyText(weight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('${detailedLocation.boxesCount ?? 0} boxes assigned', 
                               style: AppTypography.bodyText()),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (storageController.canManageStorage)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                              onPressed: () {
                                Get.back();
                                _showEditDialog(detailedLocation);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (detailedLocation.isAvailable && (detailedLocation.boxesCount ?? 0) == 0)
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.delete),
                                label: const Text('Delete'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                ),
                                onPressed: () {
                                  Get.back();
                                  _confirmDeleteLocation(detailedLocation);
                                },
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteLocation(RackingLabelModel location) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        backgroundColor: Colors.black.withOpacity(0.1),
        title: ClipRRect(
          borderRadius: AppBorderRadius.large,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const Text('Delete Storage Location'),
          ),
        ),
        content: ClipRRect(
          borderRadius: AppBorderRadius.large,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Text('Are you sure you want to delete "${location.labelCode}"? This action cannot be undone.'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await storageController.deleteLocation(location.labelId);
              Get.back();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleLocationAction(String action, RackingLabelModel location) {
    switch (action) {
      case 'view':
        _showLocationDetails(location);
        break;
      case 'edit':
        _showEditDialog(location);
        break;
      case 'delete':
        _confirmDeleteLocation(location);
        break;
    }
  }

  IconData _getActivityIcon(String action) {
    switch (action.toLowerCase()) {
      case 'create':
        return Icons.add_circle;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      default:
        return Icons.notifications;
    }
  }

  Color _getActivityColor(String action) {
    switch (action.toLowerCase()) {
      case 'create':
        return AppColors.success;
      case 'update':
        return AppColors.warning;
      case 'delete':
        return AppColors.danger;
      case 'login':
        return AppColors.info;
      case 'logout':
        return AppColors.purple;
      default:
        return AppColors.textMedium;
    }
  }

  Color _getHealthStatusColor(SystemStats system, StorageDetailStats storage) {
    final unassignedBoxes = storage.boxesUnassigned;
    final pendingDestruction = storage.boxesPendingDestruction;
    
    if (unassignedBoxes > 10 || pendingDestruction > 20) {
      return AppColors.danger;
    } else if (unassignedBoxes > 5 || pendingDestruction > 10) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  IconData _getHealthStatusIcon(SystemStats system, StorageDetailStats storage) {
    final unassignedBoxes = storage.boxesUnassigned;
    final pendingDestruction = storage.boxesPendingDestruction;
    
    if (unassignedBoxes > 10 || pendingDestruction > 20) {
      return Icons.error;
    } else if (unassignedBoxes > 5 || pendingDestruction > 10) {
      return Icons.warning;
    }
    return Icons.check_circle;
  }

  String _getHealthStatusTitle(SystemStats system, StorageDetailStats storage) {
    final unassignedBoxes = storage.boxesUnassigned;
    final pendingDestruction = storage.boxesPendingDestruction;
    
    if (unassignedBoxes > 10 || pendingDestruction > 20) {
      return 'Attention Required';
    } else if (unassignedBoxes > 5 || pendingDestruction > 10) {
      return 'Needs Monitoring';
    }
    return 'All Systems Normal';
  }

  String _getHealthStatusMessage(SystemStats system, StorageDetailStats storage) {
    final unassignedBoxes = storage.boxesUnassigned;
    final pendingDestruction = storage.boxesPendingDestruction;
    
    if (unassignedBoxes > 10 && pendingDestruction > 20) {
      return 'High number of unassigned boxes and pending destructions';
    } else if (unassignedBoxes > 10) {
      return 'High number of unassigned boxes';
    } else if (pendingDestruction > 20) {
      return 'High number of boxes pending destruction';
    } else if (unassignedBoxes > 5 || pendingDestruction > 10) {
      return 'Moderate issues detected';
    }
    return 'Storage system operating normally';
  }
}