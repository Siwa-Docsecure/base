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

const _kAccent  = Color(0xFF3498DB);
const _kPrimary = Color(0xFF2C3E50);

class BoxImportDialog extends StatefulWidget {
  const BoxImportDialog({super.key});

  @override
  State<BoxImportDialog> createState() => _BoxImportDialogState();
}

class _BoxImportDialogState extends State<BoxImportDialog> {
  final BoxController _ctrl = Get.find<BoxController>();

  // ─── State ────────────────────────────────────────────────────────────────
  bool        _isLoading         = false;
  String?     _fileName;
  Uint8List?  _fileBytes;
  String?     _fileError;
  bool        _isParsed          = false;
  List<Map<String, dynamic>> _parsedBoxes  = [];
  List<String>               _validationErrors = [];
  Map<String, dynamic>?      _uploadResults;

  int _previewPage = 0;
  static const int _kRowsPerPage = 10;

  // ─── Derived ──────────────────────────────────────────────────────────────
  bool get _fileReady => _fileName != null && _fileError == null && _fileBytes != null;
  bool get _canUpload => _fileReady && _isParsed && _parsedBoxes.isNotEmpty && !_isLoading;

  // ─── Field mapping ────────────────────────────────────────────────────────
  static const Map<String, String> _fieldMapping = {
    'clientid': 'clientId', 'client': 'clientId', 'customerid': 'clientId',
    'boxindex': 'boxIndex', 'boxno': 'boxIndex', 'boxnumber': 'boxIndex', 'index': 'boxIndex',
    'boxdescription': 'boxDescription', 'description': 'boxDescription', 'desc': 'boxDescription',
    'datereceived': 'dateReceived', 'receiveddate': 'dateReceived', 'received': 'dateReceived',
    'retentionyears': 'retentionYears', 'retention': 'retentionYears',
    'rackinglabelid': 'rackingLabelId', 'labelid': 'rackingLabelId', 'rack': 'rackingLabelId',
    'boxsize': 'boxSize', 'size': 'boxSize',
    'datayears': 'dataYears', 'daterange': 'dateRange',
    'boximage': 'boxImage', 'image': 'boxImage',
  };

  static const List<String> _requiredFields = [
    'clientId', 'boxIndex', 'boxDescription', 'dateReceived',
  ];

  static const List<String> _allowedBoxSizes = [
    'A0', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'Custom',
  ];

  static const List<_ColDef> _previewCols = [
    _ColDef('Client ID',     'clientId',       72),
    _ColDef('Box Index',     'boxIndex',        110),
    _ColDef('Description',   'boxDescription',  200),
    _ColDef('Date Received', 'dateReceived',    120),
    _ColDef('Retention yrs', 'retentionYears',  90),
    _ColDef('Rack Label ID', 'rackingLabelId',  100),
    _ColDef('Box Size',      'boxSize',         72),
    _ColDef('Data Years',    'dataYears',       90),
    _ColDef('Date Range',    'dateRange',       120),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 6)),
          ],
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

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kAccent, Color(0xFF5DADE2)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.upload_file_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Import Boxes from Excel',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17)),
                Text('Bulk create boxes from .xlsx / .xls',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ── Content ────────────────────────────────────────────────────────────────

  Widget _buildContent() {
    if (_uploadResults != null) return _buildResults();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropZone(),
          if (_parsedBoxes.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildPreviewHeader(),
            const SizedBox(height: 10),
            Expanded(child: _buildPreviewTable()),
            if (_validationErrors.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildErrorPanel(),
            ],
          ] else ...[
            const SizedBox(height: 20),
            _buildTemplateHint(),
          ],
        ],
      ),
    );
  }

  // ── Drop / file picker zone ─────────────────────────────────────────────────

  Widget _buildDropZone() {
    final hasError  = _fileError != null;
    final isReady   = _fileReady;

    Color bgColor = isReady
        ? Colors.green.shade50
        : (hasError ? Colors.red.shade50 : Colors.grey.shade50);
    Color borderColor = isReady
        ? Colors.green.shade300
        : (hasError ? Colors.red.shade300 : Colors.grey.shade300);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isReady ? 1.5 : 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: (_isLoading && !_isParsed)
                    ? const SizedBox(
                        key: ValueKey('spin'),
                        width: 28, height: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: _kAccent))
                    : isReady
                        ? Icon(Icons.check_circle,
                            key: const ValueKey('ok'),
                            color: Colors.green.shade600, size: 28)
                        : (hasError
                            ? Icon(Icons.error_outline,
                                key: const ValueKey('err'),
                                color: Colors.red.shade600, size: 28)
                            : Icon(Icons.upload_file_outlined,
                                key: const ValueKey('none'),
                                color: Colors.grey.shade400, size: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileName ?? 'Select an Excel file',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isReady
                            ? Colors.green.shade800
                            : (_fileName != null
                                ? _kPrimary
                                : Colors.grey.shade500),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isReady
                          ? '${_parsedBoxes.length} box(es) ready to import'
                          : 'Supported formats: .xlsx, .xls',
                      style: TextStyle(
                          fontSize: 11,
                          color: isReady
                              ? Colors.green.shade600
                              : Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickFile,
                icon: const Icon(Icons.folder_open, size: 16),
                label: Text(_fileName == null ? 'Browse' : 'Change'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          // Status chips
          if (_isParsed && _fileReady) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('${_parsedBoxes.length} rows ready',
                    Icons.table_chart_outlined,
                    _parsedBoxes.isNotEmpty
                        ? Colors.green
                        : Colors.orange),
                if (_validationErrors.isNotEmpty)
                  _chip('${_validationErrors.length} skipped',
                      Icons.warning_amber_outlined, Colors.orange),
              ],
            ),
          ],

          // File error
          if (hasError) ...[
            const SizedBox(height: 8),
            _infoRow(_fileError!,
                icon: Icons.error_outline, color: Colors.red),
          ],
        ],
      ),
    );
  }

  // ── Template hint ──────────────────────────────────────────────────────────

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
              Icon(Icons.info_outline,
                  size: 16, color: Color(0xFF2980B9)),
              SizedBox(width: 8),
              Text('Required Excel Columns',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A5276),
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _colChip('clientId',       required: true),
              _colChip('boxIndex',       required: true),
              _colChip('boxDescription', required: true),
              _colChip('dateReceived',   required: true),
              _colChip('retentionYears'),
              _colChip('rackingLabelId'),
              _colChip('boxSize'),
              _colChip('dataYears'),
              _colChip('dateRange'),
              _colChip('boxImage'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'boxSize: ${_allowedBoxSizes.join(' | ')}  •  '
            'dateReceived: YYYY-MM-DD  •  '
            'retentionYears defaults to 7',
            style: const TextStyle(
                fontSize: 10, color: Color(0xFF2980B9)),
          ),
        ],
      ),
    );
  }

  // ── Preview ────────────────────────────────────────────────────────────────

  Widget _buildPreviewHeader() {
    return Row(
      children: [
        const Icon(Icons.table_chart_outlined,
            size: 16, color: _kPrimary),
        const SizedBox(width: 8),
        Text(
          'Preview — ${_parsedBoxes.length} box(es)',
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kPrimary),
        ),
        const Spacer(),
        if (_validationErrors.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber,
                    size: 12,
                    color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                    '${_validationErrors.length} row(s) skipped',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewTable() {
    final totalPages =
        (_parsedBoxes.length / _kRowsPerPage).ceil().clamp(1, 99999);
    final start   = _previewPage * _kRowsPerPage;
    final end     = (start + _kRowsPerPage).clamp(0, _parsedBoxes.length);
    final pageData = _parsedBoxes.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _BiDirectionalScrollTable(
                  columns: _previewCols, rows: pageData),
            ),
          ),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pageBtn(Icons.first_page, _previewPage > 0,
                    () => setState(() => _previewPage = 0)),
                _pageBtn(Icons.chevron_left, _previewPage > 0,
                    () => setState(() => _previewPage--)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                      'Page ${_previewPage + 1} of $totalPages',
                      style: const TextStyle(
                          fontSize: 12, color: _kAccent,
                          fontWeight: FontWeight.w600)),
                ),
                _pageBtn(Icons.chevron_right,
                    _previewPage < totalPages - 1,
                    () => setState(() => _previewPage++)),
                _pageBtn(Icons.last_page,
                    _previewPage < totalPages - 1,
                    () => setState(
                        () => _previewPage = totalPages - 1)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pageBtn(
      IconData icon, bool enabled, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon,
          size: 18,
          color: enabled ? _kAccent : Colors.grey.shade300),
      onPressed: enabled ? onTap : null,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildErrorPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skipped rows (${_validationErrors.length}):',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 11)),
            const SizedBox(height: 4),
            ..._validationErrors.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 12),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(e,
                              style: const TextStyle(
                                  fontSize: 11))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ── Results view ───────────────────────────────────────────────────────────

  Widget _buildResults() {
    final successList =
        (_uploadResults!['success'] as List?)?.cast<Map>() ?? [];
    final failedList  =
        (_uploadResults!['failed'] as List?)?.cast<Map>() ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: successList.isNotEmpty
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: successList.isNotEmpty
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  successList.isNotEmpty
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 36,
                  color: successList.isNotEmpty
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Complete',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: successList.isNotEmpty
                              ? Colors.green.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _chip(
                              '${successList.length} imported',
                              Icons.check,
                              Colors.green),
                          if (failedList.isNotEmpty)
                            _chip('${failedList.length} failed',
                                Icons.close, Colors.red),
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
            const SizedBox(height: 14),
            Row(children: [
              Icon(Icons.check_circle_outline,
                  size: 14, color: Colors.green.shade600),
              const SizedBox(width: 6),
              Text('Imported Boxes',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.green.shade700)),
            ]),
            const SizedBox(height: 8),
            Expanded(
              flex: failedList.isNotEmpty ? 1 : 2,
              child: _ResultTable(
                columns: const ['Box Number', 'Box Index', 'Box ID'],
                rows: successList
                    .map((s) => [
                          s['boxNumber']?.toString() ?? '—',
                          s['boxIndex']?.toString()  ?? '—',
                          s['boxId']?.toString()     ?? '—',
                        ])
                    .toList(),
                rowColor:    Colors.green.shade50,
                headerColor: Colors.green.shade100,
                icon:        Icons.check_circle_outline,
                iconColor:   Colors.green,
              ),
            ),
          ],

          // Failed table
          if (failedList.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(children: [
              Icon(Icons.error_outline,
                  size: 14, color: Colors.red.shade600),
              const SizedBox(width: 6),
              Text('Failed Entries',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.red.shade700)),
            ]),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: _ResultTable(
                columns: const [
                  'Client ID', 'Box Index', 'Error'
                ],
                rows: failedList
                    .map((f) => [
                          f['clientId']?.toString() ?? '—',
                          f['boxIndex']?.toString()  ?? '—',
                          f['error']?.toString()     ?? 'Unknown',
                        ])
                    .toList(),
                rowColor:    Colors.red.shade50,
                headerColor: Colors.red.shade100,
                icon:        Icons.error_outline,
                iconColor:   Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final btnLabel = _isLoading
        ? (_isParsed ? 'Uploading…' : 'Parsing…')
        : (_canUpload
            ? 'Import ${_parsedBoxes.length} Boxes'
            : 'Select a File');

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border:
            Border(top: BorderSide(color: Colors.grey.shade200)),
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_uploadResults == null) ...[
            OutlinedButton(
              onPressed:
                  _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _canUpload ? _uploadData : null,
              icon: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined,
                      size: 16),
              label: Text(btnLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canUpload ? _kAccent : Colors.grey.shade400,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check,
                  size: 16, color: Colors.white),
              label: const Text('Done',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILE HANDLING (identical logic to original)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    setState(() {
      _fileError = null; _isParsed = false;
      _parsedBoxes = []; _validationErrors = [];
      _uploadResults = null; _previewPage = 0;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (result == null) return;
      final picked = result.files.single;
      setState(() { _fileName = picked.name; _isLoading = true; });

      Uint8List? bytes;
      if (kIsWeb) {
        bytes = picked.bytes;
      } else {
        final path = picked.path;
        if (path == null) {
          setState(() { _fileError = 'Could not access file path.'; _isLoading = false; });
          return;
        }
        bytes = await File(path).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        setState(() { _fileError = 'File is empty or unreadable.'; _isLoading = false; });
        return;
      }
      setState(() => _fileBytes = bytes);
      await _parseExcel(bytes);
    } catch (e) {
      setState(() { _fileError = 'File error: $e'; _isLoading = false; });
    }
  }

  Future<void> _parseExcel(Uint8List bytes) async {
    try {
      final workbook = excel.Excel.decodeBytes(bytes);
      final sheet    = workbook.tables.values.first;
      if (sheet.rows.isEmpty) {
        setState(() { _validationErrors.add('Excel file is empty.'); _isParsed = true; _isLoading = false; });
        return;
      }

      final headerRow = sheet.rows.first;
      final Map<int, String> colMap = {};
      for (int i = 0; i < headerRow.length; i++) {
        final raw  = _cellValue(headerRow[i]);
        if (raw == null) continue;
        final canonical = _fieldMapping[_normaliseHeader(raw.toString())];
        if (canonical != null) colMap[i] = canonical;
      }

      final present = colMap.values.toSet();
      final missing = _requiredFields.where((f) => !present.contains(f)).toList();
      if (missing.isNotEmpty) {
        setState(() {
          _validationErrors.add('Missing required column(s): ${missing.join(', ')}');
          _isParsed = true; _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> parsed = [];
      final List<String>               errors = [];

      for (int ri = 1; ri < sheet.rows.length; ri++) {
        final row = sheet.rows[ri];
        if (row.every((c) => _cellValue(c) == null)) continue;

        final Map<String, dynamic> box = {};
        colMap.forEach((ci, field) {
          if (ci >= row.length) return;
          final raw = _cellValue(row[ci]);
          if (raw == null) return;
          switch (field) {
            case 'clientId': case 'rackingLabelId': case 'retentionYears':
              box[field] = _toInt(raw); break;
            case 'boxIndex':
              box[field] = _toBoxIndexString(raw); break;
            case 'dateReceived':
              box[field] = _parseDate(raw); break;
            default:
              box[field] = raw.toString().trim();
          }
        });
        box.putIfAbsent('retentionYears', () => 7);

        final label = 'Row ${ri + 1}';
        bool valid  = true;
        void fail(String msg) { errors.add('$label: $msg'); valid = false; }

        if (_toInt(box['clientId'] ?? 0) <= 0)
          fail('clientId missing or invalid');
        if ((box['boxIndex']?.toString().trim() ?? '').isEmpty)
          fail('boxIndex missing');
        if ((box['boxDescription']?.toString().trim() ?? '').isEmpty)
          fail('boxDescription missing');
        if ((box['dateReceived']?.toString().trim() ?? '').isEmpty)
          fail('dateReceived missing/unparseable');
        final bs = box['boxSize']?.toString().trim();
        if (bs != null && bs.isNotEmpty && !_allowedBoxSizes.contains(bs))
          fail('boxSize "$bs" invalid — allowed: ${_allowedBoxSizes.join(', ')}');

        if (valid) parsed.add(box);
      }

      setState(() {
        _parsedBoxes = parsed; _validationErrors = errors;
        _isParsed = true; _isLoading = false;
      });

      if (parsed.isEmpty) {
        Get.snackbar('No Valid Data',
            'No importable rows found.',
            backgroundColor: Colors.orange, colorText: Colors.white);
      } else if (errors.isNotEmpty) {
        Get.snackbar('Parsed with Warnings',
            '${parsed.length} valid, ${errors.length} skipped.',
            backgroundColor: Colors.orange, colorText: Colors.white);
      } else {
        Get.snackbar('Ready',
            '${parsed.length} box(es) ready to import.',
            backgroundColor: Colors.green, colorText: Colors.white);
      }
    } catch (e) {
      setState(() {
        _validationErrors.add('Parsing error: $e');
        _isParsed = true; _isLoading = false;
      });
    }
  }

  Future<void> _uploadData() async {
    if (_parsedBoxes.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final boxes = _parsedBoxes.map((b) {
        final Map<String, dynamic> e = {
          'clientId':       _toInt(b['clientId']),
          'boxIndex':       b['boxIndex'].toString(),
          'boxDescription': b['boxDescription'].toString(),
          'dateReceived':   b['dateReceived'].toString(),
          'retentionYears': _toInt(b['retentionYears'] ?? 7),
        };
        final rackId = _toInt(b['rackingLabelId'] ?? 0);
        if (rackId > 0) e['rackingLabelId'] = rackId;
        for (final f in ['boxSize', 'dataYears', 'dateRange', 'boxImage']) {
          final v = b[f]?.toString().trim();
          if (v != null && v.isNotEmpty) e[f] = v;
        }
        return e;
      }).toList();

      final result = await _ctrl.bulkCreateBoxes(
          BulkCreateBoxRequest.fromMap({'boxes': boxes}));

      if (result['success'] == true) {
        final data = (result['data'] as Map<String, dynamic>?) ?? {};
        setState(() => _uploadResults = {
          'success': data['success'] ?? [],
          'failed':  data['failed']  ?? [],
        });
        _ctrl.getAllBoxes();
      } else {
        Get.snackbar('Upload Failed',
            result['message']?.toString() ?? 'Server error',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Upload Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _normaliseHeader(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

  static dynamic _cellValue(excel.Data? cell) {
    if (cell == null) return null;
    final v = cell.value;
    if (v == null) return null;
    if (v is excel.TextCellValue) {
      final s = v.value.toString().trim();
      return s.isEmpty ? null : s;
    }
    if (v is excel.IntCellValue)    return v.value;
    if (v is excel.DoubleCellValue) return v.value;
    if (v is excel.BoolCellValue)   return v.value;
    if (v is excel.DateTimeCellValue) {
      final dyn = v as dynamic;
      return dyn.dateTime ?? dyn.value ?? dyn.toString();
    }
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int _toInt(dynamic v) {
    if (v is int)    return v;
    if (v is double) return v.round();
    final s = v.toString().trim();
    return int.tryParse(s) ?? double.tryParse(s)?.round() ?? 0;
  }

  static String _toBoxIndexString(dynamic raw) {
    if (raw is double) return raw.round().toString();
    if (raw is int)    return raw.toString();
    return raw.toString().trim();
  }

  static String _parseDate(dynamic raw) {
    if (raw is DateTime) return DateFormat('yyyy-MM-dd').format(raw);
    if (raw is num) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
          ((raw - 25569) * 86400000).round());
      return DateFormat('yyyy-MM-dd').format(dt);
    }
    final s = raw.toString().trim();
    for (final fmt in ['yyyy-MM-dd', 'dd/MM/yyyy', 'MM/dd/yyyy', 'dd-MM-yyyy', 'yyyy/MM/dd']) {
      try {
        return DateFormat('yyyy-MM-dd').format(DateFormat(fmt).parseStrict(s));
      } catch (_) {}
    }
    return s;
  }

  // ── Shared small widgets ──────────────────────────────────────────────────

  Widget _chip(String label, IconData icon, Color color) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _colChip(String name, {bool required = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: required
              ? const Color(0xFF2980B9).withOpacity(0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: required
                ? const Color(0xFF2980B9).withOpacity(0.4)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name,
                style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: required
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: required
                        ? const Color(0xFF1A5276)
                        : Colors.grey.shade700)),
            if (required)
              const Text(' *',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _infoRow(String text,
      {required IconData icon, required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: color.withOpacity(0.9),
                        fontSize: 12))),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// COLUMN DEFINITION
// ─────────────────────────────────────────────────────────────────────────────

class _ColDef {
  final String label;
  final String key;
  final double width;
  const _ColDef(this.label, this.key, this.width);
}

// ─────────────────────────────────────────────────────────────────────────────
// BI-DIRECTIONAL SCROLL TABLE (identical logic, cleaned up style)
// ─────────────────────────────────────────────────────────────────────────────

class _BiDirectionalScrollTable extends StatefulWidget {
  final List<_ColDef>             columns;
  final List<Map<String, dynamic>> rows;

  const _BiDirectionalScrollTable({
    required this.columns,
    required this.rows,
  });

  @override
  State<_BiDirectionalScrollTable> createState() =>
      _BiDirectionalScrollTableState();
}

class _BiDirectionalScrollTableState
    extends State<_BiDirectionalScrollTable> {
  final _hCtrl = ScrollController();
  final _vCtrl = ScrollController();

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final contentW = widget.columns
              .fold<double>(0, (s, c) => s + c.width) +
          48;
      final tableW =
          contentW < constraints.maxWidth
              ? constraints.maxWidth
              : contentW;

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
                // Header
                Container(
                  color: Colors.grey.shade100,
                  child: Row(children: [
                    _hCell('#', 44),
                    ...widget.columns
                        .map((c) => _hCell(c.label, c.width)),
                  ]),
                ),
                Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.shade200),
                // Body
                Expanded(
                  child: Scrollbar(
                    controller: _vCtrl,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _vCtrl,
                      itemCount: widget.rows.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey.shade100),
                      itemBuilder: (_, i) {
                        final row = widget.rows[i];
                        return Container(
                          color: i.isEven
                              ? Colors.white
                              : Colors.grey.shade50,
                          child: Row(children: [
                            _dCell('${i + 1}', 44,
                                color: Colors.grey.shade400),
                            ...widget.columns.map((c) =>
                                _dCell(
                                    row[c.key]?.toString() ??
                                        '',
                                    c.width)),
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

  Widget _hCell(String label, double w) => SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 9, horizontal: 8),
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: _kPrimary,
                  letterSpacing: 0.2),
              overflow: TextOverflow.ellipsis),
        ),
      );

  Widget _dCell(String text, double w, {Color? color}) => SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 9, horizontal: 8),
          child: Text(text,
              style: TextStyle(
                  fontSize: 11,
                  color: color ?? const Color(0xFF2C3E50)),
              overflow: TextOverflow.ellipsis),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULTS TABLE
// ─────────────────────────────────────────────────────────────────────────────

class _ResultTable extends StatefulWidget {
  final List<String>       columns;
  final List<List<String>> rows;
  final Color              rowColor;
  final Color              headerColor;
  final IconData           icon;
  final Color              iconColor;

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
  final _vCtrl = ScrollController();

  @override
  void dispose() {
    _vCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Container(
              color: widget.headerColor,
              child: Row(children: [
                _cell(
                    width: 32,
                    child: Icon(widget.icon,
                        size: 13, color: widget.iconColor)),
                _cell(text: '#', width: 32, bold: true),
                ...widget.columns.map((c) =>
                    _cell(text: c, width: _colW(c), bold: true)),
              ]),
            ),
            Divider(height: 1, thickness: 1,
                color: Colors.grey.shade200),
            Expanded(
              child: Scrollbar(
                controller: _vCtrl,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _vCtrl,
                  itemCount: widget.rows.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1, color: Colors.grey.shade100),
                  itemBuilder: (_, i) {
                    final row = widget.rows[i];
                    return Container(
                      color: i.isEven
                          ? widget.rowColor
                          : Colors.white,
                      child: Row(children: [
                        _cell(
                            width: 32,
                            child: Icon(widget.icon,
                                size: 11,
                                color: widget.iconColor)),
                        _cell(
                            text: '${i + 1}',
                            width: 32,
                            color: Colors.grey.shade400),
                        ...row.asMap().entries.map((e) => _cell(
                            text: e.value,
                            width: _colW(
                                widget.columns[e.key]))),
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
    double width = 110,
    bool bold = false,
    Color? color,
    Widget? child,
  }) =>
      SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 8, horizontal: 8),
          child: child ??
              Text(text ?? '',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: bold
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: color),
                  overflow: TextOverflow.ellipsis),
        ),
      );

  double _colW(String col) {
    if (col.toLowerCase() == 'error') return 250;
    if (col.toLowerCase().contains('number')) return 150;
    return 100;
  }
}