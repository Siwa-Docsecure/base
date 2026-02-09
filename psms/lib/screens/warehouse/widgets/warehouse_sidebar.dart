// warehouse_sidebar.dart
import 'package:flutter/material.dart';
import 'package:psms/controllers/auth_controller.dart';

class WarehouseSidebar extends StatelessWidget {
  final bool isCollapsed;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onToggleCollapse;
  final AuthController authController;

  const WarehouseSidebar({
    super.key,
    required this.isCollapsed,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onToggleCollapse,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? 80 : 260,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _buildMenuItems(),
            ),
          ),
          const Divider(height: 1),
          _buildUserSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'DocSecure',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (isCollapsed) const Spacer(),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA).withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                color: const Color(0xFF2C3E50),
                size: 20,
              ),
              onPressed: onToggleCollapse,
              tooltip: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    final items = <Widget>[];

    items.add(_buildMenuItem(
      index: 0,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ));

    if (authController.hasPermission('canCreateBoxes') ||
        authController.hasPermission('canEditBoxes') ||
        authController.hasPermission('canDeleteBoxes')) {
      items.add(_buildMenuItem(
        index: 1,
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        label: 'Boxes',
      ));
    }

    if (authController.hasPermission('canCreateCollections')) {
      items.add(_buildMenuItem(
        index: 2,
        icon: Icons.collections_outlined,
        selectedIcon: Icons.collections,
        label: 'Collections',
      ));
    }

    if (authController.hasPermission('canCreateRetrievals')) {
      items.add(_buildMenuItem(
        index: 3,
        icon: Icons.find_in_page_outlined,
        selectedIcon: Icons.find_in_page,
        label: 'Retrievals',
      ));
    }

    if (authController.hasPermission('canCreateDeliveries')) {
      items.add(_buildMenuItem(
        index: 4,
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping,
        label: 'Deliveries',
      ));
    }

    if (authController.hasPermission('canViewReports')) {
      items.add(_buildMenuItem(
        index: 5,
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics,
        label: 'Reports',
      ));
    }

    if (authController.hasPermission('canManageUsers')) {
      items.add(_buildMenuItem(
        index: 6,
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        label: 'Users',
      ));
    }

    if (authController.hasPermission('canManageUsers')) {
      items.add(_buildMenuItem(
        index: 7,
        icon: Icons.business_outlined,
        selectedIcon: Icons.business,
        label: 'Clients',
      ));
    }

    items.add(const SizedBox(height: 8));
    items.add(Padding(
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 16 : 20),
      child: const Divider(),
    ));
    items.add(const SizedBox(height: 8));

    items.add(_buildMenuItem(
      index: 8,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ));

    return items;
  }

  Widget _buildMenuItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final isSelected = selectedIndex == index;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemSelected(index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 44,
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF3498DB).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border(
                      left: BorderSide(
                        color: const Color(0xFF3498DB),
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                if (isCollapsed)
                  Expanded(
                    child: Icon(
                      isSelected ? selectedIcon : icon,
                      size: 22,
                      color: isSelected
                          ? const Color(0xFF3498DB)
                          : const Color(0xFF95A5A6),
                    ),
                  )
                else ...[
                  Icon(
                    isSelected ? selectedIcon : icon,
                    size: 22,
                    color: isSelected
                        ? const Color(0xFF3498DB)
                        : const Color(0xFF95A5A6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFFFFFFFF)
                            : const Color.fromARGB(255, 217, 226, 226),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection() {
    final user = authController.currentUser.value;

    return Container(
      padding: EdgeInsets.all(isCollapsed ? 12 : 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF3498DB),
            radius: isCollapsed ? 16 : 20,
            child: Text(
              user?.username?.substring(0, 1).toUpperCase() ?? 'U',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isCollapsed ? 14 : 16,
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user?.username ?? 'User',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user?.role.toUpperCase() ?? 'ROLE',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF95A5A6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}