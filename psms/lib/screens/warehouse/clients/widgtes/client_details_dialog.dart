// lib/screens/warehouse/clients/widgets/client_details_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/models/client_model.dart';
import 'package:psms/controllers/client_management_controller.dart';

import 'client_statistics_dialog.dart';
import 'client_form_dialog.dart';

class ClientDetailsDialog extends StatelessWidget {
  final ClientModel client;
  
  const ClientDetailsDialog({
    super.key,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ClientManagementController>();
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.medium,
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(context),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: AppEdgeInsets.allLarge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBadge(),
                    const SizedBox(height: 24),
                    
                    _buildSection(
                      title: 'Basic Information',
                      children: [
                        _buildDetailRow('Client Code', client.clientCode),
                        _buildDetailRow('Client Name', client.clientName),
                        _buildDetailRow('Contact Person', client.contactPerson),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildSection(
                      title: 'Contact Information',
                      children: [
                        _buildDetailRow(
                          'Email',
                          client.email ?? 'Not provided',
                          icon: Icons.email,
                        ),
                        _buildDetailRow(
                          'Phone',
                          client.phone ?? 'Not provided',
                          icon: Icons.phone,
                        ),
                        _buildDetailRow(
                          'Address',
                          client.address ?? 'Not provided',
                          icon: Icons.location_on,
                        ),
                      ],
                    ),
                    
                    if (client.boxCount != null) ...[
                      const SizedBox(height: 24),
                      _buildSection(
                        title: 'Storage Statistics',
                        children: [
                          _buildStatCard(
                            'Total Boxes',
                            client.boxCount.toString(),
                            Icons.inventory_2,
                            AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Stored',
                                  client.storedBoxes?.toString() ?? '0',
                                  Icons.check_circle,
                                  AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Retrieved',
                                  client.retrievedBoxes?.toString() ?? '0',
                                  Icons.get_app,
                                  AppColors.info,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Destroyed',
                                  client.destroyedBoxes?.toString() ?? '0',
                                  Icons.delete,
                                  AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                    
                    if (client.userCount != null) ...[
                      const SizedBox(height: 24),
                      _buildSection(
                        title: 'User Information',
                        children: [
                          _buildDetailRow(
                            'Associated Users',
                            '${client.userCount} user(s)',
                            icon: Icons.people,
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    _buildSection(
                      title: 'System Information',
                      children: [
                        _buildDetailRow(
                          'Created',
                          _formatDateTime(client.createdAt),
                          icon: Icons.calendar_today,
                        ),
                        _buildDetailRow(
                          'Last Updated',
                          _formatDateTime(client.updatedAt),
                          icon: Icons.update,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer
            _buildFooter(context, controller),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
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
              Icons.business,
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
                  'Client Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  client.clientCode,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
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
  
  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: client.isActive
            ? AppColors.success.withOpacity(0.1)
            : AppColors.danger.withOpacity(0.1),
        borderRadius: AppBorderRadius.small,
        border: Border.all(
          color: client.isActive ? AppColors.success : AppColors.danger,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            client.isActive ? Icons.check_circle : Icons.cancel,
            color: client.isActive ? AppColors.success : AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            client.isActive ? 'Active Client' : 'Inactive Client',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: client.isActive ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: AppEdgeInsets.allMedium,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppBorderRadius.small,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textMedium,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: AppEdgeInsets.allMedium,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppBorderRadius.small,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
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
              fontSize: 12,
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildFooter(BuildContext context, ClientManagementController controller) {
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
          // View Statistics Button
          TextButton.icon(
            onPressed: () {
              Get.back();
              Get.dialog(
                ClientStatisticsDialog(client: client),
              );
            },
            icon: const Icon(Icons.bar_chart, size: 18),
            label: const Text('View Statistics'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
          
          // Action Buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Get.back();
                  Get.dialog(
                    ClientFormDialog(client: client),
                  );
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.small,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.small,
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }
}