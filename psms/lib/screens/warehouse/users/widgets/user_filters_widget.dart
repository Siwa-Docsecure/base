import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/user_management_controller.dart';

class UserFiltersWidget extends StatelessWidget {
  final UserManagementController userController;
  final bool isMobile;

  const UserFiltersWidget({
    super.key,
    required this.userController,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        boxShadow: AppShadows.light,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              Obx(() {
                final hasFilters = userController.searchQuery.value.isNotEmpty ||
                    userController.selectedRole.value.isNotEmpty ||
                    userController.selectedStatus.value.isNotEmpty ||
                    userController.selectedClientId.value.isNotEmpty;
                
                return TextButton.icon(
                  onPressed: hasFilters
                      ? () => userController.clearFilters()
                      : null,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          
          if (isMobile)
            _buildMobileFilters()
          else
            _buildDesktopFilters(),
        ],
      ),
    );
  }

  Widget _buildMobileFilters() {
    return Column(
      children: [
        // Search
        Obx(() => TextField(
          controller: TextEditingController(text: userController.searchQuery.value)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: userController.searchQuery.value.length),
            ),
          onChanged: (value) => userController.searchQuery.value = value,
          onSubmitted: (_) => userController.applyFilters(),
          decoration: InputDecoration(
            hintText: 'Search users...',
            hintStyle: const TextStyle(color: AppColors.textLight),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: userController.searchQuery.value.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      userController.searchQuery.value = '';
                      userController.applyFilters();
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: AppBorderRadius.medium,
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        )),
        const SizedBox(height: 12),
        
        // Role & Status
        Row(
          children: [
            Expanded(child: _buildRoleFilter()),
            const SizedBox(width: 12),
            Expanded(child: _buildStatusFilter()),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Search Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => userController.applyFilters(),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search'),
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
    );
  }

  Widget _buildDesktopFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Obx(() => TextField(
                controller: TextEditingController(text: userController.searchQuery.value)
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: userController.searchQuery.value.length),
                  ),
                onChanged: (value) => userController.searchQuery.value = value,
                onSubmitted: (_) => userController.applyFilters(),
                decoration: InputDecoration(
                  hintText: 'Search by username, email...',
                  hintStyle: const TextStyle(color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: userController.searchQuery.value.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            userController.searchQuery.value = '';
                            userController.applyFilters();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: AppBorderRadius.medium,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildRoleFilter()),
            const SizedBox(width: 12),
            Expanded(child: _buildStatusFilter()),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => userController.applyFilters(),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search'),
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
    );
  }

  Widget _buildRoleFilter() {
    return Obx(() => DropdownButtonFormField<String>(
      value: userController.selectedRole.value.isEmpty 
          ? null 
          : userController.selectedRole.value,
      onChanged: (value) {
        userController.selectedRole.value = value ?? '';
      },
      decoration: InputDecoration(
        labelText: 'Role',
        labelStyle: const TextStyle(
          color: AppColors.textLight,
          fontSize: 14,
        ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: AppBorderRadius.medium,
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: '',
          child: Text('All Roles'),
        ),
        DropdownMenuItem(
          value: 'admin',
          child: Text('Admin'),
        ),
        DropdownMenuItem(
          value: 'staff',
          child: Text('Staff'),
        ),
        DropdownMenuItem(
          value: 'client',
          child: Text('Client'),
        ),
      ],
    ));
  }

  Widget _buildStatusFilter() {
    return Obx(() => DropdownButtonFormField<String>(
      value: userController.selectedStatus.value.isEmpty 
          ? null 
          : userController.selectedStatus.value,
      onChanged: (value) {
        userController.selectedStatus.value = value ?? '';
      },
      decoration: InputDecoration(
        labelText: 'Status',
        labelStyle: const TextStyle(
          color: AppColors.textLight,
          fontSize: 14,
        ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: AppBorderRadius.medium,
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: '',
          child: Text('All Status'),
        ),
        DropdownMenuItem(
          value: 'true',
          child: Text('Active'),
        ),
        DropdownMenuItem(
          value: 'false',
          child: Text('Inactive'),
        ),
      ],
    ));
  }
}