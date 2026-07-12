// settings_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/screens/warehouse/settings/tabs/audit_page.dart';
import 'tabs/storage_management_page.dart';
import 'widgets/general_settings_widget.dart';
import 'widgets/reports_settings_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS — match dashboard palette
// ─────────────────────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF2C3E50);
const _kAccent  = Color(0xFF3498DB);
const _kBg      = Color(0xFFF4F6F9);

// ─────────────────────────────────────────────────────────────────────────────
// TAB DEFINITION
// ─────────────────────────────────────────────────────────────────────────────

class _TabDef {
  final String label;
  final IconData icon;
  const _TabDef({required this.label, required this.icon});
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PAGE
// ─────────────────────────────────────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _auth = Get.find<AuthController>();
  int _selectedIndex = 0;

  bool get _isAdmin => _auth.currentUser.value?.role == 'admin';

  // Admin-only tabs
  static const _adminTabs = <_TabDef>[
    _TabDef(label: 'Storage', icon: Icons.storage_outlined),
    _TabDef(label: 'Reports', icon: Icons.analytics_outlined),
    _TabDef(label: 'Audits',  icon: Icons.history_outlined),
  ];

  // Visible to all roles
  static const _generalTab = _TabDef(label: 'General', icon: Icons.tune_outlined);

  List<_TabDef> get _tabs =>
      _isAdmin ? [..._adminTabs, _generalTab] : [_generalTab];

  Widget _pageForIndex(int i) {
    if (!_isAdmin) return const GeneralSettingsWidget();
    switch (i) {
      case 0:  return const StorageManagementPage();
      case 1:  return const ReportsSettingsWidget();
      case 2:  return const AuditScreen();
      default: return const GeneralSettingsWidget();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final max = _tabs.length - 1;
    if (_selectedIndex > max) setState(() => _selectedIndex = max);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 680;
    final tabs   = _tabs;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,

        // ── Title — icon badge + title + subtitle ───────────────────────────
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kAccent, Color(0xFF5DADE2)]),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.settings_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    color: _kPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                Text(
                  _isAdmin
                      ? 'System configuration & preferences'
                      : 'Personal preferences',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ],
        ),

        // ── Actions — navigation lives here ────────────────────────────────
        actions: [
          // Permission info chip for non-admins (narrow hint)
          if (!_isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 12, color: Colors.orange.shade700),
                    const SizedBox(width: 5),
                    Text(
                      'General only',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // Role pill
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _RolePill(
              isAdmin: _isAdmin,
              role: _auth.currentUser.value?.role ?? 'user',
            ),
          ),
          const SizedBox(width: 8),

          // Navigation — SegmentedButton on wide, PopupMenu on narrow
          isWide
              ? _SegmentedNav(
                  tabs: tabs,
                  selectedIndex: _selectedIndex,
                  onSelected: (i) => setState(() => _selectedIndex = i),
                )
              : _PopupNav(
                  tabs: tabs,
                  selectedIndex: _selectedIndex,
                  onSelected: (i) => setState(() => _selectedIndex = i),
                ),

          const SizedBox(width: 12),
        ],
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: _pageForIndex(_selectedIndex),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEGMENTED NAV — wide screens, in AppBar actions
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedNav extends StatelessWidget {
  final List<_TabDef> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SegmentedNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SegmentedButton<int>(
        segments: tabs.asMap().entries
            .map((e) => ButtonSegment<int>(
                  value: e.key,
                  label: Text(e.value.label,
                      style: const TextStyle(fontSize: 12)),
                  icon: Icon(e.value.icon, size: 16),
                ))
            .toList(),
        selected: {selectedIndex},
        onSelectionChanged: (s) => onSelected(s.first),
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _kAccent;
            return Colors.grey[600];
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return _kAccent.withOpacity(0.08);
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return BorderSide(color: _kAccent.withOpacity(0.4));
            return BorderSide(color: Colors.grey.shade300);
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _kAccent;
            return Colors.grey[500];
          }),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POPUP NAV — narrow screens, in AppBar actions
// ─────────────────────────────────────────────────────────────────────────────

class _PopupNav extends StatelessWidget {
  final List<_TabDef> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PopupNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final current = tabs[selectedIndex];
    return PopupMenuButton<int>(
      tooltip: 'Navigate',
      onSelected: onSelected,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => tabs.asMap().entries.map((e) {
        final isActive = e.key == selectedIndex;
        return PopupMenuItem<int>(
          value: e.key,
          child: Row(children: [
            Icon(e.value.icon,
                size: 18, color: isActive ? _kAccent : Colors.grey[600]),
            const SizedBox(width: 12),
            Text(
              e.value.label,
              style: TextStyle(
                color: isActive ? _kAccent : Colors.black87,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            if (isActive) ...[
              const Spacer(),
              Icon(Icons.check, size: 16, color: _kAccent),
            ],
          ]),
        );
      }).toList(),
      // Trigger: current tab name + chevron
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(current.icon, size: 15, color: _kAccent),
            const SizedBox(width: 6),
            Text(current.label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kPrimary)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down,
                size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROLE PILL
// ─────────────────────────────────────────────────────────────────────────────

class _RolePill extends StatelessWidget {
  final bool isAdmin;
  final String role;

  const _RolePill({required this.isAdmin, required this.role});

  @override
  Widget build(BuildContext context) {
    final color = isAdmin ? const Color(0xFFE74C3C) : _kAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin
                ? Icons.admin_panel_settings_outlined
                : Icons.person_outline,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE NAVIGATION MENU (kept for backward compat)
// ─────────────────────────────────────────────────────────────────────────────

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
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 600) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SegmentedButton<int>(
            segments: List.generate(
              navItems.length,
              (i) => ButtonSegment<int>(
                value: i,
                label: Text(navItems[i]['label']),
                icon: Icon(navItems[i]['icon'], size: 18),
              ),
            ),
            selected: {selectedIndex},
            onSelectionChanged: (s) => onItemSelected(s.first),
          ),
        );
      }
      return PopupMenuButton<int>(
        icon: const Icon(Icons.menu, color: Colors.black),
        onSelected: onItemSelected,
        itemBuilder: (_) => List.generate(
          navItems.length,
          (i) => PopupMenuItem<int>(
            value: i,
            child: Row(children: [
              Icon(navItems[i]['icon'], size: 20),
              const SizedBox(width: 12),
              Text(navItems[i]['label']),
            ]),
          ),
        ),
      );
    });
  }
}