// ─────────────────────────────────────────────────────────────────────────────
// BOX DETAIL DIALOG — professional tabbed layout
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:psms/constants/api_constants.dart'; // ADD THIS IMPORT
import 'package:psms/models/box_model.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF2C3E50);

class BoxDetailDialog extends StatefulWidget {
  final BoxModel box;
  final VoidCallback? onEdit;
  final void Function(String status) onStatusChange;

  const BoxDetailDialog({
    required this.box,
    this.onEdit,
    required this.onStatusChange,
  });

  @override
  State<BoxDetailDialog> createState() => BoxDetailDialogState();
}

class BoxDetailDialogState extends State<BoxDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: widget.box.boxImage != null && widget.box.boxImage!.isNotEmpty
            ? 3
            : 2,
        vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  BoxModel get box => widget.box;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(box.status);
    final hasImage = box.boxImage != null && box.boxImage!.isNotEmpty;

    return Container(
      width: 680,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF2C3E50), Color(0xFF3D5166)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status indicator orb
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: statusColor.withOpacity(0.5), width: 2),
                      ),
                      child: Icon(_statusIcon(box.status),
                          color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(box.boxNumber,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20)),
                          const SizedBox(height: 2),
                          Text(box.description,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _headerChip(
                                  box.client.clientCode, Icons.business),
                              const SizedBox(width: 8),
                              _headerChip(
                                  DateFormat('dd MMM yyyy')
                                      .format(box.dateReceived),
                                  Icons.calendar_today),
                              if (box.rackingLabel != null) ...[
                                const SizedBox(width: 8),
                                _headerChip(box.rackingLabel!.labelCode,
                                    Icons.location_on),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Actions
                    Row(
                      children: [
                        if (widget.onEdit != null)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Colors.white70),
                            onPressed: widget.onEdit,
                            tooltip: 'Edit',
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tab bar
                TabBar(
                  controller: _tabCtrl,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  indicatorColor: const Color(0xFF3498DB),
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  tabs: [
                    const Tab(text: 'Details'),
                    const Tab(text: 'QR Code'),
                    if (hasImage) const Tab(text: 'Image'),
                  ],
                ),
              ],
            ),
          ),

          // ── Tab content ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildDetailsTab(),
                _buildQrTab(),
                if (hasImage) _buildImageTab(),
              ],
            ),
          ),

          // ── Footer actions ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                // Status change buttons
                if (box.canBeRetrieved)
                  _footerBtn('Mark Retrieved', Icons.move_to_inbox, Colors.blue,
                      () => widget.onStatusChange('retrieved')),
                if (box.canBeStored)
                  _footerBtn('Mark Stored', Icons.storage, Colors.green,
                      () => widget.onStatusChange('stored')),
                if (box.canBeDestroyed)
                  _footerBtn('Mark Destroyed', Icons.delete_forever, Colors.red,
                      () => widget.onStatusChange('destroyed')),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white60),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('Client', [
            _detailRow('Client Code', box.client.clientCode),
            _detailRow('Client Name', box.client.clientName),
          ]),
          const SizedBox(height: 16),
          _section('Box Information', [
            _detailRow('Box Number', box.boxNumber),
            _detailRow('Description', box.description),
            _detailRow('Box Size', box.boxSize ?? 'A3'),
            _detailRow('Status', box.statusDisplay),
            _detailRow('Date Received',
                DateFormat('dd MMM yyyy').format(box.dateReceived)),
          ]),
          const SizedBox(height: 16),
          _section('Storage', [
            _detailRow(
                'Location', box.rackingLabel?.location ?? 'Not Assigned'),
            _detailRow('Rack Code', box.rackingLabel?.labelCode ?? '—'),
          ]),
          const SizedBox(height: 16),
          _section('Retention', [
            _detailRow('Data Years', box.dataYears ?? '—'),
            _detailRow('Date Range', box.dateRange ?? '—'),
            _detailRow(
                'Retention Years', box.retentionYears?.toString() ?? '—'),
            _detailRow(
                'Destruction Year', box.destructionYear?.toString() ?? '—'),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _kPrimary)),
          ),
          const Divider(height: 1),
          ...rows,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, color: _kPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildQrTab() {
    final payload = jsonEncode({
      'id': box.boxId,
      'number': box.boxNumber,
      'client': box.client.clientCode,
      'status': box.status,
      if (box.rackingLabel != null) 'rack': box.rackingLabel!.labelCode,
      if (box.destructionYear != null) 'destYear': box.destructionYear,
    });

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04), blurRadius: 10)
                ],
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(box.boxNumber,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _kPrimary)),
            Text(box.client.clientName,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Text(payload,
                style: const TextStyle(
                    fontSize: 9, color: Colors.grey, fontFamily: 'monospace'),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ========== MODIFIED IMAGE TAB ==========
  Widget _buildImageTab() {
    final imagePath = box.boxImage;
    print('DEBUG: Box image path from model: $imagePath'); // ADD THIS
    if (imagePath == null || imagePath.isEmpty) {
      print('DEBUG: No image path found');
      return const Center(
          child: Icon(Icons.broken_image, size: 80, color: Colors.grey));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildImageFromPath(imagePath),
        ),
      ),
    );
  }

  // Helper to get static base URL (without /api)
  String getStaticBaseUrl() {
    String base = ApiConstants.baseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    if (base.endsWith('/api/')) {
      return base.substring(0, base.length - 5);
    }
    return base;
  }

  Widget _buildImageFromPath(String imagePath) {
    String url;
    if (imagePath.startsWith('http')) {
      url = imagePath;
    } else {
      // Use static base URL (without /api)
      String baseUrl = getStaticBaseUrl();
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      String cleanPath =
          imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
      url = '$baseUrl/$cleanPath';
    }
    print('DEBUG: Full image URL: $url'); // Remove after debugging
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, size: 80, color: Colors.grey),
            const SizedBox(height: 8),
            Text('Failed to load image', style: TextStyle(color: Colors.grey)),
            Text('Path: $imagePath',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        );
      },
    );
  }

  Widget _footerBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 12)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
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
}
