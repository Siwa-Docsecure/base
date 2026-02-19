// lib/screens/retrievals_page.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/controllers/retrieval_controller.dart';
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
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _getStatusColor(retrieval.status).withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(retrieval.status).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: Colors.white,
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
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            retrieval.retrievalNumber,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(retrieval.status),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
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
                      Divider(color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 24),

                      // Retrieval Information
                      _buildSectionTitle('Retrieval Information'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Item Description', retrieval.itemDescription),
                      _buildInfoRow('Reason', retrieval.retrievalReason),
                      _buildInfoRow('Request Date', DateFormat('MMM dd, yyyy HH:mm').format(retrieval.requestDate)),
                      _buildInfoRow('Requested By', retrieval.requestedBy),
                      
                      if (retrieval.approvedBy != null)
                        _buildInfoRow('Approved By', retrieval.approvedBy!),
                      if (retrieval.approvalDate != null)
                        _buildInfoRow('Approval Date', DateFormat('MMM dd, yyyy HH:mm').format(retrieval.approvalDate!)),
                      if (retrieval.collectedBy != null)
                        _buildInfoRow('Collected By', retrieval.collectedBy!),
                      if (retrieval.collectionDate != null)
                        _buildInfoRow('Collection Date', DateFormat('MMM dd, yyyy HH:mm').format(retrieval.collectionDate!)),
                      if (retrieval.notes != null && retrieval.notes!.isNotEmpty)
                        _buildInfoRow('Notes', retrieval.notes!),
                      if (retrieval.rejectionReason != null && retrieval.rejectionReason!.isNotEmpty)
                        _buildInfoRow('Rejection Reason', retrieval.rejectionReason!, isError: true),

                      // Items
                      if (retrieval.items != null && retrieval.items!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Items'),
                        const SizedBox(height: 12),
                        ...retrieval.items!.map((item) => _buildItemCard(item)),
                      ],

                      // Documents
                      if (retrieval.documents != null && retrieval.documents!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Documents'),
                        const SizedBox(height: 12),
                        ...retrieval.documents!.map((doc) => _buildDocumentCard(doc)),
                      ],

                      // Signatures
                      if (retrieval.hasClientSignature || retrieval.hasStaffSignature) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Signatures'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (retrieval.hasClientSignature)
                              Expanded(child: _buildSignatureBox('Client Signature', true)),
                            if (retrieval.hasClientSignature && retrieval.hasStaffSignature)
                              const SizedBox(width: 16),
                            if (retrieval.hasStaffSignature)
                              Expanded(child: _buildSignatureBox('Staff Signature', true)),
                          ],
                        ),
                      ],

                      // Add signature option if no signatures
                      if (!retrieval.hasClientSignature && !retrieval.hasStaffSignature) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.white.withOpacity(0.2)),
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
                            backgroundColor: Colors.blue.withOpacity(0.7),
                          ),
                        ),
                      ],

                      // History
                      if (retrieval.history != null && retrieval.history!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Divider(color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 24),
                        _buildSectionTitle('History'),
                        const SizedBox(height: 12),
                        ...retrieval.history!.map((history) => _buildHistoryCard(history)),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (retrieval.pdfPath != null && retrieval.pdfPath!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () {
                          Get.snackbar(
                            'Download',
                            'PDF: ${retrieval.pdfPath}',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        },
                        icon: const Icon(Icons.download, color: Colors.white),
                        label: const Text('Download PDF', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.5)),
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
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                      ),
                      child: const Text('Close', style: TextStyle(color: Colors.white)),
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
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.draw, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Capture Signatures',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
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
                      'Client Signature',
                      clientSignatureController,
                    ),
                    const SizedBox(height: 24),
                    
                    // Staff Signature
                    _buildSignaturePad(
                      'Staff Signature',
                      staffSignatureController,
                    ),
                  ],
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        // Get signature data
                        final clientSignature = await clientSignatureController.toPngBytes();
                        final staffSignature = await staffSignatureController.toPngBytes();

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
                          clientSignatureBase64 = 'data:image/png;base64,${base64Encode(clientSignature)}';
                        }

                        if (staffSignature != null) {
                          staffSignatureBase64 = 'data:image/png;base64,${base64Encode(staffSignature)}';
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
                        backgroundColor: Colors.green.withOpacity(0.7),
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
                color: Colors.white,
              ),
            ),
            TextButton.icon(
              onPressed: () => controller.clear(),
              icon: const Icon(Icons.clear, size: 16, color: Colors.white),
              label: const Text('Clear', style: TextStyle(color: Colors.white)),
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
        color: Colors.white,
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
              color: Colors.white,
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
        backgroundColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Retrieval', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this retrieval?',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Retrieval: ${retrieval.retrievalNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Client: ${retrieval.clientName}',
                    style: const TextStyle(color: Colors.white),
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
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (retrieval.retrievalId != null) {
                final success = await controller.deleteRetrieval(retrieval.retrievalId!);
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
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? Colors.red : Colors.white,
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
          Icon(Icons.inventory_2, color: Colors.white.withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                ),
                Text(
                  '${item.itemCategory} • Qty: ${item.quantity}',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
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
          Icon(Icons.insert_drive_file, color: Colors.white.withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.documentName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                ),
                Text(
                  '${doc.documentType} • ${DateFormat('MMM dd, yyyy').format(doc.uploadedDate)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
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
              border: Border.all(color: _getActionColor(history.action).withOpacity(0.3)),
            ),
            child: Icon(_getActionIcon(history.action), color: _getActionColor(history.action), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  history.action.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'By: ${history.performedBy}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(history.timestamp),
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                ),
                if (history.comments != null && history.comments!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    history.comments!,
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white),
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
        color: _getStatusColor(status).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
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
        baseList = controller.retrievals.where((r) => r.status.toLowerCase() == 'approved').toList();
        break;
      case 'completed':
        baseList = controller.retrievals.where((r) => r.status.toLowerCase() == 'completed' || r.status.toLowerCase() == 'collected').toList();
        break;
      case 'rejected':
        baseList = controller.retrievals.where((r) => r.status.toLowerCase() == 'rejected').toList();
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
        backgroundColor: Colors.black.withOpacity(0.2),
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Retrievals',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Manage warehouse retrievals efficiently',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              _showFilterDialog();
            },
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
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
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search retrievals...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                prefixIcon: Icon(Icons.search, size: 20, color: Colors.white.withOpacity(0.7)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear, size: 20, color: Colors.white.withOpacity(0.7)),
                                        onPressed: () {
                                          setState(() {
                                            _searchController.clear();
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

                  Divider(height: 1, color: Colors.white.withOpacity(0.2)),

                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
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
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Date',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Boxes',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
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
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: Colors.white.withOpacity(0.2)),

                  // Retrievals List
                  Expanded(
                    child: Obx(() {
                      if (controller.isLoading.value) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
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
                                color: Colors.white.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No retrievals found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty || _selectedFilter != 'all'
                                    ? 'Try adjusting your filters'
                                    : 'Create a new retrieval to get started',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
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
                          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.white.withOpacity(0.1)),
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

  Widget _buildStatCard(String label, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
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
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
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
        backgroundColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Filter Retrievals', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All', style: TextStyle(color: Colors.white)),
              leading: Radio<String>(
                value: 'all',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.white,
              ),
            ),
            ListTile(
              title: const Text('Pending', style: TextStyle(color: Colors.white)),
              leading: Radio<String>(
                value: 'pending',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.white,
              ),
            ),
            ListTile(
              title: const Text('Approved', style: TextStyle(color: Colors.white)),
              leading: Radio<String>(
                value: 'approved',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.white,
              ),
            ),
            ListTile(
              title: const Text('Completed', style: TextStyle(color: Colors.white)),
              leading: Radio<String>(
                value: 'completed',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.white,
              ),
            ),
            ListTile(
              title: const Text('Rejected', style: TextStyle(color: Colors.white)),
              leading: Radio<String>(
                value: 'rejected',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.white,
              ),
            ),
            ListTile(
              title: const Text('Recent', style: TextStyle(color: Colors.white)),
              leading: Radio<String>(
                value: 'recent',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.white,
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
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Icon(
                      Icons.business,
                      size: 20,
                      color: Colors.white.withOpacity(0.7),
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
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          retrieval.itemDescription,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
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
                  color: Colors.white,
                ),
              ),
            ),

            // Boxes Count
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF52BE80).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF52BE80).withOpacity(0.3)),
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
                    icon: Icon(Icons.visibility_outlined, size: 20, color: Colors.white.withOpacity(0.7)),
                    onPressed: () => _showRetrievalDetails(retrieval),
                    tooltip: 'View',
                  ),
                  IconButton(
                    icon: Icon(Icons.draw, size: 20, color: Colors.white.withOpacity(0.7)),
                    onPressed: () => _showSignatureDialog(retrieval),
                    tooltip: 'Signatures',
                  ),
                  if (controller.canDeleteRetrievals)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
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
    final TextEditingController clientNameController = TextEditingController();
    final TextEditingController clientIdController = TextEditingController();
    final TextEditingController clientContactController = TextEditingController();
    final TextEditingController itemDescController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Retrieval Request',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 24),
                _buildDialogTextField(clientNameController, 'Client Name *'),
                const SizedBox(height: 16),
                _buildDialogTextField(clientIdController, 'Client ID Number *'),
                const SizedBox(height: 16),
                _buildDialogTextField(clientContactController, 'Client Contact *'),
                const SizedBox(height: 16),
                _buildDialogTextField(itemDescController, 'Item Description *', maxLines: 2),
                const SizedBox(height: 16),
                _buildDialogTextField(reasonController, 'Retrieval Reason *', maxLines: 2),
                const SizedBox(height: 16),
                _buildDialogTextField(notesController, 'Notes (Optional)', maxLines: 3),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (clientNameController.text.isEmpty ||
                            clientIdController.text.isEmpty ||
                            clientContactController.text.isEmpty ||
                            itemDescController.text.isEmpty ||
                            reasonController.text.isEmpty) {
                          Get.snackbar(
                            'Error',
                            'Please fill in all required fields',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        final request = CreateRetrievalRequest(
                          clientName: clientNameController.text,
                          clientIdNumber: clientIdController.text,
                          clientContact: clientContactController.text,
                          itemDescription: itemDescController.text,
                          retrievalReason: reasonController.text,
                          notes: notesController.text.isEmpty ? null : notesController.text,
                        );

                        final success = await controller.createRetrieval(request);
                        Navigator.pop(context);
                        if (success) {
                          _loadData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.7),
                      ),
                      child: const Text('Create Retrieval'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label, {int maxLines = 1}) {
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