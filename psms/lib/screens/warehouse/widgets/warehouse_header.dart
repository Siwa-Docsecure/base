import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/controllers/auth_controller.dart';

class WarehouseHeader extends StatelessWidget {
  final String title;
  final AuthController authController;

  const WarehouseHeader({
    super.key,
    required this.title,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color.fromARGB(255, 255, 255, 255),
              ),
            ),
            
            const Spacer(),

            // Search
            Container(
              width: 320,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF95A5A6),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF95A5A6),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Notifications
            _buildIconButton(
              icon: Icons.notifications_outlined,
              onPressed: () {
                Get.snackbar(
                  'Notifications',
                  'No new notifications',
                  snackPosition: SnackPosition.TOP,
                  duration: const Duration(seconds: 2),
                );
              },
              badge: true,
            ),

            const SizedBox(width: 12),

            // Refresh
            _buildIconButton(
              icon: Icons.refresh,
              onPressed: () async {
                await authController.getProfile();
                Get.snackbar(
                  'Success',
                  'Data refreshed',
                  snackPosition: SnackPosition.TOP,
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF27AE60),
                  colorText: Colors.white,
                );
              },
            ),

            const SizedBox(width: 12),

            // Logout
            _buildIconButton(
              icon: Icons.logout,
              onPressed: () => _handleLogout(),
              color: const Color(0xFFE74C3C),
            ),

            const SizedBox(width: 16),

            // User Avatar
            Obx(() => GestureDetector(
              onTap: () => _showUserMenu(context),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF3498DB),
                      radius: 16,
                      child: Text(
                        authController.currentUser.value?.username
                            ?.substring(0, 1)
                            .toUpperCase() ??
                            'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authController.currentUser.value?.username ?? 'User',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          authController.currentUser.value?.role.toUpperCase() ?? 'ROLE',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF95A5A6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: Color(0xFF95A5A6),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
    bool badge = false,
  }) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              size: 20,
              color: color ?? const Color(0xFF95A5A6),
            ),
            onPressed: onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
        if (badge)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE74C3C),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  void _showUserMenu(BuildContext context) {
    final user = authController.currentUser.value;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF3498DB),
                radius: 32,
                child: Text(
                  user?.username?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.username ?? 'User',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? 'email@example.com',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF95A5A6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3498DB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user?.role.toUpperCase() ?? 'ROLE',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3498DB),
                  ),
                ),
              ),
              if (user?.clientName != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.business,
                      size: 16,
                      color: Color(0xFF95A5A6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user?.clientName ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7F8C8D),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

  void _handleLogout() {
    Get.defaultDialog(
      title: 'Logout',
      titleStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C3E50),
      ),
      content: const Text(
        'Are you sure you want to logout?',
        textAlign: TextAlign.center,
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE74C3C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: () async {
          Get.back();
          await authController.logout();
        },
        child: const Text('Yes, Logout'),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('Cancel'),
      ),
    );
  }
}
