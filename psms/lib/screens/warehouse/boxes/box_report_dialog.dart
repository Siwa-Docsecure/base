import 'package:excel/excel.dart' as exl;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:psms/controllers/box_controller.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/controllers/storage_controller.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:psms/models/report_models.dart';
import 'package:psms/models/client_model.dart';
import 'package:share_plus/share_plus.dart';
import 'widgets/client_search_field.dart';


  // ==================== ENHANCED REPORT DIALOG ====================

void showReportOptionsDialog() {
    final BoxController boxController = Get.find<BoxController>();
    // Ensure storageController is available (if not already in scope)
    final StorageController storageController = Get.find<StorageController>();
    // Same controller UserDialogs/BoxDialog use for client pickers — reuse
    // the existing instance if the app already registered one.
    final ClientManagementController clientController =
        Get.isRegistered<ClientManagementController>()
            ? Get.find<ClientManagementController>()
            : Get.put(ClientManagementController());
    // fetchClients() is paginated (20/page by default) — bump the page
    // size so this one call returns every client, not just page 1.
    clientController.itemsPerPage.value = 1000;
    clientController.fetchClients(showLoading: true);

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
                              ? ClientSearchField(
                                  clients: clientController.clients
                                      .where((c) => c.isActive)
                                      .toList(),
                                  selectedClientId: selectedClientId.value == 0
                                      ? null
                                      : selectedClientId.value,
                                  isLoading: clientController.isLoading.value,
                                  allOptionLabel: 'All Clients',
                                  label: 'Client',
                                  onChanged: (value) =>
                                      selectedClientId.value = value ?? 0,
                                )
                              : ClientMultiSelectField(
                                  clients: clientController.clients
                                      .where((c) => c.isActive)
                                      .toList(),
                                  selectedClientIds: selectedClientIds,
                                  isLoading: clientController.isLoading.value,
                                  label: 'Clients',
                                  emptyLabel: 'All Clients (optional)',
                                  onChanged: (ids) {
                                    selectedClientIds
                                      ..clear()
                                      ..addAll(ids);
                                  },
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
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
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

  pw.Widget _buildCompactStat(String label, String value) {
    return pw.Row(
      children: [
        pw.Text('$label: ',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.Text(value, style: pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  // ==================== SAFE CLIENT LOOKUP ====================
  // report.boxes can legitimately be empty (a client with zero boxes
  // matching the current filters) — never index into it with .first.
  // This looks the client up directly instead, so report generation
  // still works and shows the real client name/code either way.
  ClientModel? _lookupClient(int? clientId) {
    if (clientId == null) return null;
    try {
      final clientController = Get.isRegistered<ClientManagementController>()
          ? Get.find<ClientManagementController>()
          : null;
      if (clientController == null) return null;
      for (final c in clientController.clients) {
        if (c.clientId == clientId) return c;
      }
    } catch (_) {
      // Controller not available for some reason — fall through to the
      // generic "Client #id" label below rather than crashing.
    }
    return null;
  }

  String _clientLabel(int? clientId, {String fallbackAllLabel = 'All Clients'}) {
    if (clientId == null) return fallbackAllLabel;
    final client = _lookupClient(clientId);
    if (client != null) return '${client.clientName} (${client.clientCode})';
    return 'Client #$clientId';
  }

  // ==================== PDF BUILD (SINGLE) ====================
  Future<pw.Document> _buildPdfDocument(
    BoxReportResponse report, {
    int? clientId,
    bool includeStats = true,
  }) async {
    final pdf = pw.Document();

    // Determine if this is a single‑client report and the client name for the signature
    final bool isSingleClient = clientId != null;
    final String? clientNameForSignature =
        isSingleClient ? _lookupClient(clientId)?.clientName : null;

    // Load fonts
    final fontData = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final boldFontData =
        await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(boldFontData);

    // Load logo (optional)
    final logoImage = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),

        // ===== HEADER (only on first page) =====
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
              // Client info (always shown)
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    color: PdfColors.white),
                child: pw.Row(
                  children: [
                    pw.Text('Client: ',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text(
                      _clientLabel(clientId),
                      style: pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ]);
          }
          return pw.Container();
        },

        // ===== FOOTER (page numbers) =====
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ),

        // ===== MAIN CONTENT =====
        build: (context) {
          final List<pw.Widget> content = [];

          // ---- 1. Filters Table (if any) ----
          content.add(pw.Text('Filters Applied',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)));
          content.add(pw.SizedBox(height: 6));

          if (report.filters.isEmpty) {
            // No filters – show "N/A"
            content.add(
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('No filters applied',
                        style: pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ),
            );
          } else {
            // Build a two‑column table of filters
            final filterData =
                report.filters.entries.map((e) => [e.key, e.value]).toList();
            content.add(
              pw.TableHelper.fromTextArray(
                headers: ['Filter', 'Value'],
                data: filterData,
                border:
                    pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: pw.TextStyle(fontSize: 9),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(2),
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                },
              ),
            );
          }
          content.add(pw.SizedBox(height: 16));

          // ---- 2. Summary Table (if requested) ----
          if (includeStats && report.summary != null) {
            content.add(pw.Text('Summary',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)));
            content.add(pw.SizedBox(height: 6));

            final summaryData = [
              ['Total Boxes', report.summary!.totalBoxes.toString()],
              ['Unique Clients', report.summary!.uniqueClients.toString()],
              [
                'Stored',
                (report.summary!.statusCounts['stored'] ?? 0).toString()
              ],
              [
                'Retrieved',
                (report.summary!.statusCounts['retrieved'] ?? 0).toString()
              ],
              [
                'Destroyed',
                (report.summary!.statusCounts['destroyed'] ?? 0).toString()
              ],
              [
                'Pending Destruction',
                report.summary!.pendingDestruction.toString()
              ],
            ];

            content.add(
              pw.TableHelper.fromTextArray(
                headers: ['Metric', 'Value'],
                data: summaryData,
                border:
                    pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: pw.TextStyle(fontSize: 9),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1),
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                },
              ),
            );
            content.add(pw.SizedBox(height: 16));
          }

          // ---- 3. Boxes Table ----
          content.add(
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
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(0.8),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1),
                6: const pw.FlexColumnWidth(1),
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
          );

          content.add(pw.SizedBox(height: 20));

          // ---- 4. Footer summary line (total boxes) ----
          content.add(
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
                      style:
                          pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ),
          );

          content.add(pw.Spacer());

          // ---- 5. Signature row (conditional) ----
          content.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Representative signature (always)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Docsecure Representative',
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.normal)),
                    pw.SizedBox(height: 10),
                    pw.Text('_____________________________',
                        style: pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
                // Client signature – only for single‑client reports
                if (clientNameForSignature != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('For Client: $clientNameForSignature',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.normal)),
                      pw.SizedBox(height: 10),
                      pw.Text('______________________________',
                          style: pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
              ],
            ),
          );

          return content;
        },
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
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${client.clientName} (${client.clientCode})',
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      _buildCompactStat(
                          'Total', client.summary.totalBoxes.toString()),
                      pw.SizedBox(width: 12),
                      _buildCompactStat(
                          'Stored', client.summary.stored.toString()),
                      pw.SizedBox(width: 12),
                      _buildCompactStat(
                          'Retrieved', client.summary.retrieved.toString()),
                      pw.SizedBox(width: 12),
                      _buildCompactStat(
                          'Destroyed', client.summary.destroyed.toString()),
                      pw.SizedBox(width: 12),
                      _buildCompactStat('Pending',
                          client.summary.pendingDestruction.toString()),
                    ],
                  ),
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