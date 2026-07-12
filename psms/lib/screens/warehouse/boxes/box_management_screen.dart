// box_management_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as exl;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/box_controller.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/controllers/storage_controller.dart';
import 'package:psms/models/box_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'box_report_dialog.dart';
import 'widgets/box_dialog.dart';
import 'widgets/box_details_dialog.dart';
import 'widgets/box_import_dialog.dart';
import 'widgets/box_qr_payload.dart';
import 'widgets/box_stats_dialog.dart';
import 'widgets/client_search_field.dart';
import 'widgets/qr_scanner_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kAccent = Color(0xFF3498DB);
const _kPrimary = Color(0xFF2C3E50);
const _kBg = Color(0xFFF4F6F9);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

String _getStaticBaseUrl() {
  String base = ApiConstants.baseUrl;
  if (base.endsWith('/api')) {
    return base.substring(0, base.length - 4);
  }
  if (base.endsWith('/api/')) {
    return base.substring(0, base.length - 5);
  }
  return base;
}

class BoxManagementScreen extends StatefulWidget {
  const BoxManagementScreen({super.key});

  @override
  State<BoxManagementScreen> createState() => _BoxManagementScreenState();
}

class _BoxManagementScreenState extends State<BoxManagementScreen>
    with SingleTickerProviderStateMixin {
  final BoxController boxCtrl = Get.put(BoxController());
  final AuthController authCtrl = Get.find<AuthController>();
  final StorageController storageCtrl = Get.put(StorageController());
  // Same controller BoxDialog/showReportOptionsDialog use for client
  // pickers — reuse the existing instance if the app already registered
  // one, so filter/pagination state elsewhere isn't clobbered.
  late final ClientManagementController clientCtrl;

  late TabController _tabCtrl;

  // Search
  final _searchCtrl = TextEditingController();
  bool _searchExpanded = false;
  final _searchFocus = FocusNode();

  // View / filter state
  int _viewMode = 0; // 0 = table, 1 = grid
  String _selectedStatus = 'all';
  int? _selectedClientId;
  bool _showPendingOnly = false;
  bool _showFilters = false;

  // Selection
  final Set<int> _selectedBoxes = {};
  bool _isSelectMode = false;

  // Pagination — always use explicit page navigation (not infinite scroll)
  final ScrollController _scrollCtrl = ScrollController();

  // Hardware barcode/QR scanner (keyboard-wedge) support — see
  // _handleHardwareKey for details. Works on every platform, including
  // Windows/Linux desktop where mobile_scanner has no native camera impl.
  String _scanBuffer = '';
  DateTime? _lastScanKeyTime;
  static const _scanKeyGapMs = 60; // faster than any sustained human typing
  static const _minScanLength = 4;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);

    clientCtrl = Get.isRegistered<ClientManagementController>()
        ? Get.find<ClientManagementController>()
        : Get.put(ClientManagementController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      boxCtrl.initialize();
      storageCtrl.initialize();
      boxCtrl.getAllBoxes();
      _loadClients();
    });
  }

  Future<void> _loadClients() async {
    // fetchClients() is paginated (20/page by default) — bump the page
    // size so this one call returns every client for the filter dropdown,
    // instead of just the first page.
    clientCtrl.itemsPerPage.value = 1000;
    await clientCtrl.fetchClients(showLoading: true);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: _isSelectMode ? _buildBulkBar() : null,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APP BAR — persistent search bar on desktop/tablet
  // ─────────────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    final isWide = MediaQuery.of(context).size.width > 720;

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      title: isWide
          // ── Wide: title + inline search bar ──
          ? Row(
              children: [
                Obx(() => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Box Management',
                            style: TextStyle(
                                color: _kPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18)),
                        Text('${boxCtrl.totalBoxes.value} boxes',
                            style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.w400)),
                      ],
                    )),
                const SizedBox(width: 24),
                // Persistent search bar
                Flexible(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search box number, description, client…',
                        hintStyle:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search,
                            size: 18, color: Colors.grey),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close,
                                    size: 16, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _applyFilter();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: _kBg,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: _kAccent, width: 1.5),
                        ),
                      ),
                      onChanged: (v) {
                        setState(() {});
                        // Debounce: call on submit / enter
                      },
                      onSubmitted: (v) => _applyFilter(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner,
                      color: _kPrimary, size: 20),
                  tooltip: 'Find by QR Code',
                  onPressed: _scanQrToFindBox,
                ),
              ],
            )
          // ── Narrow: title only (search in actions) ──
          : Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Box Management',
                      style: TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                  Text('${boxCtrl.totalBoxes.value} boxes',
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              )),
      actions: _buildActions(isWide),
      bottom: _buildTabBar(),
    );
  }

  List<Widget> _buildActions(bool isWide) {
    return [
      // On narrow: show search icon that expands, plus a dedicated QR scan
      // entry point (wide layout gets its scan icon inline next to the
      // persistent search field instead — see _buildAppBar).
      if (!isWide) ...[
        IconButton(
          icon: const Icon(Icons.search, color: _kPrimary),
          onPressed: _showSearchSheet,
        ),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner, color: _kPrimary),
          tooltip: 'Find by QR Code',
          onPressed: _scanQrToFindBox,
        ),
      ],
      IconButton(
        icon: const Icon(Icons.bar_chart, color: _kPrimary),
        tooltip: 'Stats',
        onPressed: () => showDialog(
            context: context, builder: (_) => const BoxStatsDialog()),
      ),
      IconButton(
        icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            color: _showFilters ? _kAccent : _kPrimary),
        tooltip: 'Filters',
        onPressed: () => setState(() => _showFilters = !_showFilters),
      ),
      IconButton(
        icon: Icon(_viewMode == 0 ? Icons.grid_view : Icons.table_chart,
            color: _kPrimary),
        tooltip: _viewMode == 0 ? 'Grid view' : 'Table view',
        onPressed: () => setState(() => _viewMode = _viewMode == 0 ? 1 : 0),
      ),
      IconButton(
        icon: Icon(_isSelectMode ? Icons.deselect : Icons.select_all,
            color: _kPrimary),
        tooltip: 'Select mode',
        onPressed: () => setState(() {
          _isSelectMode = !_isSelectMode;
          if (!_isSelectMode) _selectedBoxes.clear();
        }),
      ),
      IconButton(
        icon: const Icon(Icons.refresh, color: _kPrimary),
        tooltip: 'Refresh',
        onPressed: () {
          boxCtrl.initialize();
          storageCtrl.initialize();
        },
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: _kPrimary),
        onSelected: _handleAppBarAction,
        itemBuilder: (_) => [
          const PopupMenuItem(
              value: 'print',
              child: ListTile(
                  leading: Icon(Icons.print),
                  title: Text('Print/Export Report'))),
          const PopupMenuItem(
              value: 'import',
              child: ListTile(
                  leading: Icon(Icons.upload),
                  title: Text('Import from Excel'))),
        ],
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BODY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return Column(
      children: [
        if (_showFilters) _buildFilterPanel(),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildContentView(),
              _buildContentView(),
              _buildContentView(),
              _buildPendingDestructionView(),
            ],
          ),
        ),
        // Pagination footer — outside the scroll area, never hidden
        AnimatedBuilder(
          animation: _tabCtrl,
          builder: (_, __) => _tabCtrl.index == 3
              ? const SizedBox.shrink()
              : _buildPaginationBar(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTENT VIEW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContentView() {
    return Obx(() {
      if (boxCtrl.isLoading.value && boxCtrl.boxes.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: _kAccent));
      }
      if (boxCtrl.boxes.isEmpty) return _buildEmptyState();
      return _viewMode == 0 ? _buildTableView() : _buildGridView();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TABLE VIEW — slim rows, no cards
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTableView() {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          _buildSlimTableHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => boxCtrl.getAllBoxes(refresh: true),
              color: _kAccent,
              child: Obx(() {
                final boxes = boxCtrl.boxes;
                return ListView.builder(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: boxes.length,
                  itemBuilder: (_, i) => _buildSlimRow(boxes[i]),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlimTableHeader() {
    return Container(
      height: 36,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (_isSelectMode) const SizedBox(width: 40),
          Expanded(flex: 2, child: _hdr('Box Number')),
          Expanded(flex: 3, child: _hdr('Description')),
          Expanded(flex: 2, child: _hdr('Client')),
          Expanded(flex: 2, child: _hdr('Status')),
          Expanded(flex: 2, child: _hdr('Location')),
          Expanded(flex: 1, child: _hdr('Actions')),
          // const SizedBox(width: 96),
        ],
      ),
    );
  }

  Widget _hdr(String t) => Text(t,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
          letterSpacing: 0.5));

  Widget _buildSlimRow(BoxModel box) {
    final isSelected = _selectedBoxes.contains(box.boxId);
    final statusColor = _statusColor(box.status);

    return InkWell(
      onTap: () {
        if (_isSelectMode) {
          setState(() => isSelected
              ? _selectedBoxes.remove(box.boxId)
              : _selectedBoxes.add(box.boxId));
        } else {
          _showBoxDetails(box);
        }
      },
      onLongPress: () => setState(() {
        _isSelectMode = true;
        _selectedBoxes.add(box.boxId);
      }),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? _kAccent.withOpacity(0.06) : Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100),
            left: BorderSide(
                color: isSelected ? _kAccent : Colors.transparent, width: 3),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (_isSelectMode)
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: isSelected,
                  activeColor: _kAccent,
                  onChanged: (v) => setState(() => v == true
                      ? _selectedBoxes.add(box.boxId)
                      : _selectedBoxes.remove(box.boxId)),
                ),
              ),
            // Box number + date
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(box.boxNumber,
                      style: const TextStyle(
                          color: _kAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text(DateFormat('dd MMM yyyy').format(box.dateReceived),
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            // Description
            Expanded(
              flex: 3,
              child: Text(
                box.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: _kPrimary),
              ),
            ),
            // Client
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(box.client.clientCode,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: _kPrimary)),
                  Text(box.client.clientName,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Status pill
            Expanded(
              flex: 2,
              child: _statusPill(box.status),
            ),
            // Location
            Expanded(
              flex: 2,
              child: Text(
                box.rackingLabel?.location ?? 'Unassigned',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: box.rackingLabel != null
                        ? Colors.grey[700]
                        : Colors.grey[400]),
              ),
            ),
            // Actions
            Expanded(
              flex: 2,
              child: _rowActions(box),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowActions(BoxModel box) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _iconBtn(Icons.visibility_outlined, () => _showBoxDetails(box),
            tooltip: 'View'),
        if (authCtrl.hasPermission('canEditBoxes'))
          _iconBtn(Icons.edit_outlined, () => _editBox(box), tooltip: 'Edit'),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18, color: _kPrimary),
          onSelected: (v) => _handleBoxAction(v, box),
          itemBuilder: (_) => _boxMenuItems(box),
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {String? tooltip}) {
    return IconButton(
      icon: Icon(icon, size: 18, color: _kAccent),
      onPressed: onTap,
      tooltip: tooltip,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GRID VIEW — compact cards with image
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGridView() {
    return RefreshIndicator(
      onRefresh: () => boxCtrl.getAllBoxes(refresh: true),
      color: _kAccent,
      child: Obx(() {
        final boxes = boxCtrl.boxes;
        final cols = MediaQuery.of(context).size.width > 1200
            ? 5
            : MediaQuery.of(context).size.width > 900
                ? 4
                : MediaQuery.of(context).size.width > 600
                    ? 3
                    : 2;

        return GridView.builder(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 200, // ← fixed height — no overflow
          ),
          itemCount: boxes.length,
          itemBuilder: (_, i) => _buildCompactCard(boxes[i]),
        );
      }),
    );
  }

  Widget _buildCompactCard(BoxModel box) {
    final isSelected = _selectedBoxes.contains(box.boxId);
    final statusColor = _statusColor(box.status);

    return GestureDetector(
      onTap: () {
        if (_isSelectMode) {
          setState(() => isSelected
              ? _selectedBoxes.remove(box.boxId)
              : _selectedBoxes.add(box.boxId));
        } else {
          _showBoxDetails(box);
        }
      },
      onLongPress: () => setState(() {
        _isSelectMode = true;
        _selectedBoxes.add(box.boxId);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? _kAccent : Colors.grey.shade200,
              width: isSelected ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status colour bar + image area
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
              child: SizedBox(
                height: 72,
                width: double.infinity,
                child: box.boxImage != null
                    ? _boxImageWidget(box.boxImage!)
                    : Container(
                        color: statusColor.withOpacity(0.08),
                        child: Center(
                          child: Icon(Icons.inventory_2_outlined,
                              size: 32, color: statusColor.withOpacity(0.4)),
                        ),
                      ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(box.boxNumber,
                              style: const TextStyle(
                                  color: _kAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (_isSelectMode)
                          Transform.scale(
                            scale: 0.85,
                            child: Checkbox(
                              value: isSelected,
                              activeColor: _kAccent,
                              onChanged: (v) => setState(() => v == true
                                  ? _selectedBoxes.add(box.boxId)
                                  : _selectedBoxes.remove(box.boxId)),
                            ),
                          ),
                      ],
                    ),
                    Text(box.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey, height: 1.2)),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.business, size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(box.client.clientCode,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _statusPill(box.status, small: true),
                        Text(DateFormat('dd/MM/yy').format(box.dateReceived),
                            style: const TextStyle(
                                fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boxImageWidget(String imagePath) {
    try {
      // If it's already a full URL, use it
      if (imagePath.startsWith('http')) {
        return Image.network(imagePath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imagePlaceholder());
      }
      // If it's a relative path (uploads/...), construct full URL
      if (imagePath.startsWith('uploads/')) {
        String baseUrl = _getStaticBaseUrl();
        if (baseUrl.endsWith('/')) {
          baseUrl = baseUrl.substring(0, baseUrl.length - 1);
        }
        String fullUrl = '$baseUrl/$imagePath';
        print('DEBUG: Loading image from: $fullUrl');
        return Image.network(fullUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              );
            },
            errorBuilder: (_, __, ___) => _imagePlaceholder());
      }
      // Fallback for base64 (old data)
      final bytes = base64Decode(
          imagePath.contains(',') ? imagePath.split(',').last : imagePath);
      return Image.memory(bytes,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imagePlaceholder());
    } catch (_) {
      return _imagePlaceholder();
    }
  }

  Widget _imagePlaceholder() => Container(
        color: Colors.grey.shade100,
        child: const Center(
          child:
              Icon(Icons.broken_image_outlined, size: 28, color: Colors.grey),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // BOX DETAILS DIALOG — professional, tabbed
  // ─────────────────────────────────────────────────────────────────────────

  void _showBoxDetails(BoxModel box) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: BoxDetailDialog(
          box: box,
          onEdit: authCtrl.hasPermission('canEditBoxes')
              ? () {
                  Navigator.pop(ctx);
                  _editBox(box);
                }
              : null,
          onStatusChange: (status) {
            Navigator.pop(ctx);
            _changeBoxStatus(box, status);
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE / EDIT BOX DIALOG — with image upload
  // ─────────────────────────────────────────────────────────────────────────

  void _showCreateBoxDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BoxDialog(),
    );
  }

  void _editBox(BoxModel box) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BoxDialog(box: box),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PENDING DESTRUCTION VIEW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPendingDestructionView() {
    return Obx(() {
      final boxes = boxCtrl.pendingDestructionBoxes;
      if (boxes.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
              SizedBox(height: 16),
              Text('No boxes pending destruction',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: boxes.length,
        itemBuilder: (_, i) {
          final box = boxes[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: Colors.orange, width: 4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(box.boxNumber,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: _kPrimary)),
                      Text('${box.client.clientName} · ${box.description}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      Text('Destruction year: ${box.destructionYear}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.red)),
                    ],
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.visibility_outlined,
                        color: _kAccent, size: 18),
                    onPressed: () => _showBoxDetails(box)),
                IconButton(
                    icon: const Icon(Icons.delete_forever,
                        color: Colors.red, size: 18),
                    onPressed: () => _markAsDestroyed(box)),
              ],
            ),
          );
        },
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGINATION BAR — always visible, never inside scroll
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPaginationBar() {
    return Obx(() {
      final page = boxCtrl.currentPage.value;
      final total = boxCtrl.totalPages.value;
      final count = boxCtrl.totalBoxes.value;

      return Container(
        height: 46,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Page info
            Text('Page $page of $total  ($count boxes)',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 16),
            // Rows per page
            const Text('Rows:',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: boxCtrl.pageSize.value,
                isDense: true,
                style: const TextStyle(fontSize: 12, color: _kPrimary),
                items: [10, 20, 50, 100]
                    .map((s) => DropdownMenuItem(value: s, child: Text('$s')))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  boxCtrl.pageSize.value = v;
                  _applyFilter(page: 1);
                },
              ),
            ),
            const SizedBox(width: 4),
            // Prev / page indicator / next
            IconButton(
              icon: const Icon(Icons.first_page, size: 18),
              color: page > 1 ? _kAccent : Colors.grey.shade300,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: page > 1 && !boxCtrl.isLoading.value
                  ? () => _applyFilter(page: 1)
                  : null,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 18),
              color: page > 1 ? _kAccent : Colors.grey.shade300,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: page > 1 && !boxCtrl.isLoading.value
                  ? () => _applyFilter(page: page - 1)
                  : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$page',
                  style: const TextStyle(
                      color: _kAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              color: page < total ? _kAccent : Colors.grey.shade300,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: page < total && !boxCtrl.isLoading.value
                  ? () => _applyFilter(page: page + 1)
                  : null,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.last_page, size: 18),
              color: page < total ? _kAccent : Colors.grey.shade300,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: page < total && !boxCtrl.isLoading.value
                  ? () => _applyFilter(page: total)
                  : null,
            ),
          ],
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTER PANEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFilterPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          const Text('Filter:',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: _kPrimary, fontSize: 13)),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              isDense: true,
              decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'stored', child: Text('Stored')),
                DropdownMenuItem(value: 'retrieved', child: Text('Retrieved')),
                DropdownMenuItem(value: 'destroyed', child: Text('Destroyed')),
              ],
              onChanged: (v) {
                setState(() => _selectedStatus = v ?? 'all');
                _applyFilter();
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 220,
            child: Obx(() => ClientSearchField(
                  clients: clientCtrl.clients,
                  selectedClientId: _selectedClientId,
                  isLoading: clientCtrl.isLoading.value,
                  allOptionLabel: 'All Clients',
                  label: 'Client',
                  onChanged: (v) {
                    setState(() => _selectedClientId = v);
                    _applyFilter();
                  },
                )),
          ),
          const SizedBox(width: 10),
          Row(
            children: [
              Checkbox(
                value: _showPendingOnly,
                activeColor: _kAccent,
                onChanged: (v) {
                  setState(() => _showPendingOnly = v ?? false);
                  _applyFilter();
                },
              ),
              const Text('Pending only', style: TextStyle(fontSize: 12)),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Clear', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB BAR
  // ─────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: _tabCtrl,
      labelColor: _kPrimary,
      unselectedLabelColor: Colors.grey,
      indicatorColor: _kAccent,
      indicatorWeight: 2,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      tabs: const [
        Tab(icon: Icon(Icons.all_inbox, size: 18), text: 'All Boxes'),
        Tab(icon: Icon(Icons.storage, size: 18), text: 'In Storage'),
        Tab(icon: Icon(Icons.move_to_inbox, size: 18), text: 'Retrieved'),
        Tab(icon: Icon(Icons.warning_amber, size: 18), text: 'Pending Destr.'),
      ],
      onTap: (i) {
        switch (i) {
          case 0:
            _applyFilter(status: 'all', pendingOnly: false);
            break;
          case 1:
            _applyFilter(status: 'stored', pendingOnly: false);
            break;
          case 2:
            _applyFilter(status: 'retrieved', pendingOnly: false);
            break;
          case 3:
            _applyFilter(status: 'all', pendingOnly: true);
            break;
        }
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text('No boxes found',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Try adjusting your filters or create a new box',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          if (authCtrl.hasPermission('canCreateBoxes'))
            ElevatedButton.icon(
              onPressed: _showCreateBoxDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label:
                  const Text('New Box', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent, elevation: 0),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FAB + BULK BAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _showCreateBoxDialog,
      backgroundColor: _kAccent,
      elevation: 4,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('New Box',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildBulkBar() {
    return Obx(() {
      final boxes = boxCtrl.boxes;
      final allSelected = boxes.isNotEmpty &&
          boxes.every((b) => _selectedBoxes.contains(b.boxId));

      return Container(
        height: 56,
        color: Colors.blue[50],
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Tooltip(
              message: allSelected ? 'Deselect all' : 'Select all on this page',
              child: Checkbox(
                value: allSelected,
                activeColor: _kAccent,
                onChanged: (_) => _toggleSelectAll(boxes),
              ),
            ),
            Text('${_selectedBoxes.length} selected',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            // Horizontally scrollable so the action set can grow without
            // overflowing on narrow screens.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _bulkBtn(
                        'Stored', Icons.storage, () => _bulkUpdateStatus('stored')),
                    const SizedBox(width: 8),
                    _bulkBtn('Retrieved', Icons.move_to_inbox,
                        () => _bulkUpdateStatus('retrieved')),
                    const SizedBox(width: 8),
                    _bulkBtn('Destroyed', Icons.delete_forever,
                        () => _bulkUpdateStatus('destroyed'),
                        danger: true),
                    const SizedBox(width: 8),
                    _bulkBtn(
                        'Print QR', Icons.qr_code, _bulkPrintQrCodes),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isSelectMode = false;
                _selectedBoxes.clear();
              }),
            ),
          ],
        ),
      );
    });
  }

  Widget _bulkBtn(String label, IconData icon, VoidCallback onTap,
      {bool danger = false}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: danger ? Colors.red : _kAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEARCH (narrow devices)
  // ─────────────────────────────────────────────────────────────────────────

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search…',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _applyFilter();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent, elevation: 0),
                child:
                    const Text('Search', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _scanQrToFindBox();
                },
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Scan QR Code'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kAccent.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tip: a handheld USB/Bluetooth scanner works automatically —\n'
              'just point it at a box label.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FIND BY QR CODE
  // ─────────────────────────────────────────────────────────────────────────

  /// mobile_scanner only ships native camera code for Android, iOS, macOS,
  /// and Web — there is no Windows/Linux implementation, which is exactly
  /// what throws MissingPluginException if you try to open it there. Gate
  /// the camera entry point on this so we never attempt it on a platform
  /// it doesn't support; the hardware scanner listener below covers those
  /// platforms instead.
  bool get _supportsCameraQrScan {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  Future<void> _scanQrToFindBox() async {
    if (!_supportsCameraQrScan) {
      _showHardwareScannerHint();
      return;
    }
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerSheet()),
    );
    if (scanned == null || scanned.isEmpty) return;
    _handleScannedCode(scanned);
  }

  void _showHardwareScannerHint() {
    Get.defaultDialog(
      title: 'Find by QR Code',
      content: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Camera scanning isn't available on this platform.\n\n"
          'Connect a USB or Bluetooth handheld barcode/QR scanner instead, \n'
          "it works automatically as soon as it's plugged in.\n Just point it "
          'at a box label; no need to click anything first.',
          textAlign: TextAlign.center,
        ),
      ),
      textConfirm: 'Got it',
      onConfirm: () => Get.back(),
    );
  }

  /// Once we have a scanned string — whether from the camera or a hardware
  /// scanner — both paths funnel through here so the "what does a scan
  /// mean" logic only lives in one place.
  void _handleScannedCode(String scanned) {
    final payload = parseBoxQrPayload(scanned);
    final boxId = payload?['id'] as int?;
    final boxNumber = payload?['number'] as String?;

    // Fast path: if the scanned box is already loaded on the current page,
    // jump straight to its details instead of round-tripping a search.
    if (boxId != null) {
      for (final b in boxCtrl.boxes) {
        if (b.boxId == boxId) {
          _showBoxDetails(b);
          return;
        }
      }
    }

    // Otherwise, search using the box number from the payload, or — if the
    // scanned code wasn't a recognised PSMS box QR — the raw scanned text.
    final query = boxNumber ?? scanned;
    _searchCtrl.text = query;
    setState(() {});
    _applyFilter();

    Get.snackbar(
      'QR Scanned',
      'Searching for "$query"',
      backgroundColor: _kAccent,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  // ── Hardware barcode/QR scanner (keyboard-wedge) support ──
  //
  // Handheld USB/Bluetooth scanners emulate a keyboard: they "type" the
  // decoded value far faster than any human can, then send Enter. This
  // listens for that pattern globally — regardless of which widget (if any)
  // currently has focus — so scanning works the same way on every platform
  // Flutter targets, including Windows/Linux desktop where the camera path
  // above isn't available at all. Normal, human-paced typing (e.g. in the
  // search box) is left completely alone.
  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final gap = _lastScanKeyTime == null
        ? null
        : now.difference(_lastScanKeyTime!).inMilliseconds;
    _lastScanKeyTime = now;

    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;

    if (isEnter) {
      final code = _scanBuffer;
      final wasFastBurst = gap != null && gap <= _scanKeyGapMs;
      _scanBuffer = '';
      if (wasFastBurst && code.length >= _minScanLength) {
        _handleScannedCode(code);
        return true; // swallow Enter so it doesn't also submit a focused field
      }
      return false; // a normal Enter press — let it behave as usual
    }

    final char = event.character;
    if (char == null || char.isEmpty) return false;

    if (gap != null && gap > _scanKeyGapMs) {
      // Pace broke — this starts a fresh burst, not a continuation.
      _scanBuffer = char;
      return false;
    }

    _scanBuffer += char;
    // Once the pace is fast enough to be confident this is a scanner (not
    // a person typing), swallow the keystrokes so they don't also leak
    // into whatever text field happens to have focus.
    return gap != null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _statusPill(String status, {bool small = false}) {
    final color = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 10, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: small ? 9 : 12, color: color),
          SizedBox(width: small ? 3 : 5),
          Text(
            status.capitalizeFirst ?? status,
            style: TextStyle(
                color: color,
                fontSize: small ? 9 : 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'stored':
        return Colors.green;
      case 'retrieved':
        return Colors.blue;
      case 'destroyed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'stored':
        return Icons.storage;
      case 'retrieved':
        return Icons.move_to_inbox;
      case 'destroyed':
        return Icons.delete_forever;
      default:
        return Icons.help_outline;
    }
  }

  List<PopupMenuEntry<String>> _boxMenuItems(BoxModel box) {
    return [
      const PopupMenuItem(
          value: 'view',
          child: ListTile(
              leading: Icon(Icons.visibility),
              title: Text('View Details'),
              dense: true)),
      if (authCtrl.hasPermission('canEditBoxes'))
        const PopupMenuItem(
            value: 'edit',
            child: ListTile(
                leading: Icon(Icons.edit), title: Text('Edit'), dense: true)),
      const PopupMenuItem(
          value: 'qr',
          child: ListTile(
              leading: Icon(Icons.qr_code),
              title: Text('QR Code'),
              dense: true)),
      if (box.canBeRetrieved)
        const PopupMenuItem(
            value: 'retrieve',
            child: ListTile(
                leading: Icon(Icons.move_to_inbox),
                title: Text('Mark Retrieved'),
                dense: true)),
      if (box.canBeStored)
        const PopupMenuItem(
            value: 'store',
            child: ListTile(
                leading: Icon(Icons.storage),
                title: Text('Mark Stored'),
                dense: true)),
      if (box.canBeDestroyed && authCtrl.hasPermission('canEditBoxes'))
        const PopupMenuItem(
            value: 'destroy',
            child: ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red),
                title:
                    Text('Mark Destroyed', style: TextStyle(color: Colors.red)),
                dense: true)),
      if (authCtrl.hasPermission('canDeleteBoxes') && box.status != 'destroyed')
        const PopupMenuItem(
            value: 'delete',
            child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                dense: true)),
      // const PopupMenuItem(
      //   value: 'audit',
      //   child: ListTile(
      //       leading: Icon(Icons.history),
      //       title: Text('Audit Log'),
      //       dense: true),
      // ),
    ];
  }

  void _applyFilter({String? status, bool? pendingOnly, int? page}) {
    if (status != null) setState(() => _selectedStatus = status);
    if (pendingOnly != null) setState(() => _showPendingOnly = pendingOnly);
    boxCtrl.getAllBoxes(
      page: page ?? 1,
      search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
      status: _selectedStatus == 'all' ? null : _selectedStatus,
      clientId: _selectedClientId,
      pendingDestruction: _showPendingOnly,
      refresh: true,
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'all';
      _selectedClientId = null;
      _showPendingOnly = false;
      _showFilters = false;
    });
    _searchCtrl.clear();
    boxCtrl.getAllBoxes(refresh: true);
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    switch (_tabCtrl.index) {
      case 0:
        _applyFilter(status: 'all', pendingOnly: false);
        break;
      case 1:
        _applyFilter(status: 'stored', pendingOnly: false);
        break;
      case 2:
        _applyFilter(status: 'retrieved', pendingOnly: false);
        break;
      case 3:
        _applyFilter(status: 'all', pendingOnly: true);
        break;
    }
  }

  void _handleAppBarAction(String action) {
    switch (action) {
      case 'print':
        _showReportOptionsDialog();
        break;
      case 'import':
        _showImportDialog();
        break;
    }
  }

  void _handleBoxAction(String action, BoxModel box) {
    switch (action) {
      case 'view':
        _showBoxDetails(box);
        break;
      case 'edit':
        _editBox(box);
        break;
      case 'qr':
        _showQrDialog(box);
        break;
      case 'retrieve':
        _changeBoxStatus(box, 'retrieved');
        break;
      case 'store':
        _changeBoxStatus(box, 'stored');
        break;
      case 'destroy':
        _changeBoxStatus(box, 'destroyed');
        break;
      case 'delete':
        _deleteBox(box);
        break;
      // case 'audit':
      //   _showAuditLog(box);
      //   break;
    }
  }

  void _changeBoxStatus(BoxModel box, String status) {
    Get.defaultDialog(
      title: 'Confirm',
      content: Text('Change ${box.boxNumber} to ${status.capitalizeFirst}?'),
      textConfirm: 'Confirm',
      textCancel: 'Cancel',
      onConfirm: () async {
        Get.back();
        await boxCtrl.changeBoxStatus(box.boxId, status);
      },
    );
  }

  void _markAsDestroyed(BoxModel box) => _changeBoxStatus(box, 'destroyed');

  void _deleteBox(BoxModel box) {
    Get.defaultDialog(
      title: 'Delete Box',
      content: Text('Delete ${box.boxNumber}? This cannot be undone.'),
      textConfirm: 'Delete',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      onConfirm: () async {
        Get.back();
        await boxCtrl.deleteBox(box.boxId);
      },
    );
  }

  void _bulkUpdateStatus(String status) {
    if (_selectedBoxes.isEmpty) return;
    Get.defaultDialog(
      title: 'Bulk Update',
      content: Text(
          'Update ${_selectedBoxes.length} boxes to ${status.capitalizeFirst}?'),
      textConfirm: 'Confirm',
      textCancel: 'Cancel',
      onConfirm: () async {
        Get.back();
        await boxCtrl.bulkUpdateBoxStatus(_selectedBoxes.toList(), status);
        setState(() {
          _selectedBoxes.clear();
          _isSelectMode = false;
        });
      },
    );
  }

  // Selects/deselects every box currently loaded for this page. Selection
  // is scoped to the active page (not the full filtered result set) since
  // boxCtrl only keeps one page of boxes in memory at a time.
  void _toggleSelectAll(List<BoxModel> boxes) {
    final allSelected =
        boxes.isNotEmpty && boxes.every((b) => _selectedBoxes.contains(b.boxId));
    setState(() {
      if (allSelected) {
        _selectedBoxes.removeAll(boxes.map((b) => b.boxId));
      } else {
        _selectedBoxes.addAll(boxes.map((b) => b.boxId));
      }
    });
  }

  // void _showAuditLog(BoxModel box) =>
  //     Get.snackbar('Info', 'Audit log coming soon',
  //         backgroundColor: Colors.blue, colorText: Colors.white);

  void _showImportDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          width: 900,
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: const BoxImportDialog(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QR CODE DIALOG
  // ─────────────────────────────────────────────────────────────────────────

  void _showQrDialog(BoxModel box) {
    // Build a compact JSON payload for the QR code — shared with bulk
    // printing and the "Find by QR Code" scanner via box_qr_payload.dart.
    final payload = buildBoxQrPayload(box);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: _kAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.qr_code, color: _kAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Box QR Code',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _kPrimary)),
                        Text(box.boxNumber,
                            style:
                                const TextStyle(color: _kAccent, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close), onPressed: Get.back),
                ],
              ),
              const SizedBox(height: 20),
              // QR Code widget
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Box details under QR
              _qrDetailRow('Box Number', box.boxNumber),
              _qrDetailRow('Client',
                  '${box.client.clientCode} – ${box.client.clientName}'),
              _qrDetailRow('Status', box.statusDisplay),
              if (box.rackingLabel != null)
                _qrDetailRow('Location', box.rackingLabel!.location),
              if (box.destructionYear != null)
                _qrDetailRow('Destruction Year', '${box.destructionYear}'),
              const SizedBox(height: 20),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Get.back();
                        await _printQrCode(box, payload);
                      },
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kAccent.withOpacity(0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Get.back();
                        await _shareQrCode(box, payload);
                      },
                      icon: const Icon(Icons.share,
                          size: 16, color: Colors.white),
                      label: const Text('Share',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccent, elevation: 0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qrDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, color: _kPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _printQrCode(BoxModel box, String payload) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (ctx) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(box.boxNumber,
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(box.client.clientName,
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
              pw.SizedBox(height: 16),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: payload,
                width: 180,
                height: 180,
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Status: ${box.statusDisplay}',
                      style: pw.TextStyle(fontSize: 10)),
                  if (box.rackingLabel != null)
                    pw.Text('Rack: ${box.rackingLabel!.labelCode}',
                        style: pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (box.destructionYear != null) ...[
                pw.SizedBox(height: 4),
                pw.Text('Destruction Year: ${box.destructionYear}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.red)),
              ],
              pw.SizedBox(height: 8),
              pw.Text('PSMS ® – Docsecure Eswatini',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _shareQrCode(BoxModel box, String payload) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (ctx) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(box.boxNumber,
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: payload,
                  width: 180,
                  height: 180),
            ],
          ),
        ),
      ),
    );
    final bytes = await pdf.save();
    final name =
        'qr_${box.boxNumber}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/$name');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)], text: 'QR Code – ${box.boxNumber}'));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BULK QR PRINTING — one label sheet for every selected box
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _bulkPrintQrCodes() async {
    if (_selectedBoxes.isEmpty) return;

    final boxes =
        boxCtrl.boxes.where((b) => _selectedBoxes.contains(b.boxId)).toList();
    if (boxes.isEmpty) return;

    Get.dialog(
      const Center(child: CircularProgressIndicator(color: _kAccent)),
      barrierDismissible: false,
    );

    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          // GridView is a spanning widget, so the label grid automatically
          // continues onto extra pages if there are more boxes than fit.
          build: (ctx) => [
            pw.GridView(
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: boxes.map(_buildQrLabelCell).toList(),
            ),
          ],
        ),
      );

      if (mounted) Get.back(); // close loading indicator
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      if (mounted) Get.back();
      Get.snackbar('Error', 'Failed to generate QR labels: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  /// A single label cell: QR code plus box number / client / rack — the
  /// same payload schema used by the single-box QR dialog above.
  pw.Widget _buildQrLabelCell(BoxModel box) {
    final payload = buildBoxQrPayload(box);
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: payload,
              width: 70,
              height: 70),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(box.boxNumber,
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(box.client.clientCode,
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                if (box.rackingLabel != null)
                  pw.Text(box.rackingLabel!.labelCode,
                      style:
                          pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REPORT DIALOG + PDF / EXCEL (kept from original, unchanged)
  // ─────────────────────────────────────────────────────────────────────────

  void _showReportOptionsDialog() {
    showReportOptionsDialog(); // directly calls the original function
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PDF / EXCEL helpers (kept — your original implementations are still
  // in box_dialog.dart / box_details_dialog.dart; these are thin stubs
  // so the file compiles without them being duplicated here)
  // ─────────────────────────────────────────────────────────────────────────

  Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/logo/logo.jpeg');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}