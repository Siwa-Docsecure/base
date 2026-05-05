// lib/screens/retrievals_page.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/controllers/retrieval_controller.dart';
import 'package:psms/models/retrieval_model.dart';
import 'package:signature/signature.dart';
import 'package:intl/intl.dart';

import 'widgets/create_retrieval_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Groups same-client + same-local-date retrievals into one list row.
// ─────────────────────────────────────────────────────────────────────────────
class _RetrievalGroup {
  final List<RetrievalModel> retrievals;
  _RetrievalGroup(this.retrievals);

  RetrievalModel get first  => retrievals.first;
  String get clientName     => first.clientName;
  String get clientIdNumber => first.clientIdNumber;
  DateTime get date         => first.requestDate.toLocal();
  String get status         => first.status;
  int    get boxCount       => retrievals.length;

  bool get isComplete =>
      retrievals.every((r) => r.hasClientSignature && r.hasStaffSignature);

  bool get awaitingClientSignature =>
      retrievals.every((r) => r.hasStaffSignature) &&
      retrievals.every((r) => !r.hasClientSignature);

  /// Comma-separated box numbers: "BOX-001, BOX-002" or "BOX-001 +2 more"
  String get boxNumbersSummary {
    final names =
        retrievals.map((r) => r.boxNumber ?? r.retrievalNumber).toList();
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2} more';
  }

  /// Reason from the first retrieval (they share the same reason in a batch).
  String get reason => first.retrievalReason;
}

// ─────────────────────────────────────────────────────────────────────────────

class RetrievalsPage extends StatefulWidget {
  const RetrievalsPage({Key? key}) : super(key: key);

  @override
  State<RetrievalsPage> createState() => _RetrievalsPageState();
}

class _RetrievalsPageState extends State<RetrievalsPage> {
  final RetrievalController controller = Get.put(RetrievalController());
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _searchQuery    = '';

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async => controller.initialize();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── filtering & grouping ──────────────────────────────────────────────────

  List<RetrievalModel> _getFilteredRetrievals() {
    List<RetrievalModel> base;
    switch (_selectedFilter) {
      case 'pending':
        base = controller.pendingRetrievals;
        break;
      case 'recent':
        base = controller.recentRetrievals;
        break;
      case 'completed':
        base = controller.retrievals
            .where((r) =>
                r.status.toLowerCase() == 'completed' ||
                r.status.toLowerCase() == 'collected')
            .toList();
        break;
      case 'rejected':
        base = controller.retrievals
            .where((r) => r.status.toLowerCase() == 'rejected')
            .toList();
        break;
      default:
        base = controller.retrievals;
    }
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((r) =>
        r.retrievalNumber.toLowerCase().contains(q) ||
        r.clientName.toLowerCase().contains(q) ||
        r.clientIdNumber.toLowerCase().contains(q) ||
        r.itemDescription.toLowerCase().contains(q) ||
        r.clientContact.toLowerCase().contains(q) ||
        (r.boxNumber?.toLowerCase().contains(q) ?? false)).toList();
  }

  List<_RetrievalGroup> _groupRetrievals(List<RetrievalModel> list) {
    final map = <String, List<RetrievalModel>>{};
    for (final r in list) {
      final day = DateFormat('yyyy-MM-dd').format(r.requestDate.toLocal());
      map.putIfAbsent('${r.clientName}___$day', () => []).add(r);
    }
    return map.values.map((g) => _RetrievalGroup(g)).toList();
  }

  // ── dialogs ───────────────────────────────────────────────────────────────

  void _showCreateRetrievalDialog() {
    showDialog(
        context: context, builder: (_) => const CreateRetrievalDialog());
  }

  // ── detail dialog ─────────────────────────────────────────────────────────

  void _showRetrievalDetails(RetrievalModel retrieval) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _getStatusColor(retrieval.status).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border:
                      Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            _getStatusColor(retrieval.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _getStatusColor(retrieval.status)
                                .withOpacity(0.5)),
                      ),
                      child: Icon(Icons.inventory_2,
                          color: _getStatusColor(retrieval.status), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // Show box number prominently if available
                            retrieval.boxNumber != null
                                ? 'Box ${retrieval.boxNumber}'
                                : 'Retrieval Details',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            retrieval.retrievalNumber,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(retrieval.status),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Box info — shown first, most relevant
                      if (retrieval.boxNumber != null) ...[
                        _buildSectionTitle('Box Information'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Box Number', retrieval.boxNumber!),
                        if (retrieval.boxDescription != null &&
                            retrieval.boxDescription!.isNotEmpty)
                          _buildInfoRow('Description', retrieval.boxDescription!),
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 24),
                      ],

                      _buildSectionTitle('Client Information'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Name', retrieval.clientName),
                      _buildInfoRow('ID / Code', retrieval.clientIdNumber),
                      _buildInfoRow('Contact', retrieval.clientContact),

                      const SizedBox(height: 24),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 24),

                      _buildSectionTitle('Retrieval Information'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Ref No.', retrieval.retrievalNumber),
                      if (retrieval.itemDescription.isNotEmpty)
                        _buildInfoRow('Item Description', retrieval.itemDescription),
                      _buildInfoRow('Reason', retrieval.retrievalReason),
                      _buildInfoRow(
                        'Request Date',
                        DateFormat('MMM dd, yyyy HH:mm')
                            .format(retrieval.requestDate.toLocal()),
                      ),
                      _buildInfoRow('Requested By', retrieval.requestedBy),
                      if (retrieval.approvedBy != null)
                        _buildInfoRow('Approved By', retrieval.approvedBy!),
                      if (retrieval.approvalDate != null)
                        _buildInfoRow(
                          'Approval Date',
                          DateFormat('MMM dd, yyyy HH:mm')
                              .format(retrieval.approvalDate!.toLocal()),
                        ),
                      if (retrieval.collectedBy != null)
                        _buildInfoRow('Collected By', retrieval.collectedBy!),
                      if (retrieval.collectionDate != null)
                        _buildInfoRow(
                          'Collection Date',
                          DateFormat('MMM dd, yyyy HH:mm')
                              .format(retrieval.collectionDate!.toLocal()),
                        ),
                      if (retrieval.notes != null &&
                          retrieval.notes!.isNotEmpty)
                        _buildInfoRow('Notes', retrieval.notes!),
                      if (retrieval.rejectionReason != null &&
                          retrieval.rejectionReason!.isNotEmpty)
                        _buildInfoRow(
                            'Rejection Reason', retrieval.rejectionReason!,
                            isError: true),

                      if (retrieval.items != null &&
                          retrieval.items!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Items'),
                        const SizedBox(height: 12),
                        ...retrieval.items!.map(_buildItemCard),
                      ],

                      if (retrieval.documents != null &&
                          retrieval.documents!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Documents'),
                        const SizedBox(height: 12),
                        ...retrieval.documents!.map(_buildDocumentCard),
                      ],

                      // Signatures
                      const SizedBox(height: 24),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Signatures'),
                      const SizedBox(height: 12),
                      _buildSignatureStatusPanel(retrieval, context),

                      if (retrieval.history != null &&
                          retrieval.history!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 24),
                        _buildSectionTitle('History'),
                        const SizedBox(height: 12),
                        ...retrieval.history!.map(_buildHistoryCard),
                      ],
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
                    if (retrieval.pdfPath != null &&
                        retrieval.pdfPath!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => Get.snackbar(
                            'Download', 'PDF: ${retrieval.pdfPath}',
                            snackPosition: SnackPosition.BOTTOM),
                        icon: const Icon(Icons.download, color: Colors.blue),
                        label: const Text('Download PDF',
                            style: TextStyle(color: Colors.blue)),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blue)),
                      ),
                    const SizedBox(width: 12),
                    // Manual status change — admin only
                    if (controller.canDeleteRetrievals)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showStatusChangeDialog(retrieval);
                        },
                        icon: const Icon(Icons.swap_horiz,
                            color: Color(0xFF8E44AD)),
                        label: const Text('Change Status',
                            style: TextStyle(color: Color(0xFF8E44AD))),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFF8E44AD))),
                      ),
                    const SizedBox(width: 12),
                    if (controller.canDeleteRetrievals)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showDeleteDialog(retrieval);
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red)),
                      ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureStatusPanel(
      RetrievalModel retrieval, BuildContext dialogContext) {
    final staffDone  = retrieval.hasStaffSignature;
    final clientDone = retrieval.hasClientSignature;
    final complete   = staffDone && clientDone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (complete)
          _signatureBanner(
            icon: Icons.verified,
            color: Colors.green,
            title: 'Retrieval Complete',
            subtitle: 'Both signatures have been captured.',
          )
        else if (staffDone && !clientDone)
          _signatureBanner(
            icon: Icons.pending_actions,
            color: Colors.orange,
            title: 'Awaiting Client Signature',
            subtitle: 'Staff has signed. Waiting on client to complete.',
            action: TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showSignatureDialog(retrieval);
              },
              icon: const Icon(Icons.draw, size: 16),
              label: const Text('Capture Client Signature'),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade800),
            ),
          )
        else
          _signatureBanner(
            icon: Icons.edit_note,
            color: Colors.grey,
            title: 'No Signatures Yet',
            subtitle: 'Staff must sign before the client.',
            action: TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showSignatureDialog(retrieval);
              },
              icon: const Icon(Icons.draw, size: 16),
              label: const Text('Add Staff Signature'),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSignatureDisplay(
                title: 'Staff Signature',
                signatureBytes: retrieval.getStaffSignatureBytes(),
                signed: staffDone,
                stepLabel: 'Step 1',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSignatureDisplay(
                title: 'Client Signature',
                signatureBytes: retrieval.getClientSignatureBytes(),
                signed: clientDone,
                stepLabel: 'Step 2',
                locked: !staffDone,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _signatureBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
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
          if (action != null) action,
        ],
      ),
    );
  }

  // ── smart signature dialog ────────────────────────────────────────────────

  void _showSignatureDialog(RetrievalModel retrieval) {
    final staffDone  = retrieval.hasStaffSignature;
    final clientDone = retrieval.hasClientSignature;

    if (staffDone && clientDone) {
      Get.snackbar(
        'Already Complete',
        'Both signatures have already been captured.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: const Icon(Icons.verified, color: Colors.white),
      );
      return;
    }

    final bool captureClient = staffDone && !clientDone;
    final bool captureStaff  = !staffDone;

    final String dialogTitle = captureClient
        ? 'Client Signature — Step 2'
        : 'Staff Signature — Step 1';

    final SignatureController sigCtrl = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: captureClient
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: captureClient
                            ? Colors.orange.shade100
                            : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: captureClient
                                ? Colors.orange.shade300
                                : Colors.blue.shade300),
                      ),
                      child: Icon(Icons.draw,
                          color:
                              captureClient ? Colors.orange : Colors.blue,
                          size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dialogTitle,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          const SizedBox(height: 4),
                          // Show box number in header
                          if (retrieval.boxNumber != null)
                            Text('Box: ${retrieval.boxNumber}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700)),
                          Text(
                            captureClient
                                ? 'Client should sign to confirm collection.'
                                : 'Staff authorisation signature required.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Step indicator
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: _buildStepIndicator(
                  staffDone: staffDone,
                  clientDone: clientDone,
                  activeStep: captureClient ? 2 : 1,
                ),
              ),

              // Pad
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          captureClient
                              ? 'Client — draw signature below'
                              : 'Staff — draw signature below',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700),
                        ),
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
                        border: Border.all(color: Colors.grey.shade300),
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
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
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

                          if (retrieval.retrievalId == null) return;

                          final success =
                              await controller.updateSignatures(
                            retrievalId:     retrieval.retrievalId!,
                            staffSignature:  captureStaff  ? b64 : null,
                            clientSignature: captureClient ? b64 : null,
                          );

                          if (success && context.mounted) {
                            // Auto-complete when client signature finalises the pair.
                            if (captureClient && retrieval.retrievalId != null) {
                              await controller.updateRetrievalStatus(
                                  retrieval.retrievalId!, 'completed');
                            }

                            Navigator.pop(context);
                            _loadData();
                            Get.snackbar(
                              captureClient
                                  ? 'Retrieval Complete'
                                  : 'Staff Signature Saved',
                              captureClient
                                  ? '${retrieval.clientName}\'s retrieval is now complete.'
                                  : 'Awaiting client signature to complete.',
                              backgroundColor: captureClient
                                  ? Colors.green
                                  : Colors.blue,
                              colorText: Colors.white,
                              icon: captureClient
                                  ? const Icon(Icons.verified,
                                      color: Colors.white)
                                  : null,
                              duration: const Duration(seconds: 4),
                            );
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: Text(captureClient
                            ? 'Save & Complete'
                            : 'Save Staff Signature'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: captureClient
                              ? Colors.green
                              : Colors.blue,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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

  Widget _buildStepIndicator({
    required bool staffDone,
    required bool clientDone,
    required int activeStep,
  }) {
    return Row(
      children: [
        _stepDot(
            step: 1, label: 'Staff Signs', done: staffDone, active: activeStep == 1),
        Expanded(
          child: Container(
              height: 2,
              color: staffDone ? Colors.green : Colors.grey.shade300),
        ),
        _stepDot(
            step: 2,
            label: 'Client Signs',
            done: clientDone,
            active: activeStep == 2,
            locked: !staffDone),
      ],
    );
  }

  Widget _stepDot({
    required int step,
    required String label,
    required bool done,
    required bool active,
    bool locked = false,
  }) {
    final color = done
        ? Colors.green
        : active
            ? Colors.blue
            : locked
                ? Colors.grey.shade300
                : Colors.grey.shade400;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: done
                ? Colors.green
                : active
                    ? Colors.blue
                    : Colors.grey.shade200,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : locked
                    ? const Icon(Icons.lock, size: 14, color: Colors.grey)
                    : Text('$step',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: active ? Colors.white : Colors.grey)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: active || done
                    ? FontWeight.w600
                    : FontWeight.normal)),
      ],
    );
  }

  // ── group detail dialog ───────────────────────────────────────────────────

  void _showGroupDetails(_RetrievalGroup group) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 650),
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
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.clientName,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          Text(
                            '${group.boxCount} box${group.boxCount == 1 ? '' : 'es'}  •  '
                            '${DateFormat('MMM dd, yyyy').format(group.date)}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    if (group.isComplete)
                      _headerChip(Icons.verified, 'Complete', Colors.green)
                    else if (group.awaitingClientSignature)
                      _headerChip(Icons.pending_actions, 'Awaiting Client',
                          Colors.orange),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Retrieval rows
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: group.retrievals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final r = group.retrievals[i];
                    final bothSigned =
                        r.hasStaffSignature && r.hasClientSignature;
                    final awaitClient =
                        r.hasStaffSignature && !r.hasClientSignature;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: box name + status + actions
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3498DB)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.inventory_2,
                                    size: 18,
                                    color: Color(0xFF3498DB)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Box number — primary label
                                    Text(
                                      r.boxNumber ?? r.retrievalNumber,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.black87),
                                    ),
                                    if (r.boxDescription != null &&
                                        r.boxDescription!.isNotEmpty)
                                      Text(r.boxDescription!,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(r.status),
                              const SizedBox(width: 8),
                              if (!bothSigned)
                                IconButton(
                                  icon: Icon(Icons.draw,
                                      size: 18,
                                      color: awaitClient
                                          ? Colors.orange
                                          : Colors.blue),
                                  tooltip: awaitClient
                                      ? 'Capture client signature'
                                      : 'Add staff signature',
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showSignatureDialog(r);
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 18, color: Color(0xFF3498DB)),
                                tooltip: 'View details',
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showRetrievalDetails(r);
                                },
                              ),
                            ],
                          ),
                          // Bottom row: ref number + signature chips
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Retrieval ref as a small tag
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(r.retrievalNumber,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                        fontFamily: 'monospace')),
                              ),
                              const SizedBox(width: 8),
                              _sigChip('Staff', r.hasStaffSignature),
                              const SizedBox(width: 6),
                              _sigChip('Client', r.hasClientSignature),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
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

  Widget _headerChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _sigChip(String label, bool signed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: signed
            ? Colors.green.withOpacity(0.12)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: signed ? Colors.green.withOpacity(0.4) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            signed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12,
            color: signed ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: signed ? Colors.green.shade700 : Colors.grey,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── other dialogs ─────────────────────────────────────────────────────────

  // ── status change dialog ──────────────────────────────────────────────────

  static final _statusOptions = [
    _StatusOption('pending',   Color(0xFFEB984E), Icons.hourglass_empty, 'Pending'),
    _StatusOption('completed', Colors.blue,       Icons.verified,        'Completed'),
    _StatusOption('retrieved', Colors.teal,       Icons.move_to_inbox,   'Retrieved'),
  ];

  void _showStatusChangeDialog(RetrievalModel retrieval) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E44AD).withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E44AD).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.swap_horiz,
                          color: Color(0xFF8E44AD), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Change Status',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text(
                            retrieval.boxNumber != null
                                ? 'Box ${retrieval.boxNumber}'
                                : retrieval.retrievalNumber,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(retrieval.status),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black45),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Status option list
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select new status:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700)),
                    const SizedBox(height: 12),
                    ..._statusOptions.map((opt) {
                      final isCurrent =
                          retrieval.status.toLowerCase() == opt.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: isCurrent
                              ? null
                              : () async {
                                  Navigator.pop(context);
                                  if (retrieval.retrievalId != null) {
                                    await controller.updateRetrievalStatus(
                                        retrieval.retrievalId!, opt.key);
                                    _loadData();
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? opt.color.withOpacity(0.12)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrent
                                    ? opt.color.withOpacity(0.5)
                                    : Colors.grey.shade200,
                                width: isCurrent ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(opt.icon,
                                    color: isCurrent
                                        ? opt.color
                                        : Colors.grey.shade500,
                                    size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(opt.label,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isCurrent
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isCurrent
                                              ? opt.color
                                              : Colors.black87)),
                                ),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: opt.color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('Current',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: opt.color,
                                            fontWeight: FontWeight.w600)),
                                  )
                                else
                                  Icon(Icons.arrow_forward_ios,
                                      size: 14, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── delete dialog ─────────────────────────────────────────────────────────

  void _showDeleteDialog(RetrievalModel retrieval) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Retrieval',
            style: TextStyle(color: Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this retrieval?',
                style: TextStyle(color: Colors.black87)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (retrieval.boxNumber != null)
                    Text('Box: ${retrieval.boxNumber}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  Text('Ref: ${retrieval.retrievalNumber}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  Text('Client: ${retrieval.clientName}',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('This action cannot be undone.',
                style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.black54),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (retrieval.retrievalId != null) {
                final ok = await controller
                    .deleteRetrieval(retrieval.retrievalId!);
                if (context.mounted) Navigator.pop(context);
                if (ok) _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    final counts = {
      'all':       controller.retrievals.length,
      'pending':   controller.pendingRetrievals.length,
      'completed': controller.retrievals
          .where((r) => r.status.toLowerCase() == 'completed').length,
      'retrieved': controller.retrievals
          .where((r) => r.status.toLowerCase() == 'retrieved').length,
      'rejected':  controller.retrievals
          .where((r) => r.status.toLowerCase() == 'rejected').length,
      'recent':    controller.recentRetrievals.length,
    };

    // Explicitly typed to avoid null-safety false positives on field access.
    final List<_FilterOption> options = [
      const _FilterOption('all',       'All Retrievals', Icons.inventory_2_outlined, Colors.blueGrey),
      const _FilterOption('pending',   'Pending',        Icons.hourglass_empty,      Colors.orange),
      const _FilterOption('completed', 'Completed',      Icons.verified,             Colors.blue),
      const _FilterOption('retrieved', 'Retrieved',      Icons.move_to_inbox,        Colors.teal),
      const _FilterOption('rejected',  'Rejected',       Icons.cancel_outlined,      Colors.red),
      const _FilterOption('recent',    'Recent',         Icons.history,              Colors.purple),
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setLocalState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50).withOpacity(0.04),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF2C3E50), size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Filter Retrievals',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      if (_selectedFilter != 'all')
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedFilter = 'all');
                            Navigator.pop(context);
                          },
                          child: const Text('Clear',
                              style: TextStyle(color: Colors.red, fontSize: 13)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.black45, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // ── Filter cards grid ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: options.map((opt) {
                      final isSelected = _selectedFilter == opt.value;
                      final count      = counts[opt.value] ?? 0;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() => _selectedFilter = opt.value);
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? opt.color.withOpacity(0.12)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? opt.color.withOpacity(0.6)
                                  : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(opt.icon,
                                  size: 18,
                                  color: isSelected
                                      ? opt.color
                                      : Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  opt.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? opt.color
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? opt.color.withOpacity(0.18)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? opt.color
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // ── Footer note ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Counts reflect currently loaded data. '
                    'Refresh the list to see updated totals.',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

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
            const Text('Retrievals',
                style: TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 20)),
            Text('Manage warehouse retrievals efficiently',
                style: TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w100,
                    fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF2C3E50)),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2C3E50)),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF2C3E50)),
            onPressed: () {},
            tooltip: 'More',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Stats cards
          Obx(() {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard('All time',
                        controller.retrievals.length.toString(),
                        'Total Retrievals', Icons.inventory_2,
                        const Color(0xFF5DADE2)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard('In collections',
                        controller.pendingRetrievals.length.toString(),
                        'Total Boxes', Icons.add_box,
                        const Color(0xFF52BE80)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard('Collections',
                        controller.recentRetrievals.length.toString(),
                        'This Month', Icons.calendar_today,
                        const Color(0xFFEB984E)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Active clients',
                      // Read the real total from the API, not just
                      // clients who happen to have retrievals.
                      controller.activeClientsCount.value.toString(),
                      'Clients',
                      Icons.people,
                      const Color(0xFFAB47BC),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // Search + chips
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.black.withOpacity(0.3)),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                hintText: 'Search by client, box, ref…',
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
                                        onPressed: () => setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        }),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                              ),
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildFilterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Pending', 'pending'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Recent', 'recent'),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: Colors.black.withOpacity(0.2)),

                  // ── Table header ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    color: Colors.black.withOpacity(0.05),
                    child: Row(
                      children: [
                        // Client — flex 3
                        Expanded(
                          flex: 3,
                          child: _headerCell('Client'),
                        ),
                        // Box(es) — flex 2
                        Expanded(
                          flex: 2,
                          child: _headerCell('Box(es)'),
                        ),
                        // Date — flex 2
                        Expanded(
                          flex: 2,
                          child: _headerCell('Date'),
                        ),
                        // Reason — flex 2
                        Expanded(
                          flex: 2,
                          child: _headerCell('Reason'),
                        ),
                        // Status — flex 1
                        Expanded(
                          flex: 1,
                          child: _headerCell('Status'),
                        ),
                        // Signatures — fixed
                        SizedBox(
                          width: 110,
                          child: _headerCell('Signatures'),
                        ),
                        // Actions — fixed
                        SizedBox(
                          width: 100,
                          child: _headerCell('Actions', align: TextAlign.end),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: Colors.black.withOpacity(0.2)),

                  // List
                  Expanded(
                    child: Obx(() {
                      if (controller.isLoading.value) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.black));
                      }
                      final groups =
                          _groupRetrievals(_getFilteredRetrievals());

                      if (groups.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.black.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text('No retrievals found',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black
                                          .withOpacity(0.8))),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedFilter != 'all'
                                    ? 'Try adjusting your filters'
                                    : 'Create a new retrieval to get started',
                                style: TextStyle(
                                    color: Colors.black.withOpacity(0.6),
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async => _loadData(),
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: groups.length,
                                separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Colors.black.withOpacity(0.1)),
                                itemBuilder: (_, i) =>
                                    _buildGroupListItem(groups[i]),
                              ),
                            ),
                            // ── Pagination bar (visible for 'all' filter) ──
                            if (_selectedFilter == 'all' &&
                                controller.totalPages.value > 1)
                              _buildPaginationBar(),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: controller.canCreateRetrievals
          ? FloatingActionButton.extended(
              onPressed: _showCreateRetrievalDialog,
              icon: const Icon(Icons.add),
              label: const Text('New Retrieval'),
              backgroundColor:
                  const Color(0xFF1976D2).withOpacity(0.8),
            )
          : null,
    );
  }

  // ── list row ──────────────────────────────────────────────────────────────

  Widget _buildGroupListItem(_RetrievalGroup group) {
    return InkWell(
      onTap: () => group.retrievals.length == 1
          ? _showRetrievalDetails(group.first)
          : _showGroupDetails(group),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            // ── Client ───────────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Row(
                children: [
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
                        Text(group.clientName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.black),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(group.clientIdNumber,
                            style: TextStyle(
                                color: Colors.black.withOpacity(0.5),
                                fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Box number(s) ─────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.boxNumbersSummary,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2980B9)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Box count badge
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
                      '${group.boxCount} box${group.boxCount == 1 ? '' : 'es'}',
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
                DateFormat('MMM dd, yyyy').format(group.date),
                style: const TextStyle(fontSize: 13, color: Colors.black),
              ),
            ),

            // ── Reason ────────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Text(
                group.reason,
                style: TextStyle(
                    fontSize: 12, color: Colors.black.withOpacity(0.65)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── Status ────────────────────────────────────────────────────
            Expanded(
              flex: 1,
              child: _buildStatusBadge(group.status),
            ),

            // ── Signatures ────────────────────────────────────────────────
            SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sigChip('Staff',
                      group.retrievals.every((r) => r.hasStaffSignature)),
                  const SizedBox(height: 4),
                  _sigChip('Client',
                      group.retrievals.every((r) => r.hasClientSignature)),
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
                    onPressed: () => group.retrievals.length == 1
                        ? _showRetrievalDetails(group.first)
                        : _showGroupDetails(group),
                    tooltip: 'View',
                  ),
                  if (!group.isComplete)
                    IconButton(
                      icon: Icon(Icons.draw,
                          size: 18,
                          color: group.awaitingClientSignature
                              ? Colors.orange
                              : Colors.black.withOpacity(0.7)),
                      onPressed: () =>
                          _showSignatureDialog(group.first),
                      tooltip: group.awaitingClientSignature
                          ? 'Capture client signature'
                          : 'Add signature',
                    ),
                  if (controller.canDeleteRetrievals)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: () => _showDeleteDialog(group.first),
                      tooltip: 'Delete',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Widget _headerCell(String label, {TextAlign align = TextAlign.left}) =>
      Text(label,
          textAlign: align,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.black.withOpacity(0.6)));

  // ── Pagination bar ────────────────────────────────────────────────────────

  Widget _buildPaginationBar() {
    return Obx(() {
      final current = controller.currentPage.value;
      final total   = controller.totalPages.value;
      final count   = controller.totalRetrievals.value;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(top: BorderSide(color: Colors.black.withOpacity(0.08))),
        ),
        child: Row(
          children: [
            Text(
              '$count retrieval${count == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.5),
                  fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            _pageBtn(
              icon: Icons.chevron_left,
              enabled: current > 1,
              onTap: controller.loadPreviousPage,
            ),
            ...List.generate(total, (i) {
              final page        = i + 1;
              final isCurrent   = page == current;
              final visible     = page == 1 || page == total ||
                  (page >= current - 1 && page <= current + 1);
              final isGapBefore = page == current - 2 && page > 2;
              final isGapAfter  = page == current + 2 && page < total - 1;

              if (isGapBefore || isGapAfter) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
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
                    : () => controller.getAllRetrievals(
                          page:      page,
                          search:    controller.searchQuery.value.isNotEmpty
                              ? controller.searchQuery.value
                              : null,
                          sortBy:    controller.sortBy.value,
                          sortOrder: controller.sortOrder.value,
                        ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
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
              onTap: controller.loadNextPage,
            ),
          ],
        ),
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
            color: enabled ? Colors.black54 : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String subtitle,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                  border: Border.all(color: color.withOpacity(0.3)),
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
                  color: Colors.black.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildSectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black));

  Widget _buildInfoRow(String label, String value,
      {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: _getStatusColor(status).withOpacity(0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: _getStatusColor(status),
            fontSize: 10,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSignatureDisplay({
    required String title,
    required Uint8List? signatureBytes,
    bool signed = false,
    String? stepLabel,
    bool locked = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: signed
              ? Colors.green.shade300
              : locked
                  ? Colors.grey.shade200
                  : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
        color: locked ? Colors.grey.shade50 : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (stepLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: signed
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(stepLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: signed
                              ? Colors.green.shade700
                              : Colors.grey.shade500)),
                ),
                const SizedBox(width: 6),
              ],
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50))),
              const Spacer(),
              Icon(
                signed
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 16,
                color: signed ? Colors.green : Colors.grey.shade400,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color:
                  locked ? Colors.grey.shade100 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: signed && signatureBytes != null
                  ? Image.memory(signatureBytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Text('Invalid signature')))
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              locked
                                  ? Icons.lock
                                  : Icons.draw_outlined,
                              color: Colors.grey.shade400,
                              size: 24),
                          const SizedBox(height: 4),
                          Text(
                              locked
                                  ? 'Awaiting staff first'
                                  : 'Not yet signed',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(RetrievalItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2,
              color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87)),
                Text('${item.itemCategory} • Qty: ${item.quantity}',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          if (item.serialNumber != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text('SN: ${item.serialNumber}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54)),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(RetrievalDocumentModel doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file,
              color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.documentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87)),
                Text(
                  '${doc.documentType}  •  '
                  '${DateFormat('MMM dd, yyyy').format(doc.uploadedDate.toLocal())}',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.download,
                size: 20, color: Colors.grey.shade600),
            onPressed: () => Get.snackbar(
                'Download', 'Downloading ${doc.documentName}...',
                snackPosition: SnackPosition.BOTTOM),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(RetrievalHistoryModel history) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getActionColor(history.action).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(_getActionIcon(history.action),
                color: _getActionColor(history.action), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(history.action.toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text('By: ${history.performedBy}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm')
                      .format(history.timestamp.toLocal()),
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 11),
                ),
                if (history.comments != null &&
                    history.comments!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(history.comments!,
                      style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.black54)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':    return Colors.orange;
      case 'completed':  return Colors.blue;
      case 'retrieved':  return Colors.teal;
      case 'collected':  return Colors.teal;
      case 'rejected':   return Colors.red;
      default:           return Colors.grey;
    }
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'collected':
      case 'collection':
      case 'completed':  return Colors.blue;
      case 'rejected':
      case 'reject':     return Colors.red;
      case 'created':
      case 'submitted':  return Colors.orange;
      default:           return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'collected':
      case 'collection':
      case 'completed':  return Icons.assignment_turned_in;
      case 'rejected':
      case 'reject':     return Icons.cancel;
      case 'created':
      case 'submitted':  return Icons.add_circle;
      default:           return Icons.info;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Simple config class for status options — avoids Dart record destructuring
// which is not reliably supported across all Flutter/Dart versions.
// ─────────────────────────────────────────────────────────────────────────────
class _StatusOption {
  final String key;
  final Color color;
  final IconData icon;
  final String label;
  const _StatusOption(this.key, this.color, this.icon, this.label);
}

/// Filter option used in the professional filter dialog.
class _FilterOption {
  final String value;   // renamed from 'key' — avoids clash with Widget.key
  final String label;
  final IconData icon;
  final Color color;
  const _FilterOption(this.value, this.label, this.icon, this.color);
}