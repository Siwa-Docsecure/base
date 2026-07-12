// report_management_screen.dart
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
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/box_controller.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/controllers/report_controller.dart';
import 'package:psms/controllers/storage_controller.dart';
import 'package:psms/models/report_models_module.dart';
import 'package:share_plus/share_plus.dart';
import 'package:psms/screens/warehouse/boxes/widgets/client_search_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL: one tab / report-type descriptor
// ─────────────────────────────────────────────────────────────────────────────

class _ReportType {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String description;

  const _ReportType({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });
}

const _reportTypes = [
  _ReportType(
    id: 'boxes',
    label: 'Boxes',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFF3498DB),
    description: 'Box inventory by client, status and location',
  ),
  _ReportType(
    id: 'collections',
    label: 'Collections',
    icon: Icons.local_shipping_outlined,
    color: Color(0xFF27AE60),
    description: 'Box collection events and totals',
  ),
  _ReportType(
    id: 'retrievals',
    label: 'Retrievals',
    icon: Icons.move_to_inbox_outlined,
    color: Color(0xFF8E44AD),
    description: 'Box retrieval events and signature status',
  ),
  _ReportType(
    id: 'deliveries',
    label: 'Deliveries',
    icon: Icons.outbox_outlined,
    color: Color(0xFFE67E22),
    description: 'Item delivery records and quantities',
  ),
  _ReportType(
    id: 'requests',
    label: 'Requests',
    icon: Icons.assignment_outlined,
    color: Color(0xFFE74C3C),
    description: 'Client service requests by type and status',
  ),
  _ReportType(
    id: 'storage',
    label: 'Storage',
    icon: Icons.warehouse_outlined,
    color: Color(0xFF16A085),
    description: 'Rack utilisation and capacity overview',
  ),
  _ReportType(
    id: 'destruction',
    label: 'Destruction',
    icon: Icons.warning_amber_outlined,
    color: Color(0xFFC0392B),
    description: 'Boxes overdue for scheduled destruction',
  ),
  _ReportType(
    id: 'client_activity',
    label: 'Client Activity',
    icon: Icons.person_search_outlined,
    color: Color(0xFF2980B9),
    description: 'Full 360° activity summary per client',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ReportManagementScreen extends StatefulWidget {
  const ReportManagementScreen({super.key});

  @override
  State<ReportManagementScreen> createState() => _ReportManagementScreenState();
}

class _ReportManagementScreenState extends State<ReportManagementScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final ReportController _reportCtrl = Get.put(ReportController());
  final BoxController _boxCtrl = Get.put(BoxController());
  final StorageController _storageCtrl = Get.put(StorageController());
  final AuthController _authCtrl = Get.find<AuthController>();
  // Dedicated client source for the filter pickers, instead of
  // BoxController's own client cache. Lazy getter so it can never throw
  // a LateInitializationError.
  ClientManagementController? _clientCtrl;
  ClientManagementController get clientCtrl {
    if (_clientCtrl == null) {
      _clientCtrl = Get.isRegistered<ClientManagementController>()
          ? Get.find<ClientManagementController>()
          : Get.put(ClientManagementController());
    }
    return _clientCtrl!;
  }

  late TabController _tabController;

  // Active report type index
  int _activeTypeIndex = 0;

  // Generated data (held per-session)
  dynamic _generatedData; // any report data model
  String _generatedFormat = ''; // 'pdf' | 'excel' | 'preview'

  // ── common filter state ──────────────────────────────────────────────────
  int? _filterClientId;
  List<int> _filterClientIds = [];
  String _filterStatus = '';
  int _filterRackLabelId = 0;
  String _filterSearch = '';
  String _filterDateFrom = '';
  String _filterDateTo = '';
  int? _filterDestrYearFrom;
  int? _filterDestrYearTo;
  int? _filterRetentionYears;
  String _filterRequestType = '';
  String _filterItemName = '';
  bool _grouped = false;
  bool _includeStats = true;
  bool _showFilters = false;

  // text controllers for date / year fields
  final _dateFromCtrl = TextEditingController();
  final _dateToCtrl = TextEditingController();
  final _destrFromCtrl = TextEditingController();
  final _destrToCtrl = TextEditingController();
  final _retentionCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _itemNameCtrl = TextEditingController();

  // view mode for result table
  int _viewMode = 0; // 0 = table, 1 = grid

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _reportTypes.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTypeIndex = _tabController.index;
          _clearFilterState();
          _generatedData = null;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClients();
      _storageCtrl.initialize();
    });
  }

  Future<void> _loadClients() async {
    // fetchClients() is paginated (20/page by default) — bump the page
    // size so this one call returns every client for the filter pickers.
    clientCtrl.itemsPerPage.value = 1000;
    await clientCtrl.fetchClients(showLoading: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dateFromCtrl.dispose();
    _dateToCtrl.dispose();
    _destrFromCtrl.dispose();
    _destrToCtrl.dispose();
    _retentionCtrl.dispose();
    _searchCtrl.dispose();
    _itemNameCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  _ReportType get _active => _reportTypes[_activeTypeIndex];

  void _clearFilterState() {
    _filterClientId = null;
    _filterClientIds = [];
    _filterStatus = '';
    _filterRackLabelId = 0;
    _filterSearch = '';
    _filterDateFrom = '';
    _filterDateTo = '';
    _filterDestrYearFrom = null;
    _filterDestrYearTo = null;
    _filterRetentionYears = null;
    _filterRequestType = '';
    _filterItemName = '';
    _grouped = false;
    _includeStats = true;
    _dateFromCtrl.clear();
    _dateToCtrl.clear();
    _destrFromCtrl.clear();
    _destrToCtrl.clear();
    _retentionCtrl.clear();
    _searchCtrl.clear();
    _itemNameCtrl.clear();
  }

  Future<void> _pickDate(TextEditingController ctrl, ValueSetter<String> onPick) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      final fmt = DateFormat('yyyy-MM-dd').format(date);
      ctrl.text = fmt;
      onPick(fmt);
    }
  }

  Color get _accent => _active.color;

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
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
              color: _accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.assessment_outlined, color: _accent, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Report Management',
                style: TextStyle(
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                ),
              ),
              Text(
                _active.description,
                style: const TextStyle(
                  color: Color(0xFF7F8C8D),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            color: _showFilters ? _accent : const Color(0xFF2C3E50),
          ),
          tooltip: 'Toggle Filters',
          onPressed: () => setState(() => _showFilters = !_showFilters),
        ),
        IconButton(
          icon: Icon(
            _viewMode == 0 ? Icons.grid_view : Icons.table_chart,
            color: const Color(0xFF2C3E50),
          ),
          tooltip: 'Toggle View',
          onPressed: () => setState(() => _viewMode = _viewMode == 0 ? 1 : 0),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF2C3E50)),
          tooltip: 'Refresh',
          onPressed: () {
            _loadClients();
            _storageCtrl.initialize();
            setState(() => _generatedData = null);
          },
        ),
        if (_generatedData != null) ...[
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: const Color(0xFFC0392B)),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: Icon(Icons.table_chart, color: const Color(0xFF27AE60)),
            tooltip: 'Export Excel',
            onPressed: _exportExcel,
          ),
        ],
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: _buildTabBar(),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: _accent,
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: _accent,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: _reportTypes
            .map((t) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 16),
                      const SizedBox(width: 6),
                      Text(t.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── layouts ──────────────────────────────────────────────────────────────

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left panel — filters + generate
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: _showFilters ? 320 : 0,
          child: _showFilters
              ? _buildFilterPanel()
              : const SizedBox.shrink(),
        ),
        // Right panel — results
        Expanded(child: _buildResultsPanel()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        if (_showFilters) _buildFilterPanel(),
        Expanded(child: _buildResultsPanel()),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTER PANEL
  // ─────────────────────────────────────────────────────────────────────────

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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_accent, _accent.withOpacity(0.75)]),
            ),
            child: Row(
              children: [
                Icon(Icons.tune, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Filters & Options',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(_clearFilterState),
                  child: const Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
          ),
          // Scrollable filter body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildFilterCard('Client', Icons.business, _buildClientFilter()),
                  if (_active.id == 'boxes') ...[
                    const SizedBox(height: 12),
                    _buildFilterCard('Status', Icons.label_outline, _buildStatusFilter()),
                    const SizedBox(height: 12),
                    _buildFilterCard('Location', Icons.location_on_outlined, _buildRackFilter()),
                    const SizedBox(height: 12),
                    _buildFilterCard('Date Received', Icons.calendar_today_outlined, _buildDateRangeFilter()),
                    const SizedBox(height: 12),
                    _buildFilterCard('Destruction Year', Icons.timer_off_outlined, _buildDestrYearFilter()),
                    const SizedBox(height: 12),
                    _buildFilterCard('Retention', Icons.lock_clock_outlined, _buildRetentionFilter()),
                    const SizedBox(height: 12),
                    _buildFilterCard('View', Icons.view_agenda_outlined, _buildBoxViewOptions()),
                  ],
                  if (_active.id == 'collections' || _active.id == 'retrievals' || _active.id == 'deliveries' || _active.id == 'requests') ...[
                    const SizedBox(height: 12),
                    _buildFilterCard('Date Range', Icons.calendar_today_outlined, _buildDateRangeFilter()),
                  ],
                  if (_active.id == 'retrievals') ...[
                    const SizedBox(height: 12),
                    _buildFilterCard('Status', Icons.label_outline, _buildRetrievalStatusFilter()),
                  ],
                  if (_active.id == 'requests') ...[
                    const SizedBox(height: 12),
                    _buildFilterCard('Request Type', Icons.category_outlined, _buildRequestTypeFilter()),
                    const SizedBox(height: 12),
                    _buildFilterCard('Status', Icons.label_outline, _buildRequestStatusFilter()),
                  ],
                  if (_active.id == 'deliveries') ...[
                    const SizedBox(height: 12),
                    _buildFilterCard('Item Name', Icons.inventory_outlined, _buildItemNameFilter()),
                  ],
                  if (_active.id == 'destruction') ...[
                    const SizedBox(height: 12),
                    _buildFilterCard('Client Filter', Icons.business, _buildSingleClientFilter()),
                  ],
                  if (_active.id == 'client_activity') ...[
                    const SizedBox(height: 12),
                    _buildFilterCard('Client (Required)', Icons.person_outlined, _buildSingleClientFilter()),
                  ],
                  const SizedBox(height: 12),
                  _buildFilterCard('Options', Icons.settings_outlined, _buildOptions()),
                  const SizedBox(height: 20),
                  // GENERATE BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: Obx(() => ElevatedButton.icon(
                      onPressed: _reportCtrl.isLoading.value ? null : _generate,
                      icon: _reportCtrl.isLoading.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.play_arrow, color: Colors.white),
                      label: Text(
                        _reportCtrl.isLoading.value ? 'Generating…' : 'Generate Report',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    )),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(String title, IconData icon, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 15, color: _accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  // ── filter sub-widgets ────────────────────────────────────────────────────

  Widget _buildClientFilter() {
    // multi-select for box bulk, single for others
    if (_active.id == 'boxes') {
      return Obx(() => ClientMultiSelectField(
            clients: clientCtrl.clients,
            selectedClientIds: _filterClientIds,
            isLoading: clientCtrl.isLoading.value,
            label: 'Clients',
            emptyLabel: 'All Clients (optional)',
            onChanged: (ids) => setState(() => _filterClientIds = ids),
          ));
    }
    return _buildSingleClientFilter();
  }

  Widget _buildSingleClientFilter() {
    return Obx(() => ClientSearchField(
          clients: clientCtrl.clients,
          selectedClientId: _filterClientId,
          isLoading: clientCtrl.isLoading.value,
          allOptionLabel: 'All Clients',
          label: 'Client',
          onChanged: (v) => setState(() => _filterClientId = v),
        ));
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String>(
      value: _filterStatus.isEmpty ? null : _filterStatus,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: '', child: Text('All')),
        DropdownMenuItem(value: 'stored', child: Text('Stored')),
        DropdownMenuItem(value: 'retrieved', child: Text('Retrieved')),
        DropdownMenuItem(value: 'destroyed', child: Text('Destroyed')),
      ],
      onChanged: (v) => setState(() => _filterStatus = v ?? ''),
    );
  }

  Widget _buildRetrievalStatusFilter() {
    return DropdownButtonFormField<String>(
      value: _filterStatus.isEmpty ? null : _filterStatus,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: '', child: Text('All')),
        DropdownMenuItem(value: 'pending', child: Text('Pending')),
        DropdownMenuItem(value: 'completed', child: Text('Completed')),
        DropdownMenuItem(value: 'retrieved', child: Text('Retrieved')),
      ],
      onChanged: (v) => setState(() => _filterStatus = v ?? ''),
    );
  }

  Widget _buildRequestTypeFilter() {
    return DropdownButtonFormField<String>(
      value: _filterRequestType.isEmpty ? null : _filterRequestType,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: '', child: Text('All Types')),
        DropdownMenuItem(value: 'retrieval', child: Text('Retrieval')),
        DropdownMenuItem(value: 'destruction', child: Text('Destruction')),
        DropdownMenuItem(value: 'collection', child: Text('Collection')),
      ],
      onChanged: (v) => setState(() => _filterRequestType = v ?? ''),
    );
  }

  Widget _buildRequestStatusFilter() {
    return DropdownButtonFormField<String>(
      value: _filterStatus.isEmpty ? null : _filterStatus,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: '', child: Text('All')),
        DropdownMenuItem(value: 'pending', child: Text('Pending')),
        DropdownMenuItem(value: 'approved', child: Text('Approved')),
        DropdownMenuItem(value: 'completed', child: Text('Completed')),
        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
      ],
      onChanged: (v) => setState(() => _filterStatus = v ?? ''),
    );
  }

  Widget _buildRackFilter() {
    return Obx(() => DropdownButtonFormField<int>(
          value: _filterRackLabelId == 0 ? 0 : _filterRackLabelId,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: 0, child: Text('Any Location')),
            ..._storageCtrl.storageLocations.map((l) => DropdownMenuItem(
                  value: l.labelId,
                  child: Text('${l.labelCode} — ${l.locationDescription}', overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: (v) => setState(() => _filterRackLabelId = v ?? 0),
        ));
  }

  Widget _buildDateRangeFilter() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _dateFromCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'From',
              isDense: true,
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today, size: 16),
            ),
            onTap: () => _pickDate(_dateFromCtrl, (v) => setState(() => _filterDateFrom = v)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _dateToCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'To',
              isDense: true,
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today, size: 16),
            ),
            onTap: () => _pickDate(_dateToCtrl, (v) => setState(() => _filterDateTo = v)),
          ),
        ),
      ],
    );
  }

  Widget _buildDestrYearFilter() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _destrFromCtrl,
            decoration: const InputDecoration(
              labelText: 'From Year',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => _filterDestrYearFrom = int.tryParse(v)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _destrToCtrl,
            decoration: const InputDecoration(
              labelText: 'To Year',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => _filterDestrYearTo = int.tryParse(v)),
          ),
        ),
      ],
    );
  }

  Widget _buildRetentionFilter() {
    return TextFormField(
      controller: _retentionCtrl,
      decoration: const InputDecoration(
        labelText: 'Retention Years (exact)',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) => setState(() => _filterRetentionYears = int.tryParse(v)),
    );
  }

  Widget _buildItemNameFilter() {
    return TextFormField(
      controller: _itemNameCtrl,
      decoration: const InputDecoration(
        labelText: 'Item Name',
        isDense: true,
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.search, size: 18),
      ),
      onChanged: (v) => setState(() => _filterItemName = v),
    );
  }

  Widget _buildBoxViewOptions() {
    return Column(
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Group by Client', style: TextStyle(fontSize: 13)),
          value: _grouped,
          activeColor: _accent,
          onChanged: (v) => setState(() => _grouped = v),
        ),
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            labelText: 'Search (box # / description)',
            isDense: true,
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search, size: 18),
          ),
          onChanged: (v) => setState(() => _filterSearch = v),
        ),
      ],
    );
  }

  Widget _buildOptions() {
    return Column(
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Include Summary Stats', style: TextStyle(fontSize: 13)),
          value: _includeStats,
          activeColor: _accent,
          onChanged: (v) => setState(() => _includeStats = v),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESULTS PANEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildResultsPanel() {
    return Column(
      children: [
        // Quick-action bar
        _buildQuickActionBar(),
        // Content
        Expanded(
          child: _generatedData == null
              ? _buildWelcomeState()
              : _buildDataView(),
        ),
      ],
    );
  }

  Widget _buildQuickActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_active.icon, size: 14, color: _accent),
                const SizedBox(width: 6),
                Text(
                  _active.label,
                  style: TextStyle(color: _accent, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!_showFilters)
            Obx(() => ElevatedButton.icon(
                  onPressed: _reportCtrl.isLoading.value ? null : _generate,
                  icon: _reportCtrl.isLoading.value
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                  label: const Text('Generate', style: TextStyle(color: Colors.white, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )),
          const Spacer(),
          if (_generatedData != null) ...[
            _exportButton(
              icon: Icons.picture_as_pdf,
              label: 'PDF',
              color: const Color(0xFFC0392B),
              onTap: _exportPdf,
            ),
            const SizedBox(width: 8),
            _exportButton(
              icon: Icons.table_chart,
              label: 'Excel',
              color: const Color(0xFF27AE60),
              onTap: _exportExcel,
            ),
            const SizedBox(width: 8),
            _exportButton(
              icon: Icons.print,
              label: 'Print',
              color: const Color(0xFF2C3E50),
              onTap: _printReport,
            ),
          ],
        ],
      ),
    );
  }

  Widget _exportButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(_active.icon, size: 56, color: _accent.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          Text(
            'Generate a ${_active.label} Report',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(height: 8),
          Text(
            _active.description,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showFilters = true),
            icon: const Icon(Icons.tune, color: Colors.white),
            label: const Text('Configure & Generate', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA VIEW — dispatches to specific renderers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDataView() {
    return Obx(() {
      if (_reportCtrl.isLoading.value) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _accent),
              const SizedBox(height: 16),
              const Text('Generating report…', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }

      final data = _generatedData;
      if (data == null) return _buildWelcomeState();

      switch (_active.id) {
        case 'boxes':
          if (data is GroupedBoxReportData) return _buildGroupedBoxesView(data);
          if (data is BoxReportData)         return _buildFlatBoxesView(data);
          return _buildWelcomeState();
        case 'collections':
          return _buildCollectionsView(data as CollectionReportData);
        case 'retrievals':
          return _buildRetrievalsView(data as RetrievalReportData);
        case 'deliveries':
          return _buildDeliveriesView(data as DeliveryReportData);
        case 'requests':
          return _buildRequestsView(data as RequestReportData);
        case 'storage':
          return _buildStorageView(data as StorageUtilisationData);
        case 'destruction':
          return _buildDestructionView(data as PendingDestructionData);
        case 'client_activity':
          return _buildClientActivityView(data as ClientActivityData);
        default:
          return const SizedBox.shrink();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GENERATE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _generate() async {
    setState(() => _generatedData = null);

    switch (_active.id) {
      case 'boxes':
        await _reportCtrl.getBoxReport(
          clientIds: _filterClientIds.isEmpty ? null : _filterClientIds,
          status: _filterStatus.isEmpty ? null : _filterStatus,
          rackingLabelId: _filterRackLabelId == 0 ? null : _filterRackLabelId,
          search: _filterSearch.isEmpty ? null : _filterSearch,
          dateFrom: _filterDateFrom.isEmpty ? null : _filterDateFrom,
          dateTo: _filterDateTo.isEmpty ? null : _filterDateTo,
          destructionYearFrom: _filterDestrYearFrom,
          destructionYearTo: _filterDestrYearTo,
          retentionYears: _filterRetentionYears,
          grouped: _grouped,
          includeStats: _includeStats,
        );
        final d = _grouped ? _reportCtrl.groupedBoxReport.value : _reportCtrl.boxReport.value;
        if (d != null) setState(() => _generatedData = d);
        break;

      case 'collections':
        await _reportCtrl.getCollectionsReport(
          clientId: _filterClientId,
          dateFrom: _filterDateFrom.isEmpty ? null : _filterDateFrom,
          dateTo: _filterDateTo.isEmpty ? null : _filterDateTo,
          includeStats: _includeStats,
        );
        if (_reportCtrl.collectionReport.value != null) {
          setState(() => _generatedData = _reportCtrl.collectionReport.value);
        }
        break;

      case 'retrievals':
        await _reportCtrl.getRetrievalsReport(
          clientId: _filterClientId,
          status: _filterStatus.isEmpty ? null : _filterStatus,
          dateFrom: _filterDateFrom.isEmpty ? null : _filterDateFrom,
          dateTo: _filterDateTo.isEmpty ? null : _filterDateTo,
          includeStats: _includeStats,
        );
        if (_reportCtrl.retrievalReport.value != null) {
          setState(() => _generatedData = _reportCtrl.retrievalReport.value);
        }
        break;

      case 'deliveries':
        await _reportCtrl.getDeliveriesReport(
          clientId: _filterClientId,
          dateFrom: _filterDateFrom.isEmpty ? null : _filterDateFrom,
          dateTo: _filterDateTo.isEmpty ? null : _filterDateTo,
          itemName: _filterItemName.isEmpty ? null : _filterItemName,
          includeStats: _includeStats,
        );
        if (_reportCtrl.deliveryReport.value != null) {
          setState(() => _generatedData = _reportCtrl.deliveryReport.value);
        }
        break;

      case 'requests':
        await _reportCtrl.getRequestsReport(
          clientId: _filterClientId,
          requestType: _filterRequestType.isEmpty ? null : _filterRequestType,
          status: _filterStatus.isEmpty ? null : _filterStatus,
          dateFrom: _filterDateFrom.isEmpty ? null : _filterDateFrom,
          dateTo: _filterDateTo.isEmpty ? null : _filterDateTo,
          includeStats: _includeStats,
        );
        if (_reportCtrl.requestReport.value != null) {
          setState(() => _generatedData = _reportCtrl.requestReport.value);
        }
        break;

      case 'storage':
        await _reportCtrl.getStorageUtilisationReport();
        if (_reportCtrl.storageUtilisation.value != null) {
          setState(() => _generatedData = _reportCtrl.storageUtilisation.value);
        }
        break;

      case 'destruction':
        await _reportCtrl.getPendingDestructionReport(clientId: _filterClientId);
        if (_reportCtrl.pendingDestruction.value != null) {
          setState(() => _generatedData = _reportCtrl.pendingDestruction.value);
        }
        break;

      case 'client_activity':
        if (_filterClientId == null) {
          Get.snackbar('Required', 'Please select a client for the activity report',
              backgroundColor: Colors.orange, colorText: Colors.white);
          return;
        }
        await _reportCtrl.getClientActivityReport(_filterClientId!);
        if (_reportCtrl.clientActivity.value != null) {
          setState(() => _generatedData = _reportCtrl.clientActivity.value);
        }
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA VIEW RENDERERS
  // ─────────────────────────────────────────────────────────────────────────


  // ── SUMMARY CARD — prominent stat strip ─────────────────────────────────────

  Widget _buildSummaryCard(List<_SumStat> stats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
          top:    BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(Icons.summarize_outlined, size: 14, color: _accent),
                const SizedBox(width: 6),
                Text('REPORT SUMMARY',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: _accent, letterSpacing: 1.1)),
                const Spacer(),
                Text('Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: stats.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: const BoxConstraints(minWidth: 90),
                decoration: BoxDecoration(
                  color: s.color.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: s.color.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, size: 13, color: s.color),
                        const SizedBox(width: 5),
                        Text(s.label,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600],
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(s.value,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                            color: s.color, height: 1)),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChips(List<_Chip> chips) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _accent.withOpacity(0.04),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: chips
            .map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accent.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icon, size: 14, color: c.color ?? _accent),
                      const SizedBox(width: 6),
                      Text(c.label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        c.value,
                        style: TextStyle(
                          color: c.color ?? _accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── BOXES flat ────────────────────────────────────────────────────────────

  Widget _buildFlatBoxesView(BoxReportData data) {
    final s = data.summary;
    return Column(
      children: [
        if (s != null) _buildSummaryCard([
          _SumStat('Total Boxes',    '${s.totalBoxes}',            Icons.inventory_2_outlined,   Colors.blue),
          _SumStat('In Storage',     '${s.stored}',                Icons.storage_outlined,       Colors.green),
          _SumStat('Retrieved',      '${s.retrieved}',             Icons.move_to_inbox_outlined,  const Color(0xFF8E44AD)),
          _SumStat('Destroyed',      '${s.destroyed}',             Icons.delete_forever_outlined, Colors.red),
          _SumStat('Pending Destr.', '${s.pendingDestruction}',    Icons.warning_amber_outlined,  Colors.orange),
          _SumStat('Unique Clients', '${s.uniqueClients}',          Icons.business_outlined,      const Color(0xFF16A085)),
        ]),
        Expanded(
          child: _viewMode == 0
              ? _buildBoxTable(data.boxes)
              : _buildBoxGrid(data.boxes),
        ),
      ],
    );
  }

  Widget _buildGroupedBoxesView(GroupedBoxReportData data) {
    final s = data.summary;
    return Column(
      children: [
        if (s != null) _buildSummaryCard([
          _SumStat('Total Boxes',    '${s.totalBoxes}',            Icons.inventory_2_outlined,   Colors.blue),
          _SumStat('In Storage',     '${s.stored}',                Icons.storage_outlined,       Colors.green),
          _SumStat('Retrieved',      '${s.retrieved}',             Icons.move_to_inbox_outlined,  const Color(0xFF8E44AD)),
          _SumStat('Destroyed',      '${s.destroyed}',             Icons.delete_forever_outlined, Colors.red),
          _SumStat('Pending Destr.', '${s.pendingDestruction}',    Icons.warning_amber_outlined,  Colors.orange),
          _SumStat('Unique Clients', '${s.uniqueClients}',          Icons.business_outlined,      const Color(0xFF16A085)),
        ]),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: data.clients.length,
            itemBuilder: (_, i) {
              final group = data.clients[i];
              return ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: _accent.withOpacity(0.12),
                  child: Text(group.clientCode.substring(0, 1),
                      style: TextStyle(color: _accent, fontWeight: FontWeight.bold)),
                ),
                title: Text('${group.clientName} (${group.clientCode})',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'Boxes: ${group.summary.totalBoxes}  ·  Stored: ${group.summary.stored}  ·  Pending: ${group.summary.pendingDestruction}',
                    style: const TextStyle(fontSize: 12)),
                children: [_buildBoxTable(group.boxes)],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBoxTable(List<ReportBoxItem> boxes) {
    if (boxes.isEmpty) {
      return const Padding(padding: EdgeInsets.all(40),
          child: Center(child: Text('No boxes found', style: TextStyle(color: Colors.grey))));
    }
    // Nested scroll views: outer handles vertical (many rows), inner
    // handles horizontal (many columns) — DataTable has no scrolling
    // of its own in either direction.
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(_accent.withOpacity(0.07)),
        columnSpacing: 14,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 64,
        columns: const [
          DataColumn(label: Text('Box Number',   style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Size',          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Description',   style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Client',        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Date Received', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Retention',     style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Dest. Year',    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Status',        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Location',      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        ],
        rows: boxes.map((b) {
          String dDate = b.dateReceived ?? '—';
          try { if (dDate != '—') dDate = DateFormat('dd MMM yyyy').format(DateTime.parse(dDate)); } catch (_) {}
          final isOverdue = b.destructionYear != null &&
              b.destructionYear! <= DateTime.now().year && b.status == 'stored';
          return DataRow(cells: [
            DataCell(SizedBox(width: 130,
                child: Text(b.boxNumber, style: TextStyle(color: _accent, fontWeight: FontWeight.w600, fontSize: 13)))),
            DataCell(Text(b.boxSize, style: const TextStyle(fontSize: 13))),
            DataCell(SizedBox(width: 200,
                child: Text(b.description ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)))),
            DataCell(SizedBox(width: 130,
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.client.clientCode,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  Text(b.client.clientName,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]))),
            DataCell(SizedBox(width: 110, child: Text(dDate, style: const TextStyle(fontSize: 12)))),
            DataCell(Text(b.retentionYears != null ? '${b.retentionYears}y' : '—',
                style: const TextStyle(fontSize: 12))),
            DataCell(SizedBox(width: 80,
                child: Text(b.destructionYear?.toString() ?? '—',
                    style: TextStyle(fontSize: 12,
                        color: isOverdue ? Colors.red : null,
                        fontWeight: isOverdue ? FontWeight.w700 : null)))),
            DataCell(_statusChip(b.status)),
            DataCell(SizedBox(width: 110,
                child: Text(b.rackLabel ?? '—', style: const TextStyle(fontSize: 12)))),
          ]);
        }).toList(),
      ),
      ),
    );
  }

  Widget _buildBoxGrid(List<ReportBoxItem> boxes) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : MediaQuery.of(context).size.width > 800 ? 3 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: boxes.length,
      itemBuilder: (_, i) {
        final b = boxes[i];
        final color = _statusColor(b.status);
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 4, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(10)))),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.boxNumber, style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(b.description ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      Row(children: [
                        Icon(Icons.business, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(b.client.clientCode, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ]),
                      const SizedBox(height: 4),
                      _statusChip(b.status),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── COLLECTIONS ───────────────────────────────────────────────────────────

  Widget _buildCollectionsView(CollectionReportData data) {
    final s = data.summary;
    return Column(
      children: [
        if (s != null) _buildSummaryCard([
          _SumStat('Total Collections', '${s.totalCollections}',    Icons.local_shipping_outlined,  const Color(0xFF27AE60)),
          _SumStat('Total Boxes',       '${s.totalBoxesCollected}', Icons.inventory_2_outlined,     Colors.blue),
          _SumStat('Unique Clients',    '${s.uniqueClients}',        Icons.business_outlined,        const Color(0xFF16A085)),
        ]),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFF27AE60).withOpacity(0.07)),
              columns: const [
                DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Boxes', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Dispatcher', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Collector', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Created By', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: data.collections.map((c) => DataRow(cells: [
                    DataCell(Text('#${c.collectionId}')),
                    DataCell(Text(c.client.clientCode)),
                    DataCell(Center(child: Text('${c.totalBoxes}', style: const TextStyle(fontWeight: FontWeight.bold)))),
                    DataCell(Text(c.dispatcherName)),
                    DataCell(Text(c.collectorName)),
                    DataCell(Text(c.collectionDate)),
                    DataCell(Text(c.createdBy ?? '—')),
                  ])).toList(),
            ),
            ),
          ),
        ),
      ],
    );
  }

  // ── RETRIEVALS ────────────────────────────────────────────────────────────

  Widget _buildRetrievalsView(RetrievalReportData data) {
    final s = data.summary;
    return Column(
      children: [
        if (s != null) _buildSummaryCard([
          _SumStat('Total',        '${s.totalRetrievals}',  Icons.move_to_inbox_outlined,    const Color(0xFF8E44AD)),
          _SumStat('Pending',      '${s.pending}',          Icons.pending_actions_outlined,  Colors.orange),
          _SumStat('Completed',    '${s.completed}',        Icons.check_circle_outline,      Colors.green),
          _SumStat('Retrieved',    '${s.retrieved}',        Icons.archive_outlined,          Colors.blue),
          _SumStat('Clients',      '${s.uniqueClients}',     Icons.business_outlined,         const Color(0xFF16A085)),
          _SumStat('Unique Boxes', '${s.uniqueBoxes}',       Icons.inventory_2_outlined,      Colors.teal),
        ]),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFF8E44AD).withOpacity(0.07)),
              columns: const [
                DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Box #', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Retrieved By', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Client Sig.', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Staff Sig.', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: data.retrievals.map((r) => DataRow(cells: [
                    DataCell(Text('#${r.retrievalId}')),
                    DataCell(Text(r.box.boxNumber, style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(r.client.clientCode)),
                    DataCell(Text(r.retrievalDate)),
                    DataCell(Text(r.retrievedBy ?? '—')),
                    DataCell(_statusChip(r.status)),
                    DataCell(_sigIcon(r.signatures.clientSigned)),
                    DataCell(_sigIcon(r.signatures.staffSigned)),
                  ])).toList(),
            ),
            ),
          ),
        ),
      ],
    );
  }

  // ── DELIVERIES ────────────────────────────────────────────────────────────

  Widget _buildDeliveriesView(DeliveryReportData data) {
    final s = data.summary;
    return Column(
      children: [
        if (s != null) _buildSummaryCard([
          _SumStat('Total Deliveries', '${s.totalDeliveries}', Icons.outbox_outlined,    const Color(0xFFE67E22)),
          _SumStat('Total Quantity',   '${s.totalQuantity}',   Icons.numbers,            Colors.blue),
          _SumStat('Unique Clients',   '${s.uniqueClients}',    Icons.business_outlined,  const Color(0xFF16A085)),
        ]),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFFE67E22).withOpacity(0.07)),
              columns: const [
                DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Item', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Receiver', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Signed', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: data.deliveries.map((d) => DataRow(cells: [
                    DataCell(Text('#${d.deliveryId}')),
                    DataCell(Text(d.client.clientCode)),
                    DataCell(SizedBox(width: 140, child: Text(d.itemName, overflow: TextOverflow.ellipsis))),
                    DataCell(Text('${d.quantity}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(d.receiverName)),
                    DataCell(Text(d.deliveryDate)),
                    DataCell(_sigIcon(d.receiverSigned)),
                  ])).toList(),
            ),
            ),
          ),
        ),
      ],
    );
  }

  // ── REQUESTS ─────────────────────────────────────────────────────────────

  Widget _buildRequestsView(RequestReportData data) {
    final s = data.summary;
    return Column(
      children: [
        if (s != null) _buildSummaryCard([
          _SumStat('Total Requests', '${s.totalRequests}', Icons.assignment_outlined,    const Color(0xFFE74C3C)),
          _SumStat('Unique Clients', '${s.uniqueClients}',  Icons.business_outlined,      const Color(0xFF16A085)),
          ...s.byStatus.entries.map((e) => _SumStat(e.key.capitalizeFirst ?? e.key, '${e.value}', Icons.label_outlined, const Color(0xFF8E44AD))),
        ]),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFFE74C3C).withOpacity(0.07)),
              columns: const [
                DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Box', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Requested', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Completed', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: data.requests.map((r) => DataRow(cells: [
                    DataCell(Text('#${r.requestId}')),
                    DataCell(Text(r.client.clientCode)),
                    DataCell(Text(r.requestType.capitalizeFirst ?? r.requestType)),
                    DataCell(_statusChip(r.status)),
                    DataCell(Text(r.boxNumber ?? '—')),
                    DataCell(Text(r.requestedDate)),
                    DataCell(Text(r.completedDate ?? '—')),
                  ])).toList(),
            ),
            ),
          ),
        ),
      ],
    );
  }

  // ── STORAGE ───────────────────────────────────────────────────────────────

  Widget _buildStorageView(StorageUtilisationData data) {
    final s = data.summary;
    return Column(
      children: [
        _buildSummaryCard([
          _SumStat('Total Racks',  '${s.totalRacks}',    Icons.warehouse_outlined,        Colors.blue),
          _SumStat('Occupied',     '${s.occupiedRacks}', Icons.inventory_2_outlined,      Colors.orange),
          _SumStat('Available',    '${s.availableRacks}',Icons.check_circle_outline,      Colors.green),
          _SumStat('Utilisation',  s.totalRacks > 0 ? '${(s.occupiedRacks / s.totalRacks * 100).toStringAsFixed(0)}%' : '0%',
                   Icons.pie_chart_outline, const Color(0xFF8E44AD)),
        ]),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 1000 ? 4 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2,
              ),
              itemCount: data.racks.length,
              itemBuilder: (_, i) {
                final rack = data.racks[i];
                final occupied = rack.boxesStored > 0;
                final color = rack.isAvailable && !occupied ? Colors.green : occupied ? Colors.orange : Colors.grey;
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: color, width: 4)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(rack.labelCode, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                        Text(rack.location, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.inventory_2, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text('${rack.boxesStored} stored', style: const TextStyle(fontSize: 11)),
                        ]),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── DESTRUCTION ───────────────────────────────────────────────────────────

  Widget _buildDestructionView(PendingDestructionData data) {
    return Column(
      children: [
        _buildSummaryCard([
          _SumStat('Overdue Boxes', '${data.count}', Icons.warning_amber_outlined, Colors.red),
        ]),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: data.boxes.length,
            itemBuilder: (_, i) {
              final b = data.boxes[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.red[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.warning, color: Colors.red[700], size: 20),
                  ),
                  title: Text(b.boxNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${b.client.clientName} · ${b.description ?? ''}'),
                      Text(
                        'Destruction Year: ${b.destructionYear}  (${b.yearsOverdue ?? '?'}y overdue)',
                        style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Text(b.rackLabel ?? '—', style: const TextStyle(fontSize: 12)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── CLIENT ACTIVITY ───────────────────────────────────────────────────────

  Widget _buildClientActivityView(ClientActivityData data) {
    final c = data.client;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client header card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _accent.withOpacity(0.12),
                    child: Text(c.clientCode.substring(0, 1),
                        style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Code: ${c.clientCode}  ·  ${c.email ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        if (c.contactPerson != null) Text('Contact: ${c.contactPerson}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Activity summary grid
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 5 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _activityTile('Total Boxes', '${data.boxSummary.total}', Icons.inventory_2, _accent),
              _activityTile('Stored', '${data.boxSummary.stored}', Icons.storage, Colors.green),
              _activityTile('Retrieved', '${data.boxSummary.retrieved}', Icons.move_to_inbox, Colors.blue),
              _activityTile('Collections', '${data.totalCollections}', Icons.local_shipping, Colors.teal),
              _activityTile('Retrievals', '${data.totalRetrievals}', Icons.move_to_inbox, Colors.purple),
              _activityTile('Deliveries', '${data.totalDeliveries}', Icons.outbox, Colors.orange),
              _activityTile('Requests', '${data.totalRequests}', Icons.assignment, Colors.red),
              _activityTile('Pending Destr.', '${data.boxSummary.pendingDestruction}', Icons.warning, Colors.deepOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityTile(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SMALL HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.capitalizeFirst ?? status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _sigIcon(bool signed) => Icon(
        signed ? Icons.verified : Icons.cancel_outlined,
        color: signed ? Colors.green : Colors.red[300],
        size: 18,
      );

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'stored':
      case 'completed':
      case 'approved':
        return Colors.green;
      case 'retrieved':
      case 'pending':
        return Colors.blue;
      case 'destroyed':
      case 'cancelled':
        return Colors.red;
      case 'pending_signature':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXPORT — PDF
  // ─────────────────────────────────────────────────────────────────────────

  Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final d = await rootBundle.load('assets/logo/logo.jpeg');
      return pw.MemoryImage(d.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<pw.Document> _buildGenericPdf({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    List<_Chip>? summaryChips,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(boldData);
    final logo = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logo != null)
                        pw.Container(width: 55, height: 55, child: pw.Image(logo)),
                      pw.SizedBox(width: 14),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Docsecure Eswatini (Pty) Ltd',
                                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                            pw.Text('Physical Storage Management System ®',
                                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                            pw.Text('Matsapha M201, Eswatini',
                                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Generated', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 8),
                  pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(subtitle, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.SizedBox(height: 12),
                  if (summaryChips != null && summaryChips.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        border: pw.Border.all(color: PdfColors.blue200, width: 0.8),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('REPORT SUMMARY',
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800, letterSpacing: 0.8)),
                          pw.SizedBox(height: 6),
                          pw.Wrap(
                            spacing: 18,
                            runSpacing: 5,
                            children: summaryChips.map((c) => pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Container(width: 7, height: 7, decoration: pw.BoxDecoration(color: PdfColors.blue600, shape: pw.BoxShape.circle)),
                                pw.SizedBox(width: 4),
                                pw.Text('${c.label}:  ', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                pw.Text(c.value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                              ],
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 10),
                ],
              )
            : pw.SizedBox(),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
            cellStyle: pw.TextStyle(fontSize: 8.5),
            cellHeight: 30,
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total records: ${rows.length}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('PSMS — Docsecure Eswatini', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Authorised (Docsecure Representative)', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.SizedBox(height: 14),
                pw.Text('_________________________________', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                pw.Text('Signature & Date', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Received (Client Representative)', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.SizedBox(height: 14),
                pw.Text('_________________________________', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                pw.Text('Signature & Date', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
              ]),
            ],
          ),
        ],
      ),
    );
    return pdf;
  }

  Future<pw.Document?> _buildPdfForCurrentData() async {
    final data = _generatedData;
    if (data == null) return null;

    switch (_active.id) {
      case 'boxes':
        final boxes = (data is GroupedBoxReportData)
            ? data.clients.expand((c) => c.boxes).toList()
            : (data is BoxReportData ? data.boxes : <ReportBoxItem>[]);
        final anySummary = (data is BoxReportData) ? data.summary
            : (data is GroupedBoxReportData ? data.summary : null);
        return _buildGenericPdf(
          title: 'Box Inventory Report',
          subtitle: 'Generated by PSMS — Docsecure Eswatini',
          headers: ['Box #', 'Size', 'Description', 'Client', 'Date Received', 'Retention', 'Dest. Year', 'Status', 'Location'],
          rows: boxes.map((b) {
            String dDate = b.dateReceived ?? '—';
            try { if (dDate != '—') dDate = DateFormat('dd MMM yyyy').format(DateTime.parse(dDate)); } catch (_) {}
            return [
              b.boxNumber, b.boxSize, b.description ?? '—',
              '${b.client.clientCode} (${b.client.clientName})',
              dDate,
              b.retentionYears != null ? '${b.retentionYears}y' : '—',
              b.destructionYear?.toString() ?? '—', b.status, b.rackLabel ?? '—',
            ];
          }).toList(),
          summaryChips: anySummary != null ? [
            _Chip(Icons.inventory_2, 'Total', '${anySummary.totalBoxes}'),
            _Chip(Icons.storage, 'Stored', '${anySummary.stored}'),
            _Chip(Icons.move_to_inbox, 'Retrieved', '${anySummary.retrieved}'),
            _Chip(Icons.delete_forever, 'Destroyed', '${anySummary.destroyed}'),
            _Chip(Icons.warning, 'Pending Destr.', '${anySummary.pendingDestruction}'),
            _Chip(Icons.business, 'Clients', '${anySummary.uniqueClients}'),
          ] : null,
        );

      case 'collections':
        final d = data as CollectionReportData;
        return _buildGenericPdf(
          title: 'Collections Report',
          subtitle: 'Generated by PSMS',
          headers: ['ID', 'Client', 'Total Boxes', 'Dispatcher', 'Collector', 'Date', 'Created By'],
          rows: d.collections.map((c) => [
                '#${c.collectionId}', c.client.clientCode, '${c.totalBoxes}',
                c.dispatcherName, c.collectorName, c.collectionDate, c.createdBy ?? '—',
              ]).toList(),
          summaryChips: d.summary != null
              ? [
                  _Chip(Icons.local_shipping, 'Collections', '${d.summary!.totalCollections}'),
                  _Chip(Icons.inventory_2, 'Boxes', '${d.summary!.totalBoxesCollected}'),
                ]
              : null,
        );

      case 'retrievals':
        final d = data as RetrievalReportData;
        return _buildGenericPdf(
          title: 'Retrievals Report',
          subtitle: 'Generated by PSMS',
          headers: ['ID', 'Box #', 'Client', 'Date', 'Retrieved By', 'Status', 'Client Sig.', 'Staff Sig.'],
          rows: d.retrievals.map((r) => [
                '#${r.retrievalId}', r.box.boxNumber, r.client.clientCode,
                r.retrievalDate, r.retrievedBy ?? '—', r.status,
                r.signatures.clientSigned ? 'Yes' : 'No',
                r.signatures.staffSigned ? 'Yes' : 'No',
              ]).toList(),
        );

      case 'deliveries':
        final d = data as DeliveryReportData;
        return _buildGenericPdf(
          title: 'Deliveries Report',
          subtitle: 'Generated by PSMS',
          headers: ['ID', 'Client', 'Item', 'Qty', 'Receiver', 'Date', 'Signed'],
          rows: d.deliveries.map((dv) => [
                '#${dv.deliveryId}', dv.client.clientCode, dv.itemName,
                '${dv.quantity}', dv.receiverName, dv.deliveryDate,
                dv.receiverSigned ? 'Yes' : 'No',
              ]).toList(),
        );

      case 'requests':
        final d = data as RequestReportData;
        return _buildGenericPdf(
          title: 'Service Requests Report',
          subtitle: 'Generated by PSMS',
          headers: ['ID', 'Client', 'Type', 'Status', 'Box', 'Requested', 'Completed'],
          rows: d.requests.map((r) => [
                '#${r.requestId}', r.client.clientCode, r.requestType,
                r.status, r.boxNumber ?? '—', r.requestedDate, r.completedDate ?? '—',
              ]).toList(),
        );

      case 'storage':
        final d = data as StorageUtilisationData;
        return _buildGenericPdf(
          title: 'Storage Utilisation Report',
          subtitle: 'Generated by PSMS',
          headers: ['Label Code', 'Location', 'Available', 'Boxes Stored'],
          rows: d.racks.map((r) => [
                r.labelCode, r.location,
                r.isAvailable ? 'Yes' : 'No', '${r.boxesStored}',
              ]).toList(),
          summaryChips: [
            _Chip(Icons.warehouse, 'Total', '${d.summary.totalRacks}'),
            _Chip(Icons.inventory_2, 'Occupied', '${d.summary.occupiedRacks}'),
            _Chip(Icons.check_circle, 'Available', '${d.summary.availableRacks}'),
          ],
        );

      case 'destruction':
        final d = data as PendingDestructionData;
        return _buildGenericPdf(
          title: 'Pending Destruction Report',
          subtitle: 'Generated by PSMS',
          headers: ['Box #', 'Client', 'Dest. Year', 'Yrs Overdue', 'Location'],
          rows: d.boxes.map((b) => [
                b.boxNumber, b.client.clientCode,
                b.destructionYear?.toString() ?? '—',
                b.yearsOverdue?.toString() ?? '—', b.rackLabel ?? '—',
              ]).toList(),
          summaryChips: [_Chip(Icons.warning, 'Overdue', '${d.count}', color: Colors.red)],
        );

      default:
        return null;
    }
  }

  Future<void> _exportPdf() async {
    final pdf = await _buildPdfForCurrentData();
    if (pdf == null) {
      Get.snackbar('Error', 'Nothing to export', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: MediaQuery.of(Get.context!).size.width * 0.85,
          height: MediaQuery.of(Get.context!).size.height * 0.85,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red[50]),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red[700]),
                    const SizedBox(width: 10),
                    Text('PDF Preview — ${_active.label} Report',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  pdfFileName:
                      '${_active.id}_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
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
                        await _savePdf(pdf);
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
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3E50), elevation: 0),
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

  Future<void> _savePdf(pw.Document pdf) async {
    final bytes = await pdf.save();
    final name = '${_active.id}_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    if (Platform.isWindows) {
      final dir = await getDownloadsDirectory();
      if (dir == null) return;
      await File('${dir.path}/$name').writeAsBytes(bytes);
      await OpenFile.open(dir.path);
      Get.snackbar('Saved', 'PDF saved to Downloads', backgroundColor: Colors.green, colorText: Colors.white);
    } else {
      final tmp = await getTemporaryDirectory();
      final f = File('${tmp.path}/$name');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)], text: '${_active.label} Report');
    }
  }

  Future<void> _printReport() async {
    final pdf = await _buildPdfForCurrentData();
    if (pdf == null) return;
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXPORT — EXCEL
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final data = _generatedData;
    if (data == null) {
      Get.snackbar('Error', 'Nothing to export', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final excel = exl.Excel.createExcel();
    final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = '${_active.id}_report_$now.xlsx';

    switch (_active.id) {
      case 'boxes':
        final boxes = (data is GroupedBoxReportData)
            ? data.clients.expand((c) => c.boxes).toList()
            : (data is BoxReportData ? data.boxes : <ReportBoxItem>[]);
        final sheet = excel['Box Report'];
        sheet.appendRow([
          exl.TextCellValue('Box Number'), exl.TextCellValue('Size'),
          exl.TextCellValue('Description'), exl.TextCellValue('Client Code'),
          exl.TextCellValue('Client Name'), exl.TextCellValue('Date Received'),
          exl.TextCellValue('Dest. Year'), exl.TextCellValue('Status'),
          exl.TextCellValue('Rack Label'), exl.TextCellValue('Location'),
        ]);
        for (final b in boxes) {
          sheet.appendRow([
            exl.TextCellValue(b.boxNumber), exl.TextCellValue(b.boxSize),
            exl.TextCellValue(b.description ?? ''), exl.TextCellValue(b.client.clientCode),
            exl.TextCellValue(b.client.clientName), exl.TextCellValue(b.dateReceived ?? ''),
            exl.IntCellValue(b.destructionYear ?? 0), exl.TextCellValue(b.status),
            exl.TextCellValue(b.rackLabel ?? ''), exl.TextCellValue(b.rackLocation ?? ''),
          ]);
        }
        break;

      case 'collections':
        final sheet = excel['Collections'];
        sheet.appendRow([exl.TextCellValue('ID'), exl.TextCellValue('Client'), exl.TextCellValue('Total Boxes'), exl.TextCellValue('Dispatcher'), exl.TextCellValue('Collector'), exl.TextCellValue('Date'), exl.TextCellValue('Created By')]);
        for (final c in (data as CollectionReportData).collections) {
          sheet.appendRow([exl.IntCellValue(c.collectionId), exl.TextCellValue(c.client.clientName), exl.IntCellValue(c.totalBoxes), exl.TextCellValue(c.dispatcherName), exl.TextCellValue(c.collectorName), exl.TextCellValue(c.collectionDate), exl.TextCellValue(c.createdBy ?? '')]);
        }
        break;

      case 'retrievals':
        final sheet = excel['Retrievals'];
        sheet.appendRow([exl.TextCellValue('ID'), exl.TextCellValue('Box #'), exl.TextCellValue('Client'), exl.TextCellValue('Date'), exl.TextCellValue('Retrieved By'), exl.TextCellValue('Status'), exl.TextCellValue('Client Signed'), exl.TextCellValue('Staff Signed')]);
        for (final r in (data as RetrievalReportData).retrievals) {
          sheet.appendRow([exl.IntCellValue(r.retrievalId), exl.TextCellValue(r.box.boxNumber), exl.TextCellValue(r.client.clientName), exl.TextCellValue(r.retrievalDate), exl.TextCellValue(r.retrievedBy ?? ''), exl.TextCellValue(r.status), exl.TextCellValue(r.signatures.clientSigned ? 'Yes' : 'No'), exl.TextCellValue(r.signatures.staffSigned ? 'Yes' : 'No')]);
        }
        break;

      case 'deliveries':
        final sheet = excel['Deliveries'];
        sheet.appendRow([exl.TextCellValue('ID'), exl.TextCellValue('Client'), exl.TextCellValue('Item Name'), exl.TextCellValue('Quantity'), exl.TextCellValue('Receiver'), exl.TextCellValue('Date'), exl.TextCellValue('Signed')]);
        for (final d in (data as DeliveryReportData).deliveries) {
          sheet.appendRow([exl.IntCellValue(d.deliveryId), exl.TextCellValue(d.client.clientName), exl.TextCellValue(d.itemName), exl.IntCellValue(d.quantity), exl.TextCellValue(d.receiverName), exl.TextCellValue(d.deliveryDate), exl.TextCellValue(d.receiverSigned ? 'Yes' : 'No')]);
        }
        break;

      case 'requests':
        final sheet = excel['Requests'];
        sheet.appendRow([exl.TextCellValue('ID'), exl.TextCellValue('Client'), exl.TextCellValue('Type'), exl.TextCellValue('Status'), exl.TextCellValue('Box'), exl.TextCellValue('Requested'), exl.TextCellValue('Completed')]);
        for (final r in (data as RequestReportData).requests) {
          sheet.appendRow([exl.IntCellValue(r.requestId), exl.TextCellValue(r.client.clientName), exl.TextCellValue(r.requestType), exl.TextCellValue(r.status), exl.TextCellValue(r.boxNumber ?? ''), exl.TextCellValue(r.requestedDate), exl.TextCellValue(r.completedDate ?? '')]);
        }
        break;

      case 'storage':
        final sheet = excel['Storage Utilisation'];
        sheet.appendRow([exl.TextCellValue('Label Code'), exl.TextCellValue('Location'), exl.TextCellValue('Available'), exl.TextCellValue('Boxes Stored')]);
        for (final r in (data as StorageUtilisationData).racks) {
          sheet.appendRow([exl.TextCellValue(r.labelCode), exl.TextCellValue(r.location), exl.TextCellValue(r.isAvailable ? 'Yes' : 'No'), exl.IntCellValue(r.boxesStored)]);
        }
        break;

      case 'destruction':
        final sheet = excel['Pending Destruction'];
        sheet.appendRow([exl.TextCellValue('Box #'), exl.TextCellValue('Client'), exl.TextCellValue('Dest. Year'), exl.TextCellValue('Yrs Overdue'), exl.TextCellValue('Rack Label')]);
        for (final b in (data as PendingDestructionData).boxes) {
          sheet.appendRow([exl.TextCellValue(b.boxNumber), exl.TextCellValue(b.client.clientName), exl.IntCellValue(b.destructionYear ?? 0), exl.IntCellValue(b.yearsOverdue ?? 0), exl.TextCellValue(b.rackLabel ?? '')]);
        }
        break;

      default:
        break;
    }

    final bytes = excel.encode();
    if (bytes == null) {
      Get.snackbar('Error', 'Failed to encode Excel', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (Platform.isWindows) {
      final dir = await getDownloadsDirectory();
      if (dir == null) return;
      await File('${dir.path}/$fileName').writeAsBytes(bytes);
      await OpenFile.open(dir.path);
      Get.snackbar('Saved', 'Excel saved to Downloads: $fileName',
          backgroundColor: Colors.green, colorText: Colors.white, duration: const Duration(seconds: 4));
    } else {
      final tmp = await getTemporaryDirectory();
      final f = File('${tmp.path}/$fileName');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)], text: '${_active.label} Report (Excel)');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHIP DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _Chip {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _Chip(this.icon, this.label, this.value, {this.color});
}

// _SumStat — local summary stat model
class _SumStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SumStat(this.label, this.value, this.icon, this.color);
}