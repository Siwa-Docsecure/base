// lib/screens/warehouse/clients/widgets/client_table_widget.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/models/client_model.dart';

class ClientTableWidget extends StatelessWidget {
  final ClientManagementController controller;
  final bool isMobile;
  final Function(ClientModel) onClientTap;
  final Function(ClientModel) onEdit;
  final Function(int) onDelete;
  final Function(int) onActivate;
  final Function(ClientModel) onViewStatistics;

  const ClientTableWidget({
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
    final authController = Get.find<AuthController>();

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

      if (isMobile) {
        return _buildMobileList(authController);
      }

      return _buildDesktopTable(authController);
    });
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

  Widget _buildMobileList(AuthController authController) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: controller.clients.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final client = controller.clients[index];
        final isSelected = controller.selectedClientIds.contains(client.clientId);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (controller.isBulkSelectMode.value)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) => controller.toggleClientSelection(client.clientId),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              client.clientName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              client.clientCode,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(client.isActive),
                    ],
                  ),
                  
                  const Divider(height: 24),
                  
                  _buildInfoRow(Icons.person, client.contactPerson),
                  if (client.email != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.email, client.email!),
                  ],
                  if (client.phone != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.phone, client.phone!),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatChip(
                          Icons.inventory_2,
                          '${client.boxCount ?? 0} Boxes',
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatChip(
                          Icons.people,
                          '${client.userCount ?? 0} Users',
                          AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  
                  if (!controller.isBulkSelectMode.value) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bar_chart, size: 20),
                          color: AppColors.purple,
                          tooltip: 'Statistics',
                          onPressed: () => onViewStatistics(client),
                        ),
                        if (authController.hasPermission('canManageUsers'))
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            color: AppColors.warning,
                            tooltip: 'Edit',
                            onPressed: () => onEdit(client),
                          ),
                        if (authController.hasPermission('canManageUsers'))
                          IconButton(
                            icon: Icon(
                              client.isActive ? Icons.delete : Icons.restore,
                              size: 20,
                            ),
                            color: client.isActive ? AppColors.danger : AppColors.success,
                            tooltip: client.isActive ? 'Delete' : 'Activate',
                            onPressed: () => client.isActive
                                ? onDelete(client.clientId)
                                : onActivate(client.clientId),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(AuthController authController) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        boxShadow: AppShadows.light,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: controller.isBulkSelectMode.value,
          headingRowColor: MaterialStateProperty.all(AppColors.background),
          columns: [
            if (controller.isBulkSelectMode.value)
              DataColumn(
                label: Obx(() => Checkbox(
                  value: controller.selectedClientIds.length == controller.clients.length &&
                      controller.clients.isNotEmpty,
                  onChanged: (_) {
                    if (controller.selectedClientIds.length == controller.clients.length) {
                      controller.clearSelection();
                    } else {
                      controller.selectAllClients();
                    }
                  },
                  tristate: true,
                )),
              ),
            const DataColumn(label: Text('Client Name')),
            const DataColumn(label: Text('Code')),
            const DataColumn(label: Text('Contact')),
            const DataColumn(label: Text('Email')),
            const DataColumn(label: Text('Phone')),
            const DataColumn(label: Text('Boxes')),
            const DataColumn(label: Text('Users')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Created')),
            if (!controller.isBulkSelectMode.value)
              const DataColumn(label: Text('Actions')),
          ],
          rows: controller.clients.map((client) {
            final isSelected = controller.selectedClientIds.contains(client.clientId);
            
            return DataRow(
              selected: isSelected,
              onSelectChanged: controller.isBulkSelectMode.value
                  ? (_) => controller.toggleClientSelection(client.clientId)
                  : (_) => onClientTap(client),
              cells: [
                if (controller.isBulkSelectMode.value)
                  DataCell(
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => controller.toggleClientSelection(client.clientId),
                    ),
                  ),
                DataCell(
                  Text(
                    client.clientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                DataCell(Text(client.clientCode)),
                DataCell(Text(client.contactPerson)),
                DataCell(Text(client.email ?? '-')),
                DataCell(Text(client.phone ?? '-')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('${client.boxCount ?? 0}'),
                    ],
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('${client.userCount ?? 0}'),
                    ],
                  ),
                ),
                DataCell(_buildStatusBadge(client.isActive)),
                DataCell(
                  Text(
                    DateFormat('MMM dd, yyyy').format(client.createdAt),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (!controller.isBulkSelectMode.value)
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, size: 20),
                          color: AppColors.info,
                          tooltip: 'View Details',
                          onPressed: () => onClientTap(client),
                        ),
                        IconButton(
                          icon: const Icon(Icons.bar_chart, size: 20),
                          color: AppColors.purple,
                          tooltip: 'Statistics',
                          onPressed: () => onViewStatistics(client),
                        ),
                        if (authController.hasPermission('canManageUsers'))
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            color: AppColors.warning,
                            tooltip: 'Edit',
                            onPressed: () => onEdit(client),
                          ),
                        if (authController.hasPermission('canManageUsers'))
                          IconButton(
                            icon: Icon(
                              client.isActive ? Icons.delete : Icons.restore,
                              size: 20,
                            ),
                            color: client.isActive ? AppColors.danger : AppColors.success,
                            tooltip: client.isActive ? 'Delete' : 'Activate',
                            onPressed: () => client.isActive
                                ? onDelete(client.clientId)
                                : onActivate(client.clientId),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withOpacity(0.1)
            : AppColors.danger.withOpacity(0.1),
        borderRadius: AppBorderRadius.small,
        border: Border.all(
          color: isActive ? AppColors.success : AppColors.danger,
        ),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.success : AppColors.danger,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMedium),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppBorderRadius.small,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
