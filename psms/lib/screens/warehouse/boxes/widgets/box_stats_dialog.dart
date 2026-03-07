// box_stats_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/controllers/box_controller.dart';
import 'package:psms/models/box_model.dart';

class BoxStatsDialog extends StatefulWidget {
  const BoxStatsDialog({super.key});

  @override
  State<BoxStatsDialog> createState() => _BoxStatsDialogState();
}

class _BoxStatsDialogState extends State<BoxStatsDialog> {
  final BoxController _boxController = Get.find<BoxController>();
  BoxStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Load stats after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final stats = await _boxController.getBoxStatistics();
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Color(0xFF3498DB)),
                const SizedBox(width: 10),
                const Text(
                  'Box Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadStats,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Content
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_stats == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 10),
                    const Text(
                      'Failed to load statistics',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _boxController.errorMessage.value.isNotEmpty
                          ? _boxController.errorMessage.value
                          : 'Unknown error',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _loadStats,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  _buildStatCard(
                    icon: Icons.inbox,
                    label: 'Total Boxes',
                    value: _stats!.totalBoxes,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  _buildStatCard(
                    icon: Icons.storage,
                    label: 'Stored',
                    value: _stats!.boxesStored,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _buildStatCard(
                    icon: Icons.move_to_inbox,
                    label: 'Retrieved',
                    value: _stats!.boxesRetrieved,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _buildStatCard(
                    icon: Icons.delete_forever,
                    label: 'Destroyed',
                    value: _stats!.boxesDestroyed,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 8),
                  _buildStatCard(
                    icon: Icons.warning,
                    label: 'Pending Destruction',
                    value: _stats!.boxesPendingDestruction,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 8),
                  _buildStatCard(
                    icon: Icons.business,
                    label: 'Clients with Boxes',
                    value: _stats!.totalClientsWithBoxes,
                    color: Colors.purple,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
