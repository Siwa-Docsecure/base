// lib/screens/warehouse/delivery/delivery_management_screen.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:signature/signature.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/delivery_controller.dart';
import 'package:psms/models/delivery_model.dart';
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryManagementScreen> createState() =>
      _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState
    extends State<DeliveryManagementScreen> {
  final DeliveryController _ctrl   = Get.put(DeliveryController());
  final AuthController     _auth   = Get.find<AuthController>();
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'all'; // 'all' | 'by_client' | 'recent'
  String _searchQuery    = '';

  // Date + client filter state (applied via filter dialog)
  int?   _clientId;
  String _startDate = '';
  String _endDate   = '';

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ctrl.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  void _applyFilter() {
    _ctrl.getAllDeliveries(
      search:    _searchQuery.isNotEmpty ? _searchQuery : null,
      clientId:  _clientId,
      startDate: _startDate.isNotEmpty ? _startDate : null,
      endDate:   _endDate.isNotEmpty   ? _endDate   : null,
    );
  }

  // ── filter dialog ─────────────────────────────────────────────────────────

  void _showFilterDialog() {
    int?   tmpClient = _clientId;
    String tmpStart  = _startDate;
    String tmpEnd    = _endDate;
    final  startCtrl = TextEditingController(text: tmpStart);
    final  endCtrl   = TextEditingController(text: tmpEnd);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50).withOpacity(0.04),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.tune,
                        color: Color(0xFF2C3E50), size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Filter Deliveries',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50))),
                    ),
                    if (_clientId != null ||
                        _startDate.isNotEmpty ||
                        _endDate.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _clientId  = null;
                            _startDate = '';
                            _endDate   = '';
                          });
                          _applyFilter();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear',
                            style: TextStyle(
                                color: Colors.red, fontSize: 13)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.black45, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ]),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Client',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      Obx(() => DropdownButtonFormField<int?>(
                            value: tmpClient,
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('All Clients')),
                              ..._ctrl.clients.map((c) => DropdownMenuItem(
                                    value: c.clientId,
                                    child: Text(
                                        '${c.clientCode} – ${c.clientName}',
                                        overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (v) =>
                                setDlg(() => tmpClient = v),
                          )),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: startCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Date From',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                              suffixIcon: tmpStart.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setDlg(() {
                                        tmpStart = '';
                                        startCtrl.clear();
                                      }))
                                  : const Icon(Icons.calendar_today,
                                      size: 18),
                            ),
                            onTap: () async {
                              final p = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now());
                              if (p != null) {
                                setDlg(() {
                                  tmpStart       =
                                      DateFormat('yyyy-MM-dd').format(p);
                                  startCtrl.text = tmpStart;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: endCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Date To',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                              suffixIcon: tmpEnd.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setDlg(() {
                                        tmpEnd = '';
                                        endCtrl.clear();
                                      }))
                                  : const Icon(Icons.calendar_today,
                                      size: 18),
                            ),
                            onTap: () async {
                              final p = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now());
                              if (p != null) {
                                setDlg(() {
                                  tmpEnd       =
                                      DateFormat('yyyy-MM-dd').format(p);
                                  endCtrl.text = tmpEnd;
                                });
                              }
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498DB),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _clientId  = tmpClient;
                              _startDate = tmpStart;
                              _endDate   = tmpEnd;
                              _selectedFilter = 'all';
                            });
                            _applyFilter();
                          },
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── dialogs ───────────────────────────────────────────────────────────────

  void _showCreateDeliveryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeliveryFormDialog(controller: _ctrl),
    );
  }

  void _showEditDeliveryDialog(DeliveryModel d) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeliveryFormDialog(controller: _ctrl, delivery: d),
    );
  }

  void _showDeliveryDetails(DeliveryModel d) {
    showDialog(
      context: context,
      builder: (_) => _DeliveryDetailsDialog(
        delivery:   d,
        controller: _ctrl,
        onEdit:     _auth.hasPermission('canCreateDeliveries')
            ? () {
                Navigator.pop(context);
                _showEditDeliveryDialog(d);
              }
            : null,
        onDelete:   _auth.hasPermission('canDeleteDeliveries')
            ? () {
                Navigator.pop(context);
                _showDeleteDialog(d);
              }
            : null,
        onSign:     !d.hasSignature
            ? () {
                Navigator.pop(context);
                _showSignatureDialog(d);
              }
            : null,
      ),
    );
  }

  void _showDeleteDialog(DeliveryModel d) {
    Get.defaultDialog(
      title: 'Delete Delivery',
      content: Text(
        'Delete the delivery of "${d.itemName}" for '
        '${d.client.clientName}?\nThis cannot be undone.',
        textAlign: TextAlign.center,
      ),
      textConfirm: 'Delete',
      textCancel:  'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        Get.back();
        await _ctrl.deleteDelivery(d.deliveryId);
      },
    );
  }

  // ── signature dialog (mirrors retrievals_page._showSignatureDialog) ─────────

  void _showSignatureDialog(DeliveryModel delivery) {
    if (delivery.hasSignature) {
      Get.snackbar(
        'Already Signed',
        'Receiver signature has already been captured.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: const Icon(Icons.verified, color: Colors.white),
      );
      return;
    }

    final SignatureController sigCtrl = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header — blue, matching retrievals capture-client style
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: const Icon(Icons.draw,
                        color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Receiver Signature',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text(
                          '${delivery.receiverName}  ·  '
                          'Delivery #${delivery.deliveryId}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700),
                        ),
                        Text(
                          'Receiver should sign to confirm delivery.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),

              // Signature pad
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Receiver — draw signature below',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700)),
                        TextButton.icon(
                          onPressed: sigCtrl.clear,
                          icon: const Icon(Icons.clear,
                              size: 16, color: Colors.grey),
                          label: const Text('Clear',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Signature(
                          controller: sigCtrl,
                          backgroundColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                      top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        foregroundColor: Colors.black87,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (sigCtrl.isEmpty) {
                          Get.snackbar(
                            'Signature Required',
                            'Please draw a signature before saving.',
                            backgroundColor: Colors.orange,
                            colorText: Colors.white,
                          );
                          return;
                        }
                        final bytes = await sigCtrl.toPngBytes();
                        if (bytes == null) return;
                        final b64 =
                            'data:image/png;base64,${base64Encode(bytes)}';

                        final success = await _ctrl.updateSignature(
                            delivery.deliveryId, b64);

                        if (success && ctx.mounted) {
                          Navigator.pop(ctx);
                          _ctrl.initialize();
                          Get.snackbar(
                            'Signature Saved',
                            'Receiver signature captured for '
                            '${delivery.receiverName}.',
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                            icon: const Icon(Icons.verified,
                                color: Colors.white),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('Save Signature'),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── report ────────────────────────────────────────────────────────────────

  void _showReportDialog() {
    int?   rptClient;
    String rptStart  = '';
    String rptEnd    = '';
    final  startCtrl = TextEditingController();
    final  endCtrl   = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF3498DB), Color(0xFF2980B9)]),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.print, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Generate Delivery Report',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                            Text('Docsecure PSMS',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70)),
                          ]),
                    ),
                    IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx)),
                  ]),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Client (optional)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      Obx(() => DropdownButtonFormField<int?>(
                            value: rptClient,
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('All Clients')),
                              ..._ctrl.clients.map((c) => DropdownMenuItem(
                                    value: c.clientId,
                                    child: Text(
                                        '${c.clientCode} – ${c.clientName}',
                                        overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (v) => setDlg(() => rptClient = v),
                          )),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: startCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Date From',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                              suffixIcon: const Icon(
                                  Icons.calendar_today, size: 18),
                            ),
                            onTap: () async {
                              final p = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now());
                              if (p != null) {
                                setDlg(() {
                                  rptStart       =
                                      DateFormat('yyyy-MM-dd').format(p);
                                  startCtrl.text = rptStart;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: endCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Date To',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                              suffixIcon: const Icon(
                                  Icons.calendar_today, size: 18),
                            ),
                            onTap: () async {
                              final p = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now());
                              if (p != null) {
                                setDlg(() {
                                  rptEnd       =
                                      DateFormat('yyyy-MM-dd').format(p);
                                  endCtrl.text = rptEnd;
                                });
                              }
                            },
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(
                        top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          foregroundColor: Colors.black87,
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.preview),
                        label: const Text('Preview'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final pdf = await _buildPdfDocument(
                            clientId:  rptClient,
                            startDate: rptStart.isNotEmpty ? rptStart : null,
                            endDate:   rptEnd.isNotEmpty   ? rptEnd   : null,
                          );
                          _showPdfPreview(pdf);
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                        ),
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Save PDF'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final pdf = await _buildPdfDocument(
                            clientId:  rptClient,
                            startDate: rptStart.isNotEmpty ? rptStart : null,
                            endDate:   rptEnd.isNotEmpty   ? rptEnd   : null,
                          );
                          await _sharePdf(pdf);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showPdfPreview(pw.Document pdf) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.92,
            maxWidth: 900,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  border: Border(
                      bottom:
                          BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(children: [
                  const Text('Delivery Report Preview',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Expanded(
                child: PdfPreview(
                  build: (_) async => pdf.save(),
                  allowSharing: true,
                  allowPrinting: true,
                  pdfFileName:
                      'delivery_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12)),
                  border: Border(
                      top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                      ),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3498DB),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save PDF'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _sharePdf(pdf);
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                      ),
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Printing.layoutPdf(
                            onLayout: (_) async => pdf.save());
                      },
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.95),
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deliveries',
                style: TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 20)),
            Text('Manage warehouse deliveries efficiently',
                style: TextStyle(
                    color: const Color(0xFF2C3E50).withOpacity(0.6),
                    fontWeight: FontWeight.w100,
                    fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list,
                color: Color(0xFF2C3E50)),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2C3E50)),
            onPressed: _ctrl.initialize,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF2C3E50)),
            onSelected: (v) {
              if (v == 'print') _showReportDialog();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'print',
                child: ListTile(
                  leading: Icon(Icons.print),
                  title: Text('Print Report'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Stats cards ────────────────────────────────────────────────────
          Obx(() {
            final s = _ctrl.deliveryStats.value;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Row(children: [
                Expanded(
                  child: _buildStatCard(
                    'All time',
                    (s?.totalDeliveries ?? _ctrl.totalDeliveries.value)
                        .toString(),
                    'Total Deliveries',
                    Icons.local_shipping,
                    const Color(0xFF5DADE2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Today',
                    (s?.todayDeliveries ?? 0).toString(),
                    "Today's Deliveries",
                    Icons.add_circle_outline,
                    const Color(0xFF52BE80),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'This month',
                    (s?.thisMonthDeliveries ?? 0).toString(),
                    'This Month',
                    Icons.calendar_today,
                    const Color(0xFFEB984E),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Active clients',
                    (s?.clientsWithDeliveries ?? 0).toString(),
                    'Clients',
                    Icons.people,
                    const Color(0xFFAB47BC),
                  ),
                ),
              ]),
            );
          }),

          // ── Content card ───────────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.black.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // Search + filter chips
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    Colors.black.withOpacity(0.3)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style:
                                const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText:
                                  'Search by client, item, receiver…',
                              hintStyle: TextStyle(
                                  color: Colors.black.withOpacity(0.5)),
                              prefixIcon: Icon(Icons.search,
                                  size: 20,
                                  color: Colors.black.withOpacity(0.7)),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear,
                                          size: 20,
                                          color: Colors.black
                                              .withOpacity(0.7)),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                        _applyFilter();
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                            ),
                            onChanged: (v) {
                              setState(() => _searchQuery = v);
                              _applyFilter();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildFilterChip('All',       'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('By Client', 'by_client'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Recent',    'recent'),
                    ]),
                  ),

                  Divider(
                      height: 1,
                      color: Colors.black.withOpacity(0.2)),

                  // Table header — only for 'all' view
                  if (_selectedFilter == 'all') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      color: Colors.black.withOpacity(0.05),
                      child: Row(children: [
                        Expanded(
                            flex: 3,
                            child: _headerCell('Client')),
                        Expanded(
                            flex: 2,
                            child: _headerCell('Item')),
                        Expanded(
                            flex: 2,
                            child: _headerCell('Date')),
                        Expanded(
                            flex: 2,
                            child: _headerCell('Receiver')),
                        SizedBox(
                            width: 110,
                            child: _headerCell('Docs')),
                        SizedBox(
                            width: 100,
                            child: _headerCell('Actions',
                                align: TextAlign.end)),
                      ]),
                    ),
                    Divider(
                        height: 1,
                        color: Colors.black.withOpacity(0.2)),
                  ],

                  // List area
                  Expanded(
                    child: Obx(() {
                      if (_ctrl.isLoading.value &&
                          _ctrl.deliveries.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.black),
                        );
                      }

                      // Dispatch to the right view
                      switch (_selectedFilter) {
                        case 'by_client':
                          return _buildByClientView();
                        case 'recent':
                          return _buildRecentView();
                        default:
                          return _buildAllDeliveriesView();
                      }
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _auth.hasPermission('canCreateDeliveries')
          ? FloatingActionButton.extended(
              onPressed: _showCreateDeliveryDialog,
              icon: const Icon(Icons.add),
              label: const Text('New Delivery'),
              backgroundColor:
                  const Color(0xFF1976D2).withOpacity(0.8),
            )
          : null,
    );
  }

  // ── ALL DELIVERIES TABLE ───────────────────────────────────────────────────

  Widget _buildAllDeliveriesView() {
    if (_ctrl.deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 64, color: Colors.black.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No deliveries found',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.8))),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _clientId != null
                  ? 'Try adjusting your filters'
                  : 'Create a new delivery to get started',
              style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _ctrl.initialize(),
      child: Column(children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _ctrl.deliveries.length,
            separatorBuilder: (_, __) => Divider(
                height: 1, color: Colors.black.withOpacity(0.1)),
            itemBuilder: (_, i) =>
                _buildDeliveryRow(_ctrl.deliveries[i]),
          ),
        ),
        // Pagination bar — always visible
        _buildPaginationBar(),
      ]),
    );
  }

  Widget _buildDeliveryRow(DeliveryModel d) {
    return InkWell(
      onTap: () => _showDeliveryDetails(d),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 14),
        child: Row(children: [
          // ── Client ────────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.black.withOpacity(0.2)),
                ),
                child: Icon(Icons.business,
                    size: 18,
                    color: Colors.black.withOpacity(0.7)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.client.clientName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(d.client.clientCode,
                        style: TextStyle(
                            color: Colors.black.withOpacity(0.5),
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ]),
          ),

          // ── Item + quantity badge (mirrors box number + box count) ────
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.itemName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2980B9)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF52BE80).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF52BE80)
                            .withOpacity(0.35)),
                  ),
                  child: Text(
                    '${d.quantity} item${d.quantity == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF52BE80)),
                  ),
                ),
              ],
            ),
          ),

          // ── Date ──────────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('MMM dd, yyyy').format(d.deliveryDate),
              style: const TextStyle(
                  fontSize: 13, color: Colors.black),
            ),
          ),

          // ── Receiver ──────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Text(d.receiverName,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.65)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),

          // ── Docs (mirrors Signatures column) ──────────────────────────
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _docChip('Signed', d.hasSignature),
                const SizedBox(height: 4),
                _docChip('PDF', d.hasPdf),
              ],
            ),
          ),

          // ── Actions ───────────────────────────────────────────────────
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.visibility_outlined,
                      size: 18,
                      color: Colors.black.withOpacity(0.7)),
                  onPressed: () => _showDeliveryDetails(d),
                  tooltip: 'View',
                ),
                // Draw button — mirrors retrievals signature action
                if (!d.hasSignature)
                  IconButton(
                    icon: Icon(Icons.draw,
                        size: 18,
                        color: Colors.black.withOpacity(0.7)),
                    onPressed: () => _showSignatureDialog(d),
                    tooltip: 'Capture receiver signature',
                  ),
                if (_auth.hasPermission('canCreateDeliveries'))
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: Color(0xFF2980B9)),
                    onPressed: () => _showEditDeliveryDialog(d),
                    tooltip: 'Edit',
                  ),
                if (_auth.hasPermission('canDeleteDeliveries'))
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    onPressed: () => _showDeleteDialog(d),
                    tooltip: 'Delete',
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── BY CLIENT VIEW ────────────────────────────────────────────────────────

  Widget _buildByClientView() {
    if (_ctrl.isLoading.value && _ctrl.byClientReport.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ctrl.byClientReport.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.business_outlined,
              size: 64, color: Colors.black.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('No client delivery data',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.7))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _ctrl.getReportByClient(),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _ctrl.byClientReport.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.black.withOpacity(0.1)),
        itemBuilder: (_, i) {
          final r = _ctrl.byClientReport[i];
          return InkWell(
            onTap: () {
              setState(() {
                _clientId       = r.clientId;
                _selectedFilter = 'all';
              });
              _applyFilter();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              child: Row(children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.black.withOpacity(0.2)),
                  ),
                  child: Text(
                    r.clientCode.isNotEmpty
                        ? r.clientCode[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2980B9),
                        fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.clientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(r.clientCode,
                          style: TextStyle(
                              color: Colors.black.withOpacity(0.5),
                              fontSize: 11)),
                    ],
                  ),
                ),
                // Delivery count (mirrors box count badge)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${r.deliveryCount} delivery${r.deliveryCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2980B9)),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF52BE80).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF52BE80)
                                .withOpacity(0.35)),
                      ),
                      child: Text(
                        '${r.totalItemsDelivered} items',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF52BE80)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right,
                    color: Colors.black.withOpacity(0.3), size: 20),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── RECENT VIEW ───────────────────────────────────────────────────────────

  Widget _buildRecentView() {
    if (_ctrl.isLoading.value && _ctrl.recentDeliveries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ctrl.recentDeliveries.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history_outlined,
              size: 64, color: Colors.black.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('No recent deliveries',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.7))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _ctrl.getRecentDeliveries,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _ctrl.recentDeliveries.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.black.withOpacity(0.1)),
        itemBuilder: (_, i) {
          final d = _ctrl.recentDeliveries[i];
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF52BE80).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF52BE80).withOpacity(0.3)),
                ),
                child: const Icon(Icons.local_shipping,
                    size: 18, color: Color(0xFF52BE80)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.itemName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '${d.clientCode} · ${d.clientName}  ·  '
                      '${DateFormat('MMM dd, yyyy').format(d.deliveryDate)}',
                      style: TextStyle(
                          color: Colors.black.withOpacity(0.5),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF52BE80).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF52BE80).withOpacity(0.35)),
                ),
                child: Text('×${d.quantity}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF52BE80))),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── PAGINATION BAR (exact pattern from retrievals_page) ───────────────────

  Widget _buildPaginationBar() {
    return Obx(() {
      final current = _ctrl.currentPage.value;
      final total   = _ctrl.totalPages.value;
      final count   = _ctrl.totalDeliveries.value;

      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(
              top: BorderSide(
                  color: Colors.black.withOpacity(0.08))),
        ),
        child: Row(children: [
          Text(
            '$count delivery${count == 1 ? '' : 's'}',
            style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.5),
                fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          _pageBtn(
            icon: Icons.chevron_left,
            enabled: current > 1,
            onTap: _ctrl.loadPreviousPage,
          ),
          ...List.generate(total, (i) {
            final page       = i + 1;
            final isCurrent  = page == current;
            final visible    = page == 1 ||
                page == total ||
                (page >= current - 1 && page <= current + 1);
            final isGapBefore =
                page == current - 2 && page > 2;
            final isGapAfter  =
                page == current + 2 && page < total - 1;

            if (isGapBefore || isGapAfter) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 2),
                child: Text('…',
                    style: TextStyle(
                        color: Colors.black.withOpacity(0.35),
                        fontSize: 13)),
              );
            }
            if (!visible) return const SizedBox.shrink();

            return GestureDetector(
              onTap: isCurrent
                  ? null
                  : () => _ctrl.getAllDeliveries(
                        page:      page,
                        search:    _searchQuery.isNotEmpty
                            ? _searchQuery
                            : null,
                        clientId:  _clientId,
                        startDate: _startDate.isNotEmpty
                            ? _startDate
                            : null,
                        endDate:   _endDate.isNotEmpty
                            ? _endDate
                            : null,
                      ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin:
                    const EdgeInsets.symmetric(horizontal: 3),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF3498DB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFF3498DB)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Center(
                  child: Text('$page',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? Colors.white
                              : Colors.black54)),
                ),
              ),
            );
          }),
          _pageBtn(
            icon: Icons.chevron_right,
            enabled: current < total,
            onTap: _ctrl.loadNextPage,
          ),
        ]),
      );
    });
  }

  Widget _pageBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enabled
                  ? Colors.grey.shade300
                  : Colors.grey.shade200),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled
                ? Colors.black54
                : Colors.grey.shade300),
      ),
    );
  }

  // ── HELPER WIDGETS ────────────────────────────────────────────────────────

  Widget _buildStatCard(String label, String value, String subtitle,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  color: Colors.black.withOpacity(0.7),
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = value);
        switch (value) {
          case 'all':
            _applyFilter();
            break;
          case 'by_client':
            _ctrl.getReportByClient();
            break;
          case 'recent':
            _ctrl.getRecentDeliveries();
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.black.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.black.withOpacity(0.5)
                : Colors.black.withOpacity(0.3),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: Colors.black,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.normal,
                fontSize: 13)),
      ),
    );
  }

  Widget _headerCell(String label,
      {TextAlign align = TextAlign.left}) =>
      Text(label,
          textAlign: align,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.black.withOpacity(0.6)));

  /// Mirrors _sigChip from retrievals_page — green when active.
  Widget _docChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withOpacity(0.12)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? Colors.green.withOpacity(0.4)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          active
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          size: 12,
          color: active ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: active ? Colors.green.shade700 : Colors.grey,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ── PDF ───────────────────────────────────────────────────────────────────

  Future<pw.Document> _buildPdfDocument({
    int? clientId, String? startDate, String? endDate,
  }) async {
    final pdf = pw.Document();

    final fontData =
        await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final boldData =
        await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    final ttf     = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(boldData);
    final logo    = await _loadLogo();

    final rows = _ctrl.deliveries
        .where((d) =>
            clientId == null || d.client.clientId == clientId)
        .toList();

    final clientLabel = clientId != null && rows.isNotEmpty
        ? '${rows.first.client.clientName} (${rows.first.client.clientCode})'
        : 'All Clients';

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
      header: (ctx) {
        if (ctx.pageNumber != 1) return pw.Container();
        return pw.Column(children: [
          pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.Container(
                      width: 60, height: 60, child: pw.Image(logo)),
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
                            'Below Gcina Trading, Plot 769 First street Mangozeni,\n'
                            'Matsapha M201, Eswatini',
                            style: pw.TextStyle(
                                fontSize: 8, color: PdfColors.grey600)),
                      ]),
                ),
              ]),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 12),
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Delivery Register Report',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
              ]),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300)),
            child: pw.Row(children: [
              pw.Text('Client:  ',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text(clientLabel,
                  style: pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 24),
              pw.Text('Date From:  ',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text(startDate ?? 'N/A',
                  style: pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 24),
              pw.Text('Date To:  ',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text(endDate ?? 'N/A',
                  style: pw.TextStyle(fontSize: 10)),
            ]),
          ),
          pw.SizedBox(height: 16),
        ]);
      },
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 16),
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
      ),
      build: (ctx) {
        final content = <pw.Widget>[];

        // Summary
        final s = _ctrl.deliveryStats.value;
        if (s != null) {
          content.add(pw.Text('Summary',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)));
          content.add(pw.SizedBox(height: 6));
          content.add(pw.TableHelper.fromTextArray(
            headers: ['Metric', 'Value'],
            data: [
              ['Total Deliveries',        '${s.totalDeliveries}'],
              ['Total Items Delivered',   '${s.totalItemsDelivered}'],
              ['Clients with Deliveries', '${s.clientsWithDeliveries}'],
              ["Today's Deliveries",      '${s.todayDeliveries}'],
              ['This Month',              '${s.thisMonthDeliveries}'],
            ],
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: pw.TextStyle(fontSize: 9),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
            },
          ));
          content.add(pw.SizedBox(height: 16));
        }

        // Deliveries table
        content.add(pw.Text('Deliveries',
            style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold)));
        content.add(pw.SizedBox(height: 6));
        content.add(pw.TableHelper.fromTextArray(
          headers: ['Date', 'Client', 'Item', 'Qty', 'Receiver', 'Signed', 'PDF'],
          data: rows.map((d) => [
            DateFormat('yyyy-MM-dd').format(d.deliveryDate),
            '${d.client.clientName}\n(${d.client.clientCode})',
            d.itemName,
            '${d.quantity}',
            d.receiverName,
            d.hasSignature ? 'Yes' : 'No',
            d.hasPdf ? 'Yes' : 'No',
          ]).toList(),
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
              color: PdfColors.white),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.blue700),
          cellStyle: pw.TextStyle(fontSize: 8),
          cellHeight: 28,
          columnWidths: {
            0: const pw.FlexColumnWidth(1.3),
            1: const pw.FlexColumnWidth(2.0),
            2: const pw.FlexColumnWidth(2.0),
            3: const pw.FlexColumnWidth(0.6),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(0.7),
            6: const pw.FlexColumnWidth(0.6),
          },
          cellAlignments: {
            3: pw.Alignment.center,
            5: pw.Alignment.center,
            6: pw.Alignment.center,
          },
        ));

        content.add(pw.SizedBox(height: 20));
        content.add(pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Records: ${rows.length}',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Report generated by PSMS ®',
                    style: pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
              ]),
        ));
        content.add(pw.Spacer());
        content.add(pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Docsecure Representative',
                      style: pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 10),
                  pw.Text('_____________________________',
                      style: pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600)),
                ]),
            if (clientId != null && rows.isNotEmpty)
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                        'For Client: ${rows.first.client.clientName}',
                        style: pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 10),
                    pw.Text('______________________________',
                        style: pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600)),
                  ]),
          ],
        ));
        return content;
      },
    ));
    return pdf;
  }

  Future<void> _sharePdf(pw.Document pdf) async {
    final bytes = await pdf.save();
    final fileName =
        'delivery_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    if (Platform.isWindows) {
      final dir = await getDownloadsDirectory();
      if (dir == null) return;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await OpenFile.open(dir.path);
      Get.snackbar('Saved', 'PDF saved: $fileName',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 4));
    } else {
      final tmp  = await getTemporaryDirectory();
      final file = File('${tmp.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Delivery Report');
    }
  }

  Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/logo/logo.jpeg');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY FORM DIALOG  — matches CreateRetrievalDialog structure
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryFormDialog extends StatefulWidget {
  final DeliveryController controller;
  final DeliveryModel?     delivery;

  const _DeliveryFormDialog({required this.controller, this.delivery});

  @override
  State<_DeliveryFormDialog> createState() => _DeliveryFormDialogState();
}

class _DeliveryFormDialogState extends State<_DeliveryFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _itemCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _receiverCtrl;
  late final TextEditingController _sigCtrl;
  late final TextEditingController _ackCtrl;
  late final TextEditingController _dateCtrl;

  int?     _clientId;
  DateTime _date = DateTime.now();

  bool get _isEdit => widget.delivery != null;

  @override
  void initState() {
    super.initState();
    final d       = widget.delivery;
    _itemCtrl     = TextEditingController(text: d?.itemName ?? '');
    _qtyCtrl      = TextEditingController(
        text: d != null ? '${d.quantity}' : '');
    _receiverCtrl = TextEditingController(text: d?.receiverName ?? '');
    _sigCtrl      = TextEditingController(
        text: d?.receiverSignature ?? '');
    _ackCtrl      = TextEditingController(
        text: d?.acknowledgementStatement ?? '');
    _clientId     = d?.client.clientId;
    _date         = d?.deliveryDate ?? DateTime.now();
    _dateCtrl     = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(_date));
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    _receiverCtrl.dispose();
    _sigCtrl.dispose();
    _ackCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) => Get.snackbar('Validation', msg,
      backgroundColor: Colors.orange, colorText: Colors.white);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _clientId == null) {
      _snack('Please select a client.');
      return;
    }

    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);

    final ok = _isEdit
        ? await widget.controller.updateDelivery(
            widget.delivery!.deliveryId,
            UpdateDeliveryRequest(
              itemName:    _itemCtrl.text.trim(),
              quantity:    int.tryParse(_qtyCtrl.text.trim()),
              deliveryDate: _dateCtrl.text.trim(),
              receiverName: _receiverCtrl.text.trim(),
              acknowledgementStatement:
                  _ackCtrl.text.trim().isNotEmpty
                      ? _ackCtrl.text.trim()
                      : null,
            ))
        : await widget.controller.createDelivery(
            CreateDeliveryRequest(
              clientId:    _clientId!,
              itemName:    _itemCtrl.text.trim(),
              quantity:    int.parse(_qtyCtrl.text.trim()),
              deliveryDate: _dateCtrl.text.trim(),
              receiverName: _receiverCtrl.text.trim(),
              receiverSignature: _sigCtrl.text.trim().isNotEmpty
                  ? _sigCtrl.text.trim()
                  : null,
              acknowledgementStatement:
                  _ackCtrl.text.trim().isNotEmpty
                      ? _ackCtrl.text.trim()
                      : null,
            ));

    if (!mounted) return;
    Get.back(); // close loader
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4)),
          ],
        ),
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isEdit) ...[
                      _label('Client'),
                      const SizedBox(height: 8),
                      Obx(() => DropdownButtonFormField<int>(
                            value: _clientId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              hintText: 'Select client',
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                            ),
                            items: widget.controller.clients
                                .map((c) => DropdownMenuItem(
                                      value: c.clientId,
                                      child: Text(
                                          '${c.clientCode} – ${c.clientName}',
                                          overflow:
                                              TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _clientId = v),
                            validator: (v) => v == null
                                ? 'Please select a client'
                                : null,
                          )),
                      const SizedBox(height: 20),
                    ],

                    _label('Item Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _itemCtrl,
                      decoration: _inputDec('e.g. Office Documents'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Item name is required'
                              : null,
                    ),
                    const SizedBox(height: 20),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Quantity'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _inputDec('1'),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty)
                                    return 'Required';
                                  if ((int.tryParse(v.trim()) ?? 0) < 1)
                                    return 'Min 1';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Delivery Date'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _dateCtrl,
                                readOnly: true,
                                decoration: _inputDec('').copyWith(
                                  suffixIcon: const Icon(
                                      Icons.calendar_today, size: 18),
                                ),
                                onTap: () async {
                                  final p = await showDatePicker(
                                    context: context,
                                    initialDate: _date,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now().add(
                                        const Duration(days: 365)),
                                    builder: (ctx, child) => Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme:
                                            const ColorScheme.light(
                                                primary:
                                                    Color(0xFF3498DB)),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (p != null && mounted) {
                                    setState(() {
                                      _date = p;
                                      _dateCtrl.text =
                                          DateFormat('yyyy-MM-dd')
                                              .format(p);
                                    });
                                  }
                                },
                                validator: (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'Date is required'
                                        : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _label('Receiver Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _receiverCtrl,
                      decoration:
                          _inputDec('Full name of the receiver'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Receiver name is required'
                              : null,
                    ),

                    if (!_isEdit) ...[
                      const SizedBox(height: 20),
                      _buildDividerLabel('Receiver Signature (optional)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _sigCtrl,
                        decoration: _inputDec(
                            'Signature data or reference'),
                      ),
                    ],

                    const SizedBox(height: 20),
                    _buildDividerLabel(
                        'Acknowledgement Statement (optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ackCtrl,
                      maxLines: 2,
                      decoration: _inputDec(
                          'e.g. Received in good condition'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildFooter(),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF3498DB), Color(0xFF2980B9)]),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(children: [
        const Icon(Icons.local_shipping, color: Colors.white, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEdit ? 'Edit Delivery' : 'New Delivery',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                Text(
                  _isEdit
                      ? 'Update delivery details'
                      : 'Record a new delivery',
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white70),
                ),
              ]),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ]),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
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
          child: Obx(() {
            final busy = widget.controller.isLoading.value;
            return ElevatedButton(
              onPressed: busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isEdit ? 'Save Changes' : 'Create Delivery',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
            );
          }),
        ),
      ]),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2C3E50)));

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      );

  Widget _buildDividerLabel(String label) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY DETAILS DIALOG — matches _showRetrievalDetails structure
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryDetailsDialog extends StatelessWidget {
  final DeliveryModel      delivery;
  final DeliveryController controller;
  final VoidCallback?      onEdit;
  final VoidCallback?      onDelete;
  final VoidCallback?      onSign;

  const _DeliveryDetailsDialog({
    required this.delivery,
    required this.controller,
    this.onEdit,
    this.onDelete,
    this.onSign,
  });

  /// Decodes the base64 receiver signature, returns null if missing/invalid.
  Uint8List? get _signatureBytes {
    final sig = delivery.receiverSignature;
    if (sig == null || !sig.startsWith('data:image')) return null;
    try {
      return base64Decode(sig.split(',').last);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints:
            const BoxConstraints(maxWidth: 700, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.blue.withOpacity(0.4)),
                ),
                child: const Icon(Icons.local_shipping,
                    color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(delivery.itemName,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(
                      'Delivery #${delivery.deliveryId}  ·  '
                      '${delivery.client.clientCode}',
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Docs chips in header
              _sigChip('Signed', delivery.hasSignature),
              const SizedBox(width: 6),
              _sigChip('PDF', delivery.hasPdf),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Delivery Information'),
                  const SizedBox(height: 12),
                  _infoRow('Item', delivery.itemName),
                  _infoRow('Quantity', '${delivery.quantity}'),
                  _infoRow('Delivery Date',
                      DateFormat('MMM dd, yyyy HH:mm')
                          .format(delivery.deliveryDate.toLocal())),

                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 24),

                  _sectionTitle('Client Information'),
                  const SizedBox(height: 12),
                  _infoRow('Name', delivery.client.clientName),
                  _infoRow('Code', delivery.client.clientCode),
                  if (delivery.client.contactPerson != null)
                    _infoRow('Contact',
                        delivery.client.contactPerson!),
                  if (delivery.client.email != null)
                    _infoRow('Email', delivery.client.email!),
                  if (delivery.client.phone != null)
                    _infoRow('Phone', delivery.client.phone!),

                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 24),

                  _sectionTitle('Receiver'),
                  const SizedBox(height: 12),
                  _infoRow('Name', delivery.receiverName),
                  _infoRow('PDF',
                      delivery.hasPdf ? 'Available' : 'Not available'),
                  const SizedBox(height: 16),

                  // ── Signature status panel (mirrors retrievals) ──────────
                  _buildSignatureStatusPanel(),

                  if (delivery.acknowledgementStatement?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 24),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 24),
                    _sectionTitle('Acknowledgement'),
                    const SizedBox(height: 12),
                    Text(delivery.acknowledgementStatement!,
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 14)),
                  ],

                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 24),

                  _sectionTitle('Meta'),
                  const SizedBox(height: 12),
                  _infoRow(
                      'Created By', delivery.createdBy.username),
                  _infoRow('Created At',
                      DateFormat('MMM dd, yyyy HH:mm')
                          .format(delivery.createdAt.toLocal())),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border:
                  Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onSign != null)
                  OutlinedButton.icon(
                    onPressed: onSign,
                    icon: const Icon(Icons.draw, color: Colors.blue),
                    label: const Text('Add Signature',
                        style: TextStyle(color: Colors.blue)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue)),
                  ),
                if (onEdit != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit,
                        color: Color(0xFF3498DB)),
                    label: const Text('Edit',
                        style: TextStyle(
                            color: Color(0xFF3498DB))),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFF3498DB))),
                  ),
                ],
                if (onDelete != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                        side:
                            const BorderSide(color: Colors.red)),
                  ),
                ],
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black));

  Widget _infoRow(String label, String value,
      {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: isError ? Colors.red : Colors.black87,
                  fontSize: 14)),
        ),
      ]),
    );
  }

  Widget _sigChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withOpacity(0.12)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? Colors.green.withOpacity(0.4)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          active ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 12,
          color: active ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: active ? Colors.green.shade700 : Colors.grey,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ── Signature status panel (mirrors retrievals _buildSignatureStatusPanel) ──

  Widget _buildSignatureStatusPanel() {
    final signed = delivery.hasSignature;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Banner — green if signed, blue prompt if not
      _signatureBanner(
        icon:     signed ? Icons.verified : Icons.edit_note,
        color:    signed ? Colors.green   : Colors.blue,
        title:    signed
            ? 'Signature Captured'
            : 'Awaiting Receiver Signature',
        subtitle: signed
            ? 'Receiver signature has been recorded.'
            : 'Tap "Add Signature" in the footer to capture.',
      ),
      const SizedBox(height: 16),
      // Signature display box
      _buildSignatureDisplay(
        signatureBytes: _signatureBytes,
        signed: signed,
      ),
    ]);
  }

  Widget _signatureBanner({
    required IconData icon,
    required Color    color,
    required String   title,
    required String   subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: color)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildSignatureDisplay({
    required Uint8List? signatureBytes,
    bool signed = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: signed ? Colors.green.shade300 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Receiver Signature',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50))),
          const Spacer(),
          Icon(
            signed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: signed ? Colors.green : Colors.grey.shade400,
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: signed && signatureBytes != null
                ? Image.memory(
                    signatureBytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Text('Invalid signature')),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.draw_outlined,
                            color: Colors.grey.shade400, size: 24),
                        const SizedBox(height: 4),
                        Text('Not yet signed',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12)),
                      ],
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}