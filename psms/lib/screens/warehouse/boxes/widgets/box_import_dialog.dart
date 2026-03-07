// box_import_dialog.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:psms/controllers/box_controller.dart';
import 'package:psms/models/box_model.dart';

class BoxImportDialog extends StatefulWidget {
  const BoxImportDialog({super.key});

  @override
  State<BoxImportDialog> createState() => _BoxImportDialogState();
}

class _BoxImportDialogState extends State<BoxImportDialog> {
  final BoxController _boxController = Get.find<BoxController>();

  // ─── State ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _fileName;
  Uint8List? _fileBytes;
  String? _fileError;
  bool _isParsed = false;
  List<Map<String, dynamic>> _parsedBoxes = [];
  List<String> _validationErrors = [];
  Map<String, dynamic>? _uploadResults; // null = not yet uploaded

  int _previewPage = 0;
  static const int _kRowsPerPage = 10;

  // ─── Derived ──────────────────────────────────────────────────────────────
  bool get _fileReady =>
      _fileName != null && _fileError == null && _fileBytes != null;
  bool get _canUpload =>
      _fileReady && _isParsed && _parsedBoxes.isNotEmpty && !_isLoading;

  // =========================================================================
  // FIELD MAPPING
  // Keys:   lowercase, spaces / underscores / hyphens stripped.
  // Values: camelCase matching POST /api/boxes/bulk/create payload.
  //
  // DB columns (from box_routes.js INSERT):
  //   box_number       → generated server-side as clientCode-boxIndex
  //   client_id        → clientId (int, required)
  //   racking_label_id → rackingLabelId (int | null)
  //   box_description  → boxDescription (string, required)
  //   date_received    → dateReceived ("yyyy-MM-dd", required)
  //   year_received    → auto-derived server-side
  //   retention_years  → retentionYears (int, default 7)
  //   status           → always 'stored' on create
  //   box_size         → boxSize (ENUM: A0-A6 / Custom | null)
  //   data_years       → dataYears (string | null)
  //   date_range       → dateRange (string | null)
  //   box_image        → boxImage (string | null)
  //   destruction_year → auto-calculated by DB trigger
  // =========================================================================
  static const Map<String, String> _fieldMapping = {
    // clientId
    'clientid': 'clientId',
    'client': 'clientId',
    'customerid': 'clientId',
    // boxIndex — string suffix; API builds boxNumber = clientCode-boxIndex
    'boxindex': 'boxIndex',
    'boxno': 'boxIndex',
    'boxnumber': 'boxIndex',
    'index': 'boxIndex',
    // boxDescription
    'boxdescription': 'boxDescription',
    'description': 'boxDescription',
    'desc': 'boxDescription',
    // dateReceived
    'datereceived': 'dateReceived',
    'receiveddate': 'dateReceived',
    'received': 'dateReceived',
    // retentionYears
    'retentionyears': 'retentionYears',
    'retention': 'retentionYears',
    // rackingLabelId
    'rackinglabelid': 'rackingLabelId',
    'labelid': 'rackingLabelId',
    'rack': 'rackingLabelId',
    // boxSize (ENUM)
    'boxsize': 'boxSize',
    'size': 'boxSize',
    // dataYears
    'datayears': 'dataYears',
    // dateRange
    'daterange': 'dateRange',
    // boxImage
    'boximage': 'boxImage',
    'image': 'boxImage',
  };

  static const List<String> _requiredFields = [
    'clientId',
    'boxIndex',
    'boxDescription',
    'dateReceived',
  ];

  static const List<String> _allowedBoxSizes = [
    'A0',
    'A1',
    'A2',
    'A3',
    'A4',
    'A5',
    'A6',
    'Custom',
  ];

  // Preview column definitions — match API field names exactly
  static const List<_ColDef> _previewCols = [
    _ColDef('Client ID', 'clientId', 80),
    _ColDef('Box Index', 'boxIndex', 110),
    _ColDef('Description', 'boxDescription', 200),
    _ColDef('Date Received', 'dateReceived', 120),
    _ColDef('Retention yrs', 'retentionYears', 90),
    _ColDef('Rack Label ID', 'rackingLabelId', 100),
    _ColDef('Box Size', 'boxSize', 80),
    _ColDef('Data Years', 'dataYears', 90),
    _ColDef('Date Range', 'dateRange', 120),
  ];

  // =========================================================================
  // BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [Color(0xFF3498DB), Color(0xFF5DADE2)]),
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
            child: const Icon(Icons.upload_file, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Import Boxes from Excel',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 2),
                Text('Bulk create boxes from .xlsx / .xls',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ─── Content ──────────────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_uploadResults != null) return _buildResultsView();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilePicker(),
          if (_parsedBoxes.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildPreviewHeader(),
            const SizedBox(height: 12),
            Expanded(child: _buildPreviewTable()),
            if (_validationErrors.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildErrorList(),
            ],
          ] else ...[
            const SizedBox(height: 20),
            _buildTemplateHint(),
          ],
        ],
      ),
    );
  }

  // ─── File Picker ──────────────────────────────────────────────────────────
  Widget _buildFilePicker() {
    final hasError = _fileError != null;
    final borderColor = _fileReady
        ? Colors.green[300]!
        : (hasError ? Colors.red[300]! : Colors.grey[300]!);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fileReady
            ? Colors.green[50]
            : (hasError ? Colors.red[50] : Colors.grey[50]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: _fileReady ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // State icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLoading && !_isParsed
                    ? const SizedBox(
                        key: ValueKey('spin'),
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : _fileReady
                        ? const Icon(Icons.check_circle,
                            color: Colors.green, key: ValueKey('ok'))
                        : (hasError
                            ? const Icon(Icons.error_outline,
                                color: Colors.red, key: ValueKey('err'))
                            : const Icon(Icons.attach_file,
                                color: Colors.grey, key: ValueKey('none'))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Excel file (.xlsx / .xls)',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      _fileName ?? 'No file chosen',
                      style: TextStyle(
                        color: _fileReady
                            ? Colors.green[800]
                            : (_fileName != null
                                ? Colors.grey[700]
                                : Colors.grey[500]),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickFile,
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(_fileName == null ? 'Browse' : 'Change'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),

          // Status badges
          if (_isParsed && _fileReady) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatusBadge(
                  icon: Icons.table_chart,
                  label: '${_parsedBoxes.length} rows ready',
                  color: _parsedBoxes.isNotEmpty ? Colors.green : Colors.orange,
                ),
                if (_validationErrors.isNotEmpty)
                  _StatusBadge(
                    icon: Icons.warning_amber,
                    label: '${_validationErrors.length} row(s) skipped',
                    color: Colors.red,
                  ),
              ],
            ),
          ],

          // File-level error
          if (hasError) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_fileError!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Template Hint ────────────────────────────────────────────────────────
  Widget _buildTemplateHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF5FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFAED6F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF2980B9)),
              SizedBox(width: 8),
              Text('Required Excel Columns',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A5276),
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ColumnChip('clientId', required: true),
              _ColumnChip('boxIndex', required: true),
              _ColumnChip('boxDescription', required: true),
              _ColumnChip('dateReceived', required: true),
              _ColumnChip('retentionYears'),
              _ColumnChip('rackingLabelId'),
              _ColumnChip('boxSize'),
              _ColumnChip('dataYears'),
              _ColumnChip('dateRange'),
              _ColumnChip('boxImage'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'boxSize: ${_allowedBoxSizes.join(' | ')}  •  '
            'dateReceived: YYYY-MM-DD  •  '
            'retentionYears defaults to 7',
            style: TextStyle(fontSize: 11, color: Colors.blue[800]),
          ),
        ],
      ),
    );
  }

  // ─── Preview Header ───────────────────────────────────────────────────────
  Widget _buildPreviewHeader() {
    return Row(
      children: [
        Text(
          'Preview — ${_parsedBoxes.length} box(es)',
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50)),
        ),
        const Spacer(),
        if (_validationErrors.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber, size: 14, color: Colors.orange[800]),
                const SizedBox(width: 4),
                Text(
                  '${_validationErrors.length} skipped',
                  style: TextStyle(color: Colors.orange[800], fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Preview Table ────────────────────────────────────────────────────────
  Widget _buildPreviewTable() {
    final totalPages =
        (_parsedBoxes.length / _kRowsPerPage).ceil().clamp(1, 99999);
    final start = _previewPage * _kRowsPerPage;
    final end = (start + _kRowsPerPage).clamp(0, _parsedBoxes.length);
    final pageData = _parsedBoxes.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _BiDirectionalScrollTable(
                columns: _previewCols,
                rows: pageData,
              ),
            ),
          ),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.first_page),
                  onPressed: _previewPage > 0
                      ? () => setState(() => _previewPage = 0)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previewPage > 0
                      ? () => setState(() => _previewPage--)
                      : null,
                ),
                Text('Page ${_previewPage + 1} of $totalPages',
                    style: const TextStyle(fontSize: 13)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _previewPage < totalPages - 1
                      ? () => setState(() => _previewPage++)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.last_page),
                  onPressed: _previewPage < totalPages - 1
                      ? () => setState(() => _previewPage = totalPages - 1)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Validation Error List ────────────────────────────────────────────────
  Widget _buildErrorList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 110),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Skipped rows:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 12)),
            const SizedBox(height: 4),
            ..._validationErrors.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(e, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ─── Results View ─────────────────────────────────────────────────────────
  // API response shape:
  //   data.success  → [{ boxNumber, boxId, boxIndex }]
  //   data.failed   → [{ clientId, boxIndex, error }]
  Widget _buildResultsView() {
    final successList =
        (_uploadResults!['success'] as List?)?.cast<Map>() ?? [];
    final failedList = (_uploadResults!['failed'] as List?)?.cast<Map>() ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  successList.isNotEmpty ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: successList.isNotEmpty
                    ? Colors.green[200]!
                    : Colors.orange[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  successList.isNotEmpty
                      ? Icons.check_circle
                      : Icons.info_outline,
                  color: successList.isNotEmpty ? Colors.green : Colors.orange,
                  size: 36,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Complete',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: successList.isNotEmpty
                              ? Colors.green[900]
                              : Colors.orange[900],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _StatusBadge(
                            icon: Icons.check,
                            label: '${successList.length} imported',
                            color: Colors.green,
                          ),
                          if (failedList.isNotEmpty)
                            _StatusBadge(
                              icon: Icons.close,
                              label: '${failedList.length} failed',
                              color: Colors.red,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Success table
          if (successList.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Imported Boxes',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF27AE60))),
            const SizedBox(height: 8),
            Expanded(
              flex: failedList.isNotEmpty ? 1 : 2,
              child: _ResultTable(
                columns: const ['Box Number', 'Box Index', 'Box ID'],
                rows: successList
                    .map((s) => [
                          s['boxNumber']?.toString() ?? '—',
                          s['boxIndex']?.toString() ?? '—',
                          s['boxId']?.toString() ?? '—',
                        ])
                    .toList(),
                rowColor: Colors.green[50]!,
                headerColor: Colors.green[100]!,
                icon: Icons.check_circle_outline,
                iconColor: Colors.green,
              ),
            ),
          ],

          // Failed table
          if (failedList.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Failed Entries',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.red)),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: _ResultTable(
                columns: const ['Client ID', 'Box Index', 'Error'],
                rows: failedList
                    .map((f) => [
                          f['clientId']?.toString() ?? '—',
                          f['boxIndex']?.toString() ?? '—',
                          f['error']?.toString() ?? 'Unknown error',
                        ])
                    .toList(),
                rowColor: Colors.red[50]!,
                headerColor: Colors.red[100]!,
                icon: Icons.error_outline,
                iconColor: Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    final String btnLabel = _isLoading
        ? (_isParsed ? 'Uploading…' : 'Parsing…')
        : (_canUpload
            ? 'Import ${_parsedBoxes.length} Boxes'
            : 'Select a File');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_uploadResults == null) ...[
            OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _canUpload ? _uploadData : null,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(btnLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canUpload ? const Color(0xFF3498DB) : Colors.grey[400],
                foregroundColor: Colors.white,
              ),
            ),
          ] else
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // FILE HANDLING
  // =========================================================================

  Future<void> _pickFile() async {
    setState(() {
      _fileError = null;
      _isParsed = false;
      _parsedBoxes = [];
      _validationErrors = [];
      _uploadResults = null;
      _previewPage = 0;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: kIsWeb, // web: bytes in-memory; native: path
        withReadStream: false,
      );

      if (result == null) return; // user cancelled

      final picked = result.files.single;
      setState(() {
        _fileName = picked.name;
        _isLoading = true;
      });

      Uint8List? bytes;
      if (kIsWeb) {
        bytes = picked.bytes;
      } else {
        final path = picked.path;
        if (path == null) {
          setState(() {
            _fileError = 'Could not access file path on this platform.';
            _isLoading = false;
          });
          return;
        }
        bytes = await File(path).readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _fileError = 'File is empty or could not be read.';
          _isLoading = false;
        });
        return;
      }

      setState(() => _fileBytes = bytes);
      await _parseExcel(bytes);
    } catch (e) {
      setState(() {
        _fileError = 'File error: $e';
        _isLoading = false;
      });
    }
  }

  // =========================================================================
  // EXCEL PARSING
  // =========================================================================

  Future<void> _parseExcel(Uint8List bytes) async {
    try {
      final workbook = excel.Excel.decodeBytes(bytes);
      final sheet = workbook.tables.values.first;

      if (sheet.rows.isEmpty) {
        setState(() {
          _validationErrors.add('Excel file is empty.');
          _isParsed = true;
          _isLoading = false;
        });
        return;
      }

      // ── Map column index → canonical field name ────────────────────
      final headerRow = sheet.rows.first;
      final Map<int, String> colMap = {};

      for (int i = 0; i < headerRow.length; i++) {
        final raw = _cellValue(headerRow[i]);
        if (raw == null) continue;
        final key = _normaliseHeader(raw.toString());
        final canonical = _fieldMapping[key];
        if (canonical != null) colMap[i] = canonical;
      }

      // Check required columns present
      final present = colMap.values.toSet();
      final missing =
          _requiredFields.where((f) => !present.contains(f)).toList();
      if (missing.isNotEmpty) {
        setState(() {
          _validationErrors
              .add('Missing required column(s): ${missing.join(', ')}');
          _isParsed = true;
          _isLoading = false;
        });
        return;
      }

      // ── Process data rows ──────────────────────────────────────────
      final List<Map<String, dynamic>> parsed = [];
      final List<String> errors = [];

      for (int ri = 1; ri < sheet.rows.length; ri++) {
        final row = sheet.rows[ri];

        // Skip completely blank rows
        if (row.every((c) => _cellValue(c) == null)) continue;

        final Map<String, dynamic> box = {};

        colMap.forEach((ci, field) {
          if (ci >= row.length) return;
          final raw = _cellValue(row[ci]);
          if (raw == null) return;

          switch (field) {
            // Int fields: Excel stores these as DoubleCellValue (e.g. 1 → 1.0)
            // _toInt() handles int, double, and string "1.0"
            case 'clientId':
            case 'rackingLabelId':
            case 'retentionYears':
              box[field] = _toInt(raw);
              break;

            // boxIndex must stay as string.
            // Numeric Excel cells (1.0) → "1"; text cells ("001") → "001"
            case 'boxIndex':
              box[field] = _toBoxIndexString(raw);
              break;

            // Date → ISO "yyyy-MM-dd" string
            case 'dateReceived':
              box[field] = _parseDate(raw);
              break;

            // All other string fields
            default:
              box[field] = raw.toString().trim();
          }
        });

        // Defaults
        box.putIfAbsent('retentionYears', () => 7);

        // ── Row validation ─────────────────────────────────────────
        final label = 'Row ${ri + 1}';
        bool valid = true;

        void fail(String msg) {
          errors.add('$label: $msg');
          valid = false;
        }

        final clientId = _toInt(box['clientId'] ?? 0);
        if (clientId <= 0) {
          fail('clientId is missing or invalid — must be a positive integer'
              ' (check that the Excel cell is a number, not text)');
        }

        if ((box['boxIndex']?.toString().trim() ?? '').isEmpty) {
          fail('boxIndex is missing');
        }

        if ((box['boxDescription']?.toString().trim() ?? '').isEmpty) {
          fail('boxDescription is missing');
        }

        if ((box['dateReceived']?.toString().trim() ?? '').isEmpty) {
          fail('dateReceived is missing or could not be parsed');
        }

        final boxSize = box['boxSize']?.toString().trim();
        if (boxSize != null &&
            boxSize.isNotEmpty &&
            !_allowedBoxSizes.contains(boxSize)) {
          fail(
              'boxSize "$boxSize" invalid — allowed: ${_allowedBoxSizes.join(', ')}');
        }

        if (valid) parsed.add(box);
      }

      setState(() {
        _parsedBoxes = parsed;
        _validationErrors = errors;
        _isParsed = true;
        _isLoading = false;
      });

      if (parsed.isEmpty) {
        Get.snackbar('No Valid Data',
            'No importable rows found. Check column names and values.',
            backgroundColor: Colors.orange, colorText: Colors.white);
      } else if (errors.isNotEmpty) {
        Get.snackbar('Parsed with Warnings',
            '${parsed.length} valid, ${errors.length} skipped.',
            backgroundColor: Colors.orange, colorText: Colors.white);
      } else {
        Get.snackbar(
            'Ready', '${parsed.length} box(es) parsed and ready to import.',
            backgroundColor: Colors.green, colorText: Colors.white);
      }
    } catch (e) {
      setState(() {
        _validationErrors.add('Parsing error: $e');
        _isParsed = true;
        _isLoading = false;
      });
    }
  }

  // =========================================================================
  // UPLOAD
  // =========================================================================

  Future<void> _uploadData() async {
    if (_parsedBoxes.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      // Build payload exactly as POST /api/boxes/bulk/create expects.
      // Only include optional fields when non-null and non-empty so the
      // server does not receive e.g. rackingLabelId: 0 for rows without one.
      final boxes = _parsedBoxes.map((b) {
        final Map<String, dynamic> entry = {
          'clientId': _toInt(b['clientId']),
          'boxIndex': b['boxIndex'].toString(),
          'boxDescription': b['boxDescription'].toString(),
          'dateReceived': b['dateReceived'].toString(),
          'retentionYears': _toInt(b['retentionYears'] ?? 7),
        };

        final rackId = _toInt(b['rackingLabelId'] ?? 0);
        if (rackId > 0) entry['rackingLabelId'] = rackId;

        for (final field in ['boxSize', 'dataYears', 'dateRange', 'boxImage']) {
          final val = b[field]?.toString().trim();
          if (val != null && val.isNotEmpty) entry[field] = val;
        }

        return entry;
      }).toList();

      final result = await _boxController.bulkCreateBoxes(
        BulkCreateBoxRequest.fromMap({'boxes': boxes}),
      );

      if (result['success'] == true) {
        // API response: { status: 'success', data: { success: [...], failed: [...] } }
        final data = (result['data'] as Map<String, dynamic>?) ?? {};
        setState(() {
          _uploadResults = {
            'success': data['success'] ?? [],
            'failed': data['failed'] ?? [],
          };
        });
        _boxController.getAllBoxes(); // refresh list in background
      } else {
        Get.snackbar(
          'Upload Failed',
          result['message']?.toString() ?? 'Server returned an error',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar('Upload Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // STATIC HELPERS
  // =========================================================================

  /// Normalise a header string: lowercase, strip all spaces / _ / -.
  static String _normaliseHeader(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

  /// Extract a raw Dart value from an Excel cell, returning null for blanks.
  static dynamic _cellValue(excel.Data? cell) {
    if (cell == null) return null;
    final v = cell.value;
    if (v == null) return null;
    if (v is excel.TextCellValue) {
      final s = v.value.toString().trim();
      return s.isEmpty ? null : s;
    }
    if (v is excel.IntCellValue) return v.value;
    if (v is excel.DoubleCellValue) return v.value;
    if (v is excel.BoolCellValue) return v.value;
    if (v is excel.DateTimeCellValue) {
      final dynamic dyn = v;
      return dyn.dateTime ?? dyn.value ?? dyn.toString();
    }
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Convert any Excel numeric/string value to int.
  /// Key case: Excel stores integers as DoubleCellValue (1 → 1.0).
  /// int.tryParse("1.0") == null, so we parse as double first.
  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    final s = v.toString().trim();
    return int.tryParse(s) ?? double.tryParse(s)?.round() ?? 0;
  }

  /// Convert a box index cell to a clean string.
  /// Numeric cells: 1.0 → "1"  (Excel loses leading zeros in numeric cells)
  /// Text cells:   "001" → "001"  (text cells preserve them)
  static String _toBoxIndexString(dynamic raw) {
    if (raw is double) return raw.round().toString();
    if (raw is int) return raw.toString();
    return raw.toString().trim();
  }

  /// Parse an Excel date value to ISO "yyyy-MM-dd".
  /// Handles: Excel date serial (double), DateTime object, date strings.
  static String _parseDate(dynamic raw) {
    if (raw is DateTime) {
      return DateFormat('yyyy-MM-dd').format(raw);
    }
    if (raw is num) {
      // Excel serial date: days since 1900-01-01 (Lotus 1-2-3 off-by-2 baked in)
      final dt = DateTime.fromMillisecondsSinceEpoch(
          ((raw - 25569) * 86400000).round());
      return DateFormat('yyyy-MM-dd').format(dt);
    }
    final s = raw.toString().trim();
    for (final fmt in [
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'dd-MM-yyyy',
      'yyyy/MM/dd',
    ]) {
      try {
        return DateFormat('yyyy-MM-dd').format(DateFormat(fmt).parseStrict(s));
      } catch (_) {}
    }
    return s; // return as-is; server-side validation will catch bad dates
  }
}

// ─── Column definition ────────────────────────────────────────────────────────
class _ColDef {
  final String label;
  final String key;
  final double width;
  const _ColDef(this.label, this.key, this.width);
}

// ─── Bi-directional scrollable preview table ─────────────────────────────────
// MUST be a StatefulWidget so it can own ScrollControllers.
// Using Scrollbar without an attached controller throws:
//   "The Scrollbar's ScrollController has no ScrollPosition attached."
class _BiDirectionalScrollTable extends StatefulWidget {
  final List<_ColDef> columns;
  final List<Map<String, dynamic>> rows;

  const _BiDirectionalScrollTable({
    required this.columns,
    required this.rows,
  });

  @override
  State<_BiDirectionalScrollTable> createState() =>
      _BiDirectionalScrollTableState();
}

class _BiDirectionalScrollTableState extends State<_BiDirectionalScrollTable> {
  final ScrollController _hCtrl = ScrollController(); // horizontal
  final ScrollController _vCtrl = ScrollController(); // vertical

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final contentW =
          widget.columns.fold<double>(0, (s, c) => s + c.width) + 48;
      final tableW =
          contentW < constraints.maxWidth ? constraints.maxWidth : contentW;

      return Scrollbar(
        controller: _hCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hCtrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableW,
            child: Column(
              children: [
                // ── Sticky header ────────────────────────────────────
                Container(
                  color: const Color(0xFFECF0F1),
                  child: Row(children: [
                    _headerCell('#', 48),
                    ...widget.columns.map((c) => _headerCell(c.label, c.width)),
                  ]),
                ),
                const Divider(height: 1, thickness: 1),

                // ── Scrollable body ──────────────────────────────────
                Expanded(
                  child: Scrollbar(
                    controller: _vCtrl,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _vCtrl,
                      itemCount: widget.rows.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey[200]),
                      itemBuilder: (_, i) {
                        final row = widget.rows[i];
                        return Container(
                          color: i.isEven ? Colors.white : Colors.grey[50],
                          child: Row(children: [
                            _dataCell('${i + 1}', 48,
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 11)),
                            ...widget.columns.map((c) => _dataCell(
                                  row[c.key]?.toString() ?? '',
                                  c.width,
                                )),
                          ]),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _headerCell(String label, double width) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF2C3E50)),
              overflow: TextOverflow.ellipsis),
        ),
      );

  Widget _dataCell(String text, double width, {TextStyle? style}) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(text,
              style: style ?? const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
      );
}

// ─── Upload results table ─────────────────────────────────────────────────────
class _ResultTable extends StatefulWidget {
  final List<String> columns;
  final List<List<String>> rows;
  final Color rowColor;
  final Color headerColor;
  final IconData icon;
  final Color iconColor;

  const _ResultTable({
    required this.columns,
    required this.rows,
    required this.rowColor,
    required this.headerColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  State<_ResultTable> createState() => _ResultTableState();
}

class _ResultTableState extends State<_ResultTable> {
  final ScrollController _vCtrl = ScrollController();

  @override
  void dispose() {
    _vCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Header
            Container(
              color: widget.headerColor,
              child: Row(children: [
                _cell(
                    width: 36,
                    child:
                        Icon(widget.icon, size: 14, color: widget.iconColor)),
                _cell(text: '#', width: 36, bold: true),
                ...widget.columns
                    .map((c) => _cell(text: c, width: _colW(c), bold: true)),
              ]),
            ),
            const Divider(height: 1, thickness: 1),
            // Body
            Expanded(
              child: Scrollbar(
                controller: _vCtrl,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _vCtrl,
                  itemCount: widget.rows.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (_, i) {
                    final row = widget.rows[i];
                    return Container(
                      color: i.isEven ? widget.rowColor : Colors.white,
                      child: Row(children: [
                        _cell(
                            width: 36,
                            child: Icon(widget.icon,
                                size: 12, color: widget.iconColor)),
                        _cell(
                            text: '${i + 1}',
                            width: 36,
                            color: Colors.grey[500]),
                        ...row.asMap().entries.map((e) => _cell(
                            text: e.value,
                            width: _colW(widget.columns[e.key]))),
                      ]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell({
    String? text,
    double width = 120,
    bool bold = false,
    Color? color,
    Widget? child,
  }) =>
      SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          child: child ??
              Text(text ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis),
        ),
      );

  double _colW(String col) {
    if (col.toLowerCase() == 'error') return 260;
    if (col.toLowerCase().contains('number')) return 160;
    return 110;
  }
}

// ─── Status badge ────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Column hint chip (template hint) ────────────────────────────────────────
class _ColumnChip extends StatelessWidget {
  final String name;
  final bool required;

  const _ColumnChip(this.name, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: required
            ? const Color(0xFF2980B9).withOpacity(0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: required
              ? const Color(0xFF2980B9).withOpacity(0.5)
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: required ? FontWeight.bold : FontWeight.normal,
                color: required ? const Color(0xFF1A5276) : Colors.grey[700],
                fontFamily: 'monospace',
              )),
          if (required) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}
