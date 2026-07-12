// dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/dashboard_controller.dart';
import 'package:psms/models/dashboard_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _primary = Color(0xFF2C3E50);
const _accent = Color(0xFF3498DB);
const _accentLight = Color(0xFF5DADE2);
const _success = Color(0xFF27AE60);
const _warning = Color(0xFFE67E22);
const _danger = Color(0xFFE74C3C);
const _purple = Color(0xFF8E44AD);
const _teal = Color(0xFF16A085);
const _bgLight = Color(0xFFF4F6F9);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = Get.put(DashboardController());
  final _auth = Get.find<AuthController>();

  // Chart state
  int _touchedPieIndex = -1;
  int _touchedBarGroupIndex = -1;
  String _selectedSeries = 'collections';
  int _trendMonths = 12;
  int _dailyStatsDays = 30;
  int _chartTab = 0; // 0=trends, 1=clients, 2=boxes
  String _feedEntityFilter = '';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Fire everything in parallel — no sequential awaits
      await Future.wait([
        _ctrl.initialize(),
        _ctrl.getActivityFeed(limit: 25),
        _ctrl.getDailyStats(days: _dailyStatsDays),
        _ctrl.getMonthlyTrend(months: _trendMonths),
      ]);
      _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 1100;
    final isMid = w > 720;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          color: _accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isWide ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKpiStrip(isMid, isWide),
                const SizedBox(height: 20),
                _buildTodayActivityBar(),
                const SizedBox(height: 20),
                isWide ? _buildWideMiddle() : _buildNarrowMiddle(),
                const SizedBox(height: 20),
                isWide ? _buildWideBottom() : _buildNarrowBottom(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _ctrl.initialize(),
      _ctrl.getActivityFeed(
          limit: 25,
          entityType: _feedEntityFilter.isEmpty ? null : _feedEntityFilter),
      _ctrl.getDailyStats(days: _dailyStatsDays),
      _ctrl.getMonthlyTrend(months: _trendMonths),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_accent, _accentLight]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.dashboard_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dashboard',
                  style: TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
              Obx(() => Text(
                    'Welcome back, ${_auth.currentUser.value?.username ?? 'User'}',
                    style:
                        const TextStyle(color: Color(0xFF7F8C8D), fontSize: 11),
                  )),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _bgLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
            style: const TextStyle(
                fontSize: 12, color: _primary, fontWeight: FontWeight.w500),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _primary, size: 22),
          tooltip: 'Refresh all',
          onPressed: _refreshAll,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KPI STRIP — fixed-height cards to avoid overflow
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildKpiStrip(bool isMid, bool isWide) {
    return Obx(() {
      final ov = _ctrl.overview.value;
      final loading = _ctrl.isLoading.value && ov == null;
      final cols = isWide
          ? 6
          : isMid
              ? 3
              : 2;

      final kpis = [
        _KpiData('Total Boxes', ov?.boxes.total ?? 0,
            Icons.inventory_2_outlined, _accent, null),
        _KpiData('In Storage', ov?.boxes.stored ?? 0, Icons.storage_outlined,
            _success, null),
        _KpiData('Retrieved', ov?.boxes.retrieved ?? 0,
            Icons.move_to_inbox_outlined, _purple, null),
        _KpiData(
            'Pending Destr.',
            ov?.boxes.pendingDestruction ?? 0,
            Icons.warning_amber_outlined,
            _danger,
            ov?.boxes.pendingDestruction != null &&
                    ov!.boxes.pendingDestruction > 0
                ? 'Action'
                : null),
        _KpiData(
            'Pending Reqs.',
            ov?.activity.pendingRequests ?? 0,
            Icons.assignment_late_outlined,
            _warning,
            ov?.activity.pendingRequests != null &&
                    ov!.activity.pendingRequests > 0
                ? 'Review'
                : null),
        _KpiData('Clients', ov?.systemStats?.totalClients ?? 0,
            Icons.business_outlined, _teal, 'Active'),
      ];

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 110, // ← fixed height eliminates overflow
        ),
        itemCount: 6,
        itemBuilder: (_, i) => loading ? _kpiSkeleton() : _kpiCard(kpis[i]),
      );
    });
  }

  Widget _kpiCard(_KpiData d) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: d.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(d.icon, color: d.color, size: 16),
              ),
              if (d.badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: d.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(d.badge!,
                      style: TextStyle(
                          color: d.color,
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          // Use FittedBox so the number never overflows
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  NumberFormat('#,###').format(d.value),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: d.color,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                Text(
                  d.label,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiSkeleton() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _shimmer(34, 34, radius: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _shimmer(50, 24),
            const SizedBox(height: 5),
            _shimmer(90, 11),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TODAY ACTIVITY BAR — intrinsic height, no black gap
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTodayActivityBar() {
    return Obx(() {
      final act = _ctrl.overview.value?.activity;
      final items = [
        _ActivityItem('Collections Today', act?.collectionsToday ?? 0,
            Icons.local_shipping_outlined, _success),
        _ActivityItem('Retrievals Today', act?.retrievalsToday ?? 0,
            Icons.move_to_inbox_outlined, _purple),
        _ActivityItem('Deliveries Today', act?.deliveriesToday ?? 0,
            Icons.outbox_outlined, _warning),
        _ActivityItem('Pending Requests', act?.pendingRequests ?? 0,
            Icons.pending_actions_outlined, _danger),
      ];

      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: _primary.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Today',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                SizedBox(height: 2),
                Text('Activity',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
            Container(
                width: 1,
                height: 36,
                color: Colors.white12,
                margin: const EdgeInsets.symmetric(horizontal: 18)),
            Expanded(
              child: LayoutBuilder(builder: (_, constraints) {
                // On very narrow screens collapse to 2-per-row wrap
                if (constraints.maxWidth < 400) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: items.map(_activityItem).toList(),
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: items.map(_activityItem).toList(),
                );
              }),
            ),
          ],
        ),
      );
    });
  }

  Widget _activityItem(_ActivityItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: item.color.withOpacity(0.18), shape: BoxShape.circle),
          child: Icon(item.icon, color: item.color, size: 14),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${item.count}',
                style: TextStyle(
                    color: item.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 17)),
            Text(item.label,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAYOUTS
  // ─────────────────────────────────────────────────────────────────────────

  // Middle row: charts (wide) + users & clients panel
  Widget _buildWideMiddle() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildChartsSection()),
          if (_auth.currentUser.value?.role == 'admin') ...[
            const SizedBox(width: 20),
            SizedBox(width: 280, child: _buildUserBreakdownCard()),
          ],
        ],
      );

  Widget _buildNarrowMiddle() => Column(children: [
        _buildChartsSection(),
        const SizedBox(height: 20),
        _buildUserBreakdownCard(),
      ]);

  // Bottom row: activity feed + destruction timeline + daily snapshot
  Widget _buildWideBottom() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_auth.currentUser.value?.role == 'admin')
            SizedBox(width: 310, child: _buildActivityFeedCard()),
          const SizedBox(width: 20),
          Expanded(flex: 4, child: _buildDestructionCalendarCard()),
          const SizedBox(width: 20),
          Expanded(flex: 5, child: _buildDailyStatsCard()),
        ],
      );

  Widget _buildNarrowBottom() => Column(children: [
        if (_auth.currentUser.value?.role == 'admin') _buildActivityFeedCard(),
        const SizedBox(height: 20),
        _buildDestructionCalendarCard(),
        const SizedBox(height: 20),
        _buildDailyStatsCard(),
      ]);

  // ─────────────────────────────────────────────────────────────────────────
  // CHARTS SECTION
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildChartsSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: _accent, size: 20),
              const SizedBox(width: 10),
              const Text('Analytics',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _primary)),
              const Spacer(),
              _tabPill('Trends', 0),
              const SizedBox(width: 6),
              _tabPill('By Client', 1),
              const SizedBox(width: 6),
              _tabPill('Boxes', 2),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _chartTab == 0
                ? _buildTrendChart()
                : _chartTab == 1
                    ? _buildClientBarChart()
                    : _buildBoxPieChart(),
          ),
        ],
      ),
    );
  }

  Widget _tabPill(String label, int idx) {
    final sel = _chartTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _chartTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _accent : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
              color: sel ? Colors.white : Colors.grey[500],
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              fontSize: 12,
            )),
      ),
    );
  }

  // ── Trend line chart ──────────────────────────────────────────────────────

  Widget _buildTrendChart() {
    return Obx(() {
      final data = _ctrl.monthlyTrend;
      return Column(
        key: const ValueKey('trend'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _seriesToggle('Collections', 'collections', _success),
              const SizedBox(width: 12),
              _seriesToggle('Retrievals', 'retrievals', _purple),
              const SizedBox(width: 12),
              _seriesToggle('Deliveries', 'deliveries', _warning),
              const Spacer(),
              _monthsDropdown(),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: data.isEmpty
                ? _emptyChart(
                    'No trend data — generate some collections & retrievals first')
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval:
                                (data.length / 6).ceilToDouble().clamp(1, 999),
                            getTitlesWidget: (value, _) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= data.length)
                                return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                    data[idx].month.length >= 7
                                        ? data[idx].month.substring(5)
                                        : data[idx].month,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots
                              .map((s) => LineTooltipItem(
                                    '${_seriesLabel(s.barIndex)}: ${s.y.toInt()}',
                                    const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ))
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        _lineBarData(
                            data
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(),
                                    e.value.collections.toDouble()))
                                .toList(),
                            _success,
                            _selectedSeries == 'collections'),
                        _lineBarData(
                            data
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(),
                                    e.value.retrievals.toDouble()))
                                .toList(),
                            _purple,
                            _selectedSeries == 'retrievals'),
                        _lineBarData(
                            data
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(),
                                    e.value.deliveries.toDouble()))
                                .toList(),
                            _warning,
                            _selectedSeries == 'deliveries'),
                      ],
                    ),
                    duration: const Duration(milliseconds: 400),
                  ),
          ),
        ],
      );
    });
  }

  LineChartBarData _lineBarData(
          List<FlSpot> spots, Color color, bool highlighted) =>
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: highlighted ? color : color.withOpacity(0.2),
        barWidth: highlighted ? 2.5 : 1.5,
        isStrokeCapRound: true,
        dotData: FlDotData(show: highlighted),
        belowBarData:
            BarAreaData(show: highlighted, color: color.withOpacity(0.06)),
      );

  Widget _seriesToggle(String label, String value, Color color) {
    final sel = _selectedSeries == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedSeries = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: sel ? color : color.withOpacity(0.25),
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: sel ? _primary : Colors.grey[400],
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              )),
        ],
      ),
    );
  }

  Widget _monthsDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _trendMonths,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: _primary),
          items: [6, 12, 18, 24]
              .map((m) => DropdownMenuItem(value: m, child: Text('$m months')))
              .toList(),
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _trendMonths = v);
            await _ctrl.getMonthlyTrend(months: v);
          },
        ),
      ),
    );
  }

  String _seriesLabel(int i) =>
      ['Collections', 'Retrievals', 'Deliveries'].elementAtOrNull(i) ?? '';

  // ── Client bar chart ──────────────────────────────────────────────────────

  Widget _buildClientBarChart() {
    return Obx(() {
      final data = _ctrl.boxByStatus;
      return Column(
        key: const ValueKey('clients'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _legendDot(_success, 'Stored'),
            const SizedBox(width: 12),
            _legendDot(_purple, 'Retrieved'),
            const SizedBox(width: 12),
            _legendDot(_danger, 'Destroyed'),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: data.isEmpty
                ? _emptyChart('No client box data yet')
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: data
                              .map((c) => c.total.toDouble())
                              .fold(0.0, (a, b) => a > b ? a : b) *
                          1.25,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, gIdx, rod, rodIdx) {
                            final c = data[gIdx];
                            final labels = ['Stored', 'Retrieved', 'Destroyed'];
                            return BarTooltipItem(
                              '${c.clientCode}\n${labels[rodIdx]}: ${rod.toY.toInt()}',
                              const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            );
                          },
                        ),
                        touchCallback: (e, r) => setState(() =>
                            _touchedBarGroupIndex =
                                r?.spot?.touchedBarGroupIndex ?? -1),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            getTitlesWidget: (value, _) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= data.length)
                                return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(data[idx].clientCode,
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.grey)),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: data.asMap().entries.map((e) {
                        final touched = _touchedBarGroupIndex == e.key;
                        final c = e.value;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                                toY: c.stored.toDouble(),
                                color:
                                    _success.withOpacity(touched ? 1.0 : 0.75),
                                width: 7,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3))),
                            BarChartRodData(
                                toY: c.retrieved.toDouble(),
                                color:
                                    _purple.withOpacity(touched ? 1.0 : 0.75),
                                width: 7,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3))),
                            BarChartRodData(
                                toY: c.destroyed.toDouble(),
                                color:
                                    _danger.withOpacity(touched ? 1.0 : 0.75),
                                width: 7,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3))),
                          ],
                        );
                      }).toList(),
                    ),
                    duration: const Duration(milliseconds: 400),
                  ),
          ),
        ],
      );
    });
  }

  // ── Box status pie chart ──────────────────────────────────────────────────

  Widget _buildBoxPieChart() {
    return Obx(() {
      final boxes = _ctrl.overview.value?.boxes;
      if (boxes == null)
        return SizedBox(height: 240, child: _emptyChart('Loading…'));

      final sections = <_PieSection>[
        _PieSection('Stored', boxes.stored, _success),
        _PieSection('Retrieved', boxes.retrieved, _purple),
        _PieSection('Destroyed', boxes.destroyed, _danger),
        _PieSection('Pending', boxes.pendingDestruction, _warning),
      ].where((s) => s.value > 0).toList();

      if (sections.isEmpty)
        return SizedBox(height: 240, child: _emptyChart('No boxes yet'));

      final total = sections.fold(0, (s, e) => s + e.value);

      return SizedBox(
        key: const ValueKey('pie'),
        height: 240,
        child: Row(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (_, r) => setState(() =>
                            _touchedPieIndex =
                                r?.touchedSection?.touchedSectionIndex ?? -1),
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 52,
                      sections: sections.asMap().entries.map((e) {
                        final isTouched = _touchedPieIndex == e.key;
                        final pct =
                            total > 0 ? e.value.value / total * 100 : 0.0;
                        return PieChartSectionData(
                          color: e.value.color,
                          value: e.value.value.toDouble(),
                          title: '${pct.toStringAsFixed(0)}%',
                          radius: isTouched ? 66 : 54,
                          titleStyle: TextStyle(
                            fontSize: isTouched ? 13 : 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                    duration: const Duration(milliseconds: 300),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        NumberFormat('#,###').format(total),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _primary),
                      ),
                      const Text('Total',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections
                  .map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                    color: s.color,
                                    borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.label,
                                    style: const TextStyle(
                                        fontSize: 12, color: _primary)),
                                Text('${s.value}',
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: s.color,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE ACTIVITY FEED
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildActivityFeedCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_outlined, color: _accent, size: 20),
              const SizedBox(width: 10),
              const Text('Live Activity',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _primary)),
              const Spacer(),
              Obx(() => _ctrl.isActivityFeedLoading.value
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _accent))
                  : const SizedBox.shrink()),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _ctrl.getActivityFeed(
                    limit: 25,
                    entityType:
                        _feedEntityFilter.isEmpty ? null : _feedEntityFilter),
                child: const Icon(Icons.refresh, size: 16, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'All',
                'box',
                if (_auth.currentUser.value?.role == 'admin') 'user',
                'collection',
                'retrieval',
                'delivery',
                if (_auth.currentUser.value?.role == 'admin') 'auth',
              ].map((t) {
                final sel = (t == 'All' && _feedEntityFilter.isEmpty) ||
                    _feedEntityFilter == t;
                return GestureDetector(
                  onTap: () async {
                    setState(() => _feedEntityFilter = t == 'All' ? '' : t);
                    await _ctrl.getActivityFeed(
                      limit: 25,
                      entityType: t == 'All' ? null : t,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? _accent : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t == 'All' ? 'All' : (t.capitalizeFirst ?? t),
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.grey[600],
                        fontSize: 11,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final events = _ctrl.activityFeed;
            if (_ctrl.isActivityFeedLoading.value && events.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: _accent)),
              );
            }
            if (events.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: Text('No recent activity',
                        style: TextStyle(color: Colors.grey))),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length.clamp(0, 20),
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (_, i) => _feedEventTile(events[i]),
            );
          }),
        ],
      ),
    );
  }

  Widget _feedEventTile(ActivityFeedEvent e) {
    final color = _actionColor(e.action);
    final icon = _actionIcon(e.action);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        e.action.replaceAll('_', ' '),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(e.entityType,
                          style: TextStyle(color: color, fontSize: 9)),
                    ),
                  ],
                ),
                Text(
                  '${e.user?.username ?? 'System'}  ·  ${_relTime(e.timestamp)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESTRUCTION CALENDAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDestructionCalendarCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_off_outlined, color: _danger, size: 20),
              const SizedBox(width: 10),
              const Text('Destruction Timeline',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _primary)),
              const Spacer(),
              Obx(() {
                final overdue = _ctrl.destructionCalendar
                    .where((e) => e.isOverdue)
                    .fold(0, (sum, e) => sum + e.overdueCount);
                return overdue == 0
                    ? const SizedBox.shrink()
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: _danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('$overdue overdue',
                            style: const TextStyle(
                                color: _danger,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      );
              }),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            final calendar = _ctrl.destructionCalendar;
            if (calendar.isEmpty)
              return _emptyChart('No scheduled destructions');
            final maxCount = calendar
                .map((e) => e.boxCount)
                .fold(1, (a, b) => a > b ? a : b);
            return Column(
              children: calendar.map((entry) {
                final color = entry.isOverdue
                    ? _danger
                    : entry.destructionYear == DateTime.now().year
                        ? _warning
                        : _success;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 46,
                        child: Text('${entry.destructionYear}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                                height: 22,
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4))),
                            FractionallySizedBox(
                              widthFactor:
                                  (entry.boxCount / maxCount).clamp(0.0, 1.0),
                              child: Container(
                                  height: 22,
                                  decoration: BoxDecoration(
                                      color: color.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(4))),
                            ),
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${entry.boxCount} boxes${entry.isOverdue && entry.overdueCount > 0 ? '  (${entry.overdueCount} overdue)' : ''}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                          width: 16,
                          child: entry.isOverdue
                              ? const Icon(Icons.warning_amber,
                                  color: _danger, size: 14)
                              : const SizedBox.shrink()),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER BREAKDOWN
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildUserBreakdownCard() {
    return _card(
      child: Obx(() {
        final sys = _ctrl.overview.value?.systemStats;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.people_outline, color: _teal, size: 20),
              SizedBox(width: 10),
              Text('Users & Clients',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _primary)),
            ]),
            const SizedBox(height: 16),
            if (sys == null)
              const Center(
                  child: Text('Admin role required to view system stats',
                      style: TextStyle(color: Colors.grey, fontSize: 12)))
            else ...[
              _statRow('Active Clients', sys.totalClients, _teal),
              const SizedBox(height: 10),
              _statRow('Total Users', sys.totalUsers, _accent),
              const SizedBox(height: 18),
              const Text('By Role',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              _roleBar('Admin', sys.usersByRole.admin, sys.totalUsers, _danger),
              const SizedBox(height: 8),
              _roleBar('Staff', sys.usersByRole.staff, sys.totalUsers, _accent),
              const SizedBox(height: 8),
              _roleBar(
                  'Client', sys.usersByRole.client, sys.totalUsers, _success),
            ],
          ],
        );
      }),
    );
  }

  Widget _statRow(String label, int value, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _primary)),
          Text('$value',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        ],
      );

  Widget _roleBar(String label, int value, int total, Color color) {
    final pct = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _primary)),
          Text('$value',
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: Colors.grey.shade100,
            color: color,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DAILY STATS CHART
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDailyStatsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: _accent, size: 20),
              const SizedBox(width: 10),
              const Text('Daily Snapshot',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _primary)),
              const Spacer(),
              _daysDropdown(),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            _legendDot(_success, 'Collections'),
            const SizedBox(width: 10),
            _legendDot(_purple, 'Retrievals'),
            const SizedBox(width: 10),
            _legendDot(_warning, 'Deliveries'),
          ]),
          const SizedBox(height: 12),
          Obx(() {
            final snaps = _ctrl.dailySnapshots;
            if (snaps.isEmpty) return _emptyChart('No daily snapshot data');
            final allVals = snaps.expand((s) =>
                [s.collectionsCount, s.retrievalsCount, s.deliveriesCount]);
            final maxVal = allVals.fold(0, (a, b) => a > b ? a : b);

            return SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval:
                            (snaps.length / 5).ceilToDouble().clamp(1, 999),
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= snaps.length)
                            return const SizedBox.shrink();
                          final d = snaps[idx].statDate;
                          return Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(d.length >= 10 ? d.substring(8) : d,
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.grey)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                            style: const TextStyle(
                                fontSize: 9, color: Colors.grey)),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxVal > 0 ? maxVal * 1.3 : 10,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final labels = [
                          'Collections',
                          'Retrievals',
                          'Deliveries'
                        ];
                        return LineTooltipItem(
                          '${labels.elementAtOrNull(s.barIndex) ?? ''}: ${s.y.toInt()}',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    _lineBarData(
                        snaps
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(),
                                e.value.collectionsCount.toDouble()))
                            .toList(),
                        _success,
                        true),
                    _lineBarData(
                        snaps
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(),
                                e.value.retrievalsCount.toDouble()))
                            .toList(),
                        _purple,
                        true),
                    _lineBarData(
                        snaps
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(),
                                e.value.deliveriesCount.toDouble()))
                            .toList(),
                        _warning,
                        true),
                  ],
                ),
                duration: const Duration(milliseconds: 400),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _daysDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _dailyStatsDays,
            isDense: true,
            style: const TextStyle(fontSize: 12, color: _primary),
            items: [7, 14, 30, 60, 90]
                .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
                .toList(),
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _dailyStatsDays = v);
              await _ctrl.getDailyStats(days: v);
            },
          ),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // QUICK ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Obx(() {
      final perms = _ctrl.permissions.value;
      if (perms == null) return const SizedBox.shrink();

      final actions = [
        if (perms.canCreateBoxes)
          _QuickAction(
              'New Box', Icons.add_box_outlined, _accent, '/boxes/create'),
        if (perms.canCreateCollections)
          _QuickAction('Collection', Icons.local_shipping_outlined, _success,
              '/collections/create'),
        if (perms.canCreateRetrievals)
          _QuickAction('Retrieval', Icons.move_to_inbox_outlined, _purple,
              '/retrievals/create'),
        if (perms.canCreateDeliveries)
          _QuickAction('Delivery', Icons.outbox_outlined, _warning,
              '/deliveries/create'),
        if (perms.canViewReports)
          _QuickAction('Reports', Icons.assessment_outlined, _teal, '/reports'),
        if (perms.canManageUsers)
          _QuickAction(
              'Users', Icons.manage_accounts_outlined, _primary, '/users'),
      ];

      if (actions.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _primary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: actions
                .map((a) => InkWell(
                      onTap: () => Get.toNamed(a.route),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: a.color.withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6)
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(a.icon, color: a.color, size: 15),
                            const SizedBox(width: 7),
                            Text(a.label,
                                style: TextStyle(
                                    color: a.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
      );

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );

  Widget _emptyChart(String msg) => SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_outlined, size: 36, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text(msg,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _shimmer(double w, double h, {double radius = 6}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(radius)),
      );

  Color _actionColor(String a) {
    if (a.contains('CREATE')) return _success;
    if (a.contains('UPDATE') || a.contains('CHANGE')) return _accent;
    if (a.contains('DELETE') || a.contains('DESTROY')) return _danger;
    if (a.contains('LOGIN') || a.contains('LOGOUT')) return _teal;
    if (a.contains('GENERATE') || a.contains('REPORT')) return _purple;
    return Colors.grey;
  }

  IconData _actionIcon(String a) {
    if (a.contains('LOGIN')) return Icons.login_outlined;
    if (a.contains('LOGOUT')) return Icons.logout_outlined;
    if (a.contains('CREATE')) return Icons.add_circle_outline;
    if (a.contains('UPDATE')) return Icons.edit_outlined;
    if (a.contains('DELETE')) return Icons.delete_outline;
    if (a.contains('DESTROY')) return Icons.delete_forever_outlined;
    if (a.contains('GENERATE')) return Icons.assessment_outlined;
    return Icons.circle_outlined;
  }

  String _relTime(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return ts;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _KpiData {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String? badge;
  const _KpiData(this.label, this.value, this.icon, this.color, this.badge);
}

class _ActivityItem {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _ActivityItem(this.label, this.count, this.icon, this.color);
}

class _PieSection {
  final String label;
  final int value;
  final Color color;
  const _PieSection(this.label, this.value, this.color);
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _QuickAction(this.label, this.icon, this.color, this.route);
}