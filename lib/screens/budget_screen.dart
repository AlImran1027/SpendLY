/// Budget Screen — monthly budget management per category.
///
/// Layout (scrollable):
///   1. Floating app bar with month navigation + back arrow when pushed
///   2. Overall budget summary card (total budget / spent / remaining)
///   3. Health summary chips (On Track / Warning / Over Budget counts)
///   4. Per-category budget cards (progress bar, spent vs budget, edit action)
///   5. Unbudgeted categories section (tap "Set Budget" on any row)
///   6. Empty state when no budgets are set yet
///
/// Features:
///   - Pull-to-refresh
///   - Previous / next month navigation (future months locked)
///   - Edit card pencil → sheet to update amount
///   - "+ Add" button → sheet to pick any unbudgeted category + set amount
///   - "Set Budget" on unbudgeted row → same add sheet pre-selected
///   - Color-coded progress: green <80% · amber 80–100% · red >100%
///   - Uses sample data (will be replaced with SQLite queries)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/currency_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class _CategoryBudget {
  final String category;
  double budget; // 0 means unbudgeted
  final double spent;

  _CategoryBudget({
    required this.category,
    required this.budget,
    required this.spent,
  });

  double get remaining => budget - spent;
  double get fraction =>
      budget > 0 ? (spent / budget).clamp(0.0, double.infinity) : 0.0;
  bool get isOverBudget => spent > budget && budget > 0;
  bool get isWarning =>
      fraction >= AppConstants.budgetWarningThreshold && !isOverBudget;
  bool get isOnTrack => budget > 0 && !isOverBudget && !isWarning;
  bool get isUnbudgeted => budget == 0;

  Color get progressColor {
    if (isOverBudget) return AppConstants.errorRed;
    if (isWarning) return AppConstants.warningAmber;
    return AppConstants.primaryGreen;
  }

  IconData get icon {
    switch (category) {
      case 'Groceries':       return Icons.shopping_cart_outlined;
      case 'Food/Restaurant': return Icons.restaurant_outlined;
      case 'Medicine':        return Icons.medical_services_outlined;
      case 'Clothes':         return Icons.checkroom_outlined;
      case 'Hardware':        return Icons.hardware_outlined;
      case 'Cosmetics':       return Icons.face_outlined;
      case 'Entertainment':   return Icons.movie_outlined;
      default:                return Icons.receipt_outlined;
    }
  }

  Color get iconColor {
    switch (category) {
      case 'Groceries':       return AppConstants.primaryGreen;
      case 'Food/Restaurant': return const Color(0xFFE65100);
      case 'Medicine':        return AppConstants.errorRed;
      case 'Clothes':         return const Color(0xFF7B1FA2);
      case 'Hardware':        return const Color(0xFF455A64);
      case 'Cosmetics':       return const Color(0xFFD81B60);
      case 'Entertainment':   return AppConstants.infoBlue;
      default:                return AppConstants.textMediumGray;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _isLoading = true;
  late DateTime _month;
  late List<_CategoryBudget> _budgets;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  void _onCurrencyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    CurrencyService.instance.addListener(_onCurrencyChanged);
    _month = DateTime(DateTime.now().year, DateTime.now().month);
    _budgets = [];
    _loadData();
  }

  @override
  void dispose() {
    CurrencyService.instance.removeListener(_onCurrencyChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final categorySpendingFuture =
        DatabaseService.instance.getCategoryTotals(_month.year, _month.month);
    final savedBudgetsFuture =
        DatabaseService.instance.getBudgets(_month.year, _month.month);

    final categorySpending = await categorySpendingFuture;
    final savedBudgets = await savedBudgetsFuture;

    if (!mounted) return;

    final allCategories = {
      ...AppConstants.expenseCategories,
      ...categorySpending.keys,
    };

    final updated = allCategories.map((cat) {
      return _CategoryBudget(
        category: cat,
        budget: savedBudgets[cat] ?? 0,
        spent: categorySpending[cat] ?? 0,
      );
    }).toList();

    setState(() {
      _budgets = updated;
      _isLoading = false;
    });
  }

  // ─── Month navigation ──────────────────────────────────────────────────────

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _previousMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _loadData();
  }

  void _nextMonth() {
    if (_isCurrentMonth) return;
    setState(() => _month = DateTime(_month.year, _month.month + 1));
    _loadData();
  }

  // ─── Computed totals ───────────────────────────────────────────────────────

  List<_CategoryBudget> get _budgeted =>
      _budgets.where((b) => !b.isUnbudgeted).toList();

  List<_CategoryBudget> get _unbudgeted =>
      _budgets.where((b) => b.isUnbudgeted).toList();

  double get _totalBudget => _budgeted.fold(0.0, (s, b) => s + b.budget);
  double get _totalSpent  => _budgeted.fold(0.0, (s, b) => s + b.spent);
  double get _totalRemaining => _totalBudget - _totalSpent;

  double get _overallFraction =>
      _totalBudget > 0 ? (_totalSpent / _totalBudget).clamp(0.0, 1.0) : 0.0;

  int get _onTrackCount => _budgeted.where((b) => b.isOnTrack).length;
  int get _warningCount => _budgeted.where((b) => b.isWarning).length;
  int get _overCount    => _budgeted.where((b) => b.isOverBudget).length;

  // ─── Build ─────────────────────────────────────────────────────────────────

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
                    SliverToBoxAdapter(child: _buildSummaryCard()),
                    SliverToBoxAdapter(child: _buildHealthChips()),
                    SliverToBoxAdapter(child: _buildBudgetedSection()),
                    if (_unbudgeted.any(
                      (b) => b.category != 'Others' || b.spent > 0,
                    ))
                      SliverToBoxAdapter(child: _buildUnbudgetedSection()),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    final canPop = Navigator.of(context).canPop();
    return SliverAppBar(
      elevation: 0,
      floating: true,
      snap: true,
      automaticallyImplyLeading: false,
      titleSpacing: canPop ? 0 : AppConstants.paddingLarge,
      leading: canPop
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new,
                  size: 20, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Text(
        'Budget',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppConstants.paddingMedium),
          child: _MonthNavigator(
            month: _month,
            isCurrentMonth: _isCurrentMonth,
            onPrevious: _previousMonth,
            onNext: _nextMonth,
          ),
        ),
      ],
    );
  }

  // ─── Overall summary card ──────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final overallColor = _overallFraction >= 1.0
        ? AppConstants.errorRed
        : _overallFraction >= AppConstants.budgetWarningThreshold
            ? AppConstants.warningAmber
            : AppConstants.lightGreen;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge, 4,
        AppConstants.paddingLarge, AppConstants.paddingMedium,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_month),
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadiusMedium),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Spent amount
          const Text('Spent',
              style: TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 4),
          Text(
            CurrencyService.instance.format(_totalSpent),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          // Budget + Left pills on the same row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${CurrencyService.instance.format(_totalBudget, decimals: 0)} budget',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _totalRemaining >= 0
                      ? '${CurrencyService.instance.format(_totalRemaining, decimals: 0)} left'
                      : '${CurrencyService.instance.format(-_totalRemaining, decimals: 0)} over',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _totalRemaining >= 0
                        ? Colors.white
                        : AppConstants.warningAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Overall',
                      style: TextStyle(fontSize: 11, color: Colors.white54)),
                  Text(
                    '${(_overallFraction * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _overallFraction),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (ctx, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(overallColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Health chips ──────────────────────────────────────────────────────────

  Widget _buildHealthChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge, 0,
        AppConstants.paddingLarge, AppConstants.paddingMedium,
      ),
      child: Row(
        children: [
          Expanded(
            child: _HealthChip(
              icon: Icons.check_circle_outline,
              color: AppConstants.primaryGreen,
              label: 'On Track',
              count: _onTrackCount,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HealthChip(
              icon: Icons.warning_amber_outlined,
              color: AppConstants.warningAmber,
              label: 'Warning',
              count: _warningCount,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HealthChip(
              icon: Icons.error_outline,
              color: AppConstants.errorRed,
              label: 'Over Budget',
              count: _overCount,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Budgeted categories ───────────────────────────────────────────────────

  Widget _buildBudgetedSection() {
    if (_budgeted.isEmpty) return _buildEmptyState();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge, 0,
        AppConstants.paddingLarge, AppConstants.paddingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your Budgets',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showAddBudgetSheet,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: AppConstants.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._budgeted.map((b) => _BudgetCategoryCard(budget: b)),
        ],
      ),
    );
  }

  // ─── Unbudgeted categories ─────────────────────────────────────────────────

  Widget _buildUnbudgetedSection() {
    final visible = _unbudgeted
        .where((b) => b.category != 'Others' || b.spent > 0)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge, 0,
        AppConstants.paddingLarge, AppConstants.paddingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No Budget Set',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'These categories have spending but no budget.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          ...visible.map(
            (b) => _UnbudgetedCard(
              budget: b,
              onSetBudget: () => _showAddBudgetSheet(preselected: b),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppConstants.lightGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 42,
                color: AppConstants.lightGreen,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Text(
              'No Budgets Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Set category budgets to track your\nspending and stay on target.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            ElevatedButton.icon(
              onPressed: _showAddBudgetSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Set Your First Budget'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadiusMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom sheets ─────────────────────────────────────────────────────────

  /// Opens the "add budget" sheet.
  /// [preselected] pre-picks a category (used from the unbudgeted rows).
  void _showAddBudgetSheet({_CategoryBudget? preselected}) {
    final unset = _budgets.where((b) => b.isUnbudgeted).toList();
    if (unset.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All categories already have a budget.'),
          backgroundColor: AppConstants.primaryGreen,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddBudgetSheet(
        unbudgeted: unset,
        preselected: preselected ?? unset.first,
        onSave: (category, amount) async {
          await DatabaseService.instance.upsertBudget(
              category.category, _month.year, _month.month, amount);
          if (mounted) setState(() => category.budget = amount);
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MONTH NAVIGATOR
// ═════════════════════════════════════════════════════════════════════════════

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.isCurrentMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool isCurrentMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            color: Theme.of(context).colorScheme.onSurface,
            visualDensity: VisualDensity.compact,
            onPressed: onPrevious,
          ),
          Text(
            DateFormat('MMM yyyy').format(month),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              size: 20,
              color: isCurrentMonth
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.onSurface,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: isCurrentMonth ? null : onNext,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HEALTH CHIP
// ═════════════════════════════════════════════════════════════════════════════

class _HealthChip extends StatelessWidget {
  const _HealthChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BUDGET CATEGORY CARD
// ═════════════════════════════════════════════════════════════════════════════

class _BudgetCategoryCard extends StatelessWidget {
  const _BudgetCategoryCard({required this.budget});

  final _CategoryBudget budget;

  @override
  Widget build(BuildContext context) {
    final color = budget.progressColor;
    final fraction = budget.fraction.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: budget.isOverBudget
            ? Border.all(
                color: AppConstants.errorRed.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        children: [
          // Top row: icon + name + status + edit button
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: budget.iconColor.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadiusMedium),
                ),
                child: Icon(budget.icon, size: 20, color: budget.iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.category,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _StatusBadge(budget: budget),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (ctx, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: Colors.grey.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Spent / budget / remaining row
          Row(
            children: [
              Text(
                '${CurrencyService.instance.format(budget.spent)} spent',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                'of ${CurrencyService.instance.format(budget.budget, decimals: 0)}',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              Text(
                budget.isOverBudget
                    ? '${CurrencyService.instance.format(-budget.remaining)} over'
                    : '${CurrencyService.instance.format(budget.remaining)} left',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
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
// STATUS BADGE
// ═════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.budget});
  final _CategoryBudget budget;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;

    if (budget.isOverBudget) {
      color = AppConstants.errorRed;
      label = 'Over Budget';
      icon = Icons.error_outline;
    } else if (budget.isWarning) {
      color = AppConstants.warningAmber;
      label = 'Near Limit';
      icon = Icons.warning_amber_outlined;
    } else {
      color = AppConstants.primaryGreen;
      label = 'On Track';
      icon = Icons.check_circle_outline;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// UNBUDGETED CATEGORY CARD
// ═════════════════════════════════════════════════════════════════════════════

class _UnbudgetedCard extends StatelessWidget {
  const _UnbudgetedCard({required this.budget, required this.onSetBudget});
  final _CategoryBudget budget;
  final VoidCallback onSetBudget;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: budget.iconColor.withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusMedium),
            ),
            child: Icon(budget.icon, size: 18, color: budget.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  budget.category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (budget.spent > 0)
                  Text(
                    '${CurrencyService.instance.format(budget.spent)} spent — untracked',
                    style: const TextStyle(
                        fontSize: 11, color: AppConstants.warningAmber),
                  )
                else
                  Text(
                    'No spending yet',
                    style: TextStyle(
                        fontSize: 11, color: Theme.of(context).colorScheme.outline),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSetBudget,
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Set Budget',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ADD BUDGET BOTTOM SHEET  (pick category + set amount)
// ═════════════════════════════════════════════════════════════════════════════

class _AddBudgetSheet extends StatefulWidget {
  const _AddBudgetSheet({
    required this.unbudgeted,
    required this.preselected,
    required this.onSave,
  });
  final List<_CategoryBudget> unbudgeted;
  final _CategoryBudget preselected;
  final Future<void> Function(_CategoryBudget category, double amount) onSave;

  @override
  State<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<_AddBudgetSheet> {
  late _CategoryBudget _selected;
  final TextEditingController _ctrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.preselected;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_ctrl.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a valid amount greater than 0.');
      return;
    }
    await widget.onSave(_selected, value);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.borderRadiusLarge)),
        ),
        padding: const EdgeInsets.fromLTRB(AppConstants.paddingLarge, 0,
            AppConstants.paddingLarge, AppConstants.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              'Add Budget',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a category and set its monthly limit.',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),

            const SizedBox(height: AppConstants.paddingMedium),

            // Category picker label
            Text(
              'CATEGORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.outline,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),

            // Category grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.unbudgeted.map((b) {
                final selected = _selected == b;
                return GestureDetector(
                  onTap: () => setState(() => _selected = b),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? b.iconColor.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusMedium),
                      border: Border.all(
                        color: selected
                            ? b.iconColor
                            : Colors.grey.withValues(alpha: 0.2),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(b.icon,
                            size: 16,
                            color: selected
                                ? b.iconColor
                                : Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 6),
                        Text(
                          b.category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? b.iconColor
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // Spending hint for selected category
            if (_selected.spent > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 13, color: AppConstants.warningAmber),
                  const SizedBox(width: 6),
                  Text(
                    '${CurrencyService.instance.format(_selected.spent)} already spent this month.',
                    style: const TextStyle(
                        fontSize: 12, color: AppConstants.warningAmber),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppConstants.paddingMedium),

            // Amount label
            Text(
              'BUDGET AMOUNT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.outline,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),

            // Amount field
            _AmountField(
              controller: _ctrl,
              error: _error,
              onChanged: () => setState(() => _error = null),
            ),

            const SizedBox(height: AppConstants.paddingLarge),
            _SaveButton(onPressed: _save),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED SHEET WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.onChanged,
    this.error,
  });
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      onChanged: (_) => onChanged(),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: 'Monthly budget amount',
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        prefixText: '${CurrencyService.instance.symbol} ',
        prefixStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        errorText: error,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide:
              BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: const BorderSide(
              color: AppConstants.primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide:
              const BorderSide(color: AppConstants.errorRed, width: 1.5),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusMedium),
          ),
        ),
        child: const Text('Save Budget',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
