// box_details_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:psms/models/box_model.dart';

// Box Details Dialog - Professional redesign
class BoxDetailsDialog extends StatelessWidget {
  final BoxModel box;

  BoxDetailsDialog({super.key, required this.box});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700, // Fixed width
        height: MediaQuery.of(context).size.height *
            0.9, // Fixed height at 80% of screen
        constraints: BoxConstraints(
          minHeight: 600, // Minimum height
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getStatusColor(box.status),
                    _getStatusColor(box.status).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(box.status),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          box.boxNumber,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            box.statusDisplay,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description Card
                    _buildInfoCard(
                      icon: Icons.description,
                      title: 'Description',
                      children: [
                        Text(
                          box.description,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF2C3E50),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Client Information Card
                    _buildInfoCard(
                      icon: Icons.business,
                      title: 'Client Information',
                      children: [
                        _buildDetailRow('Client Code', box.client.clientCode),
                        Divider(height: 16),
                        _buildDetailRow('Client Name', box.client.clientName),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Box Details Card
                    _buildInfoCard(
                      icon: Icons.inventory_2,
                      title: 'Box Information',
                      children: [
                        _buildDetailRow(
                          'Date Received',
                          DateFormat('MMMM dd, yyyy').format(box.dateReceived),
                        ),
                        Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailRow(
                                'Year Received',
                                box.yearReceived.toString(),
                              ),
                            ),
                            Expanded(
                              child: _buildDetailRow(
                                'Retention',
                                '${box.retentionYears} years',
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 16),
                        _buildDetailRow(
                          'Destruction Year',
                          box.destructionYear?.toString() ?? 'N/A',
                        ),

                        // Pending destruction warning
                        if (box.isPendingDestruction) ...[
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: Colors.orange, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber,
                                    color: Colors.orange, size: 22),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pending Destruction',
                                        style: TextStyle(
                                          color: Colors.orange[900],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'This box is scheduled for destruction',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: 16),

                    // Location Card (if available)
                    if (box.rackingLabel != null)
                      _buildInfoCard(
                        icon: Icons.location_on,
                        title: 'Storage Location',
                        children: [
                          _buildDetailRow(
                              'Label Code', box.rackingLabel!.labelCode),
                          Divider(height: 16),
                          _buildDetailRow(
                              'Location', box.rackingLabel!.location),
                        ],
                      )
                    else
                      _buildInfoCard(
                        icon: Icons.location_off,
                        title: 'Storage Location',
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.grey[600], size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'No location assigned',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    SizedBox(height: 16),

                    // System Information Card
                    _buildInfoCard(
                      icon: Icons.info_outline,
                      title: 'System Information',
                      children: [
                        _buildDetailRow(
                          'Created',
                          DateFormat('MMM dd, yyyy - HH:mm')
                              .format(box.createdAt),
                        ),
                        Divider(height: 16),
                        _buildDetailRow(
                          'Last Updated',
                          DateFormat('MMM dd, yyyy - HH:mm')
                              .format(box.updatedAt),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // QR Code Card
                    _buildInfoCard(
                      icon: Icons.qr_code,
                      title: 'Quick Access',
                      children: [
                        Container(
                          alignment: Alignment.center,
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.qr_code_2,
                                  size: 60, color: Color(0xFF3498DB)),
                              SizedBox(height: 12),
                              Text(
                                'Scan QR code for quick access',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                box.boxNumber,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Print label functionality
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Color(0xFF3498DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.print, color: Color(0xFF3498DB)),
                      label: Text(
                        'Print Label',
                        style: TextStyle(color: Color(0xFF3498DB)),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to edit
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3498DB),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(Icons.edit, color: Colors.white),
                      label: Text(
                        'Edit Box',
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
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
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
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF3498DB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Color(0xFF3498DB), size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'stored':
        return Color(0xFF27AE60);
      case 'retrieved':
        return Color(0xFF3498DB);
      case 'destroyed':
        return Color(0xFFE74C3C);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'stored':
        return Icons.inventory_2;
      case 'retrieved':
        return Icons.assignment_return;
      case 'destroyed':
        return Icons.delete_forever;
      default:
        return Icons.help_outline;
    }
  }
}