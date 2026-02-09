import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/user_management_controller.dart';
import 'package:psms/models/user_model.dart';

import 'widgets/user_dialogs.dart';
import 'widgets/user_filters_widget.dart';
import 'widgets/user_stats_widget.dart';
import 'widgets/user_table_widget.dart';

class UserManagementPage extends StatefulWidget {
  final AuthController? authController;

  const UserManagementPage({super.key, this.authController});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserManagementController userController = Get.put(
    UserManagementController(),
  );

  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    // Auto-refresh on page load
    userController.getAllUsers();
    userController.getUserStats();
  }

  @override
  Widget build(BuildContext context) {
    // Check permission
    if (!_authController.hasPermission('canManageUsers') &&
        _authController.currentUser.value?.role != 'admin') {
      return _buildNoPermission();
    }

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
                child: SingleChildScrollView(
                  padding: AppEdgeInsets.pageDefault,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Cards
                      UserStatsWidget(userController: userController),

                      const SizedBox(height: 24),

                      // Filters
                      UserFiltersWidget(
                        userController: userController,
                        isMobile: isMobile,
                      ),

                      const SizedBox(height: 24),

                      // Bulk Actions Bar
                      Obx(
                        () =>
                            userController.isBulkSelectMode.value
                                ? _buildBulkActionsBar()
                                : const SizedBox.shrink(),
                      ),

                      if (userController.isBulkSelectMode.value)
                        const SizedBox(height: 16),

                      // User Table
                      UserTableWidget(
                        userController: userController,
                        isMobile: isMobile,
                        onUserTap: _showUserDetails,
                        onEdit: _showEditUserDialog,
                        onDelete: (userId) => _confirmAction('delete', userId),
                        onActivate:
                            (userId) => _confirmAction('activate', userId),
                        onDeactivate:
                            (userId) => _confirmAction('deactivate', userId),
                        onResetPassword: _showResetPasswordDialog,
                        onManagePermissions: _showPermissionsDialog,
                      ),

                      const SizedBox(height: 24),

                      // Pagination
                      _buildPagination(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoPermission() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 64,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Access Denied',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You do not have permission to access this page',
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
        ],
      ),
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
                    'User Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage system users and permissions',
                    style: TextStyle(fontSize: 13, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => userController.getAllUsers(),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    () => UserDialogs.showCreateUserDialog(userController),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add User'),
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
            const SizedBox(width: 8),
            _buildHeaderIconButton(
              Icons.analytics_outlined,
              () => UserDialogs.showUserStats(userController),
            ),
            const SizedBox(width: 8),
            _buildHeaderIconButton(
              Icons.group_add_outlined,
              () => UserDialogs.showBulkCreateDialog(userController),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage system users and permissions',
                style: TextStyle(fontSize: 14, color: AppColors.textLight),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.textLight),
          onPressed: () => userController.getAllUsers(),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => UserDialogs.showUserStats(userController),
          icon: const Icon(Icons.analytics_outlined, size: 18),
          label: const Text('Statistics'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDark,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.medium),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => UserDialogs.showBulkCreateDialog(userController),
          icon: const Icon(Icons.group_add_outlined, size: 18),
          label: const Text('Bulk Create'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDark,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.medium),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => UserDialogs.showCreateUserDialog(userController),
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Add User'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.medium),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderIconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppBorderRadius.medium,
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        color: AppColors.textDark,
      ),
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
                '${userController.selectedUserIds.length} user(s) selected',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => userController.selectAllUsers(),
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
            onPressed: () => userController.selectedUserIds.clear(),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Obx(() {
      final totalPages = userController.totalPages.value;
      final currentPage = userController.currentPage.value;
      final itemsPerPage = userController.itemsPerPage.value;

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
                        userController.itemsPerPage.value = value;
                        userController.currentPage.value = 1;
                        userController.getAllUsers();
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
                Text(
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
                  onPressed:
                      currentPage > 1
                          ? () {
                            userController.currentPage.value = currentPage - 1;
                            userController.getAllUsers();
                          }
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
                  onPressed:
                      currentPage < totalPages
                          ? () {
                            userController.currentPage.value = currentPage + 1;
                            userController.getAllUsers();
                          }
                          : null,
                  icon: const Icon(Icons.chevron_right),
                  color: AppColors.primary,
                ),
              ],
            ),

            // Total count
            Text(
              'Total: ${userController.totalUsers.value} users',
              style: const TextStyle(fontSize: 14, color: AppColors.textMedium),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPageButton(int pageNum, bool isActive) {
    return InkWell(
      onTap: () {
        userController.currentPage.value = pageNum;
        userController.getAllUsers();
      },
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

  void _showBulkActionDialog(String action) {
    UserDialogs.showBulkActionDialog(userController, action);
  }

  void _confirmAction(String action, int userId) {
    UserDialogs.showConfirmActionDialog(userController, action, userId);
  }

  void _showUserDetails(UserModel user) {
    UserDialogs.showUserDetails(
      userController,
      user,
      _showEditUserDialog,
      _showPermissionsDialog,
      _showResetPasswordDialog,
    );
  }

  void _showEditUserDialog(UserModel user) {
    UserDialogs.showEditUserDialog(userController, user);
  }

  void _showPermissionsDialog(UserModel user) {
    UserDialogs.showPermissionsDialog(userController, user);
  }

  void _showResetPasswordDialog(UserModel user) {
    UserDialogs.showResetPasswordDialog(userController, user);
  }
}
