import 'package:flutter/material.dart';

import 'tabs/storage_management_page.dart';
import 'widgets/audits_settings_widget.dart';
import 'widgets/general_settings_widget.dart';
import 'widgets/reports_settings_widget.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    StorageManagementPage(),
    AuditsSettingsWidget(),
    ReportsSettingsWidget(),
    GeneralSettingsWidget(),
  ];

  final List<Map<String, dynamic>> _navItems = const [
    {'label': 'Storage', 'icon': Icons.storage},
    {'label': 'Audits', 'icon': Icons.history},
    {'label': 'Reports', 'icon': Icons.analytics},
    {'label': 'General', 'icon': Icons.tune},
  ];

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.1),
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              'Configure system preferences',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          ResponsiveNavigationMenu(
            selectedIndex: _selectedIndex,
            navItems: _navItems,
            onItemSelected: _onItemSelected,
          ),
        ],
      ),
      body: Container(
        color: Colors.black.withOpacity(0.1),
        child: _pages[_selectedIndex],
      ),
    );
  }
}

/// A responsive navigation widget that shows a segmented row on wide screens
/// and a popup menu button on narrow screens (mobile).
class ResponsiveNavigationMenu extends StatelessWidget {
  final int selectedIndex;
  final List<Map<String, dynamic>> navItems;
  final ValueChanged<int> onItemSelected;

  const ResponsiveNavigationMenu({
    super.key,
    required this.selectedIndex,
    required this.navItems,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use a breakpoint of 600 (typical mobile/tablet threshold)
        final isWide = constraints.maxWidth > 600;

        if (isWide) {
          // Wide screen: show as a horizontal segmented row inside actions
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SegmentedButton<int>(
              segments: List.generate(
                navItems.length,
                (index) => ButtonSegment<int>(
                  value: index,
                  label: Text(navItems[index]['label']),
                  icon: Icon(navItems[index]['icon'], size: 18),
                ),
              ),
              selected: {selectedIndex},
              onSelectionChanged: (Set<int> newSelection) {
                onItemSelected(newSelection.first);
              },
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.black;
                  }
                  return Colors.black.withOpacity(0.7);
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.grey.shade200;
                  }
                  return Colors.transparent;
                }),
                side: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return BorderSide(color: Colors.black.withOpacity(0.3));
                  }
                  return const BorderSide(color: Colors.transparent);
                }),
              ),
            ),
          );
        } else {
          // Mobile view: popup menu button
          return PopupMenuButton<int>(
            icon: const Icon(Icons.menu, color: Colors.black),
            onSelected: onItemSelected,
            itemBuilder: (context) {
              return List.generate(
                navItems.length,
                (index) => PopupMenuItem<int>(
                  value: index,
                  child: Row(
                    children: [
                      Icon(navItems[index]['icon'], size: 20, color: Colors.black87),
                      const SizedBox(width: 12),
                      Text(navItems[index]['label']),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    navItems[selectedIndex]['label'],
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_drop_down, color: Colors.black),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}