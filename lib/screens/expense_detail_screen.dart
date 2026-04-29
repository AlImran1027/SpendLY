/// Expense Detail View — displays the full details of a single expense.
///
/// Shows:
///   - Receipt image preview (tap for full-screen pinch-to-zoom)
///   - Merchant name, category badge, date, payment method
///   - Prominent amount card with gradient background
///   - Items list with quantity × price = subtotal breakdown
///   - Additional details (notes, AI confidence badge)
///   - Timestamps (created / modified)
///   - Sticky bottom action bar (Edit / Delete)
///
/// Entry points:
///   - Expenses list → tap expense row
///   - Home dashboard → tap recent expense
///   - Analytics → tap expense in breakdown
///   - Search results → tap found expense
///
/// Receives [ExpenseDetailArgs] as a route argument.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/extracted_receipt_data.dart';
import '../services/currency_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

// ─── Route Arguments ──────────────────────────────────────────────────────────

/// Packages the data needed to display an expense's full details.
///
/// In production, [expenseId] would be used to query SQLite.
/// For now, [receiptData] carries all the information needed.
class ExpenseDetailArgs {
  /// Database ID of the expense (for future SQLite integration).
  final int? expenseId;

  /// Full receipt / expense data to display.
  final ExtractedReceiptData? receiptData;

  /// Optional notes attached to the expense.
  final String? notes;

  /// Timestamp when the expense was created.
  final DateTime? createdAt;

  /// Timestamp when the expense was last modified.
  final DateTime? modifiedAt;

  /// Overall AI extraction confidence (0.0 – 1.0). Null if manual entry.
  final double? aiConfidence;

  const ExpenseDetailArgs({
    this.expenseId,
    this.receiptData,
    this.notes,
    this.createdAt,
    this.modifiedAt,
    this.aiConfidence,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({super.key});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen>
    with TickerProviderStateMixin {
  // ─── State ──────────────────────────────────────────────────────────────────

  ExtractedReceiptData? _data;
  String? _notes;
  DateTime? _createdAt;
  DateTime? _modifiedAt;
  double? _aiConfidence;
  int? _expenseId;
  bool _isLoading = true;
  bool _argsRead = false;

  // ─── Animation ──────────────────────────────────────────────────────────────

  late AnimationController _staggerCtrl;
  late AnimationController _imageCtrl;
  late Animation<double> _imageFade;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _imageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _imageFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _imageCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ExpenseDetailArgs) {
      _expenseId = args.expenseId;
      _notes = args.notes;
      _createdAt = args.createdAt;
      _modifiedAt = args.modifiedAt;
      _aiConfidence = args.aiConfidence;

      // If a DB id was provided try to load from SQLite; fall back to the
      // passed-in receiptData (or sample data) if not found.
      if (_expenseId != null) {
        DatabaseService.instance.getExpenseById(_expenseId!).then((expense) {
          if (!mounted) return;
          if (expense != null) {
            setState(() {
              _data = expense.toExtractedReceiptData();
              _notes = expense.notes.isNotEmpty ? expense.notes : null;
              _createdAt = expense.createdAt;
              _modifiedAt = expense.modifiedAt;
              _aiConfidence = expense.aiConfidence;
              _isLoading = false;
            });
          } else {
            // Fallback to args data
            setState(() {
              _data = args.receiptData ?? ExtractedReceiptData.sample(imagePath: '');
              _createdAt ??= _data!.date ?? DateTime.now();
              _modifiedAt ??= _createdAt;
              _isLoading = false;
            });
          }
          _imageCtrl.forward();
          _staggerCtrl.forward();
        });
        return; // early return — loading handled in .then()
      }

      _data = args.receiptData;
    }

    // If no data was passed, use sample data for development.
    _data ??= ExtractedReceiptData.sample(imagePath: '');

    _createdAt ??= _data!.date ?? DateTime.now();
    _modifiedAt ??= _createdAt;

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _imageCtrl.forward();
      _staggerCtrl.forward();
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatCurrency(double amount) =>
      CurrencyService.instance.format(amount);

  /// Formats a DateTime to a full readable string.
  String _formatFullDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('EEEE, d MMMM yyyy \'at\' h:mm a').format(dt);
  }

  /// Formats a DateTime to a short timestamp.
  String _formatShortDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('d MMM yyyy, h:mm a').format(dt);
  }

  /// Returns the appropriate payment method icon.
  String _paymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'card':
        return '💳';
      case 'cash':
        return '💵';
      case 'digital wallet':
        return '📱';
      default:
        return '💰';
    }
  }

  /// Maps a category name to an appropriate Material icon.
  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Groceries':
        return Icons.shopping_cart_outlined;
      case 'Food/Restaurant':
        return Icons.restaurant_outlined;
      case 'Medicine':
        return Icons.medical_services_outlined;
      case 'Clothes':
        return Icons.checkroom_outlined;
      case 'Hardware':
        return Icons.hardware_outlined;
      case 'Cosmetics':
        return Icons.face_outlined;
      case 'Entertainment':
        return Icons.movie_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  /// Maps a category name to a theme colour.
  Color _categoryColor(String category) {
    switch (category) {
      case 'Groceries':
        return AppConstants.primaryGreen;
      case 'Food/Restaurant':
        return const Color(0xFFE65100);
      case 'Medicine':
        return AppConstants.errorRed;
      case 'Clothes':
        return const Color(0xFF7B1FA2);
      case 'Hardware':
        return const Color(0xFF455A64);
      case 'Cosmetics':
        return const Color(0xFFD81B60);
      case 'Entertainment':
        return AppConstants.infoBlue;
      default:
        return AppConstants.textMediumGray;
    }
  }

  // ─── Stagger Animation Helper ─────────────────────────────────────────────

  /// Returns a fade + slide animation for the section at the given [index].
  Animation<double> _sectionFade(int index) {
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.3).clamp(0.0, 1.0);
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );
  }

  Animation<Offset> _sectionSlide(int index) {
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.3).clamp(0.0, 1.0);
    return Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );
  }

  // ─── Navigation & Actions ─────────────────────────────────────────────────

  void _showDeleteConfirmation() {
    if (_data == null) return;

    final merchant = _data!.merchantName.isNotEmpty
        ? _data!.merchantName
        : 'Unknown Merchant';
    final amount = _formatCurrency(_data!.totalAmount);
    final date = _data!.date != null
        ? DateFormat('d MMM yyyy').format(_data!.date!)
        : 'Unknown Date';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        title: const Text(
          'Delete Expense?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppConstants.textDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: AppConstants.textMediumGray,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F0),
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 20, color: AppConstants.errorRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$merchant — $amount on $date',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppConstants.textMediumGray),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              _performDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _performDelete() {
    if (_expenseId != null) {
      DatabaseService.instance.deleteExpense(_expenseId!);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense deleted'),
        backgroundColor: AppConstants.errorRed, // Red background to indicate deletion
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true); // true = deleted
  }

  void _openReceiptModal() {
    if (_data == null) return;

    final imagePath = _data!.imagePath;
    final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();
    if (!hasImage) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _ReceiptImageModal(imagePath: imagePath),
          );
        },
      ),
    );
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton( // Back button to return to the previous screen
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), // Use a smaller back arrow icon
          onPressed: () => Navigator.pop(context), // Navigate back when pressed
        ),
        title: const Text(
          'Expense Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppConstants.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppConstants.errorRed),
            tooltip: 'Delete Expense',
            onPressed: _showDeleteConfirmation,
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingSkeleton() : _buildBody(),
    );
  }

  // ─── Loading Skeleton ─────────────────────────────────────────────────────

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Image placeholder
          Container(
            width: double.infinity,
            height: 260,
            color: const Color(0xFFE0E0E0),
          ),
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              children: List.generate(4, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    height: i == 1 ? 100 : 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Main Content Body ────────────────────────────────────────────────────

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Receipt Image Preview ──
                _buildReceiptImage(),

                const SizedBox(height: 12),

                // ── Merchant & Date Section ──
                FadeTransition(
                  opacity: _sectionFade(0),
                  child: SlideTransition(
                    position: _sectionSlide(0),
                    child: _buildMerchantSection(),
                  ),
                ),

                // ── Amount Section ──
                FadeTransition(
                  opacity: _sectionFade(1),
                  child: SlideTransition(
                    position: _sectionSlide(1),
                    child: _buildAmountCard(),
                  ),
                ),

                // ── Items List Section ──
                FadeTransition(
                  opacity: _sectionFade(2),
                  child: SlideTransition(
                    position: _sectionSlide(2),
                    child: _buildItemsSection(),
                  ),
                ),

                // ── Additional Details Section ──
                FadeTransition(
                  opacity: _sectionFade(3),
                  child: SlideTransition(
                    position: _sectionSlide(3),
                    child: _buildAdditionalDetails(),
                  ),
                ),

                // ── Timestamps Section ──
                FadeTransition(
                  opacity: _sectionFade(4),
                  child: SlideTransition(
                    position: _sectionSlide(4),
                    child: _buildTimestamps(),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Receipt Image ────────────────────────────────────────────────────────

  Widget _buildReceiptImage() {
    final imagePath = _data?.imagePath ?? '';
    final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();

    return GestureDetector(
      onTap: hasImage ? _openReceiptModal : null,
      child: FadeTransition(
        opacity: _imageFade,
        child: Container(
          width: double.infinity,
          height: 260,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: hasImage
              ? ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 260,
                  ),
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 56, color: AppConstants.textLightGray),
                    SizedBox(height: 12),
                    Text(
                      'No receipt image available',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppConstants.textMediumGray,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── Merchant & Date Section ──────────────────────────────────────────────

  Widget _buildMerchantSection() {
    final data = _data!;
    final catColor = _categoryColor(data.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          // Merchant name
          Text(
            data.merchantName.isNotEmpty ? data.merchantName : 'Unknown Merchant',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppConstants.textDark,
            ),
          ),
          const SizedBox(height: 8),

          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_categoryIcon(data.category), size: 14, color: catColor),
                const SizedBox(width: 4),
                Text(
                  data.category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: catColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Date display
          Text(
            _formatFullDate(data.date),
            style: const TextStyle(
              fontSize: 14,
              color: AppConstants.textMediumGray,
            ),
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE0E0E0), height: 1),
          const SizedBox(height: 12),

          // Payment method
          Row(
            children: [
              Text(
                _paymentIcon(data.paymentMethod),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                data.paymentMethod,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppConstants.textMediumGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Amount Card ──────────────────────────────────────────────────────────

  Widget _buildAmountCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppConstants.primaryGreen,
            AppConstants.darkGreen,
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryGreen.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total amount
          Text(
            _formatCurrency(_data!.totalAmount),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Total Amount',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Budget progress indicator (demo)
          _buildBudgetProgress(),
        ],
      ),
    );
  }

  Widget _buildBudgetProgress() {
    // Demo: show budget progress for the Groceries category
    if (_data!.category != 'Groceries') return const SizedBox.shrink();

    const budget = 3000.0;
    final spent = _data!.totalAmount;
    final ratio = (spent / budget).clamp(0.0, 1.5);

    Color progressColor;
    if (ratio >= AppConstants.budgetCriticalThreshold) {
      progressColor = AppConstants.errorRed;
    } else if (ratio >= AppConstants.budgetWarningThreshold) {
      progressColor = AppConstants.warningAmber;
    } else {
      progressColor = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(ratio * 100).toInt()}% of ${_formatCurrency(budget)} monthly budget',
            style: TextStyle(
              fontSize: 11,
              color: progressColor.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Items List Section ───────────────────────────────────────────────────

  Widget _buildItemsSection() {
    final items = _data!.items;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Items',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppConstants.textDark,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
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
            child: items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No items recorded. Total amount saved as single entry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppConstants.textMediumGray,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        _buildItemRow(items[i]),
                        if (i < items.length - 1)
                          const Divider(
                              color: Color(0xFFE0E0E0), height: 20),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(ExtractedItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtQty(item.quantity)} × ${_formatCurrency(item.unitPrice)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppConstants.textMediumGray,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(item.subtotal),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppConstants.textDark,
            ),
          ),
        ],
      ),
    );
  }

  /// Formats quantity — shows integer if whole, one decimal otherwise.
  String _fmtQty(double qty) {
    return qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(1);
  }

  // ─── Additional Details ───────────────────────────────────────────────────

  Widget _buildAdditionalDetails() {
    final data = _data!;
    final catColor = _categoryColor(data.category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Additional Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppConstants.textDark,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
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
              children: [
                // Category row
                _detailRow(
                  icon: Icon(_categoryIcon(data.category),
                      size: 20, color: catColor),
                  label: 'Category',
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      data.category,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: catColor,
                      ),
                    ),
                  ),
                ),
                const Divider(color: Color(0xFFE0E0E0), height: 1),

                // Payment method row
                _detailRow(
                  icon: Text(_paymentIcon(data.paymentMethod),
                      style: const TextStyle(fontSize: 18)),
                  label: 'Payment Method',
                  trailing: Text(
                    data.paymentMethod,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppConstants.textDark,
                    ),
                  ),
                ),

                // Notes row
                if (_notes != null && _notes!.isNotEmpty) ...[
                  const Divider(color: Color(0xFFE0E0E0), height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notes_outlined,
                                size: 20, color: AppConstants.textMediumGray),
                            SizedBox(width: 8),
                            Text(
                              'Notes',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppConstants.textMediumGray,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _notes!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppConstants.textDark,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // AI confidence badge
                if (_aiConfidence != null) ...[
                  const Divider(color: Color(0xFFE0E0E0), height: 1),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outlined,
                              size: 16, color: AppConstants.primaryGreen),
                          const SizedBox(width: 6),
                          Text(
                            'Auto-extracted with ${(_aiConfidence! * 100).toInt()}% confidence',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppConstants.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A single detail row: icon – label – trailing widget.
  Widget _detailRow({
    required Widget icon,
    required String label,
    required Widget trailing,
  }) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(width: 28, child: Center(child: icon)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppConstants.textMediumGray,
            ),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }

  // ─── Timestamps Section ───────────────────────────────────────────────────

  Widget _buildTimestamps() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Timestamps',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppConstants.textMediumGray,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusMedium),
              border: const Border(
                top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _timestampRow(Icons.access_time_outlined, 'Created',
                    _formatShortDate(_createdAt)),
                if (_modifiedAt != null && _modifiedAt != _createdAt) ...[
                  const SizedBox(height: 4),
                  _timestampRow(Icons.edit_outlined, 'Modified',
                      _formatShortDate(_modifiedAt)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timestampRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppConstants.textLightGray),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppConstants.textLightGray,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: AppConstants.textMediumGray,
          ),
        ),
      ],
    );
  }

}

// ═════════════════════════════════════════════════════════════════════════════
// RECEIPT IMAGE FULL-SCREEN MODAL
// ═════════════════════════════════════════════════════════════════════════════

/// Full-screen overlay for viewing a receipt image with pinch-to-zoom.
class _ReceiptImageModal extends StatelessWidget {
  const _ReceiptImageModal({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Zoomable image ──
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // ── Close button (top-left) ──
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ),
            ),

            // ── Share button (top-right, optional) ──
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.share_outlined,
                      color: Colors.white, size: 22),
                  onPressed: () {
                    // TODO: Implement share functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  tooltip: 'Share',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
