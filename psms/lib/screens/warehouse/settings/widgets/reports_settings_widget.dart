import 'package:flutter/material.dart';

class ReportsSettingsWidget extends StatelessWidget {
  const ReportsSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics, color: Color(0xFF27AE60)),
                    SizedBox(width: 12),
                    Text(
                      'Reports Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Configure report generation, scheduling, and delivery preferences.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                _buildSettingItem(
                  icon: Icons.schedule,
                  title: 'Scheduled Reports',
                  subtitle: 'Weekly on Monday',
                ),
                const Divider(),
                _buildSettingItem(
                  icon: Icons.email,
                  title: 'Email Delivery',
                  subtitle: 'admin@docsecure.com',
                ),
                const Divider(),
                _buildSettingItem(
                  icon: Icons.picture_as_pdf,
                  title: 'Default Format',
                  subtitle: 'PDF',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF95A5A6)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: Implement navigation to detail page
      },
    );
  }
}