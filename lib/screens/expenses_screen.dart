/// Expenses Screen — full paginated list of all expenses.
///
/// Layout (top → bottom, scrollable):
///   1. Monthly total summary bar
///   2. Search field
///   3. Category filter chips (horizontal scroll)
///   4. Sort toggle (Date ↕ / Amount ↕)
///   5. Date-grouped expense list (Today / Yesterday / Earlier)
///   6. Empty state (no data or no search results)
///
/// Features:
///   - Pull-to-refresh
///   - Live search by title
///   - Filter by category chip
///   - Sort by date or amount (asc / desc)
///   - Tap any tile → ExpenseDetailScreen
///   - Uses sample data (will be replaced with SQLite queries)
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/expense.dart';
import '../services/currency_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import '../widgets/expense_list_tile.dart';
import 'expense_detail_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  // ─── State ──────────────────────────────────────────────────────────────────

  bool _isLoading = true;
  List<Expense> _allExpenses = [];
  String _searchQuery = ''; // Stores what user types in the search field
  String _selectedCategory = 'All';
  _SortMode _sortMode = _SortMode.dateDesc;

  final TextEditingController _searchController = TextEditingController(); // Controls the search field text
  final FocusNode _searchFocus = FocusNode(); // Manages focus for the search field 

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  void _onCurrencyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    CurrencyService.instance.addListener(_onCurrencyChanged);
    _loadExpenses(); // Load expenses from the database when the screen initializes
  }

  @override
  void dispose() {
    CurrencyService.instance.removeListener(_onCurrencyChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final expenses = await DatabaseService.instance.getExpenses(); //call DB
    if (!mounted) return;
    setState(() {
      _allExpenses = expenses; // Update the state with the loaded expenses
      _isLoading = false;
    });
  }

  // ─── Filtering & sorting ─────────────────────────────────────────────────

  List<Expense> get _filtered {
    var list = _allExpenses.where((e) {
      final matchesSearch = _searchQuery.isEmpty ||
          e.merchantName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' || e.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    switch (_sortMode) {
      case _SortMode.dateDesc:
        list.sort((a, b) => b.date.compareTo(a.date));
      case _SortMode.dateAsc:
        list.sort((a, b) => a.date.compareTo(b.date));
      case _SortMode.amountDesc:
        list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      case _SortMode.amountAsc:
        list.sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
    }

    return list;
  }

  /// Groups a sorted expense list into date buckets for section headers.
  Map<String, List<Expense>> _groupByDate(List<Expense> expenses) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 6));

    final groups = <String, List<Expense>>{};

    for (final e in expenses) {
      final eDay = DateTime(e.date.year, e.date.month, e.date.day);
      final String bucket;
      if (!eDay.isBefore(todayStart)) {
        bucket = 'Today';
      } else if (!eDay.isBefore(yesterdayStart)) {
        bucket = 'Yesterday';
      } else if (!eDay.isBefore(weekStart)) {
        bucket = 'This Week';
      } else {
        bucket = DateFormat('MMMM yyyy').format(e.date);
      }
      groups.putIfAbsent(bucket, () => []).add(e);
    }

    return groups;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatDate(Expense e) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final eDay = DateTime(e.date.year, e.date.month, e.date.day);
    if (!eDay.isBefore(todayStart)) return 'Today';
    if (eDay == todayStart.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM d').format(e.date);
  }

  void _toggleSort(_SortMode mode) { // Toggle sorting mode when user taps on sort chips
    setState(() {
      if (_sortMode == mode) {
        // flip direction
        if (mode == _SortMode.dateDesc) {
          _sortMode = _SortMode.dateAsc;
        } else if (mode == _SortMode.dateAsc) {
          _sortMode = _SortMode.dateDesc;
        } else if (mode == _SortMode.amountDesc) {
          _sortMode = _SortMode.amountAsc;
        } else {
          _sortMode = _SortMode.amountDesc;
        }
      } else {
        _sortMode = mode;
      }
    });
  }

  void _openDetail(Expense expense) {
    Navigator.pushNamed(
      context,
      AppConstants.expenseDetailRoute,
      arguments: ExpenseDetailArgs(expenseId: expense.id),
    ).then((_) => _loadExpenses()); // reload after returning (edit/delete may have changed data)
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppConstants.primaryGreen),
              )
            : RefreshIndicator(
                onRefresh: _loadExpenses,
                color: AppConstants.primaryGreen,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(child: _buildSummaryBar()),
                    SliverToBoxAdapter(child: _buildSearchBar()),
                    SliverToBoxAdapter(child: _buildCategoryChips()),
                    SliverToBoxAdapter(child: _buildSortRow()),
                    _buildExpenseList(),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── App bar ──────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFFF8FAF8),
      elevation: 0,
      floating: true,
      snap: true,
      titleSpacing: AppConstants.paddingLarge,
      title: const Text(
        'Expenses',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppConstants.textDark,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppConstants.paddingMedium),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.tune_outlined, color: AppConstants.textDark),
              tooltip: 'Filter',
              onPressed: _showFilterSheet,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Monthly summary bar ──────────────────────────────────────────────────

  Widget _buildSummaryBar() {
    final now = DateTime.now();
    final monthTotal = _allExpenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (s, e) => s + e.totalAmount);
    final monthLabel = DateFormat('MMMM yyyy').format(now);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge,
        AppConstants.paddingSmall,
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
                  monthLabel,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyService.instance.format(monthTotal),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Builder(builder: (_) {
                  final count = _allExpenses
                      .where((e) =>
                          e.date.year == now.year &&
                          e.date.month == now.month)
                      .length;
                  return Text(
                    '$count expense${count == 1 ? '' : 's'} this month',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  );
                }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            ),
            child: const Icon(Icons.receipt_long, size: 28, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ─── Search bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (v) => setState(() => _searchQuery = v), // Update search query on every change
        style: const TextStyle(fontSize: 14, color: AppConstants.textDark),
        decoration: InputDecoration(
          hintText: 'Search expenses…',
          hintStyle: const TextStyle(color: AppConstants.textLightGray),
          prefixIcon: const Icon(Icons.search, color: AppConstants.textMediumGray, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppConstants.textMediumGray), // Clear button appears only when there's text in the search field
                  onPressed: () {
                    _searchController.clear(); // Clear the text field
                    setState(() => _searchQuery = '');
                    _searchFocus.unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            borderSide: const BorderSide(color: AppConstants.primaryGreen, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ─── Category chips ───────────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    final categories = ['All', ...AppConstants.expenseCategories];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal, // Horizontal list of category chips
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingLarge,
          vertical: AppConstants.paddingSmall,
        ),
        itemCount: categories.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final selected = _selectedCategory == cat; // Whether this category is currently selected
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat), // Update selected category on tap
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppConstants.primaryGreen : Colors.white, // Highlight selected category
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppConstants.primaryGreen
                      : Colors.grey.withValues(alpha: 0.25),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppConstants.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppConstants.textMediumGray,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Sort row ─────────────────────────────────────────────────────────────

  Widget _buildSortRow() {
    final filtered = _filtered;
    final isDateSort =
        _sortMode == _SortMode.dateDesc || _sortMode == _SortMode.dateAsc;
    final isAmtSort =
        _sortMode == _SortMode.amountDesc || _sortMode == _SortMode.amountAsc;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge,
        AppConstants.paddingSmall,
        AppConstants.paddingLarge,
        4,
      ),
      child: Row(
        children: [
          Text(
            '${filtered.length} result${filtered.length == 1 ? '' : 's'}', // Shows how many expenses match the current filters
            style: const TextStyle(
              fontSize: 13,
              color: AppConstants.textMediumGray,
            ),
          ),
          const Spacer(),
          // Date sort chip
          _SortChip(
            label: 'Date',
            active: isDateSort,
            ascending: _sortMode == _SortMode.dateAsc,
            onTap: () => _toggleSort(
              isDateSort && _sortMode == _SortMode.dateDesc
                  ? _SortMode.dateAsc
                  : _SortMode.dateDesc,
            ),
          ),
          const SizedBox(width: 8),
          // Amount sort chip
          _SortChip(
            label: 'Amount',
            active: isAmtSort,
            ascending: _sortMode == _SortMode.amountAsc,
            onTap: () => _toggleSort(
              isAmtSort && _sortMode == _SortMode.amountDesc
                  ? _SortMode.amountAsc
                  : _SortMode.amountDesc,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Expense list sliver ──────────────────────────────────────────────────

  Widget _buildExpenseList() {
    final filtered = _filtered; // Get the filtered and sorted list of expenses based on current search query, category filter, and sort mode

    if (filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(), // Show empty state if there are no expenses to display after nothig matches
      );
    }

    final groups = _groupByDate(filtered);
    final bucketKeys = groups.keys.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, sectionIndex) {
          final bucket = bucketKeys[sectionIndex];
          final items = groups[bucket]!;

          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLarge,
              AppConstants.paddingMedium,
              AppConstants.paddingLarge,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header row: bucket label + bucket total
                Row(
                  children: [
                    Text(
                      bucket,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.textMediumGray,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      CurrencyService.instance.format(items.fold(0.0, (s, e) => s + e.totalAmount)),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.textMediumGray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Card containing the tiles for this bucket
                Container(
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
                    children: List.generate(items.length, (i) {
                      final expense = items[i];
                      return Column(
                        children: [
                          ExpenseListTile(
                            title: expense.merchantName,
                            category: expense.category,
                            amount: CurrencyService.instance.format(expense.totalAmount),
                            date: _formatDate(expense),
                            onTap: () => _openDetail(expense),
                          ),
                          if (i < items.length - 1)
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
                ),
              ],
            ),
          );
        },
        childCount: bucketKeys.length,
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final isFiltered =
        _searchQuery.isNotEmpty || _selectedCategory != 'All';

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
              child: Icon(
                isFiltered
                    ? Icons.search_off_outlined
                    : Icons.receipt_long_outlined,
                size: 42,
                color: AppConstants.lightGreen,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Text(
              isFiltered ? 'No Results Found' : 'No Expenses Yet',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppConstants.textDark,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              isFiltered
                  ? 'Try a different search term\nor change the category filter.'
                  : 'Tap the camera button below to scan\nyour first receipt and start tracking!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppConstants.textMediumGray,
                height: 1.5,
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(height: AppConstants.paddingLarge),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'All';
                  });
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.primaryGreen,
                  side: const BorderSide(color: AppConstants.primaryGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadiusMedium),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Filter bottom sheet ──────────────────────────────────────────────────

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterSheet(
        currentCategory: _selectedCategory,
        currentSort: _sortMode,
        onApply: (cat, sort) {
          setState(() {
            _selectedCategory = cat;
            _sortMode = sort;
          });
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SORT CHIP WIDGET
// ═════════════════════════════════════════════════════════════════════════════

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppConstants.primaryGreen.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? AppConstants.primaryGreen
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active
                    ? AppConstants.primaryGreen
                    : AppConstants.textMediumGray,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              active
                  ? (ascending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: active
                  ? AppConstants.primaryGreen
                  : AppConstants.textLightGray,
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FILTER BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.currentCategory,
    required this.currentSort,
    required this.onApply,
  });

  final String currentCategory;
  final _SortMode currentSort;
  final void Function(String category, _SortMode sort) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _category;
  late _SortMode _sort;

  @override
  void initState() {
    super.initState();
    _category = widget.currentCategory;
    _sort = widget.currentSort;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...AppConstants.expenseCategories];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.borderRadiusLarge),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            AppConstants.paddingLarge,
      ),
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
                color: AppConstants.textLightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppConstants.paddingLarge, 4,
              AppConstants.paddingLarge, AppConstants.paddingMedium,
            ),
            child: Text(
              'Filter & Sort',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppConstants.textDark,
              ),
            ),
          ),

          // Category section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge),
            child: Text(
              'CATEGORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppConstants.textLightGray,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingLarge,
              ),
              itemCount: categories.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final sel = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppConstants.primaryGreen : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? AppConstants.primaryGreen
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 13,
                        color: sel ? Colors.white : AppConstants.textMediumGray,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppConstants.paddingMedium),

          // Sort section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge),
            child: Text(
              'SORT BY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppConstants.textLightGray,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge),
            child: Wrap(
              spacing: 8,
              children: [
                _SortOption(label: 'Newest First', mode: _SortMode.dateDesc, current: _sort, onTap: (m) => setState(() => _sort = m)),
                _SortOption(label: 'Oldest First', mode: _SortMode.dateAsc, current: _sort, onTap: (m) => setState(() => _sort = m)),
                _SortOption(label: 'Highest Amount', mode: _SortMode.amountDesc, current: _sort, onTap: (m) => setState(() => _sort = m)),
                _SortOption(label: 'Lowest Amount', mode: _SortMode.amountAsc, current: _sort, onTap: (m) => setState(() => _sort = m)),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Apply button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_category, _sort);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.mode,
    required this.current,
    required this.onTap,
  });

  final String label;
  final _SortMode mode;
  final _SortMode current;
  final void Function(_SortMode) onTap;

  @override
  Widget build(BuildContext context) {
    final selected = current == mode;
    return GestureDetector(
      onTap: () => onTap(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppConstants.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppConstants.primaryGreen
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : AppConstants.textMediumGray,
          ),
        ),
      ),
    );
  }
}

// ─── Sort mode enum ───────────────────────────────────────────────────────────

enum _SortMode { dateDesc, dateAsc, amountDesc, amountAsc }
