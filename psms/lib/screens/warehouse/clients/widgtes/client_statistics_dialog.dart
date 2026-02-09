// lib/screens/warehouse/clients/widgets/client_statistics_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/models/client_model.dart';

class ClientStatisticsDialog extends StatefulWidget {
  final ClientModel client;
  
  const ClientStatisticsDialog({
    super.key,
    required this.client,
  });

  @override
  State<ClientStatisticsDialog> createState() => _ClientStatisticsDialogState();
}

class _ClientStatisticsDialogState extends State<ClientStatisticsDialog> {
  final ClientManagementController _controller = Get.find<ClientManagementController>();
  
  bool _isLoading = true;
  Map<String, dynamic>? _statistics;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }
  
  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final stats = await _controller.getClientStatistics(widget.client.clientId);
      if (mounted) {
        setState(() {
          _statistics = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load statistics: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.medium,
      ),
      child: Container(
        width: 900,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),
            
            // Content
            Flexible(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _buildContent(),
            ),
            
            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: AppEdgeInsets.allMedium,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppSizes.radiusMedium),
          topRight: Radius.circular(AppSizes.radiusMedium),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.analytics,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Client Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.client.clientName,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadStatistics,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Get.back(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading statistics...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Failed to Load Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unexpected error occurred',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadStatistics,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContent() {
    if (_statistics == null || _statistics!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            const Text(
              'No statistics available',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: AppEdgeInsets.allLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Cards
          _buildOverviewSection(),
          
          const SizedBox(height: 24),
          
          // Box Status Breakdown
          _buildBoxStatusSection(),
          
          const SizedBox(height: 24),
          
          // Activity Summary
          _buildActivitySection(),
          
          const SizedBox(height: 24),
          
          // Storage Information
          _buildStorageSection(),
        ],
      ),
    );
  }
  
  Widget _buildOverviewSection() {
    final stats = _statistics!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Overview', Icons.dashboard),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            
            if (isNarrow) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Total Boxes',
                          stats['totalBoxes']?.toString() ?? '0',
                          Icons.inventory_2,
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Active Users',
                          stats['totalUsers']?.toString() ?? '0',
                          Icons.people,
                          AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    'Storage Used',
                    '${stats['storagePercentage']?.toStringAsFixed(1) ?? '0'}%',
                    Icons.storage,
                    AppColors.warning,
                  ),
                ],
              );
            }
            
            return Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Boxes',
                    stats['totalBoxes']?.toString() ?? '0',
                    Icons.inventory_2,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Active Users',
                    stats['totalUsers']?.toString() ?? '0',
                    Icons.people,
                    AppColors.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Storage Used',
                    '${stats['storagePercentage']?.toStringAsFixed(1) ?? '0'}%',
                    Icons.storage,
                    AppColors.warning,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildBoxStatusSection() {
    final stats = _statistics!;
    final stored = stats['boxesByStatus']?['stored'] ?? 0;
    final retrieved = stats['boxesByStatus']?['retrieved'] ?? 0;
    final destroyed = stats['boxesByStatus']?['destroyed'] ?? 0;
    final total = stored + retrieved + destroyed;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Box Status Distribution', Icons.pie_chart),
        const SizedBox(height: 16),
        Container(
          padding: AppEdgeInsets.allMedium,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppBorderRadius.medium,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.light,
          ),
          child: Column(
            children: [
              _buildStatusRow(
                'Stored',
                stored,
                total,
                AppColors.success,
                Icons.check_circle,
              ),
              const SizedBox(height: 16),
              _buildStatusRow(
                'Retrieved',
                retrieved,
                total,
                AppColors.info,
                Icons.get_app,
              ),
              const SizedBox(height: 16),
              _buildStatusRow(
                'Destroyed',
                destroyed,
                total,
                AppColors.danger,
                Icons.delete,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildActivitySection() {
    final stats = _statistics!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recent Activity (Last 30 Days)', Icons.trending_up),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            
            if (isNarrow) {
              return Column(
                children: [
                  _buildActivityCard(
                    'Collections',
                    stats['recentActivity']?['collections']?.toString() ?? '0',
                    Icons.add_box,
                    AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  _buildActivityCard(
                    'Retrievals',
                    stats['recentActivity']?['retrievals']?.toString() ?? '0',
                    Icons.get_app,
                    AppColors.info,
                  ),
                  const SizedBox(height: 12),
                  _buildActivityCard(
                    'Deliveries',
                    stats['recentActivity']?['deliveries']?.toString() ?? '0',
                    Icons.local_shipping,
                    AppColors.warning,
                  ),
                ],
              );
            }
            
            return Row(
              children: [
                Expanded(
                  child: _buildActivityCard(
                    'Collections',
                    stats['recentActivity']?['collections']?.toString() ?? '0',
                    Icons.add_box,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActivityCard(
                    'Retrievals',
                    stats['recentActivity']?['retrievals']?.toString() ?? '0',
                    Icons.get_app,
                    AppColors.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActivityCard(
                    'Deliveries',
                    stats['recentActivity']?['deliveries']?.toString() ?? '0',
                    Icons.local_shipping,
                    AppColors.warning,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildStorageSection() {
    final stats = _statistics!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Storage Details', Icons.info),
        const SizedBox(height: 16),
        Container(
          padding: AppEdgeInsets.allMedium,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppBorderRadius.medium,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.light,
          ),
          child: Column(
            children: [
              _buildInfoRow(
                'Available Locations',
                stats['availableLocations']?.toString() ?? '0',
                Icons.location_on,
              ),
              _buildInfoRow(
                'Occupied Locations',
                stats['occupiedLocations']?.toString() ?? '0',
                Icons.meeting_room,
              ),
              _buildInfoRow(
                'Pending Destruction',
                stats['boxesPendingDestruction']?.toString() ?? '0',
                Icons.warning_amber,
              ),
              _buildInfoRow(
                'Oldest Box',
                stats['oldestBox'] ?? 'N/A',
                Icons.access_time,
              ),
              _buildInfoRow(
                'Newest Box',
                stats['newestBox'] ?? 'N/A',
                Icons.fiber_new,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
  
  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppBorderRadius.medium,
        boxShadow: AppShadows.light,
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusRow(
    String label,
    int count,
    int total,
    Color color,
    IconData icon,
  ) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Text(
              '$count (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: AppBorderRadius.small,
          child: LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
  
  Widget _buildActivityCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: AppShadows.light,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMedium,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFooter() {
    return Container(
      padding: AppEdgeInsets.allMedium,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textLight,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Close'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppBorderRadius.small,
              ),
            ),
          ),
        ],
      ),
    );
  }
}