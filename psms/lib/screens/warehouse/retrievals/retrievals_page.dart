// lib/screens/retrievals_page.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/retrieval_controller.dart';
import 'package:psms/models/box_model.dart';
import 'package:psms/models/client_model.dart';
import 'package:psms/models/retrieval_model.dart';
import 'package:signature/signature.dart';
import 'package:intl/intl.dart';

class RetrievalsPage extends StatefulWidget {
  const RetrievalsPage({Key? key}) : super(key: key);

  @override
  State<RetrievalsPage> createState() => _RetrievalsPageState();
}

class _RetrievalsPageState extends State<RetrievalsPage> {
  final RetrievalController controller = Get.put(RetrievalController());
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    await controller.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showRetrievalDetails(RetrievalModel retrieval) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
          decoration: BoxDecoration(
            color: Colors.white, // solid white background
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
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
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
                              .withOpacity(0.5),
                        ),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: _getStatusColor(retrieval.status),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Retrieval Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            retrieval.retrievalNumber,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
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
                      // Client Information
                      _buildSectionTitle('Client Information'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Name', retrieval.clientName),
                      _buildInfoRow('ID Number', retrieval.clientIdNumber),
                      _buildInfoRow('Contact', retrieval.clientContact),

                      const SizedBox(height: 24),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 24),

                      // Retrieval Information
                      _buildSectionTitle('Retrieval Information'),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                          'Item Description', retrieval.itemDescription),
                      _buildInfoRow('Reason', retrieval.retrievalReason),
                      _buildInfoRow(
                        'Request Date',
                        DateFormat('MMM dd, yyyy HH:mm')
                            .format(retrieval.requestDate),
                      ),
                      _buildInfoRow('Requested By', retrieval.requestedBy),

                      if (retrieval.approvedBy != null)
                        _buildInfoRow('Approved By', retrieval.approvedBy!),
                      if (retrieval.approvalDate != null)
                        _buildInfoRow(
                          'Approval Date',
                          DateFormat('MMM dd, yyyy HH:mm')
                              .format(retrieval.approvalDate!),
                        ),
                      if (retrieval.collectedBy != null)
                        _buildInfoRow('Collected By', retrieval.collectedBy!),
                      if (retrieval.collectionDate != null)
                        _buildInfoRow(
                          'Collection Date',
                          DateFormat('MMM dd, yyyy HH:mm')
                              .format(retrieval.collectionDate!),
                        ),
                      if (retrieval.notes != null &&
                          retrieval.notes!.isNotEmpty)
                        _buildInfoRow('Notes', retrieval.notes!),
                      if (retrieval.rejectionReason != null &&
                          retrieval.rejectionReason!.isNotEmpty)
                        _buildInfoRow(
                            'Rejection Reason', retrieval.rejectionReason!,
                            isError: true),

                      // Items
                      if (retrieval.items != null &&
                          retrieval.items!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Items'),
                        const SizedBox(height: 12),
                        ...retrieval.items!.map((item) => _buildItemCard(item)),
                      ],

                      // Documents
                      if (retrieval.documents != null &&
                          retrieval.documents!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Documents'),
                        const SizedBox(height: 12),
                        ...retrieval.documents!
                            .map((doc) => _buildDocumentCard(doc)),
                      ],

                      // Signatures
                      if (retrieval.hasClientSignature ||
                          retrieval.hasStaffSignature) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Signatures'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (retrieval.hasClientSignature)
                              Expanded(
                                child: _buildSignatureDisplay(
                                  title: 'Client Signature',
                                  signatureBytes:
                                      retrieval.getClientSignatureBytes(),
                                ),
                              ),
                            if (retrieval.hasClientSignature &&
                                retrieval.hasStaffSignature)
                              const SizedBox(width: 16),
                            if (retrieval.hasStaffSignature)
                              Expanded(
                                  child: _buildSignatureBox(
                                      'Staff Signature', true)),
                          ],
                        ),
                      ],

                      // Add signature option if no signatures
                      if (!retrieval.hasClientSignature &&
                          !retrieval.hasStaffSignature) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Signatures'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showSignatureDialog(retrieval);
                          },
                          icon: const Icon(Icons.draw),
                          label: const Text('Add Signatures'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],

                      // History
                      if (retrieval.history != null &&
                          retrieval.history!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 24),
                        _buildSectionTitle('History'),
                        const SizedBox(height: 12),
                        ...retrieval.history!
                            .map((history) => _buildHistoryCard(history)),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (retrieval.pdfPath != null &&
                        retrieval.pdfPath!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () {
                          Get.snackbar(
                            'Download',
                            'PDF: ${retrieval.pdfPath}',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        },
                        icon: const Icon(Icons.download, color: Colors.blue),
                        label: const Text('Download PDF',
                            style: TextStyle(color: Colors.blue)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blue),
                        ),
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
                          side: const BorderSide(color: Colors.red),
                        ),
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

  Widget _buildSignatureDisplay({
    required String title,
    required Uint8List? signatureBytes,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          if (signatureBytes != null)
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  signatureBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('Invalid signature'),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child:
                    Text('No signature', style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> _captureSignature(BuildContext context, String title) async {
    final controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.draw, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Signature pad
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Signature(
                          controller: controller,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: controller.clear,
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Clear'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (controller.isEmpty) {
                              Get.snackbar(
                                'Error',
                                'Please provide a signature',
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }
                            final pngBytes = await controller.toPngBytes();
                            if (pngBytes != null) {
                              final base64 = base64Encode(pngBytes);
                              Navigator.pop(context, base64);
                            }
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498DB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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
  }

  void _showSignatureDialog(RetrievalModel retrieval) {
    final SignatureController clientSignatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    final SignatureController staffSignatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
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
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child:
                          const Icon(Icons.draw, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Capture Signatures',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Client Signature
                    _buildSignaturePad(
                        'Client Signature', clientSignatureController),
                    const SizedBox(height: 24),

                    // Staff Signature
                    _buildSignaturePad(
                        'Staff Signature', staffSignatureController),
                  ],
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        foregroundColor: Colors.black87,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        // Get signature data
                        final clientSignature =
                            await clientSignatureController.toPngBytes();
                        final staffSignature =
                            await staffSignatureController.toPngBytes();

                        if (clientSignature == null && staffSignature == null) {
                          Get.snackbar(
                            'Error',
                            'Please provide at least one signature',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        // Convert to base64
                        String? clientSignatureBase64;
                        String? staffSignatureBase64;

                        if (clientSignature != null) {
                          clientSignatureBase64 =
                              'data:image/png;base64,${base64Encode(clientSignature)}';
                        }

                        if (staffSignature != null) {
                          staffSignatureBase64 =
                              'data:image/png;base64,${base64Encode(staffSignature)}';
                        }

                        if (retrieval.retrievalId != null) {
                          final success = await controller.updateSignatures(
                            retrievalId: retrieval.retrievalId!,
                            clientSignature: clientSignatureBase64,
                            staffSignature: staffSignatureBase64,
                          );

                          if (success) {
                            Navigator.pop(context);
                            _loadData();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save Signatures'),
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

  Widget _buildSignaturePad(String label, SignatureController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            TextButton.icon(
              onPressed: () => controller.clear(),
              icon: const Icon(Icons.clear, size: 16, color: Colors.black),
              label: const Text('Clear', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Signature(
            controller: controller,
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  Widget _buildSignatureBox(String label, bool hasSig) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.green.withOpacity(0.1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Icon(Icons.check_circle, color: Colors.green, size: 32),
        ],
      ),
    );
  }

  void _showDeleteDialog(RetrievalModel retrieval) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Retrieval',
            style: TextStyle(color: Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this retrieval?',
              style: TextStyle(color: Colors.black87),
            ),
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
                  Text(
                    'Retrieval: ${retrieval.retrievalNumber}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Text(
                    'Client: ${retrieval.clientName}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
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
                final success =
                    await controller.deleteRetrieval(retrieval.retrievalId!);
                Navigator.pop(context);
                if (success) {
                  _loadData();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? Colors.red : Colors.black87,
                fontSize: 14,
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2,
              color: Colors.white.withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white),
                ),
                Text(
                  '${item.itemCategory} • Qty: ${item.quantity}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ),
          if (item.serialNumber != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Text(
                'SN: ${item.serialNumber}',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file,
              color: Colors.white.withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.documentName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white),
                ),
                Text(
                  '${doc.documentType} • ${DateFormat('MMM dd, yyyy').format(doc.uploadedDate)}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download, size: 20, color: Colors.white),
            onPressed: () {
              Get.snackbar(
                'Download',
                'Downloading ${doc.documentName}...',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getActionColor(history.action).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: _getActionColor(history.action).withOpacity(0.3)),
            ),
            child: Icon(_getActionIcon(history.action),
                color: _getActionColor(history.action), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  history.action.toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'By: ${history.performedBy}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(history.timestamp),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 11),
                ),
                if (history.comments != null &&
                    history.comments!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    history.comments!,
                    style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'approved':
      case 'approve':
        return Colors.green;
      case 'rejected':
      case 'reject':
        return Colors.red;
      case 'collected':
      case 'collection':
        return Colors.blue;
      case 'created':
      case 'submitted':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'approved':
      case 'approve':
        return Icons.check_circle;
      case 'rejected':
      case 'reject':
        return Icons.cancel;
      case 'collected':
      case 'collection':
        return Icons.assignment_turned_in;
      case 'created':
      case 'submitted':
        return Icons.add_circle;
      default:
        return Icons.info;
    }
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
      case 'collected':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  List<RetrievalModel> _getFilteredRetrievals() {
    List<RetrievalModel> baseList;

    // Apply status filter
    switch (_selectedFilter) {
      case 'pending':
        baseList = controller.pendingRetrievals;
        break;
      case 'recent':
        baseList = controller.recentRetrievals;
        break;
      case 'approved':
        baseList = controller.retrievals
            .where((r) => r.status.toLowerCase() == 'approved')
            .toList();
        break;
      case 'completed':
        baseList = controller.retrievals
            .where((r) =>
                r.status.toLowerCase() == 'completed' ||
                r.status.toLowerCase() == 'collected')
            .toList();
        break;
      case 'rejected':
        baseList = controller.retrievals
            .where((r) => r.status.toLowerCase() == 'rejected')
            .toList();
        break;
      default:
        baseList = controller.retrievals;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      return baseList.where((r) {
        final searchLower = _searchQuery.toLowerCase();
        return r.retrievalNumber.toLowerCase().contains(searchLower) ||
            r.clientName.toLowerCase().contains(searchLower) ||
            r.clientIdNumber.toLowerCase().contains(searchLower) ||
            r.itemDescription.toLowerCase().contains(searchLower) ||
            r.clientContact.toLowerCase().contains(searchLower);
      }).toList();
    }

    return baseList;
  }

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
            const Text(
              'Retrievals',
              style: TextStyle(
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            Text(
              'Manage warehouse retrievals efficiently',
              style: TextStyle(
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w100,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.filter_list,
              color: const Color(0xFF2C3E50),
            ),
            onPressed: () {
              _showFilterDialog();
            },
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: const Color(0xFF2C3E50),
            ),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert,
              color: const Color(0xFF2C3E50),
            ),
            onPressed: () {},
            tooltip: 'More',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          Obx(() {
            final totalRetrievals = controller.retrievals.length;
            final pendingCount = controller.pendingRetrievals.length;
            final recentCount = controller.recentRetrievals.length;

            final uniqueClients = controller.retrievals
                .map((r) => r.clientIdNumber)
                .toSet()
                .length;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'All time',
                      totalRetrievals.toString(),
                      'Total Retrievals',
                      Icons.inventory_2,
                      const Color(0xFF5DADE2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'In collections',
                      pendingCount.toString(),
                      'Total Boxes',
                      Icons.add_box,
                      const Color(0xFF52BE80),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Collections',
                      recentCount.toString(),
                      'This Month',
                      Icons.calendar_today,
                      const Color(0xFFEB984E),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Active clients',
                      uniqueClients.toString(),
                      'Clients',
                      Icons.people,
                      const Color(0xFFAB47BC),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Content Area
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
                  // Search and Filter
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
                                hintText: 'Search retrievals...',
                                hintStyle: TextStyle(
                                    color: Colors.black.withOpacity(0.5)),
                                prefixIcon: Icon(Icons.search,
                                    size: 20,
                                    color: Colors.black.withOpacity(0.7)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            size: 20,
                                            color:
                                                Colors.black.withOpacity(0.7)),
                                        onPressed: () {
                                          setState(() {
                                            _searchController.clear();
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
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

                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Client',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Date',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Boxes',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(
                            'Actions',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: Colors.black.withOpacity(0.2)),

                  // Retrievals List
                  Expanded(
                    child: Obx(() {
                      if (controller.isLoading.value) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.black),
                        );
                      }

                      final filteredRetrievals = _getFilteredRetrievals();

                      if (filteredRetrievals.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Colors.black.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No retrievals found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedFilter != 'all'
                                    ? 'Try adjusting your filters'
                                    : 'Create a new retrieval to get started',
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          _loadData();
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(0),
                          itemCount: filteredRetrievals.length,
                          separatorBuilder: (context, index) => Divider(
                              height: 1, color: Colors.black.withOpacity(0.1)),
                          itemBuilder: (context, index) {
                            final retrieval = filteredRetrievals[index];
                            return _buildRetrievalListItem(retrieval);
                          },
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
              onPressed: () {
                _showCreateRetrievalDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('New Retrieval'),
              backgroundColor: const Color(0xFF1976D2).withOpacity(0.8),
            )
          : null,
    );
  }

  Widget _buildStatCard(
      String label, String value, String subtitle, IconData icon, Color color) {
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
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.black.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.black.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.black.withOpacity(0.5)
                : Colors.black.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Filter Retrievals',
            style: TextStyle(color: Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All', style: TextStyle(color: Colors.black)),
              leading: Radio<String>(
                value: 'all',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.black,
              ),
            ),
            ListTile(
              title:
                  const Text('Pending', style: TextStyle(color: Colors.black)),
              leading: Radio<String>(
                value: 'pending',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.black,
              ),
            ),
            ListTile(
              title:
                  const Text('Approved', style: TextStyle(color: Colors.black)),
              leading: Radio<String>(
                value: 'approved',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.black,
              ),
            ),
            ListTile(
              title: const Text('Completed',
                  style: TextStyle(color: Colors.black)),
              leading: Radio<String>(
                value: 'completed',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.black,
              ),
            ),
            ListTile(
              title:
                  const Text('Rejected', style: TextStyle(color: Colors.black)),
              leading: Radio<String>(
                value: 'rejected',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.black,
              ),
            ),
            ListTile(
              title:
                  const Text('Recent', style: TextStyle(color: Colors.black)),
              leading: Radio<String>(
                value: 'recent',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetrievalListItem(RetrievalModel retrieval) {
    return InkWell(
      onTap: () => _showRetrievalDetails(retrieval),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Client Info
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black.withOpacity(0.2)),
                    ),
                    child: Icon(
                      Icons.business,
                      size: 20,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          retrieval.clientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          retrieval.itemDescription,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.7),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Date
            Expanded(
              child: Text(
                DateFormat('MMM dd, yyyy').format(retrieval.requestDate),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black,
                ),
              ),
            ),

            // Boxes Count
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF52BE80).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF52BE80).withOpacity(0.3)),
                ),
                child: Text(
                  retrieval.items != null ? '${retrieval.items!.length}' : '1',
                  style: const TextStyle(
                    color: Color(0xFF52BE80),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Actions
            SizedBox(
              width: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.visibility_outlined,
                        size: 20, color: Colors.black.withOpacity(0.7)),
                    onPressed: () => _showRetrievalDetails(retrieval),
                    tooltip: 'View',
                  ),
                  IconButton(
                    icon: Icon(Icons.draw,
                        size: 20, color: Colors.black.withOpacity(0.7)),
                    onPressed: () => _showSignatureDialog(retrieval),
                    tooltip: 'Signatures',
                  ),
                  if (controller.canDeleteRetrievals)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: Colors.red),
                      onPressed: () => _showDeleteDialog(retrieval),
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

  void _showCreateRetrievalDialog() {
    // Local state (not reactive)
    ClientModel? selectedClient;
    BoxModel? selectedBox;
    DateTime? retrievalDate = DateTime.now();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 650),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (unchanged)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'New Retrieval',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
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
                        // Client dropdown – using Obx
                        const Text(
                          'Select Client',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Obx(
                          () => DropdownButtonFormField<ClientModel>(
                            value: selectedClient,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            hint: const Text('Choose a client'),
                            items: controller.clients.map((client) {
                              return DropdownMenuItem<ClientModel>(
                                value: client,
                                child: Text(client.clientName),
                              );
                            }).toList(),
                            onChanged: (client) {
                              setState(() {
                                selectedClient = client;
                                selectedBox = null; // reset box
                                if (client != null) {
                                  controller
                                      .getClientStoredBoxes(client.clientId);
                                }
                              });
                            },
                          ),
                        ),

                        // Client details (autofilled)
                        if (selectedClient != null) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Client Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRowStatic(
                                    'Name', selectedClient!.clientName),
                                _buildInfoRowStatic(
                                    'Code', selectedClient!.clientCode),
                                if (selectedClient!.contactPerson != null)
                                  _buildInfoRowStatic('Contact',
                                      selectedClient!.contactPerson!),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Box dropdown – using Obx
                        const Text(
                          'Select Box to Retrieve',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Obx(() {
                          if (selectedClient == null) {
                            return const Text('Please select a client first.',
                                style: TextStyle(color: Colors.grey));
                          }
                          if (controller.loadingBoxes.value) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (controller.clientStoredBoxes.isEmpty) {
                            return const Text('No stored boxes available.',
                                style: TextStyle(color: Colors.grey));
                          }
                          return DropdownButtonFormField<BoxModel>(
                            value: selectedBox,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            hint: const Text('Choose a box'),
                            items: controller.clientStoredBoxes.map((box) {
                              return DropdownMenuItem<BoxModel>(
                                value: box,
                                child: Text(
                                    '${box.boxNumber} - ${box.description ?? 'No description'}'),
                              );
                            }).toList(),
                            onChanged: (box) {
                              setState(() {
                                selectedBox = box;
                              });
                            },
                          );
                        }),

                        const SizedBox(height: 16),

                        // Retrieval Date (unchanged)
                        const Text(
                          'Retrieval Date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: retrievalDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 1)),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF3498DB),
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (date != null && mounted) {
                              setState(() {
                                retrievalDate = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  retrievalDate != null
                                      ? DateFormat('yyyy-MM-dd')
                                          .format(retrievalDate!)
                                      : 'Select date',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const Icon(Icons.calendar_today,
                                    color: Color(0xFF3498DB)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Reason / Description
                        const Text(
                          'Reason / Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Enter reason or description',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFF3498DB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF3498DB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // Validation
                            if (selectedClient == null) {
                              Get.snackbar('Error', 'Please select a client',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white);
                              return;
                            }
                            if (selectedBox == null) {
                              Get.snackbar('Error', 'Please select a box',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white);
                              return;
                            }
                            if (retrievalDate == null) {
                              Get.snackbar('Error', 'Please select a date',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white);
                              return;
                            }
                            if (reasonController.text.isEmpty) {
                              Get.snackbar('Error', 'Please enter a reason',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white);
                              return;
                            }

                            // Get current user's name for retrievedBy
                            final retrievedBy = Get.find<AuthController>().currentUser.value?.username ?? 'Unknown';

                            final request = CreateRetrievalRequest(
                              clientId: selectedClient!.clientId,
                              boxId: selectedBox!.boxId,
                              retrievalDate: DateFormat('yyyy-MM-dd')
                                  .format(retrievalDate!),
                              retrievedBy: retrievedBy,
                              reason: reasonController.text,
                            );

                            // Show loading indicator
                            Get.dialog(
                              const Center(child: CircularProgressIndicator()),
                              barrierDismissible: false,
                            );

                            final success =
                                await controller.createRetrieval(request);

                            if (!mounted) return;
                            Get.back(); // close loading

                            if (success) {
                              Navigator.pop(context); // close dialog
                              _loadData();
                              Get.snackbar(
                                'Success',
                                'Retrieval created successfully',
                                backgroundColor: Colors.green,
                                colorText: Colors.white,
                              );
                            } else {
                              Get.snackbar(
                                'Error',
                                controller.errorMessage.value.isNotEmpty
                                    ? controller.errorMessage.value
                                    : 'Failed to create retrieval',
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498DB),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Create Retrieval',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
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
      ),
    );
  }

// Helper to display static info rows
  Widget _buildInfoRowStatic(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Text(':  $value', style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}
