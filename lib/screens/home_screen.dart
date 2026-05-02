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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/expense.dart';
import '../models/split_request.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/split_bill_service.dart';
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

  // Split bill state
  List<SplitRequest> _pendingSplits = [];
  List<SplitRequest> _splitsWithRejections = [];

  // Real-time Firestore stream for pending splits directed at the current user.
  StreamSubscription<List<SplitRequest>>? _pendingSplitSub;
  // IDs of splits we have already shown a local notification for (this session).
  final Set<String> _notifiedSplitKeys = {};

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  void _onCurrencyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    CurrencyService.instance.addListener(_onCurrencyChanged);
    _loadDashboardData();
    _subscribeToSplitStream();
  }

  @override
  void dispose() {
    _pendingSplitSub?.cancel();
    CurrencyService.instance.removeListener(_onCurrencyChanged);
    super.dispose();
  }

  /// Opens a Firestore real-time stream for split requests addressed to the
  /// current user. New / retried splits trigger a local notification the first
  /// time they appear in this session. The in-app card always updates instantly.
  void _subscribeToSplitStream() {
    _pendingSplitSub =
        SplitBillService.instance.watchPendingSplitsForMe().listen(
      (splits) {
        if (!mounted) return;

        // Find splits that arrived since the stream started (or since a retry).
        final newSplits = <SplitRequest>[];
        for (final split in splits) {
          if (split.id == null) continue;
          final ts =
              (split.retriedAt ?? split.createdAt).millisecondsSinceEpoch;
          final key = '${split.id}_$ts';
          if (!_notifiedSplitKeys.contains(key)) {
            _notifiedSplitKeys.add(key);
            newSplits.add(split);
          }
        }

        // Show local notifications for any splits newly detected by the stream.
        if (newSplits.isNotEmpty) {
          NotificationService.instance
              .notifySplitRequests(newSplits)
              .catchError((_) {});
        }

        setState(() => _pendingSplits = splits);
      },
      onError: (e) {
        debugPrint('HomeScreen: pending-split stream error — $e');
      },
    );
  }

  /// Loads user name, SQLite data, and split rejection status.
  ///
  /// Pending splits are no longer fetched here — the real-time Firestore stream
  /// from [_subscribeToSplitStream] keeps [_pendingSplits] up-to-date instantly.
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    // Resolve user name before any Firestore calls so it's always available
    // even if the DB queries fail (e.g. Firestore rules not yet configured).
    final firebaseUser = AuthService.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final name = (firebaseUser?.displayName?.isNotEmpty == true
            ? firebaseUser!.displayName!
            : prefs.getString(AppConstants.prefUserName)) ??
        'User';

    try {
      // Save initiator expenses for any fully-accepted splits BEFORE querying
      // DB totals so the new expenses appear in the dashboard immediately.
      List<SplitRequest> newlySaved = [];
      try {
        newlySaved =
            await SplitBillService.instance.saveFullyAcceptedInitiatorExpenses();
      } catch (_) {}

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

      // Fetch rejection status (one-shot; stream only covers pending-for-me).
      final rejections =
          await SplitBillService.instance.getSplitsWithRejections();

      if (!mounted) return;
      setState(() {
        _userName = name;
        _recentExpenses = results[0] as List<Expense>;
        _monthlyTotal = results[1] as double;
        _totalExpenseCount = results[2] as int;
        _categoryCount = results[3] as int;
        _avgPerDay = results[4] as double;
        _highestAmount = results[5] as double;
        _totalBudget = budgets.values.fold(0.0, (sum, v) => sum + v);
        _splitsWithRejections = rejections;
        _isLoading = false;
      });

      // Notify initiator and show snackbar for splits that just became fully accepted.
      for (final split in newlySaved) {
        NotificationService.instance
            .notifySplitFullyAccepted(split)
            .catchError((_) {});
      }
      if (newlySaved.isNotEmpty && mounted) {
        final first = newlySaved.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Everyone accepted! ${first.merchant} added to your expenses.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppConstants.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusSmall),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Budget alerts on first load only (not on pull-to-refresh).
      if (_firstLoad) {
        _firstLoad = false;
        NotificationService.instance.checkAndNotify();
      }
    } catch (e) {
      debugPrint('HomeScreen: Error loading data — $e');
      if (!mounted) return;
      setState(() {
        _userName = name;
        _isLoading = false;
      });
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

        const SizedBox(height: AppConstants.paddingMedium),

        // ── Split requests (pending / rejected) ──
        if (_pendingSplits.isNotEmpty) _buildPendingSplitsSection(),
        if (_splitsWithRejections.isNotEmpty) _buildSplitUpdatesSection(),

        if (_pendingSplits.isEmpty && _splitsWithRejections.isEmpty)
          const SizedBox(height: AppConstants.paddingMedium),

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

        const SizedBox(height: AppConstants.paddingMedium),

        // Split requests (even with zero expenses)
        if (_pendingSplits.isNotEmpty) _buildPendingSplitsSection(),
        if (_splitsWithRejections.isNotEmpty) _buildSplitUpdatesSection(),

        if (_pendingSplits.isEmpty && _splitsWithRejections.isEmpty)
          const SizedBox(height: AppConstants.paddingMedium),

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

  // ─── Pending splits section ───────────────────────────────────────────────

  Widget _buildPendingSplitsSection() {
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
          Row(
            children: [
              const Icon(Icons.call_split,
                  size: 16, color: Color(0xFFE65100)),
              const SizedBox(width: 6),
              const Text(
                'Split Requests',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.textDark,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_pendingSplits.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._pendingSplits.map(_buildPendingSplitCard),
        ],
      ),
    );
  }

  Widget _buildPendingSplitCard(SplitRequest split) {
    final fromLabel = split.initiatorName.isNotEmpty
        ? split.initiatorName
        : split.initiatorEmail;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(
            color: const Color(0xFFE65100).withValues(alpha: 0.25)),
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
          // Merchant + amount
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant_outlined,
                    color: Color(0xFFE65100), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      split.merchant,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.textDark,
                      ),
                    ),
                    Text(
                      'From $fromLabel · Split ${split.splitCount} ways',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppConstants.textMediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyService.instance.format(split.amountPerPerson),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Accept / Decline buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _onRejectSplit(split),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.errorRed,
                    side: BorderSide(
                        color: AppConstants.errorRed.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusSmall),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => _onAcceptSplit(split),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppConstants.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusSmall),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAcceptSplit(SplitRequest split) async {
    try {
      await SplitBillService.instance.acceptSplit(split);
      await _loadDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Added ${split.merchant} split to your expenses!'),
          backgroundColor: AppConstants.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to accept split. Try again.'),
          backgroundColor: AppConstants.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onRejectSplit(SplitRequest split) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        title: const Text('Decline split?'),
        content: Text(
          'Decline the ${split.merchant} split from '
          '${split.initiatorName.isNotEmpty ? split.initiatorName : split.initiatorEmail}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppConstants.errorRed),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SplitBillService.instance.rejectSplit(split);
      await _loadDashboardData();
    } catch (_) {}
  }

  // ─── Split rejection updates section ──────────────────────────────────────

  Widget _buildSplitUpdatesSection() {
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
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppConstants.warningAmber),
              SizedBox(width: 6),
              Text(
                'Split Updates',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._splitsWithRejections.map(_buildRejectionCard),
        ],
      ),
    );
  }

  Widget _buildRejectionCard(SplitRequest split) {
    final rejectedNames = split.namesWithStatus('rejected');
    final names = rejectedNames.join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(
            color: AppConstants.warningAmber.withValues(alpha: 0.4)),
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppConstants.warningAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_off_outlined,
                    color: AppConstants.warningAmber, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      split.merchant,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.textDark,
                      ),
                    ),
                    Text(
                      '$names declined the split',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppConstants.textMediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyService.instance.format(split.amountPerPerson),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _onDismissRejection(split),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.textMediumGray,
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusSmall),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Save as is'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _onRetrySplit(split),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppConstants.warningAmber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusSmall),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onRetrySplit(SplitRequest split) async {
    try {
      await SplitBillService.instance.retrySplit(split);
      await _loadDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Split request re-sent!'),
          backgroundColor: AppConstants.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  Future<void> _onDismissRejection(SplitRequest split) async {
    try {
      await SplitBillService.instance.dismissRejection(split);
      await _loadDashboardData();
    } catch (_) {}
  }

  // ─── Date formatting ──────────────────────────────────────────────────────

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

