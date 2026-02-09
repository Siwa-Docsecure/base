// lib/screens/warehouse/clients/client_management_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/models/client_model.dart';


import 'widgtes/client_details_dialog.dart';
import 'widgtes/client_filters_widget.dart';
import 'widgtes/client_form_dialog.dart';
import 'widgtes/client_grid_widget.dart';
import 'widgtes/client_statistics_dialog.dart';
import 'widgtes/client_stats_widget.dart';
import 'widgtes/client_table_widget.dart';

class ClientManagementPage extends StatefulWidget {
  const ClientManagementPage({super.key});

  @override
  State<ClientManagementPage> createState() => _ClientManagementPageState();
}

class _ClientManagementPageState extends State<ClientManagementPage> {
  final ClientManagementController controller = Get.put(ClientManagementController());
  final AuthController authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    // Auto-refresh on page load
    controller.refreshClients();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = AppBreakpoints.isMobile(constraints.maxWidth);

        return Container(
          color: Colors.black.withOpacity(.2),
          child: Column(
            children: [
              // Header Section
              _buildHeader(isMobile),

              // Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refreshClients,
                  child: SingleChildScrollView(
                    padding: AppEdgeInsets.pageDefault,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Cards
                        ClientStatsWidget(controller: controller),

                        const SizedBox(height: 24),

                        // Filters
                        ClientFiltersWidget(
                          controller: controller,
                          isMobile: isMobile,
                        ),

                        const SizedBox(height: 24),

                        // Bulk Actions Bar
                        Obx(
                          () => controller.isBulkSelectMode.value
                              ? _buildBulkActionsBar()
                              : const SizedBox.shrink(),
                        ),

                        if (controller.isBulkSelectMode.value)
                          const SizedBox(height: 16),

                        // Client List (Table or Grid)
                        Obx(() {
                          if (controller.viewMode.value == 'table') {
                            return ClientTableWidget(
                              controller: controller,
                              isMobile: isMobile,
                              onClientTap: _showClientDetails,
                              onEdit: _showEditClientDialog,
                              onDelete: (id) => _confirmAction('delete', id),
                              onActivate: (id) => _confirmAction('activate', id),
                              onViewStatistics: _showClientStatistics,
                            );
                          } else {
                            return ClientGridWidget(
                              controller: controller,
                              isMobile: isMobile,
                              onClientTap: _showClientDetails,
                              onEdit: _showEditClientDialog,
                              onDelete: (id) => _confirmAction('delete', id),
                              onActivate: (id) => _confirmAction('activate', id),
                              onViewStatistics: _showClientStatistics,
                            );
                          }
                        }),

                        const SizedBox(height: 24),

                        // Pagination
                        _buildPagination(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppShadows.light,
      ),
      child: isMobile ? _buildMobileHeader() : _buildDesktopHeader(),
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Client Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage client companies and their data',
                    style: TextStyle(fontSize: 13, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => controller.refreshClients(),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showCreateClientDialog,
                icon: const Icon(Icons.add_business, size: 18),
                label: const Text('Add Client'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.medium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Manage client companies and their data',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => controller.refreshClients(),
          tooltip: 'Refresh',
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _showCreateClientDialog,
          icon: const Icon(Icons.add_business, size: 20),
          label: const Text('Add Client'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.medium,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulkActionsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: AppBorderRadius.medium,
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(
              () => Text(
                '${controller.selectedClientIds.length} client(s) selected',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => controller.selectAllClients(),
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('Select All'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showBulkActionDialog('activate'),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Activate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showBulkActionDialog('deactivate'),
            icon: const Icon(Icons.block, size: 18),
            label: const Text('Deactivate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              controller.clearSelection();
              controller.toggleBulkSelectMode();
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Obx(() {
      final totalPages = controller.totalPages.value;
      final currentPage = controller.currentPage.value;
      final itemsPerPage = controller.itemsPerPage.value;

      if (totalPages <= 0) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppBorderRadius.medium,
          boxShadow: AppShadows.light,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Items per page selector
            Row(
              children: [
                const Text(
                  'Show:',
                  style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: AppBorderRadius.medium,
                  ),
                  child: DropdownButton<int>(
                    value: itemsPerPage,
                    underline: const SizedBox(),
                    onChanged: (value) {
                      if (value != null) {
                        controller.itemsPerPage.value = value;
                        controller.currentPage.value = 1;
                        controller.fetchClients();
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 20, child: Text('20')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                      DropdownMenuItem(value: 100, child: Text('100')),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'per page',
                  style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                ),
              ],
            ),

            // Page navigation
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: currentPage > 1
                      ? () => controller.changePage(currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                ...List.generate(totalPages > 5 ? 5 : totalPages, (index) {
                  int pageNum;
                  if (totalPages <= 5) {
                    pageNum = index + 1;
                  } else if (currentPage <= 3) {
                    pageNum = index + 1;
                  } else if (currentPage >= totalPages - 2) {
                    pageNum = totalPages - 4 + index;
                  } else {
                    pageNum = currentPage - 2 + index;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildPageButton(pageNum, currentPage == pageNum),
                  );
                }),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: currentPage < totalPages
                      ? () => controller.changePage(currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  color: AppColors.primary,
                ),
              ],
            ),

            // Total count
            Text(
              'Total: ${controller.totalItems.value} clients',
              style: const TextStyle(fontSize: 14, color: AppColors.textMedium),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPageButton(int pageNum, bool isActive) {
    return InkWell(
      onTap: () => controller.changePage(pageNum),
      borderRadius: AppBorderRadius.medium,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: AppBorderRadius.medium,
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            pageNum.toString(),
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateClientDialog() {
    showDialog(
      context: context,
      builder: (context) => const ClientFormDialog(),
    );
  }

  void _showEditClientDialog(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => ClientFormDialog(client: client),
    );
  }

  void _showClientDetails(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => ClientDetailsDialog(client: client),
    );
  }

  void _showClientStatistics(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => ClientStatisticsDialog(client: client),
    );
  }

  void _showBulkActionDialog(String action) {
    final count = controller.selectedClientIds.length;
    final actionText = action == 'activate' ? 'activate' : 'deactivate';

    Get.defaultDialog(
      title: '${actionText.capitalize} Clients',
      titleStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      content: Column(
        children: [
          Icon(
            action == 'activate' ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 48,
            color: action == 'activate' ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(height: 16),
          Text(
            'Are you sure you want to $actionText $count client(s)?',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: action == 'activate' ? AppColors.success : AppColors.warning,
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          Get.back();
          if (action == 'activate') {
            controller.bulkActivateClients();
          } else {
            controller.bulkDeactivateClients();
          }
        },
        child: Text(actionText.capitalize ?? actionText),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('Cancel'),
      ),
    );
  }

  void _confirmAction(String action, int clientId) {
    final client = controller.clients.firstWhere((c) => c.clientId == clientId);
    final actionText = action == 'activate' ? 'activate' : 'delete';

    Get.defaultDialog(
      title: '${actionText.capitalize} Client',
      titleStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      content: Column(
        children: [
          Icon(
            action == 'activate' ? Icons.restore : Icons.warning_amber_rounded,
            size: 48,
            color: action == 'activate' ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(height: 16),
          Text(
            'Are you sure you want to $actionText "${client.clientName}"?',
            textAlign: TextAlign.center,
          ),
          if (action == 'delete') ...[
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.danger,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: action == 'activate' ? AppColors.success : AppColors.danger,
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          Get.back();
          if (action == 'activate') {
            controller.activateClient(clientId);
          } else {
            controller.deleteClient(clientId);
          }
        },
        child: Text(actionText.capitalize ?? actionText),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('Cancel'),
      ),
    );
  }
}