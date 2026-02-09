// lib/screens/warehouse/clients/widgets/client_filters_widget.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/client_management_controller.dart';

class ClientFiltersWidget extends StatelessWidget {
  final ClientManagementController controller;
  final bool isMobile;

  const ClientFiltersWidget({
    super.key,
    required this.controller,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppBorderRadius.medium,
        boxShadow: AppShadows.light,
      ),
      child: Column(
        children: [
          // Search and View Toggle Row
          Row(
            children: [
              Expanded(
                child: _buildSearchBar(),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 16),
                _buildViewToggle(),
                const SizedBox(width: 16),
                _buildBulkSelectButton(),
              ],
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Filter Chips Row
          if (isMobile)
            Column(
              children: [
                _buildFilterChips(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildViewToggle()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildBulkSelectButton()),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                _buildFilterChips(),
                const Spacer(),
                _buildSortDropdown(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (value) => controller.searchClients(value),
      decoration: InputDecoration(
        hintText: 'Search clients by name, code, or contact...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  controller.searchQuery.value = '';
                  controller.fetchClients();
                },
              )
            : const SizedBox.shrink()),
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
    );
  }

  Widget _buildViewToggle() {
    return Obx(() => Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppBorderRadius.medium,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewButton(
            icon: Icons.table_rows,
            viewMode: 'table',
            tooltip: 'Table View',
          ),
          Container(
            width: 1,
            height: 24,
            color: AppColors.border,
          ),
          _buildViewButton(
            icon: Icons.grid_view,
            viewMode: 'grid',
            tooltip: 'Grid View',
          ),
        ],
      ),
    ));
  }

  Widget _buildViewButton({
    required IconData icon,
    required String viewMode,
    required String tooltip,
  }) {
    final isSelected = controller.viewMode.value == viewMode;
    
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          if (!isSelected) {
            controller.viewMode.value = viewMode;
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? Colors.white : AppColors.textMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildBulkSelectButton() {
    return Obx(() => ElevatedButton.icon(
      onPressed: () => controller.toggleBulkSelectMode(),
      icon: Icon(
        controller.isBulkSelectMode.value 
            ? Icons.check_box 
            : Icons.check_box_outline_blank,
        size: 18,
      ),
      label: Text(
        controller.isBulkSelectMode.value ? 'Cancel' : 'Select',
        style: const TextStyle(fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: controller.isBulkSelectMode.value
            ? AppColors.danger
            : AppColors.textMedium,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.medium,
        ),
      ),
    ));
  }

  Widget _buildFilterChips() {
    return Obx(() => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip('All', 'all'),
        _buildFilterChip('Active', 'active'),
        _buildFilterChip('Inactive', 'inactive'),
      ],
    ));
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = controller.filterStatus.value == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => controller.filterClients(value),
      selectedColor: _getChipColor(value),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textDark,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? _getChipColor(value) : AppColors.border,
      ),
    );
  }

  Color _getChipColor(String value) {
    switch (value) {
      case 'active':
        return AppColors.success;
      case 'inactive':
        return AppColors.textMedium;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildSortDropdown() {
    return Obx(() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppBorderRadius.medium,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: controller.sortBy.value,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          onChanged: (value) {
            if (value != null) {
              controller.sortClients(value);
            }
          },
          items: const [
            DropdownMenuItem(
              value: 'client_name',
              child: Text('Name'),
            ),
            DropdownMenuItem(
              value: 'client_code',
              child: Text('Code'),
            ),
            DropdownMenuItem(
              value: 'created_at',
              child: Text('Date Created'),
            ),
          ],
        ),
      ),
    ));
  }
}
