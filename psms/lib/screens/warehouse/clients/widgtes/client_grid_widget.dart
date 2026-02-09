// lib/screens/warehouse/clients/widgets/client_grid_widget.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/models/client_model.dart';

class ClientGridWidget extends StatelessWidget {
  final ClientManagementController controller;
  final bool isMobile;
  final Function(ClientModel) onClientTap;
  final Function(ClientModel) onEdit;
  final Function(int) onDelete;
  final Function(int) onActivate;
  final Function(ClientModel) onViewStatistics;

  const ClientGridWidget({
    super.key,
    required this.controller,
    required this.isMobile,
    required this.onClientTap,
    required this.onEdit,
    required this.onDelete,
    required this.onActivate,
    required this.onViewStatistics,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.clients.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(48.0),
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (controller.clients.isEmpty) {
        return _buildEmptyState();
      }

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(context),
          childAspectRatio: 0.85,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: controller.clients.length,
        itemBuilder: (context, index) {
          final client = controller.clients[index];
          return _buildClientCard(client);
        },
      );
    });
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    return 4;
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        boxShadow: AppShadows.light,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_outlined,
                size: 64,
                color: AppColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Clients Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.searchQuery.value.isNotEmpty
                  ? 'No clients match your search criteria'
                  : 'Get started by creating your first client',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientCard(ClientModel client) {
    final authController = Get.find<AuthController>();
    final isSelected = controller.selectedClientIds.contains(client.clientId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: AppShadows.light,
      ),
      child: InkWell(
        onTap: () {
          if (controller.isBulkSelectMode.value) {
            controller.toggleClientSelection(client.clientId);
          } else {
            onClientTap(client);
          }
        },
        borderRadius: AppBorderRadius.medium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.radiusMedium),
                  topRight: Radius.circular(AppSizes.radiusMedium),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (controller.isBulkSelectMode.value)
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => controller.toggleClientSelection(client.clientId),
                          fillColor: MaterialStateProperty.all(Colors.white),
                          checkColor: AppColors.primary,
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              client.clientCode,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              client.clientName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      _buildStatusIcon(client.isActive),
                    ],
                  ),
                ],
              ),
            ),

            // Content Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      Icons.person,
                      client.contactPerson,
                      'Contact',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.email,
                      client.email ?? 'N/A',
                      'Email',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.phone,
                      client.phone ?? 'N/A',
                      'Phone',
                    ),
                    const Spacer(),
                    
                    // Stats Section
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatBox(
                            Icons.inventory_2,
                            '${client.boxCount ?? 0}',
                            'Boxes',
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatBox(
                            Icons.people,
                            '${client.userCount ?? 0}',
                            'Users',
                            AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer with Actions
            if (!controller.isBulkSelectMode.value)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      Icons.bar_chart,
                      'Stats',
                      AppColors.purple,
                      () => onViewStatistics(client),
                    ),
                    if (authController.hasPermission('canManageUsers'))
                      _buildActionButton(
                        Icons.edit,
                        'Edit',
                        AppColors.warning,
                        () => onEdit(client),
                      ),
                    if (authController.hasPermission('canManageUsers'))
                      _buildActionButton(
                        client.isActive ? Icons.delete : Icons.restore,
                        client.isActive ? 'Delete' : 'Restore',
                        client.isActive ? AppColors.danger : AppColors.success,
                        () => client.isActive
                            ? onDelete(client.clientId)
                            : onActivate(client.clientId),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isActive) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isActive ? Icons.check_circle : Icons.cancel,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMedium),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                ),
              ),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppBorderRadius.small,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
