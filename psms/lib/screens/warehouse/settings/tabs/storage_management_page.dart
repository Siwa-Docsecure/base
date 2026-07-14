import 'dart:ui';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/storage_controller.dart';
import 'package:psms/models/racking_label_model.dart';
import 'package:psms/models/storage_stats_model.dart';
import 'package:psms/utils/responsive_helper.dart';
import 'package:fl_chart/fl_chart.dart';

import 'widgets/custom_card.dart';
import 'widgets/loading_indicator.dart';
import 'widgets/search_bar.dart';

// Enum for view mode (moved outside class)
enum ViewMode { list, grid }

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

  // View mode toggles
  ViewMode _locationsViewMode = ViewMode.grid;
  ViewMode _availableViewMode = ViewMode.list;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
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
          isAvailable:
              storageController.availableOnlyFilter.value ? true : null,
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Storage Management',
          style: ResponsiveHelper.isMobile(context)
              ? AppTypography.h5(fontWeight: FontWeight.w600)
              : AppTypography.h4(color: Colors.black, FontWeight.w600),
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
          tabs: const [
            Tab(icon: Icon(Icons.storage), text: 'Locations'),
            Tab(icon: Icon(Icons.check_circle), text: 'Available'),
            Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
            Tab(icon: Icon(Icons.health_and_safety), text: 'Status'),
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
        Container(
          margin: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.isMobile(context) ? 8 : 12, vertical: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: SearchBar(
                        hintText: 'Search by label code or description...',
                        onSearch: (value) {
                          storageController.getAllLocations(
                            page: 1,
                            search: value.isNotEmpty ? value : null,
                            isAvailable:
                                storageController.availableOnlyFilter.value
                                    ? true
                                    : null,
                            sortBy: storageController.sortBy.value,
                            sortOrder: storageController.sortOrder.value,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        storageController.getAllLocations(
                          page: 1,
                          search: storageController.searchQuery.value.isNotEmpty
                              ? storageController.searchQuery.value
                              : null,
                          isAvailable:
                              storageController.availableOnlyFilter.value
                                  ? true
                                  : null,
                          sortBy: value,
                          sortOrder: storageController.sortOrder.value,
                        );
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'label_code',
                            child: Text('Sort by Label Code')),
                        const PopupMenuItem(
                            value: 'location_description',
                            child: Text('Sort by Description')),
                        const PopupMenuItem(
                            value: 'is_available',
                            child: Text('Sort by Availability')),
                        const PopupMenuItem(
                            value: 'created_at',
                            child: Text('Sort by Date Created')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.border.withOpacity(0.3)),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort, size: 18, color: AppColors.textMedium),
                              if (!ResponsiveHelper.isMobile(context)) ...[
                                const SizedBox(width: 4),
                                Obx(() => Text(
                                      storageController.sortBy.value ==
                                              'label_code'
                                          ? 'Label Code'
                                          : storageController.sortBy.value ==
                                                  'location_description'
                                              ? 'Description'
                                              : storageController.sortBy.value ==
                                                      'is_available'
                                                  ? 'Availability'
                                                  : 'Date',
                                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMedium),
                                    )),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 38,
                      child: Material(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              _locationsViewMode =
                                  _locationsViewMode == ViewMode.grid
                                      ? ViewMode.list
                                      : ViewMode.grid;
                            });
                          },
                          child: Center(
                            child: Icon(
                              _locationsViewMode == ViewMode.grid
                                  ? Icons.view_list
                                  : Icons.grid_view,
                              size: 18,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Obx(() => _compactFilterChip(
                        selected: storageController.availableOnlyFilter.value,
                        onSelected: (selected) {
                          storageController.availableOnlyFilter.value =
                              selected;
                          storageController.getAllLocations(
                            page: 1,
                            search:
                                storageController.searchQuery.value.isNotEmpty
                                    ? storageController.searchQuery.value
                                    : null,
                            isAvailable: selected ? true : null,
                            sortBy: storageController.sortBy.value,
                            sortOrder: storageController.sortOrder.value,
                          );
                        },
                      )),
                  const Spacer(),
                  Obx(() => Text(
                        '${storageController.storageLocations.length} of ${storageController.totalLocations.value}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium,
                        ),
                      )),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildLocationsList(),
        ),
        _buildPaginationControls(),
      ],
    );
  }

  Widget _compactFilterChip({
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              'Available Only',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsList() {
    return Obx(() {
      if (storageController.isLoading.value &&
          storageController.storageLocations.isEmpty) {
        return const LoadingIndicator(
            message: 'Loading storage locations...', useCard: true);
      }
      if (storageController.storageLocations.isEmpty) {
        return _buildEmptyState(
          icon: Icons.storage_outlined,
          message: storageController.searchQuery.value.isEmpty
              ? 'No storage locations found'
              : 'No matching locations found',
          showClearButton: storageController.searchQuery.value.isNotEmpty,
          onClear: () {
            storageController.clearFilters();
            storageController.getAllLocations(page: 1);
          },
        );
      }
      return RefreshIndicator(
        onRefresh: () => storageController.getAllLocations(
          page: storageController.currentPage.value,
          search: storageController.searchQuery.value.isNotEmpty
              ? storageController.searchQuery.value
              : null,
          isAvailable:
              storageController.availableOnlyFilter.value ? true : null,
          sortBy: storageController.sortBy.value,
          sortOrder: storageController.sortOrder.value,
        ),
        child: _locationsViewMode == ViewMode.list
            ? GridView.builder(
                padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.isMobile(context) ? 10 : 14, vertical: 4),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveHelper.isDesktop(context) ? 4 : 1,
                  childAspectRatio: 3.4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: storageController.storageLocations.length,
                itemBuilder: (context, index) => _buildLocationCard(
                    storageController.storageLocations[index]),
              )
            : ListView.separated(
                itemCount: storageController.storageLocations.length,
                padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.isMobile(context) ? 10 : 14, vertical: 4),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildLocationCard(
                    storageController.storageLocations[index]),
              ),
      );
    });
  }

  Widget _buildLocationCard(RackingLabelModel location) {
    final isAvailable = location.isAvailable;
    final statusColor = isAvailable ? AppColors.success : AppColors.danger;
    final qty = location.boxesCount ?? 0;
    return CustomCard(
      margin: const EdgeInsets.all(0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 1,
      borderRadius: 8,
      onTap: () => _showLocationDetails(location),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  location.labelCode,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  location.locationDescription,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isAvailable ? 'Available' : 'Occupied',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$qty',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
                Text(qty == 1 ? 'box' : 'boxes',
                    style: const TextStyle(fontSize: 8, color: AppColors.textLight)),
              ],
            ),
          ),
          if (storageController.canManageStorage)
            SizedBox(
              width: 24,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: (value) => _handleLocationAction(value, location),
                icon: Icon(Icons.more_vert, size: 16, color: AppColors.textLight),
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
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.visibility, size: 18),
              onPressed: () => _showLocationDetails(location),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    bool showClearButton = false,
    VoidCallback? onClear,
  }) {
    return Center(
      child: CustomCard(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(message,
                style: AppTypography.bodyText(color: AppColors.textMedium)),
            if (showClearButton && onClear != null)
              TextButton(
                  onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Obx(() => Container(
          padding: AppEdgeInsets.allMedium,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: AppColors.border.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: AppBorderRadius.medium,
                ),
                child: Text(
                  'Page ${storageController.currentPage.value} of ${storageController.totalPages.value}',
                  style: AppTypography.bodyText(
                      weight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: storageController.currentPage.value <
                        storageController.totalPages.value
                    ? () => storageController.loadNextPage()
                    : null,
                color: storageController.currentPage.value <
                        storageController.totalPages.value
                    ? AppColors.primary
                    : AppColors.textLight,
              ),
            ],
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
          margin: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.isMobile(context) ? 8 : 12, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
            border: Border.all(color: AppColors.border.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Storage locations currently available for new boxes',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              SizedBox(
                width: 34,
                height: 34,
                child: Material(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _availableViewMode = _availableViewMode == ViewMode.grid
                            ? ViewMode.list
                            : ViewMode.grid;
                      });
                    },
                    child: Icon(
                      _availableViewMode == ViewMode.grid
                          ? Icons.view_list
                          : Icons.grid_view,
                      size: 18,
                      color: AppColors.textMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            if (storageController.isLoading.value &&
                storageController.availableLocations.isEmpty) {
              return const LoadingIndicator(
                  message: 'Loading available locations...', useCard: true);
            }
            if (storageController.availableLocations.isEmpty) {
              return _buildEmptyState(
                icon: Icons.assignment_turned_in,
                message: 'No available storage locations',
              );
            }
            return RefreshIndicator(
              onRefresh: () => storageController.getAvailableLocations(),
              child: _availableViewMode == ViewMode.grid
                  ? GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            ResponsiveHelper.isDesktop(context) ? 3 : 1,
                        childAspectRatio: 4.2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: storageController.availableLocations.length,
                      itemBuilder: (context, index) => _buildAvailableCard(
                          storageController.availableLocations[index]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      itemCount: storageController.availableLocations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildAvailableCard(
                          storageController.availableLocations[index]),
                    ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildAvailableCard(RackingLabelModel location) {
    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onTap: () => _showLocationDetails(location),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        minVerticalPadding: 2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: CircleAvatar(
          radius: 13,
          backgroundColor: AppColors.success.withOpacity(0.15),
          child: Icon(Icons.check, size: 14, color: AppColors.success),
        ),
        title: Text(
          location.labelCode,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
        ),
        subtitle: Text(
          location.locationDescription,
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Note: this list comes from the /available endpoint, which
        // doesn't return a real box count (storage_controller.dart hard-
        // codes boxes_count to 0 for every row here) — so we don't show
        // a quantity badge; it would just be a fake "0" every time.
        // Tap through to Location Details for the real box count.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text('Available',
                  style: TextStyle(
                      fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.success)),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.success),
          ],
        ),
      ),
    );
  }

  // ============================================
  // TAB 3: Statistics with Charts
  // ============================================
  Widget _buildStatisticsTab() {
    return Obx(() {
      if (storageController.isLoading.value &&
          storageController.storageStats.value == null) {
        return const LoadingIndicator(
            message: 'Loading statistics...', useCard: true);
      }
      if (storageController.storageStats.value == null) {
        return _buildEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load statistics',
          showClearButton: true,
          onClear: () => storageController.getStorageStatistics(),
        );
      }
      final stats = storageController.storageStats.value!;
      final isMobile = ResponsiveHelper.isMobile(context);
      return RefreshIndicator(
        onRefresh: () => storageController.getStorageStatistics(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 12 : AppSizes.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Storage Overview', Icons.dashboard_outlined),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount:
                    isMobile ? 2 : (ResponsiveHelper.isTablet(context) ? 3 : 6),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.85,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _kpiTile('Total Locations', stats.totalLocations.toString(),
                      Icons.storage, AppColors.primary),
                  _kpiTile('Available', stats.availableLocations.toString(),
                      Icons.check_circle, AppColors.success),
                  _kpiTile('Occupied', stats.occupiedLocations.toString(),
                      Icons.do_not_disturb, AppColors.danger),
                  _kpiTile('Locations in Use', stats.locationsInUse.toString(),
                      Icons.inventory, AppColors.warning),
                  _kpiTile('Total Boxes', stats.totalBoxes.toString(),
                      Icons.inventory_2, AppColors.info),
                  _kpiTile('No Location', stats.boxesWithoutLocation.toString(),
                      Icons.warning_amber, AppColors.purple),
                ],
              ),
              const SizedBox(height: 20),

              _sectionHeader('Status Distribution', Icons.pie_chart_outline),
              const SizedBox(height: 10),
              CustomCard(
                padding: const EdgeInsets.fromLTRB(10, 14, 14, 6),
                child: SizedBox(
                  height: 240,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                value: stats.availableLocations.toDouble(),
                                title: '${stats.availableLocations}',
                                color: AppColors.success,
                                radius: 56,
                                titleStyle: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              PieChartSectionData(
                                value: stats.occupiedLocations.toDouble(),
                                title: '${stats.occupiedLocations}',
                                color: AppColors.danger,
                                radius: 56,
                                titleStyle: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                            sectionsSpace: 3,
                            centerSpaceRadius: 32,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _legendDot('Available', AppColors.success, stats.availableLocations),
                            const SizedBox(height: 10),
                            _legendDot('Occupied', AppColors.danger, stats.occupiedLocations),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _sectionHeader('Box Count per Location (Top 10)', Icons.bar_chart),
              const SizedBox(height: 10),
              CustomCard(
                padding: const EdgeInsets.fromLTRB(10, 14, 14, 6),
                child: SizedBox(
                  height: 260,
                  child: stats.utilization.isEmpty
                      ? const Center(child: Text('No utilization data', style: TextStyle(color: AppColors.textLight)))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: stats.utilization
                                    .map((e) => e.boxCount)
                                    .reduce((a, b) => a > b ? a : b)
                                    .toDouble() +
                                2,
                            barGroups: stats.utilization.take(10).map((item) {
                              return BarChartGroupData(
                                x: stats.utilization.indexOf(item),
                                barRods: [
                                  BarChartRodData(
                                    toY: item.boxCount.toDouble(),
                                    color: AppColors.primary,
                                    width: 16,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              );
                            }).toList(),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index >= 0 && index < stats.utilization.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          stats.utilization[index].labelCode,
                                          style: const TextStyle(fontSize: 9),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 36,
                                ),
                              ),
                              leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (v) =>
                                  FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              _sectionHeader('Activity Trend (Last 7 Days)', Icons.show_chart),
              const SizedBox(height: 10),
              CustomCard(
                padding: const EdgeInsets.fromLTRB(10, 14, 14, 6),
                child: SizedBox(
                  height: 220,
                  child: _buildActivityTrendChart(stats.recentActivities),
                ),
              ),
              const SizedBox(height: 20),

              _sectionHeader('Recent Activity', Icons.history),
              const SizedBox(height: 10),
              CustomCard(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: stats.recentActivities.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No recent activities',
                            style: TextStyle(color: AppColors.textLight, fontSize: 12.5)),
                      )
                    : Column(
                        children: stats.recentActivities.map((activity) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _getActivityColor(activity.action).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    _getActivityIcon(activity.action),
                                    color: _getActivityColor(activity.action),
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${activity.action} · ${activity.entityType}',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        DateFormat('dd MMM yyyy, HH:mm').format(activity.createdAt.toLocal()),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textMedium),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _legendDot(String label, Color color, int value) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        Text('$value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  /// Buckets recentActivities by day (last 7 days) into a smooth line
  /// chart. There's no dedicated time-series field on the stats model,
  /// so this derives one client-side from the activity feed's timestamps.
  Widget _buildActivityTrendChart(List activities) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final counts = <int>[];
    for (final day in days) {
      final count = activities.where((a) {
        final dt = (a.createdAt as DateTime).toLocal();
        return dt.year == day.year && dt.month == day.month && dt.day == day.day;
      }).length;
      counts.add(count);
    }

    if (counts.every((c) => c == 0)) {
      return const Center(
          child: Text('No recent activity to chart', style: TextStyle(color: AppColors.textLight)));
    }

    final maxY = (counts.reduce((a, b) => a > b ? a : b)).toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const Text('');
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('E').format(days[i]), style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              return LineTooltipItem(
                '${DateFormat('dd MMM').format(days[s.x.toInt()])}\n${s.y.toInt()} event(s)',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (int i = 0; i < counts.length; i++) FlSpot(i.toDouble(), counts[i].toDouble())],
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: AppColors.primary,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary.withOpacity(0.22), AppColors.primary.withOpacity(0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact KPI tile: colored left accent, icon, big number, small label.
  Widget _kpiTile(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(
            title,
            style: const TextStyle(fontSize: 9.5, color: AppColors.textMedium, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ============================================
  // TAB 4: System Status with Charts
  // ============================================
  Widget _buildStatusTab() {
    return Obx(() {
      if (storageController.isLoading.value &&
          storageController.storageStatus.value == null) {
        return const LoadingIndicator(
            message: 'Loading system status...', useCard: true);
      }
      if (storageController.storageStatus.value == null) {
        return _buildEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load system status',
          showClearButton: true,
          onClear: () => storageController.getStorageStatus(),
        );
      }
      final status = storageController.storageStatus.value!;
      final isMobile = ResponsiveHelper.isMobile(context);
      return RefreshIndicator(
        onRefresh: () => storageController.getStorageStatus(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 12 : AppSizes.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Health banner up top — most important info first.
              _healthBanner(status.system, status.storage),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  'Last updated ${DateFormat('dd MMM yyyy, HH:mm').format(status.timestamp.toLocal())}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
              ),
              const SizedBox(height: 20),

              _sectionHeader('Storage Status', Icons.storage_outlined),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount:
                    isMobile ? 2 : (ResponsiveHelper.isTablet(context) ? 3 : 6),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.85,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _kpiTile('Locations', status.storage.totalStorageLocations.toString(),
                      Icons.storage, AppColors.primary),
                  _kpiTile('Stored', status.storage.boxesStored.toString(),
                      Icons.inventory_2, AppColors.success),
                  _kpiTile('Retrieved', status.storage.boxesRetrieved.toString(),
                      Icons.move_to_inbox, AppColors.info),
                  _kpiTile('Destroyed', status.storage.boxesDestroyed.toString(),
                      Icons.delete_outline, AppColors.danger),
                  _kpiTile('Pending Destr.', status.storage.boxesPendingDestruction.toString(),
                      Icons.warning_amber, AppColors.warning),
                  _kpiTile('Unassigned', status.storage.boxesUnassigned.toString(),
                      Icons.help_outline, AppColors.purple),
                ],
              ),
              const SizedBox(height: 20),

              _sectionHeader('System Overview', Icons.dns_outlined),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount:
                    isMobile ? 2 : (ResponsiveHelper.isTablet(context) ? 3 : 5),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.85,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _kpiTile('Total Boxes', status.system.totalBoxes.toString(),
                      Icons.inventory_2, AppColors.primary),
                  _kpiTile('Clients', status.system.totalClients.toString(),
                      Icons.business, AppColors.success),
                  _kpiTile('Users', status.system.totalUsers.toString(),
                      Icons.people, AppColors.info),
                  _kpiTile('Admins', status.system.adminUsers.toString(),
                      Icons.admin_panel_settings, AppColors.warning),
                  _kpiTile('Staff', status.system.staffUsers.toString(),
                      Icons.badge, AppColors.purple),
                  _kpiTile('Client Users', status.system.clientUsers.toString(),
                      Icons.person, AppColors.danger),
                  _kpiTile('Pending Req.', status.system.pendingRequests.toString(),
                      Icons.pending_actions, Colors.orange),
                  _kpiTile('Collections Today', status.system.todayCollections.toString(),
                      Icons.local_shipping, Colors.teal),
                  _kpiTile('Retrievals Today', status.system.todayRetrievals.toString(),
                      Icons.unarchive, Colors.brown),
                  _kpiTile('Deliveries Today', status.system.todayDeliveries.toString(),
                      Icons.outbox, Colors.cyan.shade700),
                ],
              ),
              const SizedBox(height: 20),

              _sectionHeader("Today's Activity", Icons.bar_chart),
              const SizedBox(height: 10),
              CustomCard(
                padding: const EdgeInsets.fromLTRB(10, 14, 14, 6),
                child: SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: [
                            status.system.todayCollections,
                            status.system.todayRetrievals,
                            status.system.todayDeliveries,
                            status.system.pendingRequests,
                          ].reduce((a, b) => a > b ? a : b).toDouble() +
                          2,
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [
                          BarChartRodData(
                              toY: status.system.todayCollections.toDouble(),
                              color: Colors.teal,
                              width: 24,
                              borderRadius: BorderRadius.circular(4))
                        ]),
                        BarChartGroupData(x: 1, barRods: [
                          BarChartRodData(
                              toY: status.system.todayRetrievals.toDouble(),
                              color: Colors.brown,
                              width: 24,
                              borderRadius: BorderRadius.circular(4))
                        ]),
                        BarChartGroupData(x: 2, barRods: [
                          BarChartRodData(
                              toY: status.system.todayDeliveries.toDouble(),
                              color: Colors.cyan.shade700,
                              width: 24,
                              borderRadius: BorderRadius.circular(4))
                        ]),
                        BarChartGroupData(x: 3, barRods: [
                          BarChartRodData(
                              toY: status.system.pendingRequests.toDouble(),
                              color: Colors.orange,
                              width: 24,
                              borderRadius: BorderRadius.circular(4))
                        ]),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const labels = ['Collections', 'Retrievals', 'Deliveries', 'Pending Req.'];
                              final i = value.toInt();
                              if (i >= 0 && i < labels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(labels[i], style: const TextStyle(fontSize: 10)),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    });
  }

  Widget _healthBanner(SystemStats system, StorageDetailStats storage) {
    final color = _getHealthStatusColor(system, storage);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(_getHealthStatusIcon(system, storage), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getHealthStatusTitle(system, storage),
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  _getHealthStatusMessage(system, storage),
                  style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ============================================
  // HELPER METHODS (unchanged from original)
  // ============================================
  // ============================================
  // DIALOGS — shared professional shell
  // ============================================

  /// Consistent dialog chrome used by create/edit/details/delete: a
  /// colored header bar with icon + title + close, and a max-width body.
  Widget _dialogShell({
    required IconData headerIcon,
    required Color headerColor,
    required String title,
    String? subtitle,
    required Widget body,
    List<Widget>? actions,
    double width = 440,
  }) {
    final isMobile = ResponsiveHelper.isMobile(Get.context ?? context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: isMobile ? double.maxFinite : width,
        constraints: const BoxConstraints(maxHeight: 640),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(headerIcon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Get.back(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: body,
              ),
            ),
            if (actions != null)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.2))),
                ),
                child: Row(children: actions),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final labelCodeController = TextEditingController();
    final descriptionController = TextEditingController();

    await Get.dialog(
      _dialogShell(
        headerIcon: Icons.add_location_alt_outlined,
        headerColor: AppColors.primary,
        title: 'New Storage Location',
        subtitle: 'Register a new rack or shelf label',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: labelCodeController,
              decoration: InputDecoration(
                labelText: 'Label Code*',
                hintText: 'e.g., RACK-D-01 (min. 3 chars)',
                prefixIcon: const Icon(Icons.qr_code_2, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Location Description*',
                hintText: 'e.g., Warehouse D - Section 1 - Level 1 (min. 5 chars)',
                prefixIcon: const Icon(Icons.description_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Get.back(),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
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
                if (success && mounted) Get.back();
              },
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
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
      _dialogShell(
        headerIcon: Icons.edit_location_alt_outlined,
        headerColor: AppColors.warning,
        title: 'Edit ${location.labelCode}',
        subtitle: 'Update label details and availability',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: labelCodeController,
              decoration: InputDecoration(
                labelText: 'Label Code (min. 3 chars)',
                prefixIcon: const Icon(Icons.qr_code_2, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Location Description (min. 5 chars)',
                prefixIcon: const Icon(Icons.description_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Obx(() => Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    dense: true,
                    title: const Text('Available for new boxes',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: isAvailable.value,
                    activeColor: AppColors.primary,
                    onChanged: (value) => isAvailable.value = value,
                  ),
                )),
          ],
        ),
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Get.back(),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
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
                if (success && mounted) Get.back();
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationDetails(RackingLabelModel location) async {
    final detailedLocation = await storageController.getLocationDetails(location.labelId);
    if (detailedLocation == null) return;

    final isAvailable = detailedLocation.isAvailable;
    final statusColor = isAvailable ? AppColors.success : AppColors.danger;
    final boxCount = detailedLocation.boxesCount ?? 0;

    await Get.dialog(
      _dialogShell(
        headerIcon: isAvailable ? Icons.check_circle_outline : Icons.inventory_2_outlined,
        headerColor: statusColor,
        title: detailedLocation.labelCode,
        subtitle: isAvailable ? 'Available for new boxes' : 'Currently occupied',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(Icons.badge_outlined, 'Label ID', '#${detailedLocation.labelId}'),
            _detailDivider(),
            _detailRow(Icons.description_outlined, 'Description', detailedLocation.locationDescription),
            _detailDivider(),
            _detailRow(Icons.inventory_2_outlined, 'Boxes Assigned',
                '$boxCount box${boxCount == 1 ? '' : 'es'}'),
            _detailDivider(),
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: statusColor),
                const SizedBox(width: 10),
                const SizedBox(
                  width: 110,
                  child: Text('Status',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(isAvailable ? 'Available' : 'Occupied',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
          ],
        ),
        actions: storageController.canManageStorage
            ? [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                      Get.back();
                      _showEditDialog(detailedLocation);
                    },
                  ),
                ),
                if (isAvailable && boxCount == 0) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                      label: const Text('Delete', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Get.back();
                        _confirmDeleteLocation(detailedLocation);
                      },
                    ),
                  ),
                ],
              ]
            : null,
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textLight),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textLight, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _detailDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Divider(height: 1, color: AppColors.border.withOpacity(0.3)),
      );

  void _confirmDeleteLocation(RackingLabelModel location) {
    Get.dialog(
      _dialogShell(
        headerIcon: Icons.warning_amber_rounded,
        headerColor: AppColors.danger,
        title: 'Delete Storage Location',
        subtitle: 'This action cannot be undone',
        body: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.4),
            children: [
              const TextSpan(text: 'Are you sure you want to permanently delete '),
              TextSpan(text: location.labelCode, style: const TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: '? This location must remain unused to be removed.'),
            ],
          ),
        ),
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Get.back(),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () async {
                await storageController.deleteLocation(location.labelId);
                Get.back();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
        width: 400,
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

  IconData _getHealthStatusIcon(
      SystemStats system, StorageDetailStats storage) {
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

  String _getHealthStatusMessage(
      SystemStats system, StorageDetailStats storage) {
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