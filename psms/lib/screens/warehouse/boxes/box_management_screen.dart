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
import 'widgets/box_dialog.dart'; // <-- new import
import 'widgets/box_details_dialog.dart'; // <-- new import

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

    // Initialize data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      boxController.initialize();
      storageController.initialize();
    });

    // Setup scroll listener for infinite scrolling
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
      // Search
      IconButton(
        icon: Icon(Icons.search, color: Color(0xFF2C3E50)),
        onPressed: () => _showSearchDialog(),
      ),
      // Filter
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
      // View mode toggle
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
      // Select mode
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
      // Refresh
      IconButton(
        icon: Icon(Icons.refresh, color: Color(0xFF2C3E50)),
        onPressed: () {
          boxController.initialize();
          storageController.initialize();
        },
      ),
      // More options
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

  // Show dialog to select client and report format

  void _showReportOptionsDialog() {
    final BoxController boxController = Get.find<BoxController>();
    RxInt selectedClientId = 0.obs; // 0 = All Clients
    RxString selectedFormat = 'Print'.obs;

    Get.dialog(
      AlertDialog(
        title: Text('Generate Box Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select client:'),
            SizedBox(height: 8),
            Obx(
              () => DropdownButton<int>(
                value: selectedClientId.value,
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: 0, child: Text('All Clients')),
                  ...boxController.clients.map(
                    (client) => DropdownMenuItem(
                      value: client.clientId,
                      child:
                          Text('${client.clientName} (${client.clientCode})'),
                    ),
                  ),
                ],
                onChanged: (value) => selectedClientId.value = value ?? 0,
              ),
            ),
            SizedBox(height: 16),
            Text('Choose format:'),
            SizedBox(height: 8),
            Obx(
              () => Column(
                children: [
                  RadioListTile<String>(
                    title: Text('Print / Save as PDF'),
                    value: 'Print',
                    groupValue: selectedFormat.value,
                    onChanged: (val) => selectedFormat.value = val!,
                  ),
                  RadioListTile<String>(
                    title: Text('Excel (preview & save)'),
                    value: 'Excel',
                    groupValue: selectedFormat.value,
                    onChanged: (val) => selectedFormat.value = val!,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back(); // close options dialog
              final clientId =
                  selectedClientId.value == 0 ? null : selectedClientId.value;
              final report =
                  await boxController.getBoxReport(clientId: clientId);
              if (report == null) {
                Get.snackbar('Error', 'Failed to generate report',
                    backgroundColor: Colors.red);
                return;
              }
              if (selectedFormat.value == 'Print') {
                await _generateAndShowPdfPreview(report, clientId: clientId);
              } else {
                _showExcelPreview(report, clientId: clientId);
              }
            },
            child: Text('Generate'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndShowPdfPreview(
    BoxReportResponse report, {
    int? clientId,
  }) async {
    final pdf = await _buildPdfDocument(report, clientId: clientId);

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
                        Get.back(); // close preview
                        await _sharePdf(pdf);
                      },
                      icon: Icon(Icons.save),
                      label: Text('Save PDF'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Get.back(); // close dialog
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

  Future<pw.Document> _buildPdfDocument(
    BoxReportResponse report, {
    int? clientId,
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
          pw.TableHelper.fromTextArray(
            headers: [
              'Box #',
              'Size',
              'Description',
              'Date Received',
              'Year',
              'Status'
            ],
            data: report.boxes
                .map((box) => [
                      box.boxNumber,
                      box.boxSize,
                      box.description ?? '',
                      box.datesRange ?? '',
                      box.dataYears?.toString() ?? '',
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
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(3),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1.5),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
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
        ],
      ),
    );

    return pdf;
  }

  Future<void> _sharePdf(pw.Document pdf) async {
    final pdfBytes = await pdf.save();
    final fileName =
        'box_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    if (Platform.isWindows) {
      // Windows: save to Downloads and open folder
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
      // Other platforms: share via share_plus
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Box Inventory Report');
    }
  }

  void _showExcelPreview(BoxReportResponse report, {int? clientId}) {
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
                        DataColumn(label: Text('Year')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: report.boxes.map((box) {
                        return DataRow(cells: [
                          DataCell(Text(box.boxNumber)),
                          DataCell(Text(box.boxSize)),
                          DataCell(Text(box.description ?? '')),
                          DataCell(Text(box.datesRange ?? '')),
                          DataCell(Text(box.dataYears?.toString() ?? '')),
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
                        Get.back(); // close preview
                        await _generateAndShareExcel(report,
                            clientId: clientId);
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

  Future<void> _generateAndShareExcel(
    BoxReportResponse report, {
    int? clientId,
  }) async {
    // Create Excel file
    final excel = exl.Excel.createExcel();
    final sheet = excel['Box Report'];

    // Headers – wrap each in TextCellValue
    sheet.appendRow([
      exl.TextCellValue('Box Number'),
      exl.TextCellValue('Box Size'),
      exl.TextCellValue('Description'),
      exl.TextCellValue('Date Received'),
      exl.TextCellValue('Year Received'),
      exl.TextCellValue('Status'),
      exl.TextCellValue('Client ID'),
      exl.TextCellValue('Client Name'),
      exl.TextCellValue('Client Code'),
    ]);

    // Data rows
    for (final box in report.boxes) {
      sheet.appendRow([
        exl.TextCellValue(box.boxNumber),
        exl.TextCellValue(box.boxSize),
        exl.TextCellValue(box.description ?? ''),
        exl.TextCellValue(box.datesRange ?? ''),
        // Year Received: use IntCellValue if not null, otherwise empty string
        box.dataYears != null
            ? exl.IntCellValue(box.dataYears!)
            : exl.TextCellValue(''),
        exl.TextCellValue(box.status),
        exl.IntCellValue(box.client.clientId),
        exl.TextCellValue(box.client.clientName),
        exl.TextCellValue(box.client.clientCode),
      ]);
    }

    // Save file
    final fileBytes = excel.encode();
    if (fileBytes == null) {
      Get.snackbar('Error', 'Failed to generate Excel file',
          backgroundColor: Colors.red);
      return;
    }

    final fileName =
        'box_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (Platform.isWindows) {
      // Windows: save to Downloads folder and open the folder
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        Get.snackbar('Error', 'Could not access Downloads folder',
            backgroundColor: Colors.red);
        return;
      }
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      // Open the folder containing the file
      await OpenFile.open(downloadsDir.path);
      Get.snackbar(
        'Success',
        'File saved to Downloads:\n$fileName',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
    } else {
      // Other platforms: use share_plus
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Box Inventory Report (Excel)',
      );
    }
  }

// Generate CSV and share

// Generate PDF report and print/share

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
        // Apply filters based on tab
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
        // Filter panel
        if (_showFilters) _buildFilterPanel(),

        // Main content
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
              // Status filter
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

              // Client filter
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
              // Pending destruction filter
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

              // Clear filters
              OutlinedButton(
                onPressed: () => _clearFilters(),
                child: Text('Clear Filters'),
              ),
              SizedBox(width: 8),

              // Apply filters
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
            // Table header
            _buildTableHeader(),

            // Table rows
            ...boxController.boxes.map((box) => _buildTableRow(box)).toList(),

            // Loading more indicator
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

            // End of list
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
          Expanded(
            flex: 1,
            child: Text(
              'Box Number',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Description',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Client',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Location',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Actions',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2C3E50),
                    ),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
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
            // Header with status color
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

            // Card content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Box number and checkbox
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

                    // Description
                    Text(
                      box.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14),
                    ),

                    SizedBox(height: 12),

                    // Client info
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

                    // Location
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

                    // Status and date
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
              Text(
                'All boxes are up to date',
                style: TextStyle(color: Colors.grey),
              ),
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
              title: Text(
                box.boxNumber,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(box.description),
                  SizedBox(height: 4),
                  Text(
                    'Client: ${box.client.clientName}',
                    style: TextStyle(fontSize: 12),
                  ),
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
          Text(
            'No boxes found',
            style: TextStyle(fontSize: 20, color: Colors.grey),
          ),
          SizedBox(height: 10),
          Text(
            'Try adjusting your filters or create a new box',
            style: TextStyle(color: Colors.grey),
          ),
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
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
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

  // Helper methods
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
        leading: Icon(Icons.visibility),
        title: Text('View Details'),
      ),
    ));

    if (authController.hasPermission('canEditBoxes')) {
      items.add(PopupMenuItem(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit),
          title: Text('Edit Box'),
        ),
      ));
    }

    if (box.canBeRetrieved) {
      items.add(PopupMenuItem(
        value: 'retrieve',
        child: ListTile(
          leading: Icon(Icons.move_to_inbox),
          title: Text('Mark as Retrieved'),
        ),
      ));
    }

    if (box.canBeStored) {
      items.add(PopupMenuItem(
        value: 'store',
        child: ListTile(
          leading: Icon(Icons.storage),
          title: Text('Mark as Stored'),
        ),
      ));
    }

    if (box.canBeDestroyed && authController.hasPermission('canEditBoxes')) {
      items.add(PopupMenuItem(
        value: 'destroy',
        child: ListTile(
          leading: Icon(Icons.delete_forever, color: Colors.red),
          title: Text('Mark as Destroyed', style: TextStyle(color: Colors.red)),
        ),
      ));
    }

    if (authController.hasPermission('canDeleteBoxes') &&
        box.status != 'destroyed') {
      items.add(PopupMenuItem(
        value: 'delete',
        child: ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('Delete Box', style: TextStyle(color: Colors.red)),
        ),
      ));
    }

    items.add(PopupMenuItem(
      value: 'audit',
      child: ListTile(
        leading: Icon(Icons.history),
        title: Text('View Audit Log'),
      ),
    ));

    return items;
  }

  // Action handlers
  void _handleAppBarAction(String action) {
    switch (action) {
      case 'export':
        _exportData();
        break;
      case 'print':
        // _printReport();
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

  // Filter methods
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
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
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

  // CRUD Operations
  void _showCreateBoxDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BoxDialog();
      },
    );
  }

  void _editBox(BoxModel box) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BoxDialog(box: box);
      },
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
    Get.snackbar(
      'Info',
      'Export feature coming soon',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  void _showSettings() {
    Get.snackbar(
      'Info',
      'Settings feature coming soon',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  void _showAuditLog(BoxModel box) {
    Get.snackbar(
      'Info',
      'Audit log feature coming soon',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }
}
