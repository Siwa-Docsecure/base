import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/screens/warehouse/retrievals/retrievals_page.dart';
import 'package:psms/utils/responsive_helper.dart';
import 'package:psms/screens/warehouse/boxes/box_management_screen.dart';
import 'package:psms/screens/warehouse/clients/client_management_page.dart';
import 'package:psms/screens/warehouse/settings/settings_page.dart';
import 'package:psms/screens/warehouse/users/user_management_page.dart';

import 'collections/collections_page.dart';
import 'widgets/boxes_page.dart';
import 'widgets/dashboard_page.dart';
import 'widgets/placeholder_pages.dart';
import 'widgets/warehouse_header.dart';
import 'widgets/warehouse_sidebar.dart';

class WarehouseHomePage extends StatefulWidget {
  const WarehouseHomePage({super.key});

  @override
  State<WarehouseHomePage> createState() => _WarehouseHomePageState();
}

class _WarehouseHomePageState extends State<WarehouseHomePage> {
  final AuthController _authController = Get.find<AuthController>();
  final RxInt _selectedIndex = 0.obs;
  final RxBool _isCollapsed = false.obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // color: Color(0xFFF5F6FA),
          image: DecorationImage(
            image: AssetImage('assets/images/background2.jpg'),
            fit: BoxFit.cover,
            opacity: 1, // Very subtle background
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.1),
              BlendMode.lighten,
            ),
          ),
        ),
        child: context.isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.95),
        elevation: 0,
        title: Text(
          _getPageTitle(),
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2C3E50)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Obx(() => CircleAvatar(
              backgroundColor: const Color(0xFF3498DB),
              child: Text(
                _authController.currentUser.value?.username
                    ?.substring(0, 1)
                    .toUpperCase() ??
                    'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Obx(() => _getCurrentPage()),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Obx(() => WarehouseSidebar(
          isCollapsed: _isCollapsed.value,
          selectedIndex: _selectedIndex.value,
          onItemSelected: (index) => _selectedIndex.value = index,
          onToggleCollapse: () => _isCollapsed.value = !_isCollapsed.value,
          authController: _authController,
        )),
        Expanded(
          child: Column(
            children: [
              WarehouseHeader(
                title: _getPageTitle(),
                authController: _authController,
              ),
              Expanded(
                child: Obx(() => _getCurrentPage()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Obx(() {
            final user = _authController.currentUser.value;
            return UserAccountsDrawerHeader(
              accountName: Text(
                user?.username ?? 'User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(user?.email ?? 'email@example.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  user?.username?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3498DB),
                  ),
                ),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            );
          }),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _buildMenuItems(),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFE74C3C)),
            title: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFE74C3C)),
            ),
            onTap: () => _handleLogout(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    final menuItems = <Widget>[];

    menuItems.add(_buildMenuItem(0, Icons.dashboard_outlined, 'Dashboard'));

    if (_authController.hasPermission('canCreateBoxes') ||
        _authController.hasPermission('canEditBoxes') ||
        _authController.hasPermission('canDeleteBoxes')) {
      menuItems.add(_buildMenuItem(1, Icons.inventory_2_outlined, 'Boxes'));
    }

    if (_authController.hasPermission('canCreateCollections')) {
      menuItems.add(_buildMenuItem(2, Icons.collections_outlined, 'Collections'));
    }

    if (_authController.hasPermission('canCreateRetrievals')) {
      menuItems.add(_buildMenuItem(3, Icons.find_in_page_outlined, 'Retrievals'));
    }

    if (_authController.hasPermission('canCreateDeliveries')) {
      menuItems.add(_buildMenuItem(4, Icons.local_shipping_outlined, 'Deliveries'));
    }

    if (_authController.hasPermission('canViewReports')) {
      menuItems.add(_buildMenuItem(5, Icons.analytics_outlined, 'Reports'));
    }

    if (_authController.hasPermission('canManageUsers')) {
      menuItems.add(_buildMenuItem(6, Icons.people_outline, 'User Management'));
    }

    if (_authController.hasPermission('canManageUsers')) {
      menuItems.add(_buildMenuItem(7, Icons.people_outline, 'Client Management'));
    }

    menuItems.add(const Divider());
    menuItems.add(_buildMenuItem(8, Icons.settings_outlined, 'Settings'));

    return menuItems;
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    return Obx(() => ListTile(
      leading: Icon(
        icon,
        color: _selectedIndex.value == index
            ? const Color(0xFF3498DB)
            : const Color(0xFF95A5A6),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: _selectedIndex.value == index
              ? const Color(0xFF3498DB)
              : const Color(0xFF2C3E50),
          fontWeight: _selectedIndex.value == index
              ? FontWeight.w600
              : FontWeight.normal,
        ),
      ),
      selected: _selectedIndex.value == index,
      selectedTileColor: const Color(0xFF3498DB).withOpacity(0.1),
      onTap: () {
        _selectedIndex.value = index;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    ));
  }

  Widget _getCurrentPage() {
    switch (_selectedIndex.value) {
      case 0:
        return DashboardPage(authController: _authController);
      case 1:
        return BoxManagementScreen();
      case 2:
        return CollectionsPage();
      case 3:
        return RetrievalsPage();
      case 4:
        return DeliveriesPage(authController: _authController);
      case 5:
        return ReportsPage(authController: _authController);
      case 6:
        return UserManagementPage();
      case 7:
        return ClientManagementPage();
      case 8:
        return SettingsPage();
      default:
        return DashboardPage(authController: _authController);
    }
  }

  String _getPageTitle() {
    switch (_selectedIndex.value) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Box Management';
      case 2:
        return 'Collections';
      case 3:
        return 'Retrievals';
      case 4:
        return 'Deliveries';
      case 5:
        return 'Reports';
      case 6:
        return 'User Management';
      case 7:
        return 'Client Management';
      case 8:
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }

  void _handleLogout() {
    Get.defaultDialog(
      title: 'Logout',
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      content: const Text('Are you sure you want to logout?'),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE74C3C),
          foregroundColor: Colors.white,
        ),
        onPressed: () async {
          Get.back();
          await _authController.logout();
        },
        child: const Text('Yes'),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('Cancel'),
      ),
    );
  }
}