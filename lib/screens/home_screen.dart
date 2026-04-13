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
import 'package:intl/intl.dart';

import '../utils/constants.dart';
import '../widgets/spending_summary_card.dart';
import '../widgets/quick_stat_card.dart';
import '../widgets/expense_list_tile.dart';
import '../widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ─── State ──────────────────────────────────────────────────────────────────
  String _userName = 'User';
  bool _isLoading = true;

  /// Sample expense data — will be replaced with SQLite queries later.
  /// Each map simulates an expense record.
  List<Map<String, String>> _recentExpenses = [];

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// Loads user name and expense data.
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch the stored user name
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(AppConstants.prefUserName) ?? 'User';

      // TODO: Replace with real data from the database service
      // final expenses = await DatabaseService.getRecentExpenses(limit: 5);

      // ── Sample data for UI development ──
      final sampleExpenses = <Map<String, String>>[
        {
          'title': 'Whole Foods Market',
          'category': 'Groceries',
          'amount': '\$65.40',
          'date': 'Today',
        },
        {
          'title': 'Chipotle',
          'category': 'Food/Restaurant',
          'amount': '\$14.25',
          'date': 'Today',
        },
        {
          'title': 'CVS Pharmacy',
          'category': 'Medicine',
          'amount': '\$23.99',
          'date': 'Yesterday',
        },
        {
          'title': 'Netflix',
          'category': 'Entertainment',
          'amount': '\$15.99',
          'date': 'Feb 22',
        },
        {
          'title': 'Zara',
          'category': 'Clothes',
          'amount': '\$89.00',
          'date': 'Feb 21',
        },
      ];

      if (!mounted) return;

      setState(() {
        _userName = name;
        _recentExpenses = sampleExpenses;
        _isLoading = false;
      });
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
            totalSpent: '\$208.63',
            monthLabel: _currentMonthLabel,
            budgetTotal: 500,
            onEditTap: () {
              Navigator.pushNamed(context, AppConstants.budgetRoute);
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
            onActionTap: () {
              // TODO: Switch to Expenses tab / navigate
            },
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        _buildRecentExpensesList(),
      ],
    );
  }

  // ─── Sub-builders ─────────────────────────────────────────────────────────

  /// Greeting row: "Good Morning, 👋" + user name + bell icon.
  Widget _buildGreetingHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
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
          ),
        ),
        // Notification bell button
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusMedium),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppConstants.textDark,
            ),
            onPressed: () {
              // TODO: Open notifications
            },
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
            value: '${_recentExpenses.length}',
            iconColor: AppConstants.primaryGreen,
            onTap: () {
              // TODO: Navigate to expenses
            },
          ),
          const SizedBox(width: 12),
          QuickStatCard(
            icon: Icons.category_outlined,
            label: 'Categories',
            value: '${_uniqueCategories()}',
            iconColor: AppConstants.infoBlue,
            onTap: () {
              // TODO: Navigate to analytics
            },
          ),
          const SizedBox(width: 12),
          QuickStatCard(
            icon: Icons.trending_down_outlined,
            label: 'Avg / Day',
            value: '\$${_averagePerDay()}',
            iconColor: AppConstants.warningAmber,
          ),
          const SizedBox(width: 12),
          QuickStatCard(
            icon: Icons.arrow_upward_outlined,
            label: 'Highest',
            value: _highestCategory(),
            iconColor: const Color(0xFFD81B60), // pink
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
                title: expense['title']!,
                category: expense['category']!,
                amount: expense['amount']!,
                date: expense['date']!,
                onTap: () {
                  // TODO: Navigate to expense details
                },
              ),
              // Divider between items (not after the last one)
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
            totalSpent: '\$0.00',
            monthLabel: _currentMonthLabel,
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

  // ─── Data helpers (sample / placeholder) ──────────────────────────────────

  /// Counts unique categories in current expenses.
  int _uniqueCategories() {
    return _recentExpenses
        .map((e) => e['category'])
        .toSet()
        .length;
  }

  /// Computes a simple average-per-day from the sample data.
  String _averagePerDay() {
    // In production: totalSpent / daysElapsedThisMonth
    const total = 208.63;
    final daysElapsed = DateTime.now().day;
    return (total / daysElapsed).toStringAsFixed(0);
  }

  /// Returns the category with the highest total in the sample data.
  String _highestCategory() {
    if (_recentExpenses.isEmpty) return '—';
    // Simple: just return the category of the largest single expense
    // In production this aggregates by category.
    var maxAmount = 0.0;
    var maxCategory = 'Others';
    for (final expense in _recentExpenses) {
      final amount = double.tryParse(
            expense['amount']!.replaceAll(RegExp(r'[^\d.]'), ''),
          ) ?? 0;
      if (amount > maxAmount) {
        maxAmount = amount;
        maxCategory = expense['category']!;
      }
    }
    return maxCategory;
  }
}
