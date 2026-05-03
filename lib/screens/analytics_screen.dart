/// Analytics Screen — spending insights, charts, and breakdowns.
///
/// Layout (scrollable):
///   1. Floating app bar
///   2. Period selector chips (Week / Month / Year)
///   3. Total spending summary card
///   4. Spending trend bar chart (custom-painted)
///   5. Category breakdown — donut chart + legend
///   6. Top categories ranked list with progress bars
///   7. Key insights row (highest day, avg/day, top category)
///
/// All charts are drawn with CustomPainter — no third-party chart library.
/// Uses sample data (will be replaced with SQLite queries).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/currency_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

class _DaySpend {
  final String label; // e.g. "Mon", "Tue" or "Jan", "Feb"
  final double amount;
  const _DaySpend(this.label, this.amount);
}

class _CategorySpend {
  final String name;
  final double amount;
  final Color color;
  const _CategorySpend(this.name, this.amount, this.color);
}

// ─── Period enum ─────────────────────────────────────────────────────────────

enum _Period { week, month, year }

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  _Period _period = _Period.month;
  bool _isLoading = true;

  List<_DaySpend> _trend = const [];
  List<_CategorySpend> _categories = const [];

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  void _onCurrencyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    CurrencyService.instance.addListener(_onCurrencyChanged);
    _loadData();
  }

  @override
  void dispose() {
    CurrencyService.instance.removeListener(_onCurrencyChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final (trend, categories) = await _fetchForPeriod(_period, now);

    if (!mounted) return;
    setState(() {
      _trend = trend;
      _categories = categories;
      _isLoading = false;
    });
  }

  void _setPeriod(_Period p) async {
    if (_period == p) return;
    setState(() {
      _period = p;
      _isLoading = true;
    });
    final now = DateTime.now();
    final (trend, categories) = await _fetchForPeriod(p, now);
    if (!mounted) return;
    setState(() {
      _trend = trend;
      _categories = categories;
      _isLoading = false;
    });
  }

  // ─── DB fetch helpers ──────────────────────────────────────────────────────

  static const _catColors = <String, Color>{
    'Groceries':       AppConstants.primaryGreen,
    'Food/Restaurant': Color(0xFFE65100),
    'Clothes':         Color(0xFF7B1FA2),
    'Medicine':        AppConstants.errorRed,
    'Hardware':        Color(0xFF455A64),
    'Cosmetics':       Color(0xFFD81B60),
    'Entertainment':   AppConstants.infoBlue,
    'Others':          AppConstants.textMediumGray,
  };

  Future<(List<_DaySpend>, List<_CategorySpend>)> _fetchForPeriod(
      _Period p, DateTime now) async {
    final db = DatabaseService.instance;

    // ── Trend bars ──────────────────────────────────────────────────────────
    List<_DaySpend> trend;
    switch (p) {
      case _Period.week:
        // Last 7 days, labelled Mon–Sun
        final from = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        final dailyMap = await db.getDailyTotals(from, now);
        trend = List.generate(7, (i) {
          final d = from.add(Duration(days: i));
          final key =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          return _DaySpend(DateFormat('E').format(d), dailyMap[key] ?? 0);
        });

      case _Period.month:
        // Current month grouped into 4 ISO weeks
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1)
            .subtract(const Duration(days: 1));
        final dailyMap = await db.getDailyTotals(monthStart, monthEnd);
        // Bucket into W1–W4(W5)
        final weeks = <String, double>{};
        for (final entry in dailyMap.entries) {
          final d = DateTime.parse(entry.key);
          final week = ((d.day - 1) ~/ 7) + 1;
          final key = 'W$week';
          weeks[key] = (weeks[key] ?? 0) + entry.value;
        }
        trend = weeks.entries
            .map((e) => _DaySpend(e.key, e.value))
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
        if (trend.isEmpty) trend = const [_DaySpend('W1', 0)];

      case _Period.year:
        // 12 months of the current year
        final futures = List.generate(12,
            (i) => db.getMonthlyTotal(now.year, i + 1));
        final totals = await Future.wait(futures);
        trend = List.generate(12, (i) {
          final label = DateFormat('MMM')
              .format(DateTime(now.year, i + 1));
          return _DaySpend(label, totals[i]);
        });
    }

    // ── Category breakdown (current period) ─────────────────────────────────
    Map<String, double> catTotals;
    switch (p) {
      case _Period.week:
        // Category breakdown uses current month as the best available proxy.
        catTotals = await db.getCategoryTotals(now.year, now.month);
      case _Period.month:
        catTotals = await db.getCategoryTotals(now.year, now.month);
      case _Period.year:
        final allMonths = await Future.wait(List.generate(
            12, (i) => db.getCategoryTotals(now.year, i + 1)));
        catTotals = {};
        for (final m in allMonths) {
          for (final e in m.entries) {
            catTotals[e.key] = (catTotals[e.key] ?? 0) + e.value;
          }
        }
    }

    final categories = catTotals.entries
        .where((e) => e.value > 0)
        .map((e) => _CategorySpend(
              e.key,
              e.value,
              _catColors[e.key] ?? AppConstants.textMediumGray,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return (trend, categories);
  }

  // ─── Computed helpers ──────────────────────────────────────────────────────

  double get _periodTotal => _trend.fold(0.0, (s, d) => s + d.amount);

  double get _avgPerBar =>
      _trend.isEmpty ? 0 : _periodTotal / _trend.length;

  _DaySpend? get _peakBar {
    if (_trend.isEmpty) return null;
    return _trend.reduce((a, b) => a.amount > b.amount ? a : b);
  }

  double get _categoryTotal =>
      _categories.fold(0.0, (s, c) => s + c.amount);

  String get _periodLabel {
    final now = DateTime.now();
    switch (_period) {
      case _Period.week:
        return 'This Week';
      case _Period.month:
        return DateFormat('MMMM yyyy').format(now);
      case _Period.year:
        return now.year.toString();
    }
  }

  String get _avgLabel {
    switch (_period) {
      case _Period.week:
        return 'Avg / Day';
      case _Period.month:
        return 'Avg / Week';
      case _Period.year:
        return 'Avg / Month';
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppConstants.primaryGreen,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppConstants.primaryGreen,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(child: _buildPeriodSelector()),
                    SliverToBoxAdapter(child: _buildSummaryCard()),
                    SliverToBoxAdapter(child: _buildTrendSection()),
                    SliverToBoxAdapter(child: _buildCategorySection()),
                    SliverToBoxAdapter(child: _buildTopCategoriesList()),
                    SliverToBoxAdapter(child: _buildInsightsRow()),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      elevation: 0,
      floating: true,
      snap: true,
      titleSpacing: AppConstants.paddingLarge,
      title: Text(
        'Analytics',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  // ─── Period selector ───────────────────────────────────────────────────────

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge,
        4,
        AppConstants.paddingLarge,
        AppConstants.paddingMedium,
      ),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: _Period.values.map((p) {
            final selected = _period == p;
            final label = switch (p) {
              _Period.week => 'Week',
              _Period.month => 'Month',
              _Period.year => 'Year',
            };
            return Expanded(
              child: GestureDetector(
                onTap: () => _setPeriod(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: selected ? AppConstants.primaryGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    // Compare second half vs first half of trend bars as a period-over-period proxy.
    final half = _trend.length ~/ 2;
    final firstHalf = half > 0
        ? _trend.sublist(0, half).fold(0.0, (s, d) => s + d.amount)
        : 0.0;
    final secondHalf = half > 0
        ? _trend.sublist(half).fold(0.0, (s, d) => s + d.amount)
        : 0.0;
    final pctChange = firstHalf > 0
        ? ((secondHalf - firstHalf) / firstHalf * 100)
        : 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge,
        0,
        AppConstants.paddingLarge,
        AppConstants.paddingMedium,
      ),
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppConstants.primaryGreen, AppConstants.darkGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryGreen.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _periodLabel,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyService.instance.format(_periodTotal),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      pctChange >= 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 14,
                      color: pctChange >= 0
                          ? Colors.white70
                          : AppConstants.lightGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${pctChange >= 0 ? '+' : ''}${pctChange.toStringAsFixed(1)}% vs last period',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusMedium),
            ),
            child: const Icon(
              Icons.insights_outlined,
              size: 28,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Trend bar chart section ────────────────────────────────────────────────

  Widget _buildTrendSection() {
    return _SectionCard(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge,
        0,
        AppConstants.paddingLarge,
        AppConstants.paddingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Spending Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                _avgLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                CurrencyService.instance.format(_avgPerBar, decimals: 0),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          SizedBox(
            height: 160,
            child: _SpendingBarChart(data: _trend),
          ),
        ],
      ),
    );
  }

  // ─── Category donut chart section ───────────────────────────────────────────

  Widget _buildCategorySection() {
    return _SectionCard(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge,
        0,
        AppConstants.paddingLarge,
        AppConstants.paddingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            children: [
              // Donut chart
              SizedBox(
                width: 130,
                height: 130,
                child: _DonutChart(
                  categories: _categories,
                  total: _categoryTotal,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _categories.take(5).map((c) {
                    final pct = _categoryTotal > 0
                        ? (c.amount / _categoryTotal * 100)
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: c.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Top categories list with progress bars ─────────────────────────────────

  Widget _buildTopCategoriesList() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    final sorted = [..._categories]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final maxAmount = sorted.first.amount;

    return _SectionCard(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge,
        0,
        AppConstants.paddingLarge,
        AppConstants.paddingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Categories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          ...sorted.map((c) {
            final fraction = maxAmount > 0 ? c.amount / maxAmount : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        CurrencyService.instance.format(c.amount),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      builder: (ctx, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor:
                            Colors.grey.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(c.color),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Key insights row ───────────────────────────────────────────────────────

  Widget _buildInsightsRow() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    final topCat = _categories.reduce((a, b) => a.amount > b.amount ? a : b);
    final peak = _peakBar;
    final txCount = _categories.length; // placeholder
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge,
        0,
        AppConstants.paddingLarge,
        AppConstants.paddingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InsightTile(
                  icon: Icons.arrow_upward_rounded,
                  iconColor: const Color(0xFFD81B60),
                  label: 'Peak Spend',
                  value: CurrencyService.instance.format(peak?.amount ?? 0, decimals: 0),
                  sub: peak?.label ?? '—',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InsightTile(
                  icon: Icons.category_outlined,
                  iconColor: AppConstants.infoBlue,
                  label: 'Top Category',
                  value: topCat.name,
                  sub: CurrencyService.instance.format(topCat.amount),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InsightTile(
                  icon: Icons.receipt_long_outlined,
                  iconColor: AppConstants.warningAmber,
                  label: 'Transactions',
                  value: '$txCount',
                  sub: _periodLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION CARD WRAPPER
// ═════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.margin});
  final Widget child;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// INSIGHT TILE
// ═════════════════════════════════════════════════════════════════════════════

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BAR CHART — CustomPainter
// ═════════════════════════════════════════════════════════════════════════════

class _SpendingBarChart extends StatefulWidget {
  const _SpendingBarChart({required this.data});
  final List<_DaySpend> data;

  @override
  State<_SpendingBarChart> createState() => _SpendingBarChartState();
}

class _SpendingBarChartState extends State<_SpendingBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_SpendingBarChart old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Bars + grid — no text drawn inside the canvas
        Expanded(
          child: AnimatedBuilder(
            animation: _anim,
            builder: (ctx, _) => CustomPaint(
              size: Size.infinite,
              painter: _BarChartPainter(
                data: widget.data,
                progress: _anim.value,
                barColor: AppConstants.primaryGreen,
                peakColor: AppConstants.lightGreen,
                gridColor: Colors.grey.withValues(alpha: 0.12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Labels rendered as Flutter Text widgets
        Row(
          children: widget.data.map((d) {
            return Expanded(
              child: Text(
                d.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.data,
    required this.progress,
    required this.barColor,
    required this.peakColor,
    required this.gridColor,
  });

  final List<_DaySpend> data;
  final double progress;
  final Color barColor;
  final Color peakColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double topPad = 8;
    final chartH = size.height - topPad;
    final maxVal = data.map((d) => d.amount).reduce(math.max);
    if (maxVal == 0) return;

    final barCount = data.length;
    final barW = (size.width / barCount) * 0.55;
    final gap = size.width / barCount;

    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartH * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Bars
    final peakIdx = data.indexWhere((d) => d.amount == maxVal);

    for (int i = 0; i < barCount; i++) {
      final fraction = data[i].amount / maxVal;
      final barH = chartH * fraction * progress;
      final cx = gap * i + gap / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barW / 2, topPad + chartH - barH, barW, barH),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color =
              (i == peakIdx ? peakColor : barColor).withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.progress != progress || old.data != data;
}

// ═════════════════════════════════════════════════════════════════════════════
// DONUT CHART — CustomPainter
// ═════════════════════════════════════════════════════════════════════════════

class _DonutChart extends StatefulWidget {
  const _DonutChart({required this.categories, required this.total});
  final List<_CategorySpend> categories;
  final double total;

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) => CustomPaint(
        painter: _DonutPainter(
          categories: widget.categories,
          total: widget.total,
          progress: _anim.value,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\$${widget.total.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              Text(
                'total',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(ctx).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.categories,
    required this.total,
    required this.progress,
  });

  final List<_CategorySpend> categories;
  final double total;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeW = 16.0;
    const gapAngle = 0.04; // radians between segments

    double startAngle = -math.pi / 2;
    final sweepTotal = 2 * math.pi * progress;

    for (final cat in categories) {
      final fraction = cat.amount / total;
      final sweep = sweepTotal * fraction - gapAngle;
      if (sweep <= 0) continue;

      final paint = Paint()
        ..color = cat.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );

      startAngle += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.total != total;
}
