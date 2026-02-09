import 'package:flutter/material.dart';

class AuditsSettingsWidget extends StatelessWidget {
  const AuditsSettingsWidget({super.key});

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
                    Icon(Icons.history, color: Color(0xFF9B59B6)),
                    SizedBox(width: 12),
                    Text(
                      'Audit Trail Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Configure audit logging, retention, and monitoring settings.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                _buildSettingItem(
                  icon: Icons.track_changes,
                  title: 'Audit Logging',
                  subtitle: 'All actions logged',
                ),
                const Divider(),
                _buildSettingItem(
                  icon: Icons.calendar_today,
                  title: 'Log Retention',
                  subtitle: '90 days',
                ),
                const Divider(),
                _buildSettingItem(
                  icon: Icons.notifications,
                  title: 'Alert Notifications',
                  subtitle: 'Enabled for critical events',
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