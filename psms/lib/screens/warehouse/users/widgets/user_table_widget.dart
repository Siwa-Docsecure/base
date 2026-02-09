import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/user_management_controller.dart';
import 'package:psms/models/user_model.dart';

class UserTableWidget extends StatelessWidget {
  final UserManagementController userController;
  final bool isMobile;
  final Function(UserModel) onUserTap;
  final Function(UserModel) onEdit;
  final Function(int) onDelete;
  final Function(int) onActivate;
  final Function(int) onDeactivate;
  final Function(UserModel) onResetPassword;
  final Function(UserModel) onManagePermissions;

  const UserTableWidget({
    super.key,
    required this.userController,
    required this.isMobile,
    required this.onUserTap,
    required this.onEdit,
    required this.onDelete,
    required this.onActivate,
    required this.onDeactivate,
    required this.onResetPassword,
    required this.onManagePermissions,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (userController.isLoading.value) {
        return _buildLoading();
      }

      if (userController.users.isEmpty) {
        return _buildEmpty();
      }

      return isMobile ? _buildMobileList() : _buildDesktopTable();
    });
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        boxShadow: AppShadows.light,
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading users...',
              style: TextStyle(color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        boxShadow: AppShadows.light,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.textLight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 48,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your filters or create a new user',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: userController.users.length,
      itemBuilder: (context, index) {
        final user = userController.users[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    final isSelected = userController.selectedUserIds.contains(user.userId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: AppShadows.light,
      ),
      child: InkWell(
        onTap: () => onUserTap(user),
        onLongPress: () => userController.toggleUserSelection(user.userId),
        borderRadius: AppBorderRadius.medium,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (userController.isBulkSelectMode.value)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => userController.toggleUserSelection(user.userId),
                        activeColor: AppColors.primary,
                      ),
                    ),
                  CircleAvatar(
                    backgroundColor: _getRoleColor(user.role),
                    radius: 24,
                    child: Icon(
                      _getRoleIcon(user.role),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(user.isActive),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildRoleBadge(user.role),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleAction(value, user),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'permissions',
                        child: Row(
                          children: [
                            Icon(Icons.lock, size: 18),
                            SizedBox(width: 8),
                            Text('Permissions'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'password',
                        child: Row(
                          children: [
                            Icon(Icons.vpn_key, size: 18),
                            SizedBox(width: 8),
                            Text('Reset Password'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: user.isActive ? 'deactivate' : 'activate',
                        child: Row(
                          children: [
                            Icon(
                              user.isActive ? Icons.block : Icons.check_circle,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(user.isActive ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: AppBorderRadius.medium,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        size: 18,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        boxShadow: AppShadows.light,
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: userController.users.length,
            itemBuilder: (context, index) {
              final user = userController.users[index];
              return _buildTableRow(user);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          if (userController.isBulkSelectMode.value)
            const SizedBox(width: 48),
          _buildHeaderCell('User', flex: 3),
          _buildHeaderCell('Role', flex: 1),
          _buildHeaderCell('Status', flex: 1),
          _buildHeaderCell('Created', flex: 2),
          _buildHeaderCell('Actions', flex: 2),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
        ),
      ),
    );
  }

  Widget _buildTableRow(UserModel user) {
    final isSelected = userController.selectedUserIds.contains(user.userId);
    
    return InkWell(
      onTap: () => onUserTap(user),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            if (userController.isBulkSelectMode.value)
              Checkbox(
                value: isSelected,
                onChanged: (_) => userController.toggleUserSelection(user.userId),
                activeColor: AppColors.primary,
              ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRoleColor(user.role),
                    radius: 18,
                    child: Icon(
                      _getRoleIcon(user.role),
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: _buildRoleBadge(user.role),
            ),
            Expanded(
              flex: 1,
              child: _buildStatusBadge(user.isActive),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatDate(user.createdAt),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMedium,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => onEdit(user),
                    tooltip: 'Edit',
                    color: AppColors.primary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_outline, size: 18),
                    onPressed: () => onManagePermissions(user),
                    tooltip: 'Permissions',
                    color: AppColors.warning,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleAction(value, user),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'password',
                        child: Row(
                          children: [
                            Icon(Icons.vpn_key, size: 18),
                            SizedBox(width: 8),
                            Text('Reset Password'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: user.isActive ? 'deactivate' : 'activate',
                        child: Row(
                          children: [
                            Icon(
                              user.isActive ? Icons.block : Icons.check_circle,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(user.isActive ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.more_vert,
                        size: 18,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getRoleColor(role).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getRoleIcon(role),
            size: 12,
            color: _getRoleColor(role),
          ),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _getRoleColor(role),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.success : AppColors.textLight).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.success : AppColors.textLight,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppColors.danger;
      case 'staff':
        return AppColors.success;
      case 'client':
        return AppColors.warning;
      default:
        return AppColors.textLight;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'staff':
        return Icons.work;
      case 'client':
        return Icons.business;
      default:
        return Icons.person;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleAction(String action, UserModel user) {
    switch (action) {
      case 'edit':
        onEdit(user);
        break;
      case 'permissions':
        onManagePermissions(user);
        break;
      case 'password':
        onResetPassword(user);
        break;
      case 'activate':
        onActivate(user.userId);
        break;
      case 'deactivate':
        onDeactivate(user.userId);
        break;
      case 'delete':
        onDelete(user.userId);
        break;
    }
  }
}