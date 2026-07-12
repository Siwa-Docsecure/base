// box_stats_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/controllers/box_controller.dart';
import 'package:psms/models/box_model.dart';

const _kAccent  = Color(0xFF3498DB);
const _kPrimary = Color(0xFF2C3E50);

class BoxStatsDialog extends StatefulWidget {
  const BoxStatsDialog({super.key});

  @override
  State<BoxStatsDialog> createState() => _BoxStatsDialogState();
}

class _BoxStatsDialogState extends State<BoxStatsDialog>
    with SingleTickerProviderStateMixin {
  final BoxController _ctrl = Get.find<BoxController>();
  BoxStats? _stats;
  bool _loading = true;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _animCtrl.reset();
    final s = await _ctrl.getBoxStatistics();
    setState(() {
      _stats   = s;
      _loading = false;
    });
    _animCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * 0.85),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(child: _buildBody()),
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
        gradient: LinearGradient(
            colors: [_kPrimary, Color(0xFF3D5166)]),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.bar_chart_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Box Statistics',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17)),
                Text('Live snapshot from the database',
                    style: TextStyle(
                        color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white70, size: 20),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            icon: const Icon(Icons.close,
                color: Colors.white60, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _kAccent),
              SizedBox(height: 14),
              Text('Loading statistics…',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_stats == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Failed to load statistics',
                style:
                    TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 6),
            Text(
              _ctrl.errorMessage.value.isNotEmpty
                  ? _ctrl.errorMessage.value
                  : 'Check your connection and try again',
              style: const TextStyle(
                  color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16,
                  color: Colors.white),
              label: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent, elevation: 0),
            ),
          ],
        ),
      );
    }

    final s      = _stats!;
    final total  = s.totalBoxes > 0 ? s.totalBoxes : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Hero total
          _buildHero(s),
          const SizedBox(height: 16),
          // Status breakdown
          _sectionLabel('By Status'),
          const SizedBox(height: 8),
          _buildProgressCard(
            icon: Icons.storage_outlined,
            label: 'In Storage',
            value: s.boxesStored,
            total: total,
            color: const Color(0xFF27AE60),
          ),
          const SizedBox(height: 8),
          _buildProgressCard(
            icon: Icons.move_to_inbox_outlined,
            label: 'Retrieved',
            value: s.boxesRetrieved,
            total: total,
            color: _kAccent,
          ),
          const SizedBox(height: 8),
          _buildProgressCard(
            icon: Icons.delete_forever_outlined,
            label: 'Destroyed',
            value: s.boxesDestroyed,
            total: total,
            color: const Color(0xFFE74C3C),
          ),
          const SizedBox(height: 16),
          // Attention items
          _sectionLabel('Attention Required'),
          const SizedBox(height: 8),
          _buildAlertCard(
            icon: Icons.warning_amber_outlined,
            label: 'Pending Destruction',
            value: s.boxesPendingDestruction,
            color: const Color(0xFFE67E22),
            description:
                'Boxes that have passed their destruction date',
          ),
          const SizedBox(height: 8),
          _buildAlertCard(
            icon: Icons.business_outlined,
            label: 'Clients with Boxes',
            value: s.totalClientsWithBoxes,
            color: const Color(0xFF8E44AD),
            description: 'Active clients currently storing boxes',
          ),
          const SizedBox(height: 8),
          // Timestamp
          Center(
            child: Text(
              'Last refreshed: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ─────────────────────────────────────────────────────────────────

  Widget _buildHero(BoxStats s) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (_, __) => Transform.scale(
        scale: 0.85 + 0.15 * _animCtrl.value,
        child: Opacity(
          opacity: _animCtrl.value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kAccent, Color(0xFF5DADE2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: _kAccent.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Boxes',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(s.totalBoxes.toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 40,
                            height: 1)),
                    const SizedBox(height: 2),
                    Text(
                        'Across ${s.totalClientsWithBoxes} client(s)',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.8)),
    );
  }

  Widget _buildProgressCard({
    required IconData icon,
    required String label,
    required int value,
    required int total,
    required Color color,
  }) {
    final pct = (value / total).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _kPrimary)),
                      Text(value.toString(),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: color)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct * _animCtrl.value,
                      minHeight: 6,
                      backgroundColor: color.withOpacity(0.1),
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(pct * 100).toStringAsFixed(1)}% of total',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kPrimary)),
                Text(description,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text(value.toString(),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}