// audit_screen.dart
import 'dart:io';
import 'package:excel/excel.dart' as exl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:psms/controllers/audit_controller.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/models/audit_models.dart';
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kEntityTypes = ['', 'box', 'user', 'collection', 'retrieval', 'delivery', 'auth', 'report', 'permissions', 'storage_location'];
const _kEntityLabels = ['All Types', 'Box', 'User', 'Collection', 'Retrieval', 'Delivery', 'Auth', 'Report', 'Permissions', 'Storage'];

const _accentColor = Color(0xFF2C3E50);
const _blueColor   = Color(0xFF3498DB);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen>
    with SingleTickerProviderStateMixin {
  final AuditController _ctrl = Get.put(AuditController());
  final AuthController _auth = Get.find<AuthController>();

  late TabController _tabController;

  // Filter state (local copies — synced to controller on apply)
  final _searchCtrl    = TextEditingController();
  final _actionCtrl    = TextEditingController();
  final _userIdCtrl    = TextEditingController();
  final _entityIdCtrl  = TextEditingController();
  final _ipCtrl        = TextEditingController();
  final _dateFromCtrl  = TextEditingController();
  final _dateToCtrl    = TextEditingController();

  String  _filterEntityType = '';
  bool    _showFilters       = false;
  bool    _isExportMode      = false;

  // Export config
  String _exportFormat = 'csv'; // 'csv' | 'json' | 'pdf' | 'excel'
  int    _exportLimit  = 5000;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ctrl.getLogs();
      await _ctrl.getSummary();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _actionCtrl.dispose();
    _userIdCtrl.dispose();
    _entityIdCtrl.dispose();
    _ipCtrl.dispose();
    _dateFromCtrl.dispose();
    _dateToCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLogTab(isWide),
                _buildSummaryTab(),
                _buildExportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _blueColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.security, color: _blueColor, size: 22),
          ),
          const SizedBox(width: 12),
          Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Audit Log',
                    style: TextStyle(
                      color: _accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                    ),
                  ),
                  Text(
                    '${_ctrl.totalEvents.value} total events',
                    style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 11),
                  ),
                ],
              )),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            color: _showFilters ? _blueColor : _accentColor,
          ),
          tooltip: 'Toggle Filters',
          onPressed: () => setState(() => _showFilters = !_showFilters),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: _accentColor),
          tooltip: 'Refresh',
          onPressed: () async {
            _ctrl.clearAll();
            await _ctrl.getLogs();
            await _ctrl.getSummary();
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: _blueColor,
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: _blueColor,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(icon: Icon(Icons.list_alt, size: 17), text: 'Event Log'),
          Tab(icon: Icon(Icons.bar_chart, size: 17), text: 'Summary'),
          Tab(icon: Icon(Icons.download, size: 17), text: 'Export'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1 — EVENT LOG
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLogTab(bool isWide) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _showFilters ? 300 : 0,
            child: _showFilters ? _buildFilterPanel() : const SizedBox.shrink(),
          ),
          Expanded(
            child: Column(
              children: [
                _buildQuickActionBar(),
                Expanded(child: _buildEventList()),
                _buildPaginationBar(),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        if (_showFilters) _buildFilterPanel(),
        _buildQuickActionBar(),
        Expanded(child: _buildEventList()),
        _buildPaginationBar(),
      ],
    );
  }

  // ── filter panel ─────────────────────────────────────────────────────────

  Widget _buildFilterPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_blueColor, Color(0xFF5DADE2)]),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text('Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear All', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _filterField('Search', Icons.search, _searchCtrl, hint: 'action, entity type, username…'),
                  const SizedBox(height: 10),
                  _filterField('Action Contains', Icons.bolt, _actionCtrl, hint: 'e.g. CREATE_BOX'),
                  const SizedBox(height: 10),
                  _filterField('User ID', Icons.person_outline, _userIdCtrl, hint: 'numeric ID', keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  _filterField('Entity ID', Icons.tag, _entityIdCtrl, hint: 'numeric ID', keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  _filterField('IP Address', Icons.router_outlined, _ipCtrl, hint: 'e.g. 127.0.0.1'),
                  const SizedBox(height: 10),
                  // Entity type dropdown
                  DropdownButtonFormField<String>(
                    value: _filterEntityType,
                    isExpanded: true,
                    decoration: _filterDecoration('Entity Type', Icons.category_outlined),
                    items: List.generate(_kEntityTypes.length, (i) => DropdownMenuItem(
                          value: _kEntityTypes[i],
                          child: Text(_kEntityLabels[i], style: const TextStyle(fontSize: 13)),
                        )),
                    onChanged: (v) => setState(() => _filterEntityType = v ?? ''),
                  ),
                  const SizedBox(height: 10),
                  // Date range
                  _dateField('Date From', _dateFromCtrl),
                  const SizedBox(height: 8),
                  _dateField('Date To', _dateToCtrl),
                  const SizedBox(height: 10),
                  // Sort
                  Obx(() => DropdownButtonFormField<String>(
                        value: _ctrl.sortOrder.value,
                        decoration: _filterDecoration('Sort Order', Icons.sort),
                        items: const [
                          DropdownMenuItem(value: 'DESC', child: Text('Newest First')),
                          DropdownMenuItem(value: 'ASC', child: Text('Oldest First')),
                        ],
                        onChanged: (v) => setState(() => _ctrl.sortOrder.value = v ?? 'DESC'),
                      )),
                  const SizedBox(height: 10),
                  // Page size
                  Obx(() => DropdownButtonFormField<int>(
                        value: _ctrl.pageSize.value,
                        decoration: _filterDecoration('Rows per page', Icons.numbers),
                        items: [20, 50, 100, 200]
                            .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _ctrl.pageSize.value = v;
                        },
                      )),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _applyFilters,
                      icon: const Icon(Icons.search, color: Colors.white, size: 16),
                      label: const Text('Apply Filters', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blueColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterField(String label, IconData icon, TextEditingController ctrl, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: _filterDecoration(label, icon).copyWith(hintText: hint),
    );
  }

  Widget _dateField(String label, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      style: const TextStyle(fontSize: 13),
      decoration: _filterDecoration(label, Icons.calendar_today_outlined).copyWith(
        suffixIcon: const Icon(Icons.calendar_today, size: 16),
      ),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) ctrl.text = DateFormat('yyyy-MM-dd').format(d);
      },
    );
  }

  InputDecoration _filterDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      prefixIcon: Icon(icon, size: 16),
      isDense: true,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  // ── quick action bar ──────────────────────────────────────────────────────

  Widget _buildQuickActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Active filter chips
          Obx(() {
            final chips = <Widget>[];
            if (_ctrl.filterAction.value.isNotEmpty) chips.add(_filterChip('Action: ${_ctrl.filterAction.value}', () => _clearField(_actionCtrl, () => _ctrl.filterAction.value = '')));
            if (_ctrl.filterEntityType.value.isNotEmpty) chips.add(_filterChip('Type: ${_ctrl.filterEntityType.value}', () => setState(() => _filterEntityType = '')));
            if (_ctrl.filterDateFrom.value.isNotEmpty) chips.add(_filterChip('From: ${_ctrl.filterDateFrom.value}', () => _clearField(_dateFromCtrl, () => _ctrl.filterDateFrom.value = '')));
            if (_ctrl.filterSearch.value.isNotEmpty) chips.add(_filterChip('Search: ${_ctrl.filterSearch.value}', () => _clearField(_searchCtrl, () => _ctrl.filterSearch.value = '')));
            return Expanded(
              child: chips.isEmpty
                  ? const Text('No active filters', style: TextStyle(color: Colors.grey, fontSize: 12))
                  : Wrap(spacing: 6, runSpacing: 4, children: chips),
            );
          }),
          const SizedBox(width: 8),
          // Refresh mini-button
          Obx(() => _ctrl.isLoading.value
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: () {
        onRemove();
        _applyFilters();
      },
      backgroundColor: _blueColor.withOpacity(0.08),
      side: BorderSide(color: _blueColor.withOpacity(0.2)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  // ── event list ────────────────────────────────────────────────────────────

  Widget _buildEventList() {
    return Obx(() {
      if (_ctrl.isLoading.value && _ctrl.logs.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: _blueColor));
      }

      if (_ctrl.logs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('No audit events found', style: TextStyle(fontSize: 17, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('Try adjusting your filters', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => _ctrl.getLogs(refresh: true),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _ctrl.logs.length,
          itemBuilder: (_, i) => _buildEventTile(_ctrl.logs[i]),
        ),
      );
    });
  }

  Widget _buildEventTile(AuditLogEntry e) {
    final color = _actionColor(e.action);
    final icon  = _actionIcon(e.action);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showEventDetail(e),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Action icon badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              // Main info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _actionBadge(e.action, color),
                        const SizedBox(width: 8),
                        _entityBadge(e.entityType),
                        if (e.entityId != null) ...[
                          const SizedBox(width: 4),
                          Text('#${e.entityId}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          e.actor?.username ?? 'System',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.router_outlined, size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          e.ipAddress ?? '—',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Timestamp + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimestamp(e.timestamp),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right, size: 16, color: Colors.grey[300]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── event detail sheet ────────────────────────────────────────────────────

  void _showEventDetail(AuditLogEntry entry) async {
    final detail = await _ctrl.getEventDetail(entry.auditId);
    if (detail == null) return;

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _actionColor(detail.action).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_actionIcon(detail.action), color: _actionColor(detail.action), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(detail.action,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Audit ID #${detail.auditId}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: Get.back),
                ],
              ),
            ),
            const Divider(),
            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('Entity Type', detail.entityType),
                    if (detail.entityId != null) _detailRow('Entity ID', '#${detail.entityId}'),
                    _detailRow('Actor', detail.actor?.username ?? 'System'),
                    _detailRow('Role', detail.actor?.role ?? '—'),
                    _detailRow('IP Address', detail.ipAddress ?? '—'),
                    _detailRow('User Agent', detail.userAgent ?? '—'),
                    _detailRow('Timestamp', _formatTimestampFull(detail.timestamp)),
                    const SizedBox(height: 14),
                    if (detail.diff != null && detail.diff!.isNotEmpty) ...[
                      const Text('Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: detail.diff!.entries.map((e) {
                            return _diffRow(e.key, e.value.before, e.value.after);
                          }).toList(),
                        ),
                      ),
                    ] else if (detail.newValue != null) ...[
                      const Text('Payload', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      _jsonBox(detail.newValue),
                    ],
                    if (detail.oldValue != null && detail.diff == null) ...[
                      const SizedBox(height: 12),
                      const Text('Previous State', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      _jsonBox(detail.oldValue),
                    ],
                  ],
                ),
              ),
            ),
            // Footer actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Get.back();
                        _showEntityHistory(detail.entityType, detail.entityId ?? 0);
                      },
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('View Entity History'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _blueColor.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _diffRow(String field, dynamic before, dynamic after) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(6)),
                  child: Text('- ${_truncate(before)}',
                      style: TextStyle(fontSize: 11, color: Colors.red[700], fontFamily: 'monospace')),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6)),
                  child: Text('+ ${_truncate(after)}',
                      style: TextStyle(fontSize: 11, color: Colors.green[700], fontFamily: 'monospace')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _jsonBox(dynamic value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        value is Map || value is List ? value.toString() : value.toString(),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        maxLines: 20,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── entity history sheet ──────────────────────────────────────────────────

  void _showEntityHistory(String entityType, int entityId) async {
    await _ctrl.getEntityHistory(entityType, entityId);

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 640,
          height: MediaQuery.of(Get.context!).size.height * 0.75,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_blueColor, Color(0xFF5DADE2)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${entityType.capitalizeFirst ?? entityType} History',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Entity #$entityId',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: Get.back),
                  ],
                ),
              ),
              // List
              Expanded(
                child: Obx(() {
                  final h = _ctrl.entityHistory.value;
                  if (h == null) return const Center(child: CircularProgressIndicator(color: _blueColor));
                  if (h.history.isEmpty) return const Center(child: Text('No events found for this entity'));
                  return ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: h.history.length,
                    itemBuilder: (_, i) => _buildEventTile(h.history[i]),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── pagination bar ────────────────────────────────────────────────────────

  Widget _buildPaginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Obx(() => Row(
            children: [
              Text(
                'Page ${_ctrl.currentPage.value} of ${_ctrl.totalPages.value}  '
                '(${_ctrl.totalEvents.value} events)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.first_page),
                color: Colors.grey[600],
                tooltip: 'First page',
                onPressed: _ctrl.currentPage.value > 1 && !_ctrl.isLoading.value
                    ? () => _ctrl.getLogs(page: 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: Colors.grey[600],
                tooltip: 'Previous',
                onPressed: _ctrl.currentPage.value > 1 && !_ctrl.isLoading.value
                    ? _ctrl.loadPreviousPage
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _blueColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_ctrl.currentPage.value}',
                  style: const TextStyle(color: _blueColor, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: Colors.grey[600],
                tooltip: 'Next',
                onPressed: _ctrl.currentPage.value < _ctrl.totalPages.value && !_ctrl.isLoading.value
                    ? _ctrl.loadNextPage
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                color: Colors.grey[600],
                tooltip: 'Last page',
                onPressed: _ctrl.currentPage.value < _ctrl.totalPages.value && !_ctrl.isLoading.value
                    ? () => _ctrl.getLogs(page: _ctrl.totalPages.value)
                    : null,
              ),
            ],
          )),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2 — SUMMARY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSummaryTab() {
    return Obx(() {
      if (_ctrl.isLoading.value && _ctrl.summary.value == null) {
        return const Center(child: CircularProgressIndicator(color: _blueColor));
      }
      final s = _ctrl.summary.value;
      if (s == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text('No summary data available', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _ctrl.getSummary,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Load Summary', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: _blueColor, elevation: 0),
              ),
            ],
          ),
        );
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top actors
            _sectionCard(
              icon: Icons.people_outline,
              title: 'Top Actors',
              child: s.topActors.isEmpty
                  ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
                  : Column(
                      children: s.topActors.asMap().entries.map((entry) {
                        final idx   = entry.key;
                        final actor = entry.value;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: _blueColor.withOpacity(0.12),
                            child: Text('${idx + 1}',
                                style: const TextStyle(color: _blueColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          title: Text(actor.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(actor.role.capitalizeFirst ?? actor.role,
                              style: const TextStyle(fontSize: 12)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _blueColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${actor.eventCount} events',
                                style: const TextStyle(color: _blueColor, fontWeight: FontWeight.w600, fontSize: 12)),
                          ),
                          dense: true,
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 16),

            // Action breakdown
            _sectionCard(
              icon: Icons.bolt_outlined,
              title: 'Actions Breakdown',
              child: s.actionBreakdown.isEmpty
                  ? const Text('No data', style: TextStyle(color: Colors.grey))
                  : _buildBreakdownList(s.actionBreakdown, (k) => _actionBadge(k, _actionColor(k))),
            ),
            const SizedBox(height: 16),

            // Entity breakdown
            _sectionCard(
              icon: Icons.category_outlined,
              title: 'Entity Types',
              child: s.entityBreakdown.isEmpty
                  ? const Text('No data', style: TextStyle(color: Colors.grey))
                  : _buildBreakdownList(s.entityBreakdown, (k) => _entityBadge(k)),
            ),
            const SizedBox(height: 16),

            // Daily volume sparkline (text-based)
            if (s.dailyVolume.isNotEmpty)
              _sectionCard(
                icon: Icons.show_chart,
                title: 'Daily Event Volume',
                child: _buildDailyVolumeChart(s.dailyVolume),
              ),
          ],
        ),
      );
    });
  }

  Widget _sectionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _blueColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: _blueColor, size: 18),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _accentColor)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildBreakdownList(Map<String, int> data, Widget Function(String) labelBuilder) {
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max    = sorted.isNotEmpty ? sorted.first.value : 1;

    return Column(
      children: sorted.map((e) {
        final pct = e.value / max;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 160, child: labelBuilder(e.key)),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    color: _blueColor.withOpacity(0.6 + pct * 0.4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 40,
                child: Text('${e.value}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDailyVolumeChart(List<AuditDailyVolume> volume) {
    final max = volume.map((v) => v.eventCount).reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: volume.map((v) {
          final height = max == 0 ? 0.0 : (v.eventCount / max) * 100.0;
          final isToday = v.day == DateFormat('yyyy-MM-dd').format(DateTime.now());
          return Expanded(
            child: Tooltip(
              message: '${v.day}: ${v.eventCount} events',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: height,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isToday ? Colors.orange : _blueColor.withOpacity(0.65),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    v.day.substring(8), // day-of-month
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3 — EXPORT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Format selector
          _sectionCard(
            icon: Icons.file_download_outlined,
            title: 'Export Format',
            child: Column(
              children: [
                _formatTile('csv',   Icons.table_rows_outlined,       'CSV',        'Comma-separated — opens in Excel / Google Sheets', Colors.green),
                _formatTile('excel', Icons.table_chart_outlined,       'Excel',      'Native .xlsx workbook with formatted sheet',        const Color(0xFF1D6F42)),
                _formatTile('json',  Icons.data_object_outlined,       'JSON',       'Full structured JSON with metadata envelope',       Colors.blue),
                _formatTile('pdf',   Icons.picture_as_pdf_outlined,    'PDF / Print','Formatted A4 report ready for printing / sharing', Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filters for export
          _sectionCard(
            icon: Icons.filter_list,
            title: 'Scope & Filters (optional)',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _filterEntityType,
                  isExpanded: true,
                  decoration: _filterDecoration('Entity Type', Icons.category_outlined),
                  items: List.generate(_kEntityTypes.length, (i) =>
                      DropdownMenuItem(value: _kEntityTypes[i], child: Text(_kEntityLabels[i]))),
                  onChanged: (v) => setState(() => _filterEntityType = v ?? ''),
                ),
                const SizedBox(height: 10),
                _filterField('Action Contains', Icons.bolt, _actionCtrl),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _dateField('Date From', _dateFromCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _dateField('Date To', _dateToCtrl)),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _exportLimit,
                  decoration: _filterDecoration('Max Rows', Icons.numbers),
                  items: [1000, 2000, 5000, 10000, 25000, 50000]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n rows')))
                      .toList(),
                  onChanged: (v) => setState(() => _exportLimit = v ?? 5000),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Generate button
          SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton.icon(
                  onPressed: _ctrl.isExporting.value ? null : _doExport,
                  icon: _ctrl.isExporting.value
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download, color: Colors.white),
                  label: Text(
                    _ctrl.isExporting.value ? 'Exporting…' : 'Export ${_exportFormat.toUpperCase()}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blueColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )),
          ),
          const SizedBox(height: 8),
          Text(
            'Admin access required for all export operations.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _formatTile(String value, IconData icon, String label, String desc, Color color) {
    final sel = _exportFormat == value;
    return GestureDetector(
      onTap: () => setState(() => _exportFormat = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.08) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? color : Colors.grey.shade200,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: sel ? color : _accentColor)),
                  Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            if (sel)
              Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXPORT ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  AuditExportRequest get _exportRequest => AuditExportRequest(
        action:     _actionCtrl.text.isEmpty ? null : _actionCtrl.text,
        entityType: _filterEntityType.isEmpty ? null : _filterEntityType,
        dateFrom:   _dateFromCtrl.text.isEmpty ? null : _dateFromCtrl.text,
        dateTo:     _dateToCtrl.text.isEmpty ? null : _dateToCtrl.text,
        limit:      _exportLimit,
      );

  Future<void> _doExport() async {
    switch (_exportFormat) {
      case 'csv':   await _exportCsv();   break;
      case 'excel': await _exportExcel(); break;
      case 'json':  await _exportJson();  break;
      case 'pdf':   await _exportPdf();   break;
    }
  }

  Future<void> _exportCsv() async {
    final csv = await _ctrl.exportCsv(_exportRequest);
    if (csv == null) return;
    await _saveText(csv, 'audit_log_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv', 'text/csv');
  }

  Future<void> _exportJson() async {
    final data = await _ctrl.exportJson(_exportRequest);
    if (data == null) return;
    await _saveText(data.toString(), 'audit_log_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json', 'application/json');
  }

  Future<void> _exportExcel() async {
    // Get CSV then convert to Excel in-app for rich formatting
    final csv = await _ctrl.exportCsv(_exportRequest);
    if (csv == null) return;

    final excel   = exl.Excel.createExcel();
    final sheet   = excel['Audit Log'];
    final lines   = csv.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final cells = _parseCsvLine(line);
      sheet.appendRow(cells.map((c) => exl.TextCellValue(c)).toList());
    }

    final bytes    = excel.encode();
    if (bytes == null) return;
    final fileName = 'audit_log_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (Platform.isWindows) {
      final dir = await getDownloadsDirectory();
      if (dir == null) return;
      await File('${dir.path}/$fileName').writeAsBytes(bytes);
      await OpenFile.open(dir.path);
      Get.snackbar('Saved', 'Excel saved: $fileName', backgroundColor: Colors.green, colorText: Colors.white);
    } else {
      final tmp = await getTemporaryDirectory();
      final f   = File('${tmp.path}/$fileName');
      await f.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: 'Audit Log Excel Export'));
    }
  }

  Future<void> _exportPdf() async {
    final csv = await _ctrl.exportCsv(_exportRequest);
    if (csv == null) return;

    final lines   = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;

    final headers = _parseCsvLine(lines.first);
    final rows    = lines.skip(1).map(_parseCsvLine).toList();

    final pdf      = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    final ttf      = pw.Font.ttf(fontData);
    final ttfBold  = pw.Font.ttf(boldData);

    pw.ImageProvider? logo;
    try {
      final d = await rootBundle.load('assets/logo/logo.jpeg');
      logo    = pw.MemoryImage(d.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(children: [
                  if (logo != null) pw.Container(width: 48, height: 48, child: pw.Image(logo)),
                  pw.SizedBox(width: 12),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Docsecure Eswatini (Pty) Ltd',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.Text('Audit Log Export — PSMS ®',
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ]),
                ]),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 8),
              ])
            : pw.SizedBox(),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
            cellStyle: pw.TextStyle(fontSize: 6.5),
            cellHeight: 20,
          ),
        ],
      ),
    );

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: MediaQuery.of(Get.context!).size.width * 0.85,
          height: MediaQuery.of(Get.context!).size.height * 0.85,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                color: Colors.red[50],
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red[700]),
                    const SizedBox(width: 10),
                    const Text('Audit Log — PDF Preview',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: Get.back),
                  ],
                ),
              ),
              Expanded(
                child: PdfPreview(
                  build: (_) async => pdf.save(),
                  allowSharing: true,
                  allowPrinting: true,
                  pdfFileName: 'audit_log_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: Get.back, child: const Text('Close')),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Get.back();
                        final bytes = await pdf.save();
                        final name  = 'audit_log_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
                        if (Platform.isWindows) {
                          final dir = await getDownloadsDirectory();
                          if (dir == null) return;
                          await File('${dir.path}/$name').writeAsBytes(bytes);
                          await OpenFile.open(dir.path);
                        } else {
                          final tmp = await getTemporaryDirectory();
                          final f   = File('${tmp.path}/$name');
                          await f.writeAsBytes(bytes);
                          await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
                        }
                      },
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text('Save', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], elevation: 0),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        Printing.layoutPdf(onLayout: (_) async => pdf.save());
                      },
                      icon: const Icon(Icons.print, color: Colors.white),
                      label: const Text('Print', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: _accentColor, elevation: 0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _saveText(String content, String fileName, String mimeType) async {
    if (Platform.isWindows) {
      final dir = await getDownloadsDirectory();
      if (dir == null) return;
      await File('${dir.path}/$fileName').writeAsString(content);
      await OpenFile.open(dir.path);
      Get.snackbar('Saved', 'File saved: $fileName', backgroundColor: Colors.green, colorText: Colors.white);
    } else {
      final tmp = await getTemporaryDirectory();
      final f   = File('${tmp.path}/$fileName');
      await f.writeAsString(content);
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
    }
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var cur      = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        result.add(cur.toString());
        cur = StringBuffer();
      } else {
        cur.write(c);
      }
    }
    result.add(cur.toString());
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTER HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _applyFilters() async {
    await _ctrl.applyFilters(
      search:     _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
      action:     _actionCtrl.text.isEmpty ? null : _actionCtrl.text,
      userId:     _userIdCtrl.text.isEmpty ? null : _userIdCtrl.text,
      entityType: _filterEntityType.isEmpty ? null : _filterEntityType,
      entityId:   _entityIdCtrl.text.isEmpty ? null : _entityIdCtrl.text,
      ipAddress:  _ipCtrl.text.isEmpty ? null : _ipCtrl.text,
      dateFrom:   _dateFromCtrl.text.isEmpty ? null : _dateFromCtrl.text,
      dateTo:     _dateToCtrl.text.isEmpty ? null : _dateToCtrl.text,
      sort:       _ctrl.sortOrder.value,
    );
  }

  void _clearFilters() {
    _searchCtrl.clear();
    _actionCtrl.clear();
    _userIdCtrl.clear();
    _entityIdCtrl.clear();
    _ipCtrl.clear();
    _dateFromCtrl.clear();
    _dateToCtrl.clear();
    setState(() => _filterEntityType = '');
    _ctrl.clearFilters();
    _ctrl.getLogs(refresh: true);
  }

  void _clearField(TextEditingController ctrl, VoidCallback onClear) {
    ctrl.clear();
    onClear();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VISUAL HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _actionBadge(String action, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        action,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    );
  }

  Widget _entityBadge(String type) {
    final color = _entityColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(type, style: TextStyle(color: color, fontSize: 10)),
    );
  }

  Color _actionColor(String action) {
    if (action.contains('LOGIN') || action.contains('LOGOUT')) return Colors.teal;
    if (action.contains('CREATE')) return Colors.green;
    if (action.contains('UPDATE') || action.contains('CHANGE')) return Colors.blue;
    if (action.contains('DELETE') || action.contains('DESTROY')) return Colors.red;
    if (action.contains('GENERATE') || action.contains('REPORT')) return Colors.purple;
    if (action.contains('BULK')) return Colors.orange;
    return Colors.grey;
  }

  IconData _actionIcon(String action) {
    if (action.contains('LOGIN'))    return Icons.login;
    if (action.contains('LOGOUT'))   return Icons.logout;
    if (action.contains('CREATE'))   return Icons.add_circle_outline;
    if (action.contains('UPDATE'))   return Icons.edit_outlined;
    if (action.contains('DELETE'))   return Icons.delete_outline;
    if (action.contains('DESTROY'))  return Icons.delete_forever;
    if (action.contains('GENERATE')) return Icons.assessment_outlined;
    if (action.contains('BULK'))     return Icons.select_all;
    if (action.contains('CHANGE'))   return Icons.swap_horiz;
    return Icons.circle_outlined;
  }

  Color _entityColor(String type) {
    switch (type) {
      case 'box':              return const Color(0xFF3498DB);
      case 'user':             return const Color(0xFF8E44AD);
      case 'collection':       return const Color(0xFF27AE60);
      case 'retrieval':        return const Color(0xFF2980B9);
      case 'delivery':         return const Color(0xFFE67E22);
      case 'auth':             return const Color(0xFF16A085);
      case 'report':           return const Color(0xFF8E44AD);
      case 'permissions':      return const Color(0xFFE74C3C);
      case 'storage_location': return const Color(0xFF7F8C8D);
      default:                 return Colors.grey;
    }
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inHours < 1)    return '${diff.inMinutes}m ago';
      if (diff.inDays < 1)     return '${diff.inHours}h ago';
      if (diff.inDays < 7)     return '${diff.inDays}d ago';
      return DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {
      return ts;
    }
  }

  String _formatTimestampFull(String ts) {
    try {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(ts).toLocal());
    } catch (_) {
      return ts;
    }
  }

  String _truncate(dynamic value, {int max = 80}) {
    if (value == null) return 'null';
    final s = value.toString();
    return s.length > max ? '${s.substring(0, max)}…' : s;
  }
}