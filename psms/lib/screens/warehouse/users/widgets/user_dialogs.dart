import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/user_management_controller.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/models/user_model.dart';
import 'package:psms/models/client_model.dart';

class UserDialogs {
  // Show User Statistics
  static void showUserStats(UserManagementController controller) async {
    await controller.getUserStats();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: AppBorderRadius.medium,
                    ),
                    child: const Icon(
                      Icons.analytics,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'User Statistics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Obx(
                () =>
                    controller.userStats.isNotEmpty
                        ? Column(
                          children: [
                            _buildStatRow(
                              'Total Users',
                              controller.userStats['total_users']?.toString() ??
                                  '0',
                              Icons.people,
                            ),
                            _buildStatRow(
                              'Active Users',
                              controller.userStats['active_users']
                                      ?.toString() ??
                                  '0',
                              Icons.check_circle,
                              AppColors.success,
                            ),
                            _buildStatRow(
                              'Inactive Users',
                              controller.userStats['inactive_users']
                                      ?.toString() ??
                                  '0',
                              Icons.block,
                              AppColors.textLight,
                            ),
                            _buildStatRow(
                              'Admins',
                              controller.userStats['admin_users']?.toString() ??
                                  '0',
                              Icons.admin_panel_settings,
                              AppColors.danger,
                            ),
                            _buildStatRow(
                              'Staff',
                              controller.userStats['staff_users']?.toString() ??
                                  '0',
                              Icons.work,
                              AppColors.success,
                            ),
                            _buildStatRow(
                              'Clients',
                              controller.userStats['client_users']
                                      ?.toString() ??
                                  '0',
                              Icons.business,
                              AppColors.warning,
                            ),
                          ],
                        )
                        : const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppBorderRadius.medium,
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStatRow(
    String label,
    String value,
    IconData icon, [
    Color? color,
  ]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppBorderRadius.medium,
      ),
      child: Row(
        children: [
          Icon(icon, color: color ?? AppColors.textMedium, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.textMedium),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  // Show Create User Dialog
  static void showCreateUserDialog(UserManagementController controller) {
    controller.resetForm();

    // Get client controller to fetch clients
    final ClientManagementController clientController =
        Get.put(ClientManagementController());
    // Fetch active clients for dropdown
    clientController.fetchClients(showLoading: false);

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create New User',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 24),
                _buildUserForm(
                  controller,
                  isCreate: true,
                  clientController: clientController,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    Obx(
                      () => ElevatedButton.icon(
                        onPressed:
                            controller.isProcessing.value
                                ? null
                                : () async {
                                  // Validate client selection for client role
                                  if (controller.newUserRole.value ==
                                          'client' &&
                                      controller
                                          .newUserClientId
                                          .value
                                          .isEmpty) {
                                    Get.snackbar(
                                      'Error',
                                      'Please select a client for client users',
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                    );
                                    return;
                                  }

                                  // Validate passwords match for create
                                  if (controller.passwordController.text !=
                                      controller
                                          .confirmPasswordController
                                          .text) {
                                    Get.snackbar(
                                      'Error',
                                      'Passwords do not match',
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                    );
                                    return;
                                  }

                                  final result = await controller.createUser();
                                  if (result['success'] == true) {
                                    Get.back();
                                  }
                                },
                        icon:
                            controller.isProcessing.value
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.person_add, size: 18),
                        label: Text(
                          controller.isProcessing.value
                              ? 'Creating...'
                              : 'Create User',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppBorderRadius.medium,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show Edit User Dialog
  static void showEditUserDialog(
    UserManagementController controller,
    UserModel user,
  ) {
    controller.selectUser(user);

    // Get client controller to fetch clients
    final ClientManagementController clientController =
        Get.put(ClientManagementController());
    // Fetch active clients for dropdown
    clientController.fetchClients(showLoading: false);

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit User',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 24),
                _buildUserForm(
                  controller,
                  isCreate: false,
                  clientController: clientController,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        controller.resetForm();
                        Get.back();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    Obx(
                      () => ElevatedButton.icon(
                        onPressed:
                            controller.isProcessing.value
                                ? null
                                : () async {
                                  final result = await controller.updateUser(
                                    user.userId,
                                  );
                                  if (result['success'] == true) {
                                    Get.back();
                                  }
                                },
                        icon:
                            controller.isProcessing.value
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.save, size: 18),
                        label: Text(
                          controller.isProcessing.value
                              ? 'Saving...'
                              : 'Save Changes',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppBorderRadius.medium,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildUserForm(
  UserManagementController controller, 
  {required bool isCreate,
   required ClientManagementController clientController}) {
  
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Information Section
          const Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username *',
                    hintText: 'Enter username',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: AppBorderRadius.medium),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: controller.emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email *',
                    hintText: 'Enter email address',
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: AppBorderRadius.medium),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Role Selection - Single Obx wrapper
          GetBuilder<UserManagementController>(
            id: 'user_role',
            builder: (_) => DropdownButtonFormField<String>(
              value: controller.newUserRole.value,
              onChanged: (value) {
                controller.newUserRole.value = value ?? 'staff';
                if (value != 'client') {
                  controller.newUserClientId.value = '';
                }
                controller.update(['user_role', 'client_assignment']);
              },
              decoration: InputDecoration(
                labelText: 'Role *',
                prefixIcon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: AppBorderRadius.medium),
              ),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'staff', child: Text('Staff')),
                DropdownMenuItem(value: 'client', child: Text('Client')),
              ],
            ),
          ),
          
          // Client Selection Section
          const SizedBox(height: 16),
          const Text(
            'Client Assignment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          
          // Client dropdown with GetBuilder instead of Obx
          GetBuilder<UserManagementController>(
            id: 'client_assignment',
            builder: (_) {
              final isClientRole = controller.newUserRole.value == 'client';
              
              return GetBuilder<ClientManagementController>(
                builder: (clientCtrl) {
                  final isClientLoading = clientCtrl.isLoading.value;
                  
                  if (isClientLoading) {
                    return Container(
                      height: 60,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: AppBorderRadius.medium,
                      ),
                      child: const Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  
                  final activeClients = clientCtrl.clients
                      .where((client) => client.isActive)
                      .toList();
                  
                  if (activeClients.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: AppBorderRadius.medium,
                        color: Colors.grey.shade50,
                      ),
                      child: Text(
                        'No active clients available.${isClientRole ? ' Please create clients first.' : ''}',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int?>(
                        value: controller.newUserClientId.value.isNotEmpty 
                            ? int.tryParse(controller.newUserClientId.value)
                            : null,
                        onChanged: isClientRole 
                            ? (value) {
                                controller.newUserClientId.value = value?.toString() ?? '';
                              }
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Assign to Client',
                          prefixIcon: const Icon(Icons.business_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: AppBorderRadius.medium),
                          hintText: isClientRole ? 'Select a client' : 'Available only for client role',
                          filled: true,
                          fillColor: isClientRole ? AppColors.background : Colors.grey.shade100,
                        ),
                        isExpanded: true,
                        menuMaxHeight: 300,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              '-- Select a Client --',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          ...activeClients.map((client) {
                            return DropdownMenuItem<int?>(
                              value: client.clientId,
                              child: Row(
                                children: [
                                  const Icon(Icons.business, 
                                      color: AppColors.primary, 
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          client.clientName ?? 'Unnamed Client',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (client.clientCode != null)
                                          Text(
                                            client.clientCode!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                      if (!isClientRole) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Client assignment is only applicable for client role users',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
          
          // Password fields (only for create)
          if (isCreate) ...[
            const SizedBox(height: 24),
            const Text(
              'Security',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      hintText: 'Minimum 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: AppBorderRadius.medium),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: controller.confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password *',
                      hintText: 'Re-enter password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: AppBorderRadius.medium),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                'Password must be at least 6 characters long',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
          
          // Permissions section - Use GetBuilder for all permissions
          const SizedBox(height: 24),
          GetBuilder<UserManagementController>(
            id: 'permissions',
            builder: (_) => ExpansionTile(
              title: const Text(
                'Permissions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              initiallyExpanded: false,
              childrenPadding: const EdgeInsets.all(8.0),
              children: [
                _buildPermissionSwitch(
                  'Create Boxes',
                  'Allows creating new storage boxes',
                  controller.permissions['canCreateBoxes'] ?? false,
                  (value) {
                    controller.setPermission('canCreateBoxes', value);
                    controller.update(['permissions']);
                  },
                ),
                _buildPermissionSwitch(
                  'Edit Boxes',
                  'Allows modifying existing boxes',
                  controller.permissions['canEditBoxes'] ?? false,
                  (value) {
                    controller.setPermission('canEditBoxes', value);
                    controller.update(['permissions']);
                  },
                ),
                _buildPermissionSwitch(
                  'Delete Boxes',
                  'Allows deleting boxes (requires confirmation)',
                  controller.permissions['canDeleteBoxes'] ?? false,
                  (value) {
                    controller.setPermission('canDeleteBoxes', value);
                    controller.update(['permissions']);
                  },
                ),
                _buildPermissionSwitch(
                  'Create Collections',
                  'Allows creating box collection requests',
                  controller.permissions['canCreateCollections'] ?? false,
                  (value) {
                    controller.setPermission('canCreateCollections', value);
                    controller.update(['permissions']);
                  },
                ),
                _buildPermissionSwitch(
                  'Create Retrievals',
                  'Allows creating box retrieval requests',
                  controller.permissions['canCreateRetrievals'] ?? false,
                  (value) {
                    controller.setPermission('canCreateRetrievals', value);
                    controller.update(['permissions']);
                  },
                ),
                _buildPermissionSwitch(
                  'Create Deliveries',
                  'Allows creating box delivery requests',
                  controller.permissions['canCreateDeliveries'] ?? false,
                  (value) {
                    controller.setPermission('canCreateDeliveries', value);
                    controller.update(['permissions']);
                  },
                ),
                _buildPermissionSwitch(
                  'View Reports',
                  'Allows accessing system reports and analytics',
                  controller.permissions['canViewReports'] ?? false,
                  (value) {
                    controller.setPermission('canViewReports', value);
                    controller.update(['permissions']);
                  },
                ),
                _buildPermissionSwitch(
                  'Manage Users',
                  'Allows managing other user accounts (admin only)',
                  controller.permissions['canManageUsers'] ?? false,
                  (value) {
                    controller.setPermission('canManageUsers', value);
                    controller.update(['permissions']);
                  },
                ),
              ],
            ),
          ),
          
          // Set default permissions button
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                controller.setDefaultPermissionsForRole(controller.newUserRole.value);
                controller.update(['permissions']);
              },
              icon: const Icon(Icons.settings_backup_restore, size: 16),
              label: const Text('Set Default Permissions for Role'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  // Helper widget for permission switches with description
  static Widget _buildPermissionSwitch(
    String title,
    String description,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppBorderRadius.medium,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show Permissions Dialog
  static void showPermissionsDialog(
    UserManagementController controller,
    UserModel user,
  ) {
    // Load user's current permissions into the controller
    controller.selectUser(user);

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: AppBorderRadius.medium,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manage Permissions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Obx(
                () => Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('Create Boxes'),
                      subtitle: const Text('Allows creating new storage boxes'),
                      value: controller.permissions['canCreateBoxes'],
                      onChanged:
                          (value) => controller.setPermission(
                            'canCreateBoxes',
                            value ?? false,
                          ),
                      activeColor: AppColors.success,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    CheckboxListTile(
                      title: const Text('Edit Boxes'),
                      subtitle: const Text('Allows modifying existing boxes'),
                      value: controller.permissions['canEditBoxes'],
                      onChanged:
                          (value) => controller.setPermission(
                            'canEditBoxes',
                            value ?? false,
                          ),
                      activeColor: AppColors.success,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    CheckboxListTile(
                      title: const Text('Delete Boxes'),
                      subtitle: const Text(
                        'Allows deleting boxes (requires confirmation)',
                      ),
                      value: controller.permissions['canDeleteBoxes'],
                      onChanged:
                          (value) => controller.setPermission(
                            'canDeleteBoxes',
                            value ?? false,
                          ),
                      activeColor: AppColors.success,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    CheckboxListTile(
                      title: const Text('Create Collections'),
                      subtitle: const Text(
                        'Allows creating box collection requests',
                      ),
                      value: controller.permissions['canCreateCollections'],
                      onChanged:
                          (value) => controller.setPermission(
                            'canCreateCollections',
                            value ?? false,
                          ),
                      activeColor: AppColors.success,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    CheckboxListTile(
                      title: const Text('Create Retrievals'),
                      subtitle: const Text(
                        'Allows creating box retrieval requests',
                      ),
                      value: controller.permissions['canCreateRetrievals'],
                      onChanged:
                          (value) => controller.setPermission(
                            'canCreateRetrievals',
                            value ?? false,
                          ),
                      activeColor: AppColors.success,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    CheckboxListTile(
                      title: const Text('Create Deliveries'),
                      subtitle: const Text(
                        'Allows creating box delivery requests',
                      ),
                      value: controller.permissions['canCreateDeliveries'],
                      onChanged:
                          (value) => controller.setPermission(
                            'canCreateDeliveries',
                            value ?? false,
                          ),
                      activeColor: AppColors.success,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    CheckboxListTile(
                      title: const Text('View Reports'),
                      subtitle: const Text(
                        'Allows accessing system reports and analytics',
                      ),
                      value: controller.permissions['canViewReports'],
                      onChanged:
                          (value) => controller.setPermission(
                            'canViewReports',
                            value ?? false,
                          ),
                      activeColor: AppColors.success,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    CheckboxListTile(
                      title: const Text('Manage Users'),
                      subtitle: const Text(
                        'Allows managing other user accounts (admin only)',
                      ),
                      value: controller.permissions['canManageUsers'],
                      onChanged:
                          (value) => controller.setPermission(
                            'canManageUsers',
                            value ?? false,
                          ),
                      activeColor: AppColors.success,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await controller.updateUserPermissions(user.userId);
                      Get.back();
                    },
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save Permissions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.medium,
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

  // Show Reset Password Dialog
  static void showResetPasswordDialog(
    UserManagementController controller,
    UserModel user,
  ) {
    // Clear password fields
    controller.newPasswordController.clear();
    controller.confirmPasswordController.clear();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: AppBorderRadius.medium,
                    ),
                    child: const Icon(
                      Icons.vpn_key,
                      color: AppColors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller.newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  hintText: 'Minimum 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: AppBorderRadius.medium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller.confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: AppBorderRadius.medium,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text(
                  'Password must be at least 6 characters long',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (controller.newPasswordController.text !=
                          controller.confirmPasswordController.text) {
                        Get.snackbar('Error', 'Passwords do not match');
                        return;
                      }

                      if (controller.newPasswordController.text.length < 6) {
                        Get.snackbar(
                          'Error',
                          'Password must be at least 6 characters',
                        );
                        return;
                      }

                      await controller.resetPassword(user.userId);
                      Get.back();
                    },
                    icon: const Icon(Icons.vpn_key, size: 18),
                    label: const Text('Reset Password'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.medium,
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

  // Show Bulk Create Dialog
  static void showBulkCreateDialog(UserManagementController controller) {
    final jsonController = TextEditingController();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bulk Create Users',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter JSON array of users to create',
                style: TextStyle(fontSize: 14, color: AppColors.textLight),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: AppBorderRadius.medium,
                  ),
                  child: TextField(
                    controller: jsonController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '''[
  {
    "username": "user1",
    "email": "user1@example.com",
    "password": "password123",
    "role": "client",
    "clientId": 1
  }
]''',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: For client users, include "clientId" field. Password must be at least 6 characters.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final decoded = jsonDecode(jsonController.text);
                        if (decoded is List) {
                          final users =
                              decoded
                                  .map<Map<String, dynamic>>(
                                    (e) => Map<String, dynamic>.from(e as Map),
                                  )
                                  .toList();
                          await controller.bulkCreateUsers(users);
                          Get.back();
                        } else {
                          Get.snackbar(
                            'Error',
                            'JSON must be an array of user objects',
                          );
                        }
                      } catch (e) {
                        Get.snackbar('Error', 'Invalid JSON format: $e');
                      }
                    },
                    icon: const Icon(Icons.group_add, size: 18),
                    label: const Text('Create Users'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.medium,
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

  // Show Bulk Action Confirmation
  static void showBulkActionDialog(
    UserManagementController controller,
    String action,
  ) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                action == 'activate' ? Icons.check_circle : Icons.block,
                size: 64,
                color:
                    action == 'activate'
                        ? AppColors.success
                        : AppColors.warning,
              ),
              const SizedBox(height: 16),
              Text(
                action == 'activate' ? 'Activate Users' : 'Deactivate Users',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Obx(
                () => Text(
                  action == 'activate'
                      ? 'Activate ${controller.selectedUserIds.length} user(s)?'
                      : 'Deactivate ${controller.selectedUserIds.length} user(s)?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMedium),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final result =
                          action == 'activate'
                              ? await controller.bulkActivateUsers(
                                controller.selectedUserIds.toList(),
                              )
                              : await controller.bulkDeactivateUsers(
                                controller.selectedUserIds.toList(),
                              );

                      if (result['success'] == true) {
                        Get.back();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          action == 'activate'
                              ? AppColors.success
                              : AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.medium,
                      ),
                    ),
                    child: Text(
                      action == 'activate' ? 'Activate' : 'Deactivate',
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

  // Show Confirm Action Dialog
  static void showConfirmActionDialog(
    UserManagementController controller,
    String action,
    int userId,
  ) {
    String title = '';
    String message = '';
    String confirmText = '';
    Color confirmColor = AppColors.success;
    IconData icon = Icons.check_circle;

    switch (action) {
      case 'activate':
        title = 'Activate User';
        message = 'Are you sure you want to activate this user?';
        confirmText = 'Activate';
        confirmColor = AppColors.success;
        icon = Icons.check_circle;
        break;
      case 'deactivate':
        title = 'Deactivate User';
        message = 'Are you sure you want to deactivate this user?';
        confirmText = 'Deactivate';
        confirmColor = AppColors.warning;
        icon = Icons.block;
        break;
      case 'delete':
        title = 'Delete User';
        message = 'This action cannot be undone!';
        confirmText = 'Delete';
        confirmColor = AppColors.danger;
        icon = Icons.delete;
        break;
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: confirmColor),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMedium),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      Get.back();
                      switch (action) {
                        case 'activate':
                          await controller.activateUser(userId);
                          break;
                        case 'deactivate':
                          await controller.deactivateUser(userId);
                          break;
                        case 'delete':
                          await controller.deleteUser(userId);
                          break;
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.medium,
                      ),
                    ),
                    child: Text(confirmText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show User Details
  static void showUserDetails(
    UserManagementController controller,
    UserModel user,
    Function(UserModel) onEdit,
    Function(UserModel) onPermissions,
    Function(UserModel) onResetPassword,
  ) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.large),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: _getRoleColor(user.role),
                    child: Icon(
                      _getRoleIcon(user.role),
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    user.username,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    user.email,
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildInfoChip(
                      user.role.toUpperCase(),
                      _getRoleColor(user.role),
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      user.isActive ? 'ACTIVE' : 'INACTIVE',
                      user.isActive ? AppColors.success : AppColors.textLight,
                    ),
                  ],
                ),
                const Divider(height: 32),
                _buildDetailRow('User ID', user.userId.toString()),
                _buildDetailRow('Created', _formatDateTime(user.createdAt)),
                _buildDetailRow('Updated', _formatDateTime(user.updatedAt)),
                if (user.clientName != null)
                  _buildDetailRow(
                    'Client',
                    '${user.clientName} (${user.clientCode ?? 'N/A'})',
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Permissions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (user.permissions.canCreateBoxes)
                      _buildPermissionChip('Create Boxes'),
                    if (user.permissions.canEditBoxes)
                      _buildPermissionChip('Edit Boxes'),
                    if (user.permissions.canDeleteBoxes)
                      _buildPermissionChip('Delete Boxes'),
                    if (user.permissions.canCreateCollections)
                      _buildPermissionChip('Collections'),
                    if (user.permissions.canCreateRetrievals)
                      _buildPermissionChip('Retrievals'),
                    if (user.permissions.canCreateDeliveries)
                      _buildPermissionChip('Deliveries'),
                    if (user.permissions.canViewReports)
                      _buildPermissionChip('Reports'),
                    if (user.permissions.canManageUsers)
                      _buildPermissionChip('Manage Users'),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        onEdit(user);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        onPermissions(user);
                      },
                      icon: const Icon(Icons.lock, size: 18),
                      label: const Text('Permissions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        onResetPassword(user);
                      },
                      icon: const Icon(Icons.vpn_key, size: 18),
                      label: const Text('Password'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static Widget _buildPermissionChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.success.withOpacity(0.1),
      labelStyle: const TextStyle(
        color: AppColors.success,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  static Color _getRoleColor(String role) {
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

  static IconData _getRoleIcon(String role) {
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

  static String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
