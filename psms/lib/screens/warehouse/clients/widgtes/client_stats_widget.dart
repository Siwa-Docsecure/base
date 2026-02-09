// lib/screens/warehouse/clients/widgets/client_stats_widget.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/client_management_controller.dart';

class ClientStatsWidget extends StatelessWidget {
  final ClientManagementController controller;

  const ClientStatsWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stats = controller.stats;
      
      if (stats.isEmpty) {
        return const SizedBox.shrink();
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = AppBreakpoints.isMobile(constraints.maxWidth);
          
          if (isMobile) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Clients',
                        stats['totalClients']?.toString() ?? '0',
                        Icons.business,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Active',
                        stats['activeClients']?.toString() ?? '0',
                        Icons.check_circle,
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Boxes',
                        stats['totalBoxes']?.toString() ?? '0',
                        Icons.inventory_2,
                        AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total Users',
                        stats['totalUsers']?.toString() ?? '0',
                        Icons.people,
                        AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Clients',
                  stats['totalClients']?.toString() ?? '0',
                  Icons.business,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Active Clients',
                  stats['activeClients']?.toString() ?? '0',
                  Icons.check_circle,
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Boxes',
                  stats['totalBoxes']?.toString() ?? '0',
                  Icons.inventory_2,
                  AppColors.info,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Associated Users',
                  stats['totalUsers']?.toString() ?? '0',
                  Icons.people,
                  AppColors.warning,
                ),
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: AppShadows.light,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: AppBorderRadius.small,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
