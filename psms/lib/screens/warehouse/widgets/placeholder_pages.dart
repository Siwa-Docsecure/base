import 'package:flutter/material.dart';
import 'package:psms/controllers/auth_controller.dart';

// Base Page Template
class _BasePage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final AuthController authController;

  const _BasePage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF95A5A6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Coming Soon'),
          ),
        ],
      ),
    );
  }
}

// Collections Page
// class CollectionsPage extends StatelessWidget {
//   final AuthController authController;

//   const CollectionsPage({
//     super.key,
//     required this.authController,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return _BasePage(
//       title: 'Collections',
//       subtitle: 'Manage box collections and dispatches',
//       icon: Icons.collections,
//       iconColor: const Color(0xFF27AE60),
//       authController: authController,
//     );
//   }
// }

// Retrievals Page
class RetrievalsPage extends StatelessWidget {
  final AuthController authController;

  const RetrievalsPage({
    super.key,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return _BasePage(
      title: 'Retrievals',
      subtitle: 'Track and manage box retrievals',
      icon: Icons.find_in_page,
      iconColor: const Color(0xFFF39C12),
      authController: authController,
    );
  }
}

// Deliveries Page
class DeliveriesPage extends StatelessWidget {
  final AuthController authController;

  const DeliveriesPage({
    super.key,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return _BasePage(
      title: 'Deliveries',
      subtitle: 'Schedule and track deliveries',
      icon: Icons.local_shipping,
      iconColor: const Color(0xFF9B59B6),
      authController: authController,
    );
  }
}

// Reports Page
class ReportsPage extends StatelessWidget {
  final AuthController authController;

  const ReportsPage({
    super.key,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return _BasePage(
      title: 'Reports',
      subtitle: 'View analytics and generate reports',
      icon: Icons.analytics,
      iconColor: const Color(0xFFE74C3C),
      authController: authController,
    );
  }
}


