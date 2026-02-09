import 'package:flutter/material.dart';

class GeneralSettingsWidget extends StatelessWidget {
  const GeneralSettingsWidget({super.key});

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
                    Icon(Icons.tune, color: Color(0xFFE67E22)),
                    SizedBox(width: 12),
                    Text(
                      'General Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Configure general application preferences and system settings.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                _buildSettingItem(
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: 'English',
                ),
                const Divider(),
                _buildSettingItem(
                  icon: Icons.access_time,
                  title: 'Timezone',
                  subtitle: 'GMT+2 (SAST)',
                ),
                const Divider(),
                _buildSettingItem(
                  icon: Icons.color_lens,
                  title: 'Theme',
                  subtitle: 'Light',
                ),
                const Divider(),
                _buildSettingItem(
                  icon: Icons.info,
                  title: 'About',
                  subtitle: 'Version 1.0.0',
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