// box_management_screen.dart
import 'package:excel/excel.dart' as exl;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/box_controller.dart';
import 'package:psms/controllers/storage_controller.dart';
import 'package:psms/models/box_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:psms/models/report_models.dart';
import 'package:share_plus/share_plus.dart';
import 'widgets/box_dialog.dart';
import 'widgets/box_details_dialog.dart';

class BoxManagementScreen extends StatefulWidget {
  const BoxManagementScreen({super.key});

  @override
  State<BoxManagementScreen> createState() => _BoxManagementScreenState();
}

class _BoxManagementScreenState extends State<BoxManagementScreen>
    with SingleTickerProviderStateMixin {
  final BoxController boxController = Get.put(BoxController());
  final AuthController authController = Get.find<AuthController>();
  final StorageController storageController = Get.put(StorageController());

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // View mode: 0 = Table, 1 = Grid
  int _viewMode = 0;

  // Filter variables
  String _selectedStatus = 'all';
  int? _selectedClientId;
  bool _showPendingOnly = false;
  bool _showFilters = false;

  // Selection for bulk operations
  final Set<int> _selectedBoxes = <int>{};
  bool _isSelectMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      boxController.initialize();
      storageController.initialize();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        if (boxController.currentPage.value < boxController.totalPages.value) {
          boxController.loadNextPage();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(.2),
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: _isSelectMode ? _buildBulkActionBar() : null,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.95),
      centerTitle: false,
      title: Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Box Management',
                style: TextStyle(
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              Text(
                '${boxController.totalBoxes.value} boxes',
                style: TextStyle(
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w100,
                  fontSize: 12,
                ),
              ),
            ],
          )),
      actions: _buildAppBarActions(),
      bottom: _buildTabBar(),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
        icon: Icon(Icons.search, color: Color(0xFF2C3E50)),
        onPressed: () => _showSearchDialog(),
      ),
      IconButton(
        icon: Icon(
          _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
          color: Color(0xFF2C3E50),
        ),
        onPressed: () {
          setState(() {
            _showFilters = !_showFilters;
          });
        },
      ),
      IconButton(
        icon: Icon(
          _viewMode == 0 ? Icons.grid_view : Icons.table_chart,
          color: Color(0xFF2C3E50),
        ),
        onPressed: () {
          setState(() {
            _viewMode = _viewMode == 0 ? 1 : 0;
          });
        },
      ),
      IconButton(
        icon: Icon(
          _isSelectMode ? Icons.deselect : Icons.select_all,
          color: Color(0xFF2C3E50),
        ),
        onPressed: () {
          setState(() {
            _isSelectMode = !_isSelectMode;
            if (!_isSelectMode) {
              _selectedBoxes.clear();
            }
          });
        },
      ),
      IconButton(
        icon: Icon(Icons.refresh, color: Color(0xFF2C3E50)),
        onPressed: () {
          boxController.initialize();
          storageController.initialize();
        },
      ),
      PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Color(0xFF2C3E50)),
        onSelected: (value) => _handleAppBarAction(value),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'export',
            child: ListTile(
              leading: Icon(Icons.download, size: 20, color: Color(0xFF2C3E50)),
              title: Text('Export Data'),
            ),
          ),
          PopupMenuItem(
            value: 'print',
            child: ListTile(
              leading: Icon(Icons.print, size: 20, color: Color(0xFF2C3E50)),
              title: Text('Print Report'),
            ),
          ),
          PopupMenuItem(
            value: 'settings',
            child: ListTile(
              leading: Icon(Icons.settings, size: 20, color: Color(0xFF2C3E50)),
              title: Text('Settings'),
            ),
          ),
        ],
      ),
    ];
  }

  // ==================== ENHANCED REPORT DIALOG ====================
  void _showReportOptionsDialog() {
    final BoxController boxController = Get.find<BoxController>();
    // Ensure storageController is available (if not already in scope)
    final StorageController storageController = Get.find<StorageController>();

    // Report type: single (one client) or bulk (all/multiple)
    RxString reportType = 'single'.obs;
    RxInt selectedClientId = 0.obs; // 0 = All Clients (for single report)
    RxList<int> selectedClientIds = <int>[].obs; // for bulk
    RxString selectedFormat = 'Print'.obs;

    // Advanced filters
    RxString statusFilter = ''.obs;
    RxInt rackingLabelIdFilter = 0.obs;
    RxString searchFilter = ''.obs;
    Rx<DateTime?> dateFrom = Rx<DateTime?>(null);
    Rx<DateTime?> dateTo = Rx<DateTime?>(null);
    Rx<int?> destructionYearFrom = Rx<int?>(null);
    Rx<int?> destructionYearTo = Rx<int?>(null);
    Rx<int?> retentionYearsFilter = Rx<int?>(null);
    RxBool includeStats = true.obs;

    // Controllers for text fields
    final TextEditingController searchController = TextEditingController();
    final TextEditingController dateFromController = TextEditingController();
    final TextEditingController dateToController = TextEditingController();
    final TextEditingController destructionYearFromController =
        TextEditingController();
    final TextEditingController destructionYearToController =
        TextEditingController();
    final TextEditingController retentionYearsController =
        TextEditingController();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 700,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(Get.context!).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient (matching BoxDetailsDialog style)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3498DB), Color(0xFF5DADE2)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.insert_drive_file,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Generate Box Report',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Report Type Card
                      _buildReportCard(
                        icon: Icons.receipt_long,
                        title: 'Report Type',
                        child: Column(
                          children: [
                            Obx(
                              () => Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Single Client'),
                                      value: 'single',
                                      groupValue: reportType.value,
                                      onChanged: (val) =>
                                          reportType.value = val!,
                                      activeColor: const Color(0xFF3498DB),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('All Clients'),
                                      value: 'bulk',
                                      groupValue: reportType.value,
                                      onChanged: (val) =>
                                          reportType.value = val!,
                                      activeColor: const Color(0xFF3498DB),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Client Selection Card (changes with report type)
                      Obx(
                        () => _buildReportCard(
                          icon: Icons.business,
                          title: reportType.value == 'single'
                              ? 'Select Client'
                              : 'Select Clients (optional)',
                          child: reportType.value == 'single'
                              ? DropdownButtonFormField<int>(
                                  value: selectedClientId.value == 0
                                      ? null
                                      : selectedClientId.value,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(
                                      value: 0,
                                      child: Text('All Clients'),
                                    ),
                                    ...boxController.clients.map(
                                      (client) => DropdownMenuItem(
                                        value: client.clientId,
                                        child: Text(
                                            '${client.clientName} (${client.clientCode})'),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      selectedClientId.value = value ?? 0,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children:
                                        boxController.clients.map((client) {
                                      return CheckboxListTile(
                                        title: Text(
                                            '${client.clientName} (${client.clientCode})'),
                                        value: selectedClientIds
                                            .contains(client.clientId),
                                        onChanged: (checked) {
                                          if (checked == true) {
                                            selectedClientIds
                                                .add(client.clientId);
                                          } else {
                                            selectedClientIds
                                                .remove(client.clientId);
                                          }
                                        },
                                        activeColor: const Color(0xFF3498DB),
                                        dense: true,
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Advanced Filters Card
                      _buildReportCard(
                        icon: Icons.filter_alt,
                        title: 'Advanced Filters',
                        child: Column(
                          children: [
                            // Status
                            Obx(
                              () => DropdownButtonFormField<String>(
                                value: statusFilter.value.isEmpty
                                    ? null
                                    : statusFilter.value,
                                items: const [
                                  DropdownMenuItem(
                                      value: '', child: Text('All Status')),
                                  DropdownMenuItem(
                                      value: 'stored', child: Text('Stored')),
                                  DropdownMenuItem(
                                      value: 'retrieved',
                                      child: Text('Retrieved')),
                                  DropdownMenuItem(
                                      value: 'destroyed',
                                      child: Text('Destroyed')),
                                ],
                                onChanged: (value) =>
                                    statusFilter.value = value ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Racking label
                            Obx(
                              () => DropdownButtonFormField<int>(
                                value: rackingLabelIdFilter.value == 0
                                    ? null
                                    : rackingLabelIdFilter.value,
                                items: [
                                  const DropdownMenuItem(
                                      value: 0, child: Text('Any Location')),
                                  ...storageController.storageLocations.map(
                                    (loc) => DropdownMenuItem(
                                      value: loc.labelId,
                                      child: Text(
                                          '${loc.labelCode} - ${loc.locationDescription}'),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    rackingLabelIdFilter.value = value ?? 0,
                                decoration: const InputDecoration(
                                  labelText: 'Racking Label',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Search
                            TextField(
                              controller: searchController,
                              decoration: const InputDecoration(
                                labelText: 'Search (box #, description)',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) => searchFilter.value = value,
                            ),
                            const SizedBox(height: 12),

                            // Date range
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: dateFromController,
                                    decoration: const InputDecoration(
                                      labelText: 'Date From',
                                      border: OutlineInputBorder(),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: Get.context!,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime.now(),
                                      );
                                      if (date != null) {
                                        dateFromController.text =
                                            DateFormat('yyyy-MM-dd')
                                                .format(date);
                                        dateFrom.value = date;
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: dateToController,
                                    decoration: const InputDecoration(
                                      labelText: 'Date To',
                                      border: OutlineInputBorder(),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: Get.context!,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime.now(),
                                      );
                                      if (date != null) {
                                        dateToController.text =
                                            DateFormat('yyyy-MM-dd')
                                                .format(date);
                                        dateTo.value = date;
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Destruction year range
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: destructionYearFromController,
                                    decoration: const InputDecoration(
                                      labelText: 'Destruction Year From',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      destructionYearFrom.value =
                                          int.tryParse(value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: destructionYearToController,
                                    decoration: const InputDecoration(
                                      labelText: 'Destruction Year To',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      destructionYearTo.value =
                                          int.tryParse(value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Retention years
                            TextField(
                              controller: retentionYearsController,
                              decoration: const InputDecoration(
                                labelText: 'Retention Years (exact)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                retentionYearsFilter.value =
                                    int.tryParse(value);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Options Card (Include stats + format)
                      _buildReportCard(
                        icon: Icons.settings,
                        title: 'Options',
                        child: Column(
                          children: [
                            // Include stats toggle
                            Row(
                              children: [
                                Obx(
                                  () => Checkbox(
                                    value: includeStats.value,
                                    onChanged: (val) =>
                                        includeStats.value = val ?? true,
                                    activeColor: const Color(0xFF3498DB),
                                  ),
                                ),
                                const Text('Include summary statistics'),
                              ],
                            ),
                            const Divider(height: 24),

                            // Format selection
                            const Text(
                              'Choose format:',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Obx(
                              () => Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Print / PDF'),
                                      value: 'Print',
                                      groupValue: selectedFormat.value,
                                      onChanged: (val) =>
                                          selectedFormat.value = val!,
                                      activeColor: const Color(0xFF3498DB),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Excel'),
                                      value: 'Excel',
                                      groupValue: selectedFormat.value,
                                      onChanged: (val) =>
                                          selectedFormat.value = val!,
                                      activeColor: const Color(0xFF3498DB),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer with actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF3498DB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF3498DB)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Get.back(); // close options dialog

                          // Determine report type and call appropriate method
                          if (reportType.value == 'single') {
                            final clientId = selectedClientId.value == 0
                                ? null
                                : selectedClientId.value;
                            final report = await boxController.getBoxReport(
                              clientId: clientId,
                              status: statusFilter.value.isEmpty
                                  ? null
                                  : statusFilter.value,
                              rackingLabelId: rackingLabelIdFilter.value == 0
                                  ? null
                                  : rackingLabelIdFilter.value,
                              search: searchFilter.value.isEmpty
                                  ? null
                                  : searchFilter.value,
                              dateFrom: dateFrom.value != null
                                  ? DateFormat('yyyy-MM-dd')
                                      .format(dateFrom.value!)
                                  : null,
                              dateTo: dateTo.value != null
                                  ? DateFormat('yyyy-MM-dd')
                                      .format(dateTo.value!)
                                  : null,
                              destructionYearFrom: destructionYearFrom.value,
                              destructionYearTo: destructionYearTo.value,
                              retentionYears: retentionYearsFilter.value,
                              includeStats: includeStats.value,
                            );
                            if (report == null) {
                              Get.snackbar('Error', 'Failed to generate report',
                                  backgroundColor: Colors.red);
                              return;
                            }
                            if (selectedFormat.value == 'Print') {
                              await _generateAndShowPdfPreview(report,
                                  clientId: clientId,
                                  includeStats: includeStats.value);
                            } else {
                              _showExcelPreview(report,
                                  clientId: clientId,
                                  includeStats: includeStats.value);
                            }
                          } else {
                            final clientIds = selectedClientIds.isEmpty
                                ? null
                                : selectedClientIds.toList();
                            final report = await boxController.getBulkBoxReport(
                              clientIds: clientIds,
                              status: statusFilter.value.isEmpty
                                  ? null
                                  : statusFilter.value,
                              rackingLabelId: rackingLabelIdFilter.value == 0
                                  ? null
                                  : rackingLabelIdFilter.value,
                              search: searchFilter.value.isEmpty
                                  ? null
                                  : searchFilter.value,
                              dateFrom: dateFrom.value != null
                                  ? DateFormat('yyyy-MM-dd')
                                      .format(dateFrom.value!)
                                  : null,
                              dateTo: dateTo.value != null
                                  ? DateFormat('yyyy-MM-dd')
                                      .format(dateTo.value!)
                                  : null,
                              destructionYearFrom: destructionYearFrom.value,
                              destructionYearTo: destructionYearTo.value,
                              retentionYears: retentionYearsFilter.value,
                              includeStats: includeStats.value,
                            );
                            if (report == null) {
                              Get.snackbar(
                                  'Error', 'Failed to generate bulk report',
                                  backgroundColor: Colors.red);
                              return;
                            }
                            if (selectedFormat.value == 'Print') {
                              await _generateAndShowBulkPdfPreview(report,
                                  includeStats: includeStats.value);
                            } else {
                              _showBulkExcelPreview(report,
                                  includeStats: includeStats.value);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Generate',
                          style: TextStyle(color: Colors.white),
                        ),
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

// Helper widget to build a consistent info card (matching BoxDetailsDialog style)
  Widget _buildReportCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3498DB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF3498DB), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  // ==================== PDF PREVIEW (SINGLE) ====================
  Future<void> _generateAndShowPdfPreview(
    BoxReportResponse report, {
    int? clientId,
    bool includeStats = true,
  }) async {
    final pdf = await _buildPdfDocument(report,
        clientId: clientId, includeStats: includeStats);

    return Get.dialog(
      Dialog(
        insetPadding: EdgeInsets.all(20),
        child: Container(
          width: MediaQuery.of(Get.context!).size.width * 0.8,
          height: MediaQuery.of(Get.context!).size.height * 0.8,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PDF Preview',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PdfPreview(
                  build: (format) async => pdf.save(),
                  allowSharing: true,
                  allowPrinting: true,
                  pdfFileName:
                      'box_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text('Close'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Get.back();
                        await _sharePdf(pdf);
                      },
                      icon: Icon(Icons.save),
                      label: Text('Save PDF'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        Printing.layoutPdf(
                            onLayout: (format) async => pdf.save());
                      },
                      icon: Icon(Icons.print),
                      label: Text('Print'),
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

  // ==================== PDF PREVIEW (BULK) ====================
  Future<void> _generateAndShowBulkPdfPreview(
    BulkBoxReportResponse report, {
    bool includeStats = true,
  }) async {
    final pdf = await _buildBulkPdfDocument(report, includeStats: includeStats);

    return Get.dialog(
      Dialog(
        insetPadding: EdgeInsets.all(20),
        child: Container(
          width: MediaQuery.of(Get.context!).size.width * 0.8,
          height: MediaQuery.of(Get.context!).size.height * 0.8,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bulk Report PDF Preview',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PdfPreview(
                  build: (format) async => pdf.save(),
                  allowSharing: true,
                  allowPrinting: true,
                  pdfFileName:
                      'bulk_box_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text('Close'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Get.back();
                        await _sharePdf(pdf);
                      },
                      icon: Icon(Icons.save),
                      label: Text('Save PDF'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        Printing.layoutPdf(
                            onLayout: (format) async => pdf.save());
                      },
                      icon: Icon(Icons.print),
                      label: Text('Print'),
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

  // ==================== PDF BUILD (SINGLE) ====================
  Future<pw.Document> _buildPdfDocument(
    BoxReportResponse report, {
    int? clientId,
    bool includeStats = true,
  }) async {
    final pdf = pw.Document();
    final boxes = boxController.pendingDestructionBoxes;
    final box =
        boxes[0]; // Replace 0 with the desired index or pass it dynamically

    final fontData = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final boldFontData =
        await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(boldFontData);

    final logoImage = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        header: (context) {
          if (context.pageNumber == 1) {
            return pw.Column(children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null)
                    pw.Container(
                        width: 60, height: 60, child: pw.Image(logoImage)),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Docsecure Eswatini (Pty) Ltd',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800)),
                        pw.Text('Physical Storage Management System®',
                            style: pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                            'Below Gcina Trading, Plot 769 First street Mangozeni, \nMatsapha M201, Eswatini',
                            style: pw.TextStyle(
                                fontSize: 8, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Box Inventory Report',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                      style:
                          pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Row(
                  children: [
                    pw.Text('Client: ',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text(
                      clientId == null
                          ? 'All Clients'
                          : '${report.boxes.first.client.clientName} (${report.boxes.first.client.clientCode})',
                      style: pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Display applied filters
              pw.SizedBox(height: 8),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Filters applied:',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    ...report.filters.entries.map((e) => pw.Text(
                        '${e.key}: ${e.value}',
                        style: pw.TextStyle(fontSize: 8))),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ]);
          }
          return pw.Container();
        },
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: pw.EdgeInsets.only(top: 20),
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ),
        build: (context) => [
          // Summary stats
          if (includeStats && report.summary != null) ...[
            pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Summary',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Boxes: ${report.summary!.totalBoxes}',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Stored: ${report.summary!.statusCounts['stored'] ?? 0}',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Retrieved: ${report.summary!.statusCounts['retrieved'] ?? 0}',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Destroyed: ${report.summary!.statusCounts['destroyed'] ?? 0}',
                          style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Text(
                          'Pending Destruction: ${report.summary!.pendingDestruction}',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(width: 20),
                      pw.Text(
                          'Unique Clients: ${report.summary!.uniqueClients}',
                          style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],
          // Boxes table
          pw.TableHelper.fromTextArray(
            headers: [
              'Box #',
              'Size',
              'Description',
              'Date Received',
              'Data Years',
              'Destruction Year',
              'Status'
            ],
            data: report.boxes
                .map((box) => [
                      box.boxNumber,
                      box.boxSize ?? '',
                      box.description ?? '',
                      box.dateReceived != null
                          ? DateFormat('yyyy-MM-dd').format(box.dateReceived!)
                          : '',
                      box.dataYears ?? '',
                      box.destructionYear?.toString() ?? '',
                      box.status.capitalizeFirst ?? '',
                    ])
                .toList(),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blue700),
            cellStyle: pw.TextStyle(fontSize: 8),
            cellHeight: 28,
            columnWidths: {
              0: pw.FlexColumnWidth(1.5),
              1: pw.FlexColumnWidth(0.8),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1),
              6: pw.FlexColumnWidth(1),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
            },
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Boxes: ${report.boxes.length}',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Report generated by PSMS ®',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.Spacer(),

          // Signature row
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Docsecure Represantative',
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.normal)),
                    pw.SizedBox(height: 10),
                    pw.Text('_____________________________',
                        style: pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),

                // for client
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('For Client: ${box.client.clientName}',
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.normal)),
                    pw.SizedBox(height: 10),
                    pw.Text('______________________________',
                        style: pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ])
        ],
      ),
    );

    return pdf;
  }

  // ==================== PDF BUILD (BULK) ====================
  Future<pw.Document> _buildBulkPdfDocument(
    BulkBoxReportResponse report, {
    bool includeStats = true,
  }) async {
    final pdf = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final boldFontData =
        await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(boldFontData);

    final logoImage = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        header: (context) {
          if (context.pageNumber == 1) {
            return pw.Column(children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null)
                    pw.Container(
                        width: 60, height: 60, child: pw.Image(logoImage)),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Docsecure Eswatini (Pty) Ltd',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800)),
                        pw.Text('Physical Storage Management System®',
                            style: pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                            'Below Gcina Trading, Plot 769 First street Mangozeni, \nMatsapha M201, Eswatini',
                            style: pw.TextStyle(
                                fontSize: 8, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bulk Box Inventory Report',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                      style:
                          pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text('Clients: ${report.clients.length}',
                    style: pw.TextStyle(fontSize: 11)),
              ),
              // Display applied filters
              pw.SizedBox(height: 8),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Filters applied:',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    ...report.filters.entries.map((e) => pw.Text(
                        '${e.key}: ${e.value}',
                        style: pw.TextStyle(fontSize: 8))),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ]);
          }
          return pw.Container();
        },
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: pw.EdgeInsets.only(top: 20),
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ),
        build: (context) {
          final pages = <pw.Widget>[];

          // Overall summary
          if (includeStats && report.summary != null) {
            pages.add(pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Overall Summary',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Boxes: ${report.summary!.totalBoxes}',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.Text('Total Clients: ${report.summary!.totalClients}',
                          style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                          'Stored: ${report.summary!.statusCounts['stored'] ?? 0}',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Retrieved: ${report.summary!.statusCounts['retrieved'] ?? 0}',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Destroyed: ${report.summary!.statusCounts['destroyed'] ?? 0}',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Pending Destruction: ${report.summary!.pendingDestruction}',
                          style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ));
            pages.add(pw.SizedBox(height: 16));
          }

          // Per-client tables
          for (var client in report.clients) {
            pages.add(pw.Container(
              padding: pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      '${client.clientName} (${client.clientCode}) - Boxes: ${client.summary.totalBoxes}',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'Stored: ${client.summary.stored} | Retrieved: ${client.summary.retrieved} | Destroyed: ${client.summary.destroyed} | Pending: ${client.summary.pendingDestruction}',
                      style: pw.TextStyle(fontSize: 9)),
                ],
              ),
            ));
            pages.add(pw.SizedBox(height: 8));

            pages.add(pw.TableHelper.fromTextArray(
              headers: [
                'Box #',
                'Size',
                'Description',
                'Date Received',
                'Data Years',
                'Destruction Year',
                'Status'
              ],
              data: client.boxes
                  .map((box) => [
                        box.boxNumber,
                        box.boxSize ?? '',
                        box.description ?? '',
                        box.dateReceived != null
                            ? DateFormat('yyyy-MM-dd').format(box.dateReceived!)
                            : '',
                        box.dataYears ?? '',
                        box.destructionYear?.toString() ?? '',
                        box.status.capitalizeFirst ?? '',
                      ])
                  .toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blue600),
              cellStyle: pw.TextStyle(fontSize: 7),
              cellHeight: 24,
              columnWidths: {
                0: pw.FlexColumnWidth(1.5),
                1: pw.FlexColumnWidth(0.8),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(1.2),
                4: pw.FlexColumnWidth(1),
                5: pw.FlexColumnWidth(1),
                6: pw.FlexColumnWidth(1),
              },
            ));
            pages.add(pw.SizedBox(height: 16));
          }

          pages.add(pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Boxes: ${report.summary?.totalBoxes ?? 0}',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Report generated by PSMS ®',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ));

          return pages;
        },
      ),
    );

    return pdf;
  }

  // ==================== EXCEL PREVIEW (SINGLE) ====================
  void _showExcelPreview(
    BoxReportResponse report, {
    int? clientId,
    bool includeStats = true,
  }) {
    Get.dialog(
      Dialog(
        insetPadding: EdgeInsets.all(20),
        child: Container(
          width: MediaQuery.of(Get.context!).size.width * 0.8,
          height: MediaQuery.of(Get.context!).size.height * 0.8,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Excel Preview',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),
              // Summary stats
              if (includeStats && report.summary != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Summary',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('Total Boxes: ${report.summary!.totalBoxes}'),
                          Text(
                              'Stored: ${report.summary!.statusCounts['stored'] ?? 0}'),
                          Text(
                              'Retrieved: ${report.summary!.statusCounts['retrieved'] ?? 0}'),
                          Text(
                              'Destroyed: ${report.summary!.statusCounts['destroyed'] ?? 0}'),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                              'Pending Destruction: ${report.summary!.pendingDestruction}'),
                          SizedBox(width: 20),
                          Text(
                              'Unique Clients: ${report.summary!.uniqueClients}'),
                        ],
                      ),
                    ],
                  ),
                ),
              // Data preview table
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor:
                          MaterialStateProperty.all(Colors.green[100]),
                      columns: const [
                        DataColumn(label: Text('Box #')),
                        DataColumn(label: Text('Size')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Date Received')),
                        DataColumn(label: Text('Data Years')),
                        DataColumn(label: Text('Destruction Year')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: report.boxes.map((box) {
                        return DataRow(cells: [
                          DataCell(Text(box.boxNumber)),
                          DataCell(Text(box.boxSize ?? '')),
                          DataCell(Text(box.description ?? '')),
                          DataCell(Text(box.dateReceived != null
                              ? DateFormat('yyyy-MM-dd')
                                  .format(box.dateReceived!)
                              : '')),
                          DataCell(Text(box.dataYears ?? '')),
                          DataCell(Text(box.destructionYear?.toString() ?? '')),
                          DataCell(Text(box.status.capitalizeFirst ?? '')),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text('Cancel'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Get.back();
                        await _generateAndShareExcel(report,
                            clientId: clientId, includeStats: includeStats);
                      },
                      icon: Icon(Icons.save_alt),
                      label: Text('Save as Excel'),
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

  // ==================== EXCEL PREVIEW (BULK) ====================
  void _showBulkExcelPreview(
    BulkBoxReportResponse report, {
    bool includeStats = true,
  }) {
    Get.dialog(
      Dialog(
        insetPadding: EdgeInsets.all(20),
        child: Container(
          width: MediaQuery.of(Get.context!).size.width * 0.8,
          height: MediaQuery.of(Get.context!).size.height * 0.8,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bulk Excel Preview',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),
              // Overall summary
              if (includeStats && report.summary != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overall Summary',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('Total Boxes: ${report.summary!.totalBoxes}'),
                          Text(
                              'Total Clients: ${report.summary!.totalClients}'),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                              'Stored: ${report.summary!.statusCounts['stored'] ?? 0}'),
                          Text(
                              'Retrieved: ${report.summary!.statusCounts['retrieved'] ?? 0}'),
                          Text(
                              'Destroyed: ${report.summary!.statusCounts['destroyed'] ?? 0}'),
                          Text(
                              'Pending: ${report.summary!.pendingDestruction}'),
                        ],
                      ),
                    ],
                  ),
                ),
              // Data preview table (grouped by client)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    children: report.clients.map((client) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              '${client.clientName} (${client.clientCode}) - Boxes: ${client.summary.totalBoxes}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 20,
                              headingRowColor:
                                  MaterialStateProperty.all(Colors.green[100]),
                              columns: const [
                                DataColumn(label: Text('Box #')),
                                DataColumn(label: Text('Size')),
                                DataColumn(label: Text('Description')),
                                DataColumn(label: Text('Date Received')),
                                DataColumn(label: Text('Data Years')),
                                DataColumn(label: Text('Destruction Year')),
                                DataColumn(label: Text('Status')),
                              ],
                              rows: client.boxes.map((box) {
                                return DataRow(cells: [
                                  DataCell(Text(box.boxNumber)),
                                  DataCell(Text(box.boxSize ?? '')),
                                  DataCell(Text(box.description ?? '')),
                                  DataCell(Text(box.dateReceived != null
                                      ? DateFormat('yyyy-MM-dd')
                                          .format(box.dateReceived!)
                                      : '')),
                                  DataCell(Text(box.dataYears ?? '')),
                                  DataCell(Text(
                                      box.destructionYear?.toString() ?? '')),
                                  DataCell(
                                      Text(box.status.capitalizeFirst ?? '')),
                                ]);
                              }).toList(),
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text('Cancel'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Get.back();
                        await _generateAndShareBulkExcel(report,
                            includeStats: includeStats);
                      },
                      icon: Icon(Icons.save_alt),
                      label: Text('Save as Excel'),
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

  // ==================== EXCEL GENERATION (SINGLE) ====================
  Future<void> _generateAndShareExcel(
    BoxReportResponse report, {
    int? clientId,
    bool includeStats = true,
  }) async {
    final excel = exl.Excel.createExcel();
    final sheet = excel['Box Report'];

    // Add metadata sheet with summary and filters
    if (includeStats && report.summary != null) {
      final metaSheet = excel['Summary'];
      metaSheet.appendRow([exl.TextCellValue('Generated')]);
      metaSheet
          .appendRow([exl.TextCellValue(DateTime.now().toIso8601String())]);
      metaSheet.appendRow([exl.TextCellValue('Client')]);
      metaSheet.appendRow([exl.TextCellValue(clientId?.toString() ?? 'All')]);
      metaSheet.appendRow([exl.TextCellValue('Total Boxes')]);
      metaSheet.appendRow([exl.IntCellValue(report.summary!.totalBoxes)]);
      metaSheet.appendRow([exl.TextCellValue('Stored')]);
      metaSheet.appendRow(
          [exl.IntCellValue(report.summary!.statusCounts['stored'] ?? 0)]);
      metaSheet.appendRow([exl.TextCellValue('Retrieved')]);
      metaSheet.appendRow(
          [exl.IntCellValue(report.summary!.statusCounts['retrieved'] ?? 0)]);
      metaSheet.appendRow([exl.TextCellValue('Destroyed')]);
      metaSheet.appendRow(
          [exl.IntCellValue(report.summary!.statusCounts['destroyed'] ?? 0)]);
      metaSheet.appendRow([exl.TextCellValue('Pending Destruction')]);
      metaSheet
          .appendRow([exl.IntCellValue(report.summary!.pendingDestruction)]);
      metaSheet.appendRow([exl.TextCellValue('Unique Clients')]);
      metaSheet.appendRow([exl.IntCellValue(report.summary!.uniqueClients)]);
    }

    // Headers
    sheet.appendRow([
      exl.TextCellValue('Box Number'),
      exl.TextCellValue('Box Size'),
      exl.TextCellValue('Description'),
      exl.TextCellValue('Date Received'),
      exl.TextCellValue('Data Years'),
      exl.TextCellValue('Destruction Year'),
      exl.TextCellValue('Status'),
      exl.TextCellValue('Client ID'),
      exl.TextCellValue('Client Name'),
      exl.TextCellValue('Client Code'),
      exl.TextCellValue('Rack Label'),
      exl.TextCellValue('Rack Location'),
    ]);

    // Data rows
    for (final box in report.boxes) {
      sheet.appendRow([
        exl.TextCellValue(box.boxNumber),
        exl.TextCellValue(box.boxSize ?? ''),
        exl.TextCellValue(box.description ?? ''),
        exl.TextCellValue(box.dateReceived != null
            ? DateFormat('yyyy-MM-dd').format(box.dateReceived!)
            : ''),
        exl.TextCellValue(box.dataYears ?? ''),
        exl.IntCellValue(box.destructionYear ?? 0),
        exl.TextCellValue(box.status),
        exl.IntCellValue(box.client.clientId),
        exl.TextCellValue(box.client.clientName),
        exl.TextCellValue(box.client.clientCode),
        exl.TextCellValue(box.rackLabel ?? ''),
        exl.TextCellValue(box.rackLocation ?? ''),
      ]);
    }

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      Get.snackbar('Error', 'Failed to generate Excel file',
          backgroundColor: Colors.red);
      return;
    }

    final fileName =
        'box_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (Platform.isWindows) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        Get.snackbar('Error', 'Could not access Downloads folder',
            backgroundColor: Colors.red);
        return;
      }
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      await OpenFile.open(downloadsDir.path);
      Get.snackbar(
        'Success',
        'File saved to Downloads:\n$fileName',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Box Inventory Report (Excel)',
      );
    }
  }

  // ==================== EXCEL GENERATION (BULK) ====================
  Future<void> _generateAndShareBulkExcel(
    BulkBoxReportResponse report, {
    bool includeStats = true,
  }) async {
    final excel = exl.Excel.createExcel();

    // Overall summary sheet
    if (includeStats && report.summary != null) {
      final summarySheet = excel['Overall Summary'];
      summarySheet.appendRow([exl.TextCellValue('Generated')]);
      summarySheet
          .appendRow([exl.TextCellValue(DateTime.now().toIso8601String())]);
      summarySheet.appendRow([exl.TextCellValue('Total Boxes')]);
      summarySheet.appendRow([exl.IntCellValue(report.summary!.totalBoxes)]);
      summarySheet.appendRow([exl.TextCellValue('Total Clients')]);
      summarySheet.appendRow([exl.IntCellValue(report.summary!.totalClients)]);
      summarySheet.appendRow([exl.TextCellValue('Stored')]);
      summarySheet.appendRow(
          [exl.IntCellValue(report.summary!.statusCounts['stored'] ?? 0)]);
      summarySheet.appendRow([exl.TextCellValue('Retrieved')]);
      summarySheet.appendRow(
          [exl.IntCellValue(report.summary!.statusCounts['retrieved'] ?? 0)]);
      summarySheet.appendRow([exl.TextCellValue('Destroyed')]);
      summarySheet.appendRow(
          [exl.IntCellValue(report.summary!.statusCounts['destroyed'] ?? 0)]);
      summarySheet.appendRow([exl.TextCellValue('Pending Destruction')]);
      summarySheet
          .appendRow([exl.IntCellValue(report.summary!.pendingDestruction)]);
    }

    // One sheet per client
    for (final client in report.clients) {
      final sheetName = '${client.clientCode}';
      final sheet = excel[sheetName];

      // Client summary
      sheet.appendRow([exl.TextCellValue('Client')]);
      sheet.appendRow([exl.TextCellValue(client.clientName)]);
      sheet.appendRow([exl.TextCellValue('Total Boxes')]);
      sheet.appendRow([exl.IntCellValue(client.summary.totalBoxes)]);
      sheet.appendRow([exl.TextCellValue('Stored')]);
      sheet.appendRow([exl.IntCellValue(client.summary.stored)]);
      sheet.appendRow([exl.TextCellValue('Retrieved')]);
      sheet.appendRow([exl.IntCellValue(client.summary.retrieved)]);
      sheet.appendRow([exl.TextCellValue('Destroyed')]);
      sheet.appendRow([exl.IntCellValue(client.summary.destroyed)]);
      sheet.appendRow([exl.TextCellValue('Pending Destruction')]);
      sheet.appendRow([exl.IntCellValue(client.summary.pendingDestruction)]);
      sheet.appendRow([]); // empty row

      // Headers
      sheet.appendRow([
        exl.TextCellValue('Box Number'),
        exl.TextCellValue('Box Size'),
        exl.TextCellValue('Description'),
        exl.TextCellValue('Date Received'),
        exl.TextCellValue('Data Years'),
        exl.TextCellValue('Destruction Year'),
        exl.TextCellValue('Status'),
        exl.TextCellValue('Rack Label'),
        exl.TextCellValue('Rack Location'),
      ]);

      // Data rows
      for (final box in client.boxes) {
        sheet.appendRow([
          exl.TextCellValue(box.boxNumber),
          exl.TextCellValue(box.boxSize ?? ''),
          exl.TextCellValue(box.description ?? ''),
          exl.TextCellValue(box.dateReceived != null
              ? DateFormat('yyyy-MM-dd').format(box.dateReceived!)
              : ''),
          exl.TextCellValue(box.dataYears ?? ''),
          exl.IntCellValue(box.destructionYear ?? 0),
          exl.TextCellValue(box.status),
          exl.TextCellValue(box.rackLabel ?? ''),
          exl.TextCellValue(box.rackLocation ?? ''),
        ]);
      }
    }

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      Get.snackbar('Error', 'Failed to generate Excel file',
          backgroundColor: Colors.red);
      return;
    }

    final fileName =
        'bulk_box_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (Platform.isWindows) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        Get.snackbar('Error', 'Could not access Downloads folder',
            backgroundColor: Colors.red);
        return;
      }
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      await OpenFile.open(downloadsDir.path);
      Get.snackbar(
        'Success',
        'File saved to Downloads:\n$fileName',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Bulk Box Inventory Report (Excel)',
      );
    }
  }

  // ==================== PDF SHARE HELPER ====================
  Future<void> _sharePdf(pw.Document pdf) async {
    final pdfBytes = await pdf.save();
    final fileName =
        'box_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    if (Platform.isWindows) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        Get.snackbar('Error', 'Could not access Downloads folder',
            backgroundColor: Colors.red);
        return;
      }
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      await OpenFile.open(downloadsDir.path);
      Get.snackbar(
        'Success',
        'PDF saved to Downloads:\n$fileName',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Box Inventory Report');
    }
  }

  // ==================== LOGO LOADER ====================
  Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final logoData = await rootBundle.load('assets/logo/logo.jpeg');
      return pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print('Logo not found, proceeding without it');
      return null;
    }
  }

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: Color(0xFF2C3E50),
      unselectedLabelColor: Color(0xFF2C3E50).withOpacity(0.6),
      indicatorColor: Color(0xFF3498DB),
      indicatorWeight: 3,
      tabs: [
        Tab(icon: Icon(Icons.all_inbox), text: 'All Boxes'),
        Tab(icon: Icon(Icons.storage), text: 'In Storage'),
        Tab(icon: Icon(Icons.move_to_inbox), text: 'Retrieved'),
        Tab(icon: Icon(Icons.warning), text: 'Pending Destruction'),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            _applyFilter(status: 'all');
            break;
          case 1:
            _applyFilter(status: 'stored');
            break;
          case 2:
            _applyFilter(status: 'retrieved');
            break;
          case 3:
            _applyFilter(status: 'all', pendingOnly: true);
            break;
        }
      },
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        if (_showFilters) _buildFilterPanel(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildContentView(),
              _buildContentView(),
              _buildContentView(),
              _buildPendingDestructionView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  items: [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'stored', child: Text('Stored')),
                    DropdownMenuItem(
                        value: 'retrieved', child: Text('Retrieved')),
                    DropdownMenuItem(
                        value: 'destroyed', child: Text('Destroyed')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                      _applyFilter();
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Obx(() => DropdownButtonFormField<int?>(
                      value: _selectedClientId,
                      items: [
                        DropdownMenuItem(
                            value: null, child: Text('All Clients')),
                        ...boxController.clients.map((client) {
                          return DropdownMenuItem(
                            value: client.clientId,
                            child: Text(
                                '${client.clientCode} - ${client.clientName}'),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedClientId = value;
                          _applyFilter();
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Client',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _showPendingOnly,
                onChanged: (value) {
                  setState(() {
                    _showPendingOnly = value ?? false;
                    _applyFilter();
                  });
                },
              ),
              Text('Show only pending destruction'),
              Spacer(),
              OutlinedButton(
                onPressed: () => _clearFilters(),
                child: Text('Clear Filters'),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _applyFilter(),
                child: Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    return Obx(() {
      if (boxController.isLoading.value && boxController.boxes.isEmpty) {
        return Center(child: CircularProgressIndicator());
      }
      if (boxController.boxes.isEmpty) {
        return _buildEmptyState();
      }
      if (_viewMode == 0) {
        return _buildTableView();
      } else {
        return _buildGridView();
      }
    });
  }

  Widget _buildTableView() {
    return RefreshIndicator(
      onRefresh: () async {
        await boxController.getAllBoxes();
      },
      child: Scrollbar(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          children: [
            _buildTableHeader(),
            ...boxController.boxes.map((box) => _buildTableRow(box)).toList(),
            if (boxController.isLoading.value && boxController.boxes.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF3498DB)),
                  ),
                ),
              ),
            if (boxController.currentPage.value >=
                boxController.totalPages.value)
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'End of list',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (_isSelectMode)
            Container(
              width: 50,
              child: Checkbox(
                value: _selectedBoxes.length == boxController.boxes.length,
                onChanged: (value) {
                  if (value == true) {
                    _selectedBoxes.addAll(
                      boxController.boxes.map((box) => box.boxId).toSet(),
                    );
                  } else {
                    _selectedBoxes.clear();
                  }
                  setState(() {});
                },
              ),
            ),
          Expanded(flex: 1, child: Text('Box Number', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Description', style: _headerStyle)),
          Expanded(flex: 1, child: Text('Client', style: _headerStyle)),
          Expanded(flex: 1, child: Text('Status', style: _headerStyle)),
          Expanded(flex: 1, child: Text('Location', style: _headerStyle)),
          Expanded(flex: 1, child: Text('Actions', style: _headerStyle)),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Color(0xFF2C3E50),
      );

  Widget _buildTableRow(BoxModel box) {
    final isSelected = _selectedBoxes.contains(box.boxId);

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Color(0xFF3498DB).withOpacity(0.1)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Color(0xFF3498DB) : Colors.grey.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_isSelectMode) {
              setState(() {
                if (isSelected) {
                  _selectedBoxes.remove(box.boxId);
                } else {
                  _selectedBoxes.add(box.boxId);
                }
              });
            } else {
              _showBoxDetails(box);
            }
          },
          onLongPress: () {
            setState(() {
              _isSelectMode = true;
              _selectedBoxes.add(box.boxId);
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                if (_isSelectMode)
                  Container(
                    width: 50,
                    child: Checkbox(
                      value: isSelected,
                      activeColor: Color(0xFF3498DB),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedBoxes.add(box.boxId);
                          } else {
                            _selectedBoxes.remove(box.boxId);
                          }
                        });
                      },
                    ),
                  ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        box.boxNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF3498DB),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(box.dateReceived),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    box.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        box.client.clientCode,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        box.client.clientName,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(box.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(box.status),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(box.status),
                          size: 14,
                          color: _getStatusColor(box.status),
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            box.statusDisplay,
                            style: TextStyle(
                              fontSize: 12,
                              color: _getStatusColor(box.status),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    box.rackingLabel?.location ?? 'Not Assigned',
                    style: TextStyle(
                      fontSize: 13,
                      color: box.rackingLabel != null
                          ? Colors.grey[700]
                          : Colors.grey[500],
                      fontWeight: box.rackingLabel != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _buildActionButtons(box),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BoxModel box) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(Icons.visibility, size: 20),
          color: Color(0xFF3498DB),
          onPressed: () => _showBoxDetails(box),
          tooltip: 'View Details',
        ),
        if (authController.hasPermission('canEditBoxes'))
          IconButton(
            icon: Icon(Icons.edit, size: 20),
            color: Color(0xFF3498DB),
            onPressed: () => _editBox(box),
            tooltip: 'Edit',
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 20, color: Color(0xFF2C3E50)),
          itemBuilder: (context) => _buildBoxMenuItems(box),
          onSelected: (value) => _handleBoxAction(value, box),
        ),
      ],
    );
  }

  Widget _buildGridView() {
    return RefreshIndicator(
      onRefresh: () async {
        await boxController.getAllBoxes();
      },
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 1200
              ? 4
              : MediaQuery.of(context).size.width > 800
                  ? 3
                  : 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.8,
        ),
        padding: EdgeInsets.all(8),
        itemCount: boxController.boxes.length + 1,
        itemBuilder: (context, index) {
          if (index == boxController.boxes.length) {
            if (boxController.isLoading.value) {
              return Center(child: CircularProgressIndicator());
            }
            if (boxController.currentPage.value >=
                boxController.totalPages.value) {
              return Container();
            }
            return Center(child: CircularProgressIndicator());
          }
          final box = boxController.boxes[index];
          return _buildGridCard(box);
        },
      ),
    );
  }

  Widget _buildGridCard(BoxModel box) {
    final isSelected = _selectedBoxes.contains(box.boxId);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? BorderSide(color: Colors.blue, width: 2)
            : BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedBoxes.remove(box.boxId);
              } else {
                _selectedBoxes.add(box.boxId);
              }
            });
          } else {
            _showBoxDetails(box);
          }
        },
        onLongPress: () {
          setState(() {
            _isSelectMode = true;
            _selectedBoxes.add(box.boxId);
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: _getStatusColor(box.status),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            box.boxNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isSelectMode)
                          Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedBoxes.add(box.boxId);
                                } else {
                                  _selectedBoxes.remove(box.boxId);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      box.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.business, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            box.client.clientCode,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            box.rackingLabel?.location ?? 'No Location',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(box.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(_getStatusIcon(box.status),
                                  size: 12, color: _getStatusColor(box.status)),
                              SizedBox(width: 4),
                              Text(
                                box.statusDisplay,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusColor(box.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Spacer(),
                        Text(
                          DateFormat('MM/dd/yyyy').format(box.dateReceived),
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
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

  Widget _buildPendingDestructionView() {
    return Obx(() {
      final boxes = boxController.pendingDestructionBoxes;
      if (boxes.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green),
              SizedBox(height: 16),
              Text(
                'No boxes pending destruction',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text('All boxes are up to date',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }
      return ListView.builder(
        itemCount: boxes.length,
        itemBuilder: (context, index) {
          final box = boxes[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange[50],
            child: ListTile(
              leading: Icon(Icons.warning, color: Colors.orange),
              title: Text(box.boxNumber,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(box.description),
                  SizedBox(height: 4),
                  Text('Client: ${box.client.clientName}',
                      style: TextStyle(fontSize: 12)),
                  Text(
                    'Destruction Year: ${box.destructionYear} (${box.destructionYear} years overdue)',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.visibility),
                    onPressed: () => _showBoxDetails(box),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () => _markAsDestroyed(box),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
          SizedBox(height: 20),
          Text('No boxes found',
              style: TextStyle(fontSize: 20, color: Colors.grey)),
          SizedBox(height: 10),
          Text('Try adjusting your filters or create a new box',
              style: TextStyle(color: Colors.grey)),
          SizedBox(height: 20),
          if (authController.hasPermission('canCreateBoxes'))
            ElevatedButton.icon(
              onPressed: () => _showCreateBoxDialog(),
              icon: Icon(Icons.add),
              label: Text('Create New Box'),
            ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _showCreateBoxDialog(),
      backgroundColor: Color(0xFF3498DB),
      elevation: 4,
      icon: Icon(Icons.add, color: Colors.white),
      label: Text(
        'New Box',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBulkActionBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(top: BorderSide(color: Colors.blue[100]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            '${_selectedBoxes.length} boxes selected',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ElevatedButton.icon(
            onPressed: () => _bulkUpdateStatus('stored'),
            icon: Icon(Icons.storage, size: 18),
            label: Text('Mark as Stored'),
          ),
          ElevatedButton.icon(
            onPressed: () => _bulkUpdateStatus('retrieved'),
            icon: Icon(Icons.move_to_inbox, size: 18),
            label: Text('Mark as Retrieved'),
          ),
          ElevatedButton.icon(
            onPressed: () => _bulkUpdateStatus('destroyed'),
            icon: Icon(Icons.delete_forever, size: 18),
            label: Text('Mark as Destroyed'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isSelectMode = false;
                _selectedBoxes.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
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

  List<PopupMenuEntry<String>> _buildBoxMenuItems(BoxModel box) {
    final items = <PopupMenuEntry<String>>[];
    items.add(PopupMenuItem(
      value: 'view',
      child: ListTile(
          leading: Icon(Icons.visibility), title: Text('View Details')),
    ));
    if (authController.hasPermission('canEditBoxes')) {
      items.add(PopupMenuItem(
        value: 'edit',
        child: ListTile(leading: Icon(Icons.edit), title: Text('Edit Box')),
      ));
    }
    if (box.canBeRetrieved) {
      items.add(PopupMenuItem(
        value: 'retrieve',
        child: ListTile(
            leading: Icon(Icons.move_to_inbox),
            title: Text('Mark as Retrieved')),
      ));
    }
    if (box.canBeStored) {
      items.add(PopupMenuItem(
        value: 'store',
        child: ListTile(
            leading: Icon(Icons.storage), title: Text('Mark as Stored')),
      ));
    }
    if (box.canBeDestroyed && authController.hasPermission('canEditBoxes')) {
      items.add(PopupMenuItem(
        value: 'destroy',
        child: ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title:
                Text('Mark as Destroyed', style: TextStyle(color: Colors.red))),
      ));
    }
    if (authController.hasPermission('canDeleteBoxes') &&
        box.status != 'destroyed') {
      items.add(PopupMenuItem(
        value: 'delete',
        child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete Box', style: TextStyle(color: Colors.red))),
      ));
    }
    items.add(PopupMenuItem(
      value: 'audit',
      child:
          ListTile(leading: Icon(Icons.history), title: Text('View Audit Log')),
    ));
    return items;
  }

  void _handleAppBarAction(String action) {
    switch (action) {
      case 'export':
        _exportData();
        break;
      case 'print':
        _showReportOptionsDialog();
        break;
      case 'settings':
        _showSettings();
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
      case 'audit':
        _showAuditLog(box);
        break;
    }
  }

  void _applyFilter({String? status, bool? pendingOnly}) {
    setState(() {
      if (status != null) _selectedStatus = status;
      if (pendingOnly != null) _showPendingOnly = pendingOnly;
    });
    boxController.getAllBoxes(
      status: _selectedStatus == 'all' ? null : _selectedStatus,
      clientId: _selectedClientId,
      pendingDestruction: _showPendingOnly,
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'all';
      _selectedClientId = null;
      _showPendingOnly = false;
      _showFilters = false;
    });
    boxController.getAllBoxes();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Boxes'),
        content: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by box number, description, or client...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              boxController.getAllBoxes(search: _searchController.text);
            },
            child: Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showCreateBoxDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => BoxDialog(),
    );
  }

  void _editBox(BoxModel box) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => BoxDialog(box: box),
    );
  }

  void _showBoxDetails(BoxModel box) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: BoxDetailsDialog(box: box),
          ),
        ),
      ),
    );
  }

  void _changeBoxStatus(BoxModel box, String status) {
    Get.defaultDialog(
      title: 'Confirm Status Change',
      content: Text(
          'Change status of ${box.boxNumber} to ${status.capitalizeFirst}?'),
      textConfirm: 'Confirm',
      textCancel: 'Cancel',
      onConfirm: () async {
        Get.back();
        await boxController.changeBoxStatus(box.boxId, status);
      },
    );
  }

  void _markAsDestroyed(BoxModel box) {
    _changeBoxStatus(box, 'destroyed');
  }

  void _deleteBox(BoxModel box) {
    Get.defaultDialog(
      title: 'Delete Box',
      content: Text(
          'Are you sure you want to delete box ${box.boxNumber}? This action cannot be undone.'),
      textConfirm: 'Delete',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      onConfirm: () async {
        Get.back();
        await boxController.deleteBox(box.boxId);
      },
    );
  }

  void _bulkUpdateStatus(String status) {
    if (_selectedBoxes.isEmpty) return;
    Get.defaultDialog(
      title: 'Bulk Update Status',
      content: Text(
          'Update ${_selectedBoxes.length} boxes to ${status.capitalizeFirst}?'),
      textConfirm: 'Confirm',
      textCancel: 'Cancel',
      onConfirm: () async {
        Get.back();
        await boxController.bulkUpdateBoxStatus(
            _selectedBoxes.toList(), status);
        setState(() {
          _selectedBoxes.clear();
          _isSelectMode = false;
        });
      },
    );
  }

  void _exportData() {
    Get.snackbar('Info', 'Export feature coming soon',
        backgroundColor: Colors.blue, colorText: Colors.white);
  }

  void _showSettings() {
    Get.snackbar('Info', 'Settings feature coming soon',
        backgroundColor: Colors.blue, colorText: Colors.white);
  }

  void _showAuditLog(BoxModel box) {
    Get.snackbar('Info', 'Audit log feature coming soon',
        backgroundColor: Colors.blue, colorText: Colors.white);
  }
}
