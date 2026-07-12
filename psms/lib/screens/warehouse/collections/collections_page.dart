// lib/pages/collections/collections_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/controllers/collection_controller.dart';
import 'package:psms/models/box_model.dart';
import 'package:psms/models/collection_model.dart';
import 'package:psms/models/user_model.dart';
import 'package:psms/screens/warehouse/boxes/widgets/client_search_field.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});
  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final CollectionController _ctrl = Get.put(CollectionController());
  final AuthController _auth = Get.find<AuthController>();
  // Dedicated client source (same one used across the box screens),
  // instead of CollectionController's own client cache — avoids relying
  // on whatever partial list CollectionController happened to load, and
  // gives us the searchable/scrollable picker. Lazy getter so it can
  // never throw a LateInitializationError.
  ClientManagementController? _clientCtrl;
  ClientManagementController get clientCtrl {
    if (_clientCtrl == null) {
      _clientCtrl = Get.isRegistered<ClientManagementController>()
          ? Get.find<ClientManagementController>()
          : Get.put(ClientManagementController());
    }
    return _clientCtrl!;
  }

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  late SignatureController _dispSigCtrl;
  late SignatureController _collSigCtrl;

  String? _dispSigBase64;
  String? _collSigBase64;
  DateTime? _selectedDate;
  DateTime? _filterStart;
  DateTime? _filterEnd;
  int? _selectedClientId;
  int? _selectedCollectorUserId;
  String _activeFilter = 'all';
  String _searchQuery = '';

  final RxList<UserModel> _clientUsers = <UserModel>[].obs;
  final RxBool _loadingUsers = false.obs;
  final RxList<BoxModel> _clientBoxes = <BoxModel>[].obs;
  final RxBool _loadingBoxes = false.obs;
  final RxList<BoxModel> _selectedBoxes = <BoxModel>[].obs;

  final RxList<BoxModel> _collectionBoxes = <BoxModel>[].obs;
  final RxBool _loadingCollectionBoxes = false.obs;

  final RxInt _itemsPerPage = 20.obs;
  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _dispSigCtrl = SignatureController(
        penStrokeWidth: 3,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white);
    _collSigCtrl = SignatureController(
        penStrokeWidth: 3,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white);
    _ctrl.initialize();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClients());
  }

  Future<void> _loadClients() async {
    // fetchClients() is paginated (20/page by default) — bump the page
    // size so this one call returns every client for the picker.
    clientCtrl.itemsPerPage.value = 1000;
    await clientCtrl.fetchClients(showLoading: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _descCtrl.dispose();
    _dispSigCtrl.dispose();
    _collSigCtrl.dispose();
    super.dispose();
  }

  // The parsing helper (add this too)
  Future<void> _loadCollectionBoxes(CollectionModel collection) async {
    _loadingCollectionBoxes.value = true;
    _collectionBoxes.clear();

    final desc = collection.boxDescription ?? '';
    final boxNumbers = <String>[];

    final match = RegExp(r'Boxes:\s*(.+?)(?:\n|$)').firstMatch(desc);
    if (match != null) {
      final numbersPart = match.group(1) ?? '';
      boxNumbers.addAll(numbersPart
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty));
    }

    _collectionBoxes.value = boxNumbers
        .map((bn) => BoxModel(
              boxId: 0,
              boxNumber: bn,
              description: '',
              dateReceived: DateTime.now(),
              yearReceived: 0,
              retentionYears: 0,
              status: '',
              isPendingDestruction: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              client: BoxClient(clientId: 0, clientName: '', clientCode: ''),
            ))
        .toList();

    _loadingCollectionBoxes.value = false;
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  List<CollectionModel> get _filtered {
    final now = DateTime.now();
    var list = _ctrl.collections.toList();

    if (_activeFilter == 'month') {
      list = list
          .where((c) =>
              c.collectionDate.year == now.year &&
              c.collectionDate.month == now.month)
          .toList();
    } else if (_activeFilter == 'week') {
      final start = now.subtract(Duration(days: now.weekday - 1));
      final end = start.add(const Duration(days: 6));
      list = list
          .where((c) =>
              !c.collectionDate.isBefore(DateUtils.dateOnly(start)) &&
              !c.collectionDate.isAfter(DateUtils.dateOnly(end)))
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((c) =>
              c.client.clientName.toLowerCase().contains(q) ||
              (c.boxDescription?.toLowerCase().contains(q) ?? false) ||
              c.dispatcherName.toLowerCase().contains(q) ||
              c.collectorName.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatsRow(),
          Expanded(child: _buildContentCard()),
        ],
      ),
      floatingActionButton: _ctrl.canCreateCollections
          ? FloatingActionButton.extended(
              onPressed: _showCollectionDialog,
              backgroundColor: const Color(0xFF1976D2).withOpacity(0.85),
              icon: const Icon(Icons.add),
              label: const Text('New Collection',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.95),
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Collections',
              style: TextStyle(
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w700,
                  fontSize: 20)),
          Text('Manage warehouse collections',
              style: TextStyle(
                  color: const Color(0xFF2C3E50).withOpacity(0.55),
                  fontWeight: FontWeight.w300,
                  fontSize: 12)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF2C3E50)),
          tooltip: 'Refresh',
          onPressed: () async {
            await _ctrl.getAllCollections();
            _ctrl.getCollectionStatistics();
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF2C3E50)),
          onSelected: (v) {
            if (v == 'reports') _showReportsDialog();
            if (v == 'statistics') _showStatisticsDialog();
            if (v == 'export') _showExportDialog();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'reports',
                child: Row(children: [
                  Icon(Icons.summarize, size: 18),
                  SizedBox(width: 8),
                  Text('View Reports')
                ])),
            PopupMenuItem(
                value: 'statistics',
                child: Row(children: [
                  Icon(Icons.analytics, size: 18),
                  SizedBox(width: 8),
                  Text('Statistics')
                ])),
            PopupMenuItem(
                value: 'export',
                child: Row(children: [
                  Icon(Icons.download, size: 18),
                  SizedBox(width: 8),
                  Text('Export Data')
                ])),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────
  // Derived entirely from already-loaded reactive data — shows real numbers
  // the instant getAllCollections() resolves, without waiting for /stats.

  Widget _buildStatsRow() {
    return Obx(() {
      final now = DateTime.now();
      final cols = _ctrl.collections;

      // Use pagination total (all pages) when available, else current page count
      final total = _ctrl.totalCollections.value > 0
          ? _ctrl.totalCollections.value
          : cols.length;
      final totalBoxes = cols.fold<int>(0, (s, c) => s + c.totalBoxes);
      final thisMonth = cols
          .where((c) =>
              c.collectionDate.year == now.year &&
              c.collectionDate.month == now.month)
          .length;
      final clients = _ctrl.clients.length;

      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
        child: Row(
          children: [
            Expanded(
                child: _statCard(
                    'All time',
                    total.toString(),
                    'Total Collections',
                    Icons.inventory_2,
                    const Color(0xFF5DADE2))),
            const SizedBox(width: 14),
            Expanded(
                child: _statCard('Across page', totalBoxes.toString(),
                    'Total Boxes', Icons.archive, const Color(0xFF52BE80))),
            const SizedBox(width: 14),
            Expanded(
                child: _statCard(
                    'This month',
                    thisMonth.toString(),
                    'Collections',
                    Icons.calendar_today,
                    const Color(0xFFEB984E))),
            const SizedBox(width: 14),
            Expanded(
                child: _statCard('Active', clients.toString(), 'Clients',
                    Icons.business, const Color(0xFFAB47BC))),
          ],
        ),
      );
    });
  }

  Widget _statCard(
      String label, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Text(value,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: TextStyle(
                  color: Colors.black.withOpacity(0.55), fontSize: 12)),
        ],
      ),
    );
  }

  // ── Content card ──────────────────────────────────────────────────────────

  Widget _buildContentCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          _buildToolbar(),
          Divider(height: 1, color: Colors.black.withOpacity(0.12)),
          _buildTableHeader(),
          Divider(height: 1, color: Colors.black.withOpacity(0.12)),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  // ── Toolbar (search + chips) ───────────────────────────────────────────────

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search client, dispatcher, description…',
                  hintStyle: TextStyle(
                      color: Colors.black.withOpacity(0.4), fontSize: 13),
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: Colors.black.withOpacity(0.45)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: 16, color: Colors.black.withOpacity(0.45)),
                          onPressed: () => setState(() {
                            _searchCtrl.clear();
                            _searchQuery = '';
                          }),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _chip('All', 'all'),
          const SizedBox(width: 6),
          _chip('This Month', 'month'),
          const SizedBox(width: 6),
          _chip('This Week', 'week'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final on = _activeFilter == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      child: InkWell(
        onTap: () => setState(() => _activeFilter = value),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: on
                ? const Color(0xFF3498DB).withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: on
                  ? const Color(0xFF3498DB).withOpacity(0.6)
                  : Colors.grey.shade300,
              width: on ? 1.5 : 1,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? const Color(0xFF2980B9) : Colors.black54)),
        ),
      ),
    );
  }

  // ── Table header ──────────────────────────────────────────────────────────

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(flex: 3, child: _hCell('Client')),
          Expanded(flex: 2, child: _hCell('Date')),
          const SizedBox(width: 70, child: _HCell('Boxes')),
          Expanded(flex: 2, child: _hCell('Staff')),
          const SizedBox(width: 100, child: _HCell('Signatures')),
          const SizedBox(width: 96, child: _HCell('', align: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _hCell(String t) => Text(t,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.black.withOpacity(0.45),
          letterSpacing: 0.4));

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList() {
    return Obx(() {
      if (_ctrl.isLoading.value && _ctrl.collections.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF3498DB))));
      }

      final items = _filtered;

      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 56, color: Colors.black.withOpacity(0.25)),
              const SizedBox(height: 14),
              Text('No collections found',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.65))),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty || _activeFilter != 'all'
                    ? 'Try adjusting your filters'
                    : 'Tap  +  New Collection  to get started',
                style: TextStyle(
                    fontSize: 13, color: Colors.black.withOpacity(0.4)),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async => _ctrl.getAllCollections(),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                itemBuilder: (_, i) => _buildRow(items[i]),
              ),
            ),
            if (_activeFilter == 'all' && _ctrl.totalPages.value > 1)
              _buildPagination(),
          ],
        ),
      );
    });
  }

  // ── Row ───────────────────────────────────────────────────────────────────

  Widget _buildRow(CollectionModel c) {
    final dateStr = DateFormat('MMM dd, yyyy').format(c.collectionDate);
    final hasDisp = c.dispatcherSignature?.isNotEmpty ?? false;
    final hasColl = c.collectorSignature?.isNotEmpty ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showCollectionDialog(collection: c),
        hoverColor: const Color(0xFF3498DB).withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          child: Row(
            children: [
              // Client
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3498DB).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business,
                          size: 16, color: Color(0xFF3498DB)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.client.clientName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (c.boxDescription?.isNotEmpty == true)
                            Text(c.boxDescription!,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black.withOpacity(0.45)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Date
              Expanded(
                flex: 2,
                child: Text(dateStr,
                    style: TextStyle(
                        fontSize: 13, color: Colors.black.withOpacity(0.65))),
              ),

              // Boxes
              SizedBox(
                width: 70,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF52BE80).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF52BE80).withOpacity(0.4)),
                    ),
                    child: Text('${c.totalBoxes}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF27AE60))),
                  ),
                ),
              ),

              // Staff
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _staffLine(Icons.local_shipping_outlined, c.dispatcherName),
                    const SizedBox(height: 2),
                    _staffLine(Icons.person_outline, c.collectorName),
                  ],
                ),
              ),

              // Signatures
              SizedBox(
                width: 100,
                child: Row(
                  children: [
                    _sigBadge('D', hasDisp),
                    const SizedBox(width: 4),
                    _sigBadge('C', hasColl),
                  ],
                ),
              ),

              // Actions
              SizedBox(
                width: 96,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _actionBtn(
                        Icons.visibility_outlined,
                        const Color(0xFF3498DB),
                        'View',
                        () => _showCollectionDialog(collection: c)),
                    if (_ctrl.canEditCollections)
                      _actionBtn(
                          Icons.edit_outlined,
                          const Color(0xFFE67E22),
                          'Edit',
                          () => _showCollectionDialog(
                              collection: c, isEditing: true)),
                    if (_ctrl.canDeleteCollections)
                      _actionBtn(Icons.delete_outline, const Color(0xFFE74C3C),
                          'Delete', () => _confirmDelete(c)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _staffLine(IconData icon, String name) => Row(
        children: [
          Icon(icon, size: 11, color: Colors.black38),
          const SizedBox(width: 4),
          Flexible(
            child: Text(name,
                style: TextStyle(
                    fontSize: 11, color: Colors.black.withOpacity(0.6)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );

  Widget _sigBadge(String label, bool signed) {
    final color = signed ? Colors.green : Colors.grey;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(signed ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 9, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: signed ? Colors.green.shade700 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, Color color, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  // ── Pagination ────────────────────────────────────────────────────────────

  Widget _buildPagination() {
    return Obx(() {
      final cur = _ctrl.currentPage.value;
      final total = _ctrl.totalPages.value;
      final totalItems = _ctrl.totalCollections.value;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border:
              Border(top: BorderSide(color: Colors.black.withOpacity(0.08))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side: "Show X per page" dropdown
            Row(
              children: [
                Text('Show:',
                    style: TextStyle(
                        fontSize: 13, color: Colors.black.withOpacity(0.6))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButton<int>(
                    value: _itemsPerPage.value,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    onChanged: (newLimit) async {
                      if (newLimit != null && newLimit != _itemsPerPage.value) {
                        _itemsPerPage.value = newLimit;
                        await _ctrl.getAllCollections(page: 1, limit: newLimit);
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 20, child: Text('20')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                      DropdownMenuItem(value: 100, child: Text('100')),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('per page',
                    style: TextStyle(
                        fontSize: 13, color: Colors.black.withOpacity(0.6))),
              ],
            ),

            // Right side: page numbers + total
            Row(
              children: [
                // Page buttons (simplified, but existing logic works)
                _pageBtn(
                    Icons.first_page,
                    cur > 1,
                    () => _ctrl.getAllCollections(
                        page: 1, limit: _itemsPerPage.value)),
                _pageBtn(Icons.chevron_left, cur > 1,
                    () => _ctrl.loadPreviousPage(limit: _itemsPerPage.value)),
                ..._buildPageNumbers(cur, total),
                _pageBtn(Icons.chevron_right, cur < total,
                    () => _ctrl.loadNextPage(limit: _itemsPerPage.value)),
                _pageBtn(
                    Icons.last_page,
                    cur < total,
                    () => _ctrl.getAllCollections(
                        page: total, limit: _itemsPerPage.value)),
                const SizedBox(width: 12),
                Text(
                    'Total: $totalItems ${totalItems == 1 ? 'collection' : 'collections'}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.black.withOpacity(0.45))),
              ],
            ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildPageNumbers(int current, int total) {
    List<Widget> pages = [];
    for (int i = 1; i <= total; i++) {
      if (i == 1 || i == total || (i >= current - 1 && i <= current + 1)) {
        pages.add(_pageNumberButton(i, current == i));
      } else if (i == current - 2 || i == current + 2) {
        pages.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child:
              Text('…', style: TextStyle(fontSize: 13, color: Colors.black38)),
        ));
      }
    }
    return pages;
  }

  Widget _pageNumberButton(int pageNum, bool active) {
    return GestureDetector(
      onTap: active
          ? null
          : () => _ctrl.getAllCollections(
              page: pageNum, limit: _itemsPerPage.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3498DB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF3498DB) : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            '$pageNum',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageBtn(IconData icon, bool enabled, VoidCallback cb) {
    return GestureDetector(
      onTap: enabled ? cb : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: enabled ? Colors.grey.shade300 : Colors.grey.shade200),
        ),
        child: Icon(icon,
            size: 17, color: enabled ? Colors.black45 : Colors.grey.shade300),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COLLECTION DIALOG
  // ══════════════════════════════════════════════════════════════════════════

  void _showCollectionDialog(
      {CollectionModel? collection, bool isEditing = false}) {
    _selectedClientId = collection?.client.clientId;
    _selectedCollectorUserId = null;
    _selectedDate = collection?.collectionDate ?? DateTime.now();
    _descCtrl.text = collection?.boxDescription ?? '';
    _dispSigBase64 = collection?.dispatcherSignature;
    _collSigBase64 = collection?.collectorSignature;
    _selectedBoxes.clear();
    _collectionBoxes.clear();

    if (_selectedClientId != null) {
      _loadClientUsers(_selectedClientId!);
      if (collection == null) _loadClientBoxes(_selectedClientId!);
    }

    final isView = collection != null && !isEditing;
    final isCreate = collection == null;
    final isEdit = collection != null && isEditing;

    // If viewing, parse box numbers from description
    if (isView && collection != null) {
      _loadCollectionBoxes(collection);
    }

    showDialog(
      context: context,
      barrierDismissible: !isCreate,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            children: [
              // Header (matching retrieval dialog)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF3498DB), Color(0xFF2980B9)]),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isView
                            ? 'View Collection'
                            : isEdit
                                ? 'Edit Collection'
                                : 'New Collection',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Form body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client & Staff section
                      _buildDialogSectionHeader('Client & Staff'),
                      const SizedBox(height: 12),
                      Obx(() => ClientSearchField(
                            clients: clientCtrl.clients,
                            selectedClientId: _selectedClientId,
                            isLoading: clientCtrl.isLoading.value,
                            enabled: !isView,
                            label: 'Client *',
                            onChanged: (v) {
                              setState(() {
                                _selectedClientId = v;
                                _selectedCollectorUserId = null;
                                _selectedBoxes.clear();
                              });
                              if (v != null) {
                                _loadClientUsers(v);
                                _loadClientBoxes(v);
                              }
                            },
                          )),
                      const SizedBox(height: 14),
                      Obx(() {
                        if (_loadingUsers.value) {
                          return const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator()));
                        }
                        if (isView && collection != null) {
                          return InputDecorator(
                            decoration: _dialogInputDecoration(
                                'Collector', Icons.person),
                            child: Text(collection.collectorName,
                                style:
                                    const TextStyle(color: Color(0xFF2C3E50))),
                          );
                        }
                        return DropdownButtonFormField<int>(
                          value: _selectedCollectorUserId,
                          decoration:
                              _dialogInputDecoration('Collector', Icons.person),
                          items: _clientUsers
                              .map((u) => DropdownMenuItem(
                                  value: u.userId, child: Text(u.username)))
                              .toList(),
                          onChanged: isView
                              ? null
                              : (v) =>
                                  setState(() => _selectedCollectorUserId = v),
                        );
                      }),
                      if (isView && collection != null) ...[
                        const SizedBox(height: 14),
                        InputDecorator(
                          decoration: _dialogInputDecoration(
                              'Dispatcher', Icons.local_shipping),
                          child: Text(collection.dispatcherName,
                              style: const TextStyle(color: Color(0xFF2C3E50))),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildDialogDivider('Collection Details'),
                      const SizedBox(height: 16),
                      // Date picker
                      InkWell(
                        onTap: isView
                            ? null
                            : () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 1)),
                                  builder: (ctx, child) => Theme(
                                    data: Theme.of(ctx).copyWith(
                                        colorScheme: const ColorScheme.light(
                                            primary: Color(0xFF3498DB))),
                                    child: child!,
                                  ),
                                );
                                if (d != null && mounted)
                                  setState(() => _selectedDate = d);
                              },
                        child: InputDecorator(
                          decoration: _dialogInputDecoration(
                              'Collection Date', Icons.calendar_today),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDate != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(_selectedDate!)
                                    : 'Select date',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: _selectedDate != null
                                        ? const Color(0xFF2C3E50)
                                        : Colors.grey[500]),
                              ),
                              if (!isView)
                                Icon(Icons.calendar_today,
                                    size: 16, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _descCtrl,
                        enabled: !isView,
                        decoration: _dialogInputDecoration(
                            isView ? 'Description' : 'Notes (Optional)',
                            Icons.notes),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      // Boxes section
                      if (isCreate) ...[
                        _buildDialogSectionHeader('Select Boxes to Collect'),
                        const SizedBox(height: 12),
                        Obx(() {
                          if (_loadingBoxes.value) {
                            return const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator()));
                          }
                          if (_clientBoxes.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!)),
                              child: Center(
                                child: Text(
                                  _selectedClientId == null
                                      ? 'Select a client to see available boxes'
                                      : 'No stored boxes for this client',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 13),
                                ),
                              ),
                            );
                          }
                          return Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12)),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _clientBoxes.length,
                              itemBuilder: (_, i) {
                                final box = _clientBoxes[i];
                                return Obx(() => CheckboxListTile(
                                      dense: true,
                                      value: _isBoxSelected(box),
                                      onChanged: (_) => _toggleBox(box),
                                      title: Text(box.boxNumber,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14)),
                                      subtitle: Text(box.description,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500])),
                                      activeColor: const Color(0xFF3498DB),
                                    ));
                              },
                            ),
                          );
                        }),
                        Obx(() {
                          final count = _selectedBoxes.length;
                          if (count == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                                '$count box${count == 1 ? '' : 'es'} selected',
                                style: const TextStyle(
                                    color: Color(0xFF3498DB),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          );
                        }),
                      ] else if (isView) ...[
                        _buildDialogSectionHeader('Boxes in this Collection'),
                        const SizedBox(height: 12),
                        Obx(() {
                          if (_loadingCollectionBoxes.value) {
                            return const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator()));
                          }
                          if (_collectionBoxes.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!)),
                              child: Center(
                                  child: Text(
                                      'No boxes associated with this collection',
                                      style:
                                          TextStyle(color: Colors.grey[500]))),
                            );
                          }
                          return Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12)),
                            child: ListView.separated(
                              itemCount: _collectionBoxes.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, indent: 16, endIndent: 16),
                              itemBuilder: (_, i) {
                                final box = _collectionBoxes[i];
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 0),
                                  leading: const Icon(Icons.inbox,
                                      color: Color(0xFF3498DB), size: 18),
                                  title: Text(box.boxNumber,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14)),
                                  subtitle: Text(
                                      box.description.isNotEmpty
                                          ? box.description
                                          : box.description,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500])),
                                );
                              },
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 24),
                      _buildDialogDivider('Signatures'),
                      const SizedBox(height: 16),
                      if (isView)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildSignatureViewCard(
                                  'Dispatcher Signature', _dispSigBase64),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSignatureViewCard(
                                  'Collector Signature', _collSigBase64),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildSignatureSection(
                              title:
                                  'Dispatcher Signature${isCreate ? '  (required)' : ''}',
                              b64: _dispSigBase64,
                              isView: isView,
                              onCapture: () => _captureSig(
                                  context,
                                  'Dispatcher Signature',
                                  _dispSigCtrl,
                                  (b) => setState(() => _dispSigBase64 = b)),
                              onClear: () =>
                                  setState(() => _dispSigBase64 = null),
                              required: isCreate,
                            ),
                            const SizedBox(height: 20),
                            _buildSignatureSection(
                              title: 'Collector Signature  (optional)',
                              b64: _collSigBase64,
                              isView: isView,
                              onCapture: () => _captureSig(
                                  context,
                                  'Collector Signature',
                                  _collSigCtrl,
                                  (b) => setState(() => _collSigBase64 = b)),
                              onClear: () =>
                                  setState(() => _collSigBase64 = null),
                              required: false,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              // Footer (only if not view)
              if (!isView)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: Colors.grey[300]!))),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFF3498DB)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(
                                  color: Color(0xFF3498DB),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleSave(collection),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498DB),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                              isEdit
                                  ? 'Update Collection'
                                  : 'Create Collection',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50)));
  }

  Widget _buildDialogDivider(String label) {
    return Row(children: [
      Expanded(child: Divider(color: Colors.grey.shade300)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
      ),
      Expanded(child: Divider(color: Colors.grey.shade300)),
    ]);
  }

  InputDecoration _dialogInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF3498DB), size: 20),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3498DB))),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildSignatureSection({
    required String title,
    required String? b64,
    required bool isView,
    required VoidCallback onCapture,
    required VoidCallback onClear,
    required bool required,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (required)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200)),
              child: Text('Required',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600)),
            ),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50))),
        ]),
        const SizedBox(height: 8),
        Container(
          height: 130,
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
              color: b64 != null ? Colors.white : Colors.grey[50]),
          child: _sigImage(b64),
        ),
        if (!isView) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.draw, size: 16),
                  label: Text(b64 != null ? 'Change' : 'Capture'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3498DB),
                    side: const BorderSide(color: Color(0xFF3498DB)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              if (b64 != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSignatureViewCard(String title, String? b64) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50))),
        const SizedBox(height: 8),
        Container(
          height: 130,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: b64 != null ? Colors.white : Colors.grey[50],
          ),
          child: _sigImage(b64),
        ),
      ],
    );
  }

  // ── Dialog helpers ─────────────────────────────────────────────────────────

  Widget _sigImage(String? b64) {
    if (b64 == null || b64.isEmpty) {
      return Center(
          child: Text('No signature',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)));
    }
    try {
      String clean = b64.contains('base64,')
          ? b64.split('base64,').last.trim()
          : b64.trim();
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(base64Decode(clean),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.error_outline, color: Colors.red, size: 32))),
      );
    } catch (_) {
      return Center(
          child: Text('Could not render signature',
              style: TextStyle(color: Colors.grey[400], fontSize: 12)));
    }
  }

  Future<void> _captureSig(
    BuildContext ctx,
    String title,
    SignatureController ctrl,
    Function(String) onSave,
  ) async {
    ctrl.clear();
    final result = await showDialog<String>(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF3498DB), Color(0xFF2475A8)]),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18)),
                ),
                child: Row(children: [
                  const Icon(Icons.draw, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Signature(
                            controller: ctrl, backgroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: ctrl.clear,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Clear'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[300]!),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 11),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                        ),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (ctrl.isEmpty) {
                              _err('Please draw a signature');
                              return;
                            }
                            final bytes = await ctrl.toPngBytes();
                            if (bytes != null) {
                              Navigator.pop(ctx, base64Encode(bytes));
                            }
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3498DB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 11),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) onSave(result);
  }

  // ── Save handler ──────────────────────────────────────────────────────────

  Future<void> _handleSave(CollectionModel? existing) async {
    if (_selectedClientId == null) {
      _err('Please select a client');
      return;
    }
    if (_selectedDate == null) {
      _err('Please select a date');
      return;
    }
    if (_selectedCollectorUserId == null) {
      _err('Please select a collector');
      return;
    }
    if (existing == null && _selectedBoxes.isEmpty) {
      _err('Please select at least one box');
      return;
    }
    if (existing == null && _dispSigBase64 == null) {
      _err('Dispatcher signature is required');
      return;
    }

    try {
      final dispatcher = _auth.currentUser.value?.username ?? 'Unknown';
      final collector = _clientUsers
          .firstWhere((u) => u.userId == _selectedCollectorUserId)
          .username;

      if (existing == null) {
        final boxNums = _selectedBoxes.map((b) => b.boxNumber).join(', ');
        final desc = 'Boxes: $boxNums'
            '${_descCtrl.text.isNotEmpty ? '\nNotes: ${_descCtrl.text}' : ''}';

        final ok = await _ctrl.createCollection(CreateCollectionRequest(
          clientId: _selectedClientId!,
          totalBoxes: _selectedBoxes.length,
          boxDescription: desc,
          dispatcherName: dispatcher,
          collectorName: collector,
          collectionDate: DateFormat('yyyy-MM-dd').format(_selectedDate!),
          dispatcherSignature: _dispSigBase64,
          collectorSignature: _collSigBase64,
        ));
        if (ok && mounted) Navigator.pop(context);
      } else {
        final ok = await _ctrl.updateCollection(
          existing.collectionId,
          UpdateCollectionRequest(
            totalBoxes: existing.totalBoxes,
            boxDescription: _descCtrl.text.isNotEmpty
                ? _descCtrl.text
                : existing.boxDescription,
            dispatcherName: dispatcher,
            collectorName: collector,
            collectionDate: DateFormat('yyyy-MM-dd').format(_selectedDate!),
            dispatcherSignature: _dispSigBase64,
            collectorSignature: _collSigBase64,
          ),
        );
        if (ok && mounted) Navigator.pop(context);
      }
    } catch (e) {
      _err('Error saving collection: $e');
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  void _confirmDelete(CollectionModel c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Collection'),
        content: Text(
          'Delete collection for ${c.client.clientName} on '
          '${DateFormat('MMM dd, yyyy').format(c.collectionDate)}?\n\n'
          'This cannot be undone.',
          style: TextStyle(color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _ctrl.deleteCollection(c.collectionId);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Reports & Statistics ───────────────────────────────────────────────────

  void _showReportsDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                    color: Color(0xFF2C3E50),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18))),
                child: const Row(children: [
                  Icon(Icons.summarize, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Collection Reports',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _reportOption(Icons.summarize, const Color(0xFF3498DB),
                        'Summary Report', 'Overall collection statistics', () {
                      Navigator.pop(context);
                      _generateSummary();
                    }),
                    const SizedBox(height: 10),
                    _reportOption(
                        Icons.business,
                        const Color(0xFF2ECC71),
                        'By Client Report',
                        'Collections grouped by client', () {
                      Navigator.pop(context);
                      _generateClientReport();
                    }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportOption(IconData icon, Color color, String title, String sub,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50))),
                  Text(sub,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showStatisticsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF3498DB))),
              const SizedBox(height: 18),
              Text('Loading statistics…',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );

    await _ctrl.getCollectionStatistics();
    if (!mounted) return;
    Navigator.pop(context);

    final stats = _ctrl.collectionStats.value;
    if (stats == null) {
      _err('Failed to load statistics');
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                    color: Color(0xFF3498DB),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18))),
                child: const Row(children: [
                  Icon(Icons.analytics, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Collection Statistics',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _statRow('Total Collections', '${stats.totalCollections}',
                          Icons.inventory_2),
                      _statRow('Total Boxes Collected',
                          '${stats.totalBoxesCollected}', Icons.widgets),
                      _statRow('Clients with Collections',
                          '${stats.clientsWithCollections}', Icons.business),
                      _statRow('Collections Today', '${stats.todayCollections}',
                          Icons.today),
                      _statRow('Collections This Week',
                          '${stats.thisWeekCollections}', Icons.date_range),
                      _statRow(
                          'Collections This Month',
                          '${stats.thisMonthCollections}',
                          Icons.calendar_month),
                    ].expand((w) => [w, const SizedBox(height: 10)]).toList()
                      ..removeLast(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3498DB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFF3498DB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: const Color(0xFF3498DB), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF2C3E50)))),
          Text(value,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50))),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Export Data'),
        content: Text('Export collection data as CSV, Excel, or PDF.',
            style: TextStyle(color: Colors.grey[600])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _ok('Export feature coming soon');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                foregroundColor: Colors.white),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _generateSummary() async {
    await _ctrl.getSummaryReport(
      startDate: _filterStart != null
          ? DateFormat('yyyy-MM-dd').format(_filterStart!)
          : null,
      endDate: _filterEnd != null
          ? DateFormat('yyyy-MM-dd').format(_filterEnd!)
          : null,
      clientId: _selectedClientId,
    );
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader('Summary Report', Icons.summarize),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: GetBuilder<CollectionController>(
                    builder: (c) => c.summaryReport.isEmpty
                        ? Center(
                            child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text('No data for selected period',
                                    style: TextStyle(color: Colors.grey[500]))))
                        : Column(
                            children: c.summaryReport
                                .map((s) => Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: Colors.grey[200]!)),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(s.date.toString(),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF2C3E50))),
                                          const SizedBox(height: 8),
                                          Row(children: [
                                            _rStat('Collections',
                                                '${s.collectionCount}'),
                                            _rStat('Boxes', '${s.totalBoxes}'),
                                            _rStat('Clients',
                                                '${s.uniqueClients}'),
                                          ]),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                  ),
                ),
              ),
              _dialogClose(),
            ],
          ),
        ),
      ),
    );
  }

  void _generateClientReport() async {
    await _ctrl.getByClientReport(
      startDate: _filterStart != null
          ? DateFormat('yyyy-MM-dd').format(_filterStart!)
          : null,
      endDate: _filterEnd != null
          ? DateFormat('yyyy-MM-dd').format(_filterEnd!)
          : null,
    );
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader('By Client Report', Icons.business),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: GetBuilder<CollectionController>(
                    builder: (c) => c.clientReport.isEmpty
                        ? Center(
                            child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text('No data for selected period',
                                    style: TextStyle(color: Colors.grey[500]))))
                        : Column(
                            children: c.clientReport
                                .map((r) => Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: Colors.grey[200]!)),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(r.clientName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF2C3E50))),
                                          Text(r.clientCode,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500])),
                                          const SizedBox(height: 10),
                                          Row(children: [
                                            _rStat('Collections',
                                                '${r.collectionCount}'),
                                            _rStat('Boxes',
                                                '${r.totalBoxesCollected}'),
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  Text('Last',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey[500])),
                                                  Text(
                                                      r.lastCollectionDate ??
                                                          '—',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF2C3E50))),
                                                ],
                                              ),
                                            ),
                                          ]),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                  ),
                ),
              ),
              _dialogClose(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogHeader(String title, IconData icon) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: Color(0xFF2C3E50),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18))),
        child: Row(children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ]),
      );

  Widget _dialogClose() => Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Close'),
          ),
        ),
      );

  Widget _rStat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3498DB))),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      );

  // ── Client data loaders ───────────────────────────────────────────────────

  Future<void> _loadClientUsers(int clientId) async {
    try {
      _loadingUsers.value = true;
      _clientUsers.clear();
      _selectedCollectorUserId = null;

      final res = await http.get(
        Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.usersByClient(clientId.toString())}'),
        headers: _auth.getAuthHeaders(),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success') {
          _clientUsers.value = (data['data']['users'] as List)
              .map((u) => UserModel.fromJson(u))
              .toList();
        }
      }
    } catch (e) {
      _err('Error loading users: $e');
    } finally {
      _loadingUsers.value = false;
    }
  }

  Future<void> _loadClientBoxes(int clientId) async {
    try {
      _loadingBoxes.value = true;
      _clientBoxes.clear();
      _selectedBoxes.clear();

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.boxes}')
          .replace(queryParameters: {
        'clientId': clientId.toString(),
        'status': 'stored',
        'limit': '1000',
        'page': '1',
      });

      final res = await http.get(uri, headers: _auth.getAuthHeaders());

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success' && data['data'] != null) {
          _clientBoxes.value = (data['data']['boxes'] as List)
              .map((b) => BoxModel.fromJson(b))
              .toList();
        }
      }
    } catch (e) {
      _err('Error loading boxes: $e');
    } finally {
      _loadingBoxes.value = false;
    }
  }

  void _toggleBox(BoxModel box) {
    final i = _selectedBoxes.indexWhere((b) => b.boxId == box.boxId);
    if (i >= 0)
      _selectedBoxes.removeAt(i);
    else
      _selectedBoxes.add(box);
  }

  bool _isBoxSelected(BoxModel box) =>
      _selectedBoxes.any((b) => b.boxId == box.boxId);

  // ── Snackbars ─────────────────────────────────────────────────────────────
  void _ok(String msg) => Get.snackbar('Success', msg,
      backgroundColor: const Color(0xFF27AE60),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12);

  void _err(String msg) => Get.snackbar('Error', msg,
      backgroundColor: const Color(0xFFE74C3C),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12);
}

// Helper widget for column headers (const-constructible)
class _HCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _HCell(this.text, {this.align = TextAlign.start});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: align,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.black.withOpacity(0.45),
          letterSpacing: 0.4));
}