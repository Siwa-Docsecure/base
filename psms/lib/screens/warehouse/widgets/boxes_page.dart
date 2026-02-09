import 'package:flutter/material.dart';
import 'package:psms/controllers/auth_controller.dart';

class BoxesPage extends StatelessWidget {
  final AuthController authController;

  const BoxesPage({
    super.key,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Box Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage and track all storage boxes',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF95A5A6),
                    ),
                  ),
                ],
              ),
              if (authController.hasPermission('canCreateBoxes'))
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to create box page
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Box'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Filters
          _buildFilters(),

          const SizedBox(height: 24),

          // Boxes List
          _buildBoxesList(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton('All Boxes', true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterButton('Stored', false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterButton('Retrieved', false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterButton('Destroyed', false),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF3498DB).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? const Color(0xFF3498DB)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? const Color(0xFF3498DB)
                : const Color(0xFF7F8C8D),
          ),
        ),
      ),
    );
  }

  Widget _buildBoxesList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          _buildTableHeader(),
          const Divider(height: 1),
          // Table Rows
          _buildTableRow(
            'BOX-2024-156',
            'Acme Corporation',
            'RACK-A-12',
            'Stored',
            const Color(0xFF27AE60),
          ),
          _buildTableRow(
            'BOX-2024-155',
            'Global Industries',
            'RACK-B-08',
            'Stored',
            const Color(0xFF27AE60),
          ),
          _buildTableRow(
            'BOX-2024-143',
            'Tech Solutions',
            'RACK-C-05',
            'Retrieved',
            const Color(0xFF3498DB),
          ),
          _buildTableRow(
            'BOX-2019-089',
            'Premium Services',
            'RACK-A-03',
            'Pending Destruction',
            const Color(0xFFE74C3C),
          ),
          _buildTableRow(
            'BOX-2024-120',
            'Mega Enterprises',
            'RACK-B-15',
            'Stored',
            const Color(0xFF27AE60),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _buildHeaderCell('Box Number', flex: 2),
          _buildHeaderCell('Client', flex: 2),
          _buildHeaderCell('Location', flex: 2),
          _buildHeaderCell('Status', flex: 2),
          _buildHeaderCell('Actions', flex: 1),
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
          color: Color(0xFF7F8C8D),
        ),
      ),
    );
  }

  Widget _buildTableRow(
    String boxNumber,
    String client,
    String location,
    String status,
    Color statusColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              boxNumber,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              client,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF7F8C8D),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              location,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF7F8C8D),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                if (authController.hasPermission('canEditBoxes'))
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                    ),
                    onPressed: () {},
                    tooltip: 'Edit',
                  ),
                if (authController.hasPermission('canDeleteBoxes'))
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Color(0xFFE74C3C),
                    ),
                    onPressed: () {},
                    tooltip: 'Delete',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
