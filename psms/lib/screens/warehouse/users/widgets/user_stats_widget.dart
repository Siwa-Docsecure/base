import 'package:flutter/material.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/user_management_controller.dart';

class UserStatsWidget extends StatelessWidget {
  final UserManagementController userController;

  const UserStatsWidget({
    super.key,
    required this.userController,
  });

  @override
  Widget build(BuildContext context) {
    final stats = userController.userStats;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 2 : 4;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isMobile ? 1.3 : 1.5,
          children: [
            _buildStatCard(
              'Total Users',
              stats['total_users']?.toString() ?? '0',
              Icons.people,
              AppColors.primary,
              '${stats['active_users'] ?? 0} active',
            ),
            _buildStatCard(
              'Admins',
              stats['admin_users']?.toString() ?? '0',
              Icons.admin_panel_settings,
              AppColors.danger,
              'Super users',
            ),
            _buildStatCard(
              'Staff',
              stats['staff_users']?.toString() ?? '0',
              Icons.work,
              AppColors.success,
              'Team members',
            ),
            _buildStatCard(
              'Clients',
              stats['client_users']?.toString() ?? '0',
              Icons.business,
              AppColors.warning,
              'External users',
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        boxShadow: AppShadows.light,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: AppBorderRadius.medium,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
            ],
          ),
          Column(
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
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}