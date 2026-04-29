/// Home Dashboard — the primary tab of the Spendly app.
///
/// Layout (top → bottom, scrollable):
///   1. Greeting header with username + notification bell
///   2. Spending summary card (gradient green, total this month)
///   3. Quick stats row (horizontal scroll — receipts, categories, avg)
///   4. Recent expenses list preview (last 5)
///   5. Empty state when no expenses exist yet
///
/// Features:
///   - Pull-to-refresh triggers data reload
///   - Reads username from SharedPreferences
///   - Uses sample data for now (will be replaced with SQLite queries)
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/expense.dart';
import '../services/currency_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import '../widgets/spending_summary_card.dart';
import '../widgets/quick_stat_card.dart';
import '../widgets/expense_list_tile.dart';
import '../widgets/section_header.dart';
import 'expense_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onSeeAllExpenses});

  /// Callback invoked when the user taps "See all" on the recent expenses
  /// section. Provided by [MainNavShell] to switch to the Expenses tab.
  final VoidCallback? onSeeAllExpenses;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ─── State ──────────────────────────────────────────────────────────────────
  String _userName = 'User';
  bool _isLoading = true;
  bool _firstLoad = true;

  List<Expense> _recentExpenses = [];
  double _monthlyTotal = 0;
  double _totalBudget = 0;
  int _totalExpenseCount = 0;
  int _categoryCount = 0;
  double _avgPerDay = 0;
  double _highestAmount = 0;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  void _onCurrencyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    CurrencyService.instance.addListener(_onCurrencyChanged);
    _loadDashboardData();
  }

  @override
  void dispose() {
    CurrencyService.instance.removeListener(_onCurrencyChanged);
    super.dispose();
  }

  /// Loads user name and expense data from SharedPreferences + SQLite.
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(AppConstants.prefUserName) ?? 'User';

      final now = DateTime.now();
      final results = await Future.wait([
        DatabaseService.instance.getRecentExpenses(limit: 5),
        DatabaseService.instance.getMonthlyTotal(now.year, now.month),
        DatabaseService.instance.getExpenseCount(),
        DatabaseService.instance.getDistinctCategoryCount(),
        DatabaseService.instance.getAverageDailySpend(),
        DatabaseService.instance.getHighestExpense(),
        DatabaseService.instance.getBudgets(now.year, now.month),
      ]);

      if (!mounted) return;

      final budgets = results[6] as Map<String, double>;

      setState(() {
        _userName = name;
        _recentExpenses = results[0] as List<Expense>;
        _monthlyTotal = results[1] as double;
        _totalExpenseCount = results[2] as int;
        _categoryCount = results[3] as int;
        _avgPerDay = results[4] as double;
        _highestAmount = results[5] as double;
        _totalBudget = budgets.values.fold(0.0, (sum, v) => sum + v);
        _isLoading = false;
      });

      // Send push notifications on first load only (not on pull-to-refresh)
      if (_firstLoad) {
        _firstLoad = false;
        NotificationService.instance.checkAndNotify();
      }
    } catch (e) {
      debugPrint('HomeScreen: Error loading data — $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Returns a greeting based on time of day.
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  /// Returns current month label (e.g. "February 2026").
  String get _currentMonthLabel =>
      DateFormat('MMMM yyyy').format(DateTime.now());

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8), // very subtle off-white green
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppConstants.primaryGreen,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                color: AppConstants.primaryGreen,
                child: _recentExpenses.isEmpty
                    ? _buildEmptyState()
                    : _buildDashboard(),
              ),
      ),
    );
  }

  // ─── Dashboard with data ──────────────────────────────────────────────────

  Widget _buildDashboard() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        top: AppConstants.paddingMedium,
        bottom: 100, // clearance for FAB + nav bar
      ),
      children: [
        // ── 1. Greeting header ──
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
          ),
          child: _buildGreetingHeader(),
        ),

        const SizedBox(height: AppConstants.paddingLarge),

        // ── 2. Spending summary card ──
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
          ),
          child: SpendingSummaryCard(
            totalSpent: CurrencyService.instance.format(_monthlyTotal),
            monthLabel: _currentMonthLabel,
            spentAmount: _monthlyTotal,
            budgetTotal: _totalBudget > 0 ? _totalBudget : null,
            onEditTap: () {
              Navigator.pushNamed(context, AppConstants.budgetRoute)
                  .then((_) => _loadDashboardData());
            },
          ),
        ),

        const SizedBox(height: AppConstants.paddingLarge),

        // ── 3. Quick stats ──
        Padding(
          padding: const EdgeInsets.only(
            left: AppConstants.paddingLarge,
            right: AppConstants.paddingLarge,
            bottom: AppConstants.paddingSmall,
          ),
          child: const SectionHeader(title: 'Quick Stats'),
        ),
        _buildQuickStats(),

        const SizedBox(height: AppConstants.paddingLarge),

        // ── 4. Recent expenses ──
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
          ),
          child: SectionHeader(
            title: 'Recent Expenses',
            actionText: 'See all',
            onActionTap: widget.onSeeAllExpenses,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        _buildRecentExpensesList(),
      ],
    );
  }

  // ─── Sub-builders ─────────────────────────────────────────────────────────

  /// Greeting row: greeting emoji + user name.
  Widget _buildGreetingHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_greeting 👋',
          style: const TextStyle(
            fontSize: 14,
            color: AppConstants.textMediumGray,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _userName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppConstants.textDark,
          ),
        ),
      ],
    );
  }

  /// Horizontally scrollable row of quick-stat cards.
  Widget _buildQuickStats() {
    return SizedBox(
      height: 138,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingLarge,
        ),
        children: [
          QuickStatCard(
            icon: Icons.receipt_long_outlined,
            label: 'Receipts',
            value: '$_totalExpenseCount',
            iconColor: AppConstants.primaryGreen,
            onTap: widget.onSeeAllExpenses,
          ),
          const SizedBox(width: 12),
          QuickStatCard(
            icon: Icons.category_outlined,
            label: 'Categories',
            value: '$_categoryCount',
            iconColor: AppConstants.infoBlue,
          ),
          const SizedBox(width: 12),
          QuickStatCard(
            icon: Icons.trending_down_outlined,
            label: 'Avg / Day',
            value: CurrencyService.instance.format(_avgPerDay, decimals: 0),
            iconColor: AppConstants.warningAmber,
          ),
          const SizedBox(width: 12),
          QuickStatCard(
            icon: Icons.arrow_upward_outlined,
            label: 'Highest',
            value: CurrencyService.instance.format(_highestAmount, decimals: 0),
            iconColor: const Color(0xFFD81B60),
          ),
        ],
      ),
    );
  }

  /// Recent expenses rendered as styled list tiles inside a card.
  Widget _buildRecentExpensesList() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLarge,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(_recentExpenses.length, (index) {
          final expense = _recentExpenses[index];
          return Column(
            children: [
              ExpenseListTile(
                title: expense.merchantName,
                category: expense.category,
                amount: CurrencyService.instance.format(expense.totalAmount),
                date: _formatDate(expense.date),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppConstants.expenseDetailRoute,
                    arguments: ExpenseDetailArgs(expenseId: expense.id),
                  ).then((_) => _loadDashboardData());
                },
              ),
              if (index < _recentExpenses.length - 1)
                Divider(
                  height: 1,
                  indent: 72,
                  endIndent: AppConstants.paddingMedium,
                  color: Colors.grey.withValues(alpha: 0.15),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  /// Shown when the user has no expenses yet.
  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        top: AppConstants.paddingMedium,
        bottom: 100,
      ),
      children: [
        // Still show greeting at the top
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
          ),
          child: _buildGreetingHeader(),
        ),

        const SizedBox(height: AppConstants.paddingLarge),

        // Spending summary card showing zero
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
          ),
          child: SpendingSummaryCard(
            totalSpent: CurrencyService.instance.format(0),
            monthLabel: _currentMonthLabel,
            spentAmount: 0,
            budgetTotal: _totalBudget > 0 ? _totalBudget : null,
            onEditTap: () => Navigator.pushNamed(context, AppConstants.budgetRoute)
                .then((_) => _loadDashboardData()),
          ),
        ),

        // Empty illustration
        SizedBox(height: MediaQuery.of(context).size.height * 0.08),

        Center(
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppConstants.lightGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: AppConstants.lightGreen,
                ),
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              const Text(
                'No Expenses Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.textDark,
                ),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Tap the camera button below to scan your\nfirst receipt and start tracking!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppConstants.textMediumGray,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              // Arrow down pointing to FAB
              const Icon(
                Icons.keyboard_double_arrow_down,
                size: 32,
                color: AppConstants.lightGreen,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Formats a date relative to today for the tile subtitle.
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM d').format(date);
  }
}

