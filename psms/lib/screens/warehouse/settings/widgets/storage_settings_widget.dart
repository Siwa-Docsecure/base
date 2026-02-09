import 'package:flutter/material.dart';

class StorageSettingsWidget extends StatelessWidget {
  const StorageSettingsWidget({super.key});

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
                    Icon(Icons.storage, color: Color(0xFF3498DB)),
                    SizedBox(width: 12),
                    Text(
                      'Storage Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Configure storage locations, retention policies, and archival settings.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                _buildSettingItem(
                  icon: Icons.folder,
                  title: 'Default Retention Period',
                  subtitle: '7 years',
                ),
                const Divider(),
                _buildSettingItem(
                  icon: Icons.location_on,
                  title: 'Storage Locations',
                  subtitle: '15 active locations',
                ),
                const Divider(),
                _buildSettingItem(
                  icon: Icons.delete_outline,
                  title: 'Auto-Archive',
                  subtitle: 'Enabled',
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