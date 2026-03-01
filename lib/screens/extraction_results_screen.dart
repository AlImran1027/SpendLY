/// AI Extraction Results Screen — displays receipt data extracted by Gemini AI.
///
/// Shows:
///   - A compact receipt image thumbnail
///   - An extraction status banner (success / partial / failed)
///   - Editable field cards for Merchant, Date, Amount, Items, Category,
///     and Payment Method — each with a confidence badge
///   - Sticky bottom action buttons: "Edit Details" and "Save Expense"
///   - A loading skeleton state while extraction runs
///   - Staggered entrance animations for field cards
///
/// Receives the image file path as a route argument (String).
/// Generates simulated extraction data for now (Gemini integration TODO).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/extracted_receipt_data.dart';
import '../utils/constants.dart';
import 'expense_entry_screen.dart';

class ExtractionResultsScreen extends StatefulWidget {
  const ExtractionResultsScreen({super.key});

  @override
  State<ExtractionResultsScreen> createState() =>
      _ExtractionResultsScreenState();
}

class _ExtractionResultsScreenState extends State<ExtractionResultsScreen>
    with TickerProviderStateMixin {
  // ─── State ──────────────────────────────────────────────────────────────────

  /// Image path received via route arguments.
  late String _imagePath;

  /// The extracted receipt data model (populated after simulated extraction).
  ExtractedReceiptData? _data;

  /// True while the (simulated) Gemini extraction is running.
  bool _isExtracting = true;

  /// True while saving the expense to the database.
  bool _isSaving = false;

  /// The field key currently being edited, or null if none.
  String? _editingField;

  /// Whether the items list is expanded.
  bool _itemsExpanded = true;

  /// Controller for the extraction-failed retry.
  bool _extractionFailed = false;

  // ─── Text Editing Controllers (for inline edits) ────────────────────────────

  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();

  // ─── Animation ──────────────────────────────────────────────────────────────

  late AnimationController _staggerController;
  late AnimationController _bannerController;
  late Animation<Offset> _bannerSlide;
  late Animation<double> _bannerFade;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Banner slide-down animation.
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _bannerController, curve: Curves.easeOutCubic),
    );
    _bannerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bannerController, curve: Curves.easeIn),
    );

    // Stagger animation for cards (each card uses a delayed interval).
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _data == null) {
      _imagePath = args;
      _runExtraction();
    } else if (_data == null) {
      _imagePath = '';
      _runExtraction();
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _staggerController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  // ─── Extraction (Simulated) ─────────────────────────────────────────────────

  /// Simulates a Gemini API extraction call.
  ///
  /// In production this would send the image to the Generative AI SDK,
  /// parse the JSON response via [ExtractedReceiptData.fromJson], and
  /// populate the fields. For now we use sample data.
  Future<void> _runExtraction() async {
    setState(() {
      _isExtracting = true;
      _extractionFailed = false;
    });

    // Simulate network round-trip (2–3 seconds).
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    // TODO: Replace with real Gemini API call.
    final data = ExtractedReceiptData.sample(imagePath: _imagePath);

    setState(() {
      _data = data;
      _isExtracting = false;
    });

    // Kick off entrance animations.
    _bannerController.forward();
    _staggerController.forward();
  }

  /// Retries extraction after a failure.
  Future<void> _retryExtraction() async {
    await _runExtraction();
  }

  // ─── Inline Editing Helpers ─────────────────────────────────────────────────

  void _startEditing(String field) {
    final data = _data;
    if (data == null) return;

    switch (field) {
      case 'merchant':
        _merchantController.text = data.merchantName;
      case 'amount':
        _amountController.text = data.totalAmount.toStringAsFixed(2);
      case 'date':
        _dateController.text =
            data.date != null ? DateFormat('dd MMM yyyy').format(data.date!) : '';
    }
    setState(() => _editingField = field);
  }

  void _confirmEdit(String field) {
    final data = _data;
    if (data == null) return;

    setState(() {
      switch (field) {
        case 'merchant':
          data.merchantName = _merchantController.text.trim();
          data.merchantConfidence = 1.0; // user-verified
        case 'amount':
          final parsed = double.tryParse(_amountController.text.trim());
          if (parsed != null && parsed > 0) {
            data.totalAmount = parsed;
            data.totalConfidence = 1.0;
          }
        case 'date':
          // Date editing uses a date picker instead of text input.
          break;
      }
      _editingField = null;
    });
  }

  void _cancelEdit() {
    setState(() => _editingField = null);
  }

  /// Shows a date picker and updates the date field.
  Future<void> _pickDate() async {
    final data = _data;
    if (data == null) return;

    final now = DateTime.now();
    final initial = data.date ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppConstants.primaryGreen,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        data.date = picked;
        data.dateConfidence = 1.0;
        _editingField = null;
      });
    }
  }

  /// Updates the selected category.
  void _selectCategory(String category) {
    final data = _data;
    if (data == null) return;
    setState(() {
      data.category = category;
      data.categoryConfidence = 1.0;
    });
    Navigator.pop(context); // close bottom sheet
  }

  /// Updates the selected payment method.
  void _selectPaymentMethod(String method) {
    final data = _data;
    if (data == null) return;
    setState(() {
      data.paymentMethod = method;
      data.paymentMethodConfidence = 1.0;
    });
  }

  // ─── Save ───────────────────────────────────────────────────────────────────

  bool get _canSave {
    final d = _data;
    if (d == null) return false;
    return d.merchantName.trim().length >= 2 &&
        d.date != null &&
        d.totalAmount > 0;
  }

  Future<void> _saveExpense() async {
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);

    // TODO: Save to SQLite via ExpenseDao.
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    setState(() => _isSaving = false);

    // Pop back to home and show success snackbar.
    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('Expense saved successfully!')),
            ],
          ),
          backgroundColor: AppConstants.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusSmall),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ─── Back-press guard ───────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (_data == null) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        title: const Text('Discard Extraction?'),
        content: const Text(
          'If you go back, the extracted data will be lost. '
          'Are you sure you want to discard?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.errorRed,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(),
        body: _isExtracting ? _buildLoadingState() : _buildContent(),
        bottomNavigationBar:
            _isExtracting ? null : _buildBottomActions(),
      ),
    );
  }

  // ─── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppConstants.backgroundColor,
      foregroundColor: AppConstants.textDark,
      title: const Text(
        'Extracted Details',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () async {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) Navigator.of(context).pop();
        },
      ),
      actions: [
        if (_extractionFailed || (_data?.status == ExtractionStatus.failed))
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Retry extraction',
            onPressed: _retryExtraction,
          ),
      ],
    );
  }

  // ─── Loading / Skeleton State ───────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shimmer receipt icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Opacity(opacity: value, child: child);
              },
              onEnd: () {},
              child: Icon(
                Icons.document_scanner_rounded,
                size: 64,
                color: AppConstants.primaryGreen.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            const Text(
              'Extracting receipt details…',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppConstants.textDark,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            const Text(
              'This may take a few seconds',
              style: TextStyle(
                fontSize: 13,
                color: AppConstants.textMediumGray,
              ),
            ),
            const SizedBox(height: AppConstants.paddingXLarge),
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  color: AppConstants.primaryGreen,
                  backgroundColor: Color(0xFFE8F5E9),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingXXLarge),
            // Skeleton cards
            ..._buildSkeletons(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSkeletons() {
    return List.generate(3, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusSmall),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: 120,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      );
    });
  }

  // ─── Main Content ───────────────────────────────────────────────────────────

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Receipt thumbnail
          _buildThumbnail(),

          // 2. Status banner
          _buildStatusBanner(),

          const SizedBox(height: 4),

          // 3. Field cards (staggered)
          _buildAnimatedCard(0, _buildMerchantCard()),
          _buildAnimatedCard(1, _buildDateCard()),
          _buildAnimatedCard(2, _buildAmountCard()),
          _buildAnimatedCard(3, _buildItemsCard()),
          _buildAnimatedCard(4, _buildCategoryCard()),
          _buildAnimatedCard(5, _buildPaymentMethodCard()),

          // Bottom spacing for sticky buttons
          const SizedBox(height: AppConstants.paddingLarge),
        ],
      ),
    );
  }

  /// Wraps a card widget with a staggered fade-in + slide-up animation.
  Widget _buildAnimatedCard(int index, Widget card) {
    final begin = index * 0.1;
    final end = (begin + 0.4).clamp(0.0, 1.0);

    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    ));

    final fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _staggerController,
      curve: Interval(begin, end, curve: Curves.easeIn),
    ));

    return SlideTransition(
      position: slideAnim,
      child: FadeTransition(opacity: fadeAnim, child: card),
    );
  }

  // ─── 1. Thumbnail ──────────────────────────────────────────────────────────

  Widget _buildThumbnail() {
    if (_imagePath.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.paddingMedium),
      child: GestureDetector(
        onTap: _showFullImage,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 120),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusSmall),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusSmall),
            child: Image.file(
              File(_imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, e, s) => Container(
                height: 80,
                color: const Color(0xFFF5F5F5),
                child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppConstants.textLightGray, size: 32),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens a full-screen modal to view the receipt image.
  void _showFullImage() {
    if (_imagePath.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Image.file(File(_imagePath), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. Status Banner ──────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    Color bg;
    Color fg;
    IconData icon;
    String text;

    switch (data.status) {
      case ExtractionStatus.success:
        bg = const Color(0xFFE8F5E9);
        fg = AppConstants.primaryGreen;
        icon = Icons.check_circle;
        text = 'Extraction successful';
      case ExtractionStatus.partial:
        bg = const Color(0xFFFFF3E0);
        fg = AppConstants.warningAmber;
        icon = Icons.warning_rounded;
        text = 'Some fields need review';
      case ExtractionStatus.failed:
        bg = const Color(0xFFFFEBEE);
        fg = AppConstants.errorRed;
        icon = Icons.error_rounded;
        text = 'Extraction failed. Please review manually';
    }

    return SlideTransition(
      position: _bannerSlide,
      child: FadeTransition(
        opacity: _bannerFade,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(
            top: AppConstants.paddingSmall,
            bottom: AppConstants.paddingSmall,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusSmall),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                      color: fg, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 3. Merchant Card ──────────────────────────────────────────────────────

  Widget _buildMerchantCard() {
    final data = _data!;
    final isEditing = _editingField == 'merchant';

    return _fieldCard(
      label: 'Merchant Name',
      confidence: data.merchantConfidence,
      isRequired: true,
      isEmpty: data.merchantName.trim().isEmpty,
      child: isEditing
          ? _inlineEditField(
              controller: _merchantController,
              keyboardType: TextInputType.text,
              onConfirm: () => _confirmEdit('merchant'),
              onCancel: _cancelEdit,
            )
          : _displayField(
              value: data.merchantName.isEmpty
                  ? 'Not detected. Tap to enter'
                  : data.merchantName,
              isPlaceholder: data.merchantName.isEmpty,
              onEditTap: () => _startEditing('merchant'),
            ),
    );
  }

  // ─── 4. Date Card ──────────────────────────────────────────────────────────

  Widget _buildDateCard() {
    final data = _data!;
    final formatted = data.date != null
        ? DateFormat('dd MMM yyyy').format(data.date!)
        : 'Not detected. Tap to enter';

    return _fieldCard(
      label: 'Date',
      confidence: data.dateConfidence,
      isRequired: true,
      isEmpty: data.date == null,
      child: _displayField(
        value: formatted,
        isPlaceholder: data.date == null,
        onEditTap: _pickDate,
      ),
    );
  }

  // ─── 5. Amount Card ────────────────────────────────────────────────────────

  Widget _buildAmountCard() {
    final data = _data!;
    final isEditing = _editingField == 'amount';
    final formatted = data.totalAmount > 0
        ? 'Rs. ${NumberFormat('#,##0.00').format(data.totalAmount)}'
        : 'Not detected. Tap to enter';

    return _fieldCard(
      label: 'Total Amount',
      confidence: data.totalConfidence,
      isRequired: true,
      isEmpty: data.totalAmount <= 0,
      child: isEditing
          ? _inlineEditField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onConfirm: () => _confirmEdit('amount'),
              onCancel: _cancelEdit,
            )
          : _displayField(
              value: formatted,
              isPlaceholder: data.totalAmount <= 0,
              isAmount: data.totalAmount > 0,
              onEditTap: () => _startEditing('amount'),
            ),
    );
  }

  // ─── 6. Items Card ─────────────────────────────────────────────────────────

  Widget _buildItemsCard() {
    final data = _data!;

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusSmall),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row (collapsible)
          InkWell(
            onTap: () =>
                setState(() => _itemsExpanded = !_itemsExpanded),
            borderRadius: BorderRadius.circular(
                AppConstants.borderRadiusSmall),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryGreen
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${data.items.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.primaryGreen,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _itemsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more,
                        color: AppConstants.textMediumGray),
                  ),
                ],
              ),
            ),
          ),

          // Items list
          AnimatedCrossFade(
            firstChild: _buildItemsList(data),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _itemsExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(ExtractedReceiptData data) {
    if (data.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'No items detected in receipt',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppConstants.textMediumGray,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Add item manually
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.primaryGreen,
                side: const BorderSide(color: AppConstants.primaryGreen),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          const Divider(height: 1),
          ...List.generate(data.items.length, (i) {
            final item = data.items[i];
            return Column(
              children: [
                if (i > 0)
                  Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                      indent: 4,
                      endIndent: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item details
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
                              '${item.quantity > 1 ? '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} × ' : ''}'
                              'Rs. ${NumberFormat('#,##0.00').format(item.unitPrice)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppConstants.textMediumGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Subtotal + confidence
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs. ${NumberFormat('#,##0.00').format(item.subtotal)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppConstants.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _confidenceBadge(item.confidence),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── 7. Category Card ──────────────────────────────────────────────────────

  Widget _buildCategoryCard() {
    final data = _data!;

    return _fieldCard(
      label: 'Category',
      confidence: data.categoryConfidence,
      child: InkWell(
        onTap: _showCategoryPicker,
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusSmall),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _categoryColor(data.category).withValues(alpha: 0.06),
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusSmall),
            border: Border.all(
              color: _categoryColor(data.category).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _categoryIcon(data.category),
                size: 24,
                color: _categoryColor(data.category),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.category,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _categoryColor(data.category),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppConstants.textMediumGray.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.borderRadiusLarge)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppConstants.textLightGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                const Text(
                  'Select Category',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textDark),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                ...AppConstants.expenseCategories.map((cat) {
                  final isSelected = _data?.category == cat;
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _categoryColor(cat)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_categoryIcon(cat),
                          color: _categoryColor(cat), size: 20),
                    ),
                    title: Text(
                      cat,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? AppConstants.primaryGreen
                            : AppConstants.textDark,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: AppConstants.primaryGreen, size: 22)
                        : null,
                    onTap: () => _selectCategory(cat),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusSmall),
                    ),
                  );
                }),
                const SizedBox(height: AppConstants.paddingSmall),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 8. Payment Method Card ────────────────────────────────────────────────

  Widget _buildPaymentMethodCard() {
    final data = _data!;
    const methods = ['Cash', 'Card', 'Digital Wallet', 'Other'];

    return _fieldCard(
      label: 'Payment Method',
      confidence: data.paymentMethodConfidence,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: methods.map((m) {
          final isSelected = data.paymentMethod == m;
          return ChoiceChip(
            label: Text(m),
            selected: isSelected,
            onSelected: (_) => _selectPaymentMethod(m),
            selectedColor:
                AppConstants.primaryGreen.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? AppConstants.primaryGreen
                  : AppConstants.textDark,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  AppConstants.borderRadiusSmall),
              side: BorderSide(
                color: isSelected
                    ? AppConstants.primaryGreen
                    : const Color(0xFFE0E0E0),
              ),
            ),
            showCheckmark: false,
            avatar: isSelected
                ? const Icon(Icons.check,
                    size: 16, color: AppConstants.primaryGreen)
                : null,
          );
        }).toList(),
      ),
    );
  }

  // ─── Reusable Field Card Wrapper ────────────────────────────────────────────

  Widget _fieldCard({
    required String label,
    required double confidence,
    required Widget child,
    bool isRequired = false,
    bool isEmpty = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: (isRequired && isEmpty)
            ? Border.all(color: AppConstants.errorRed.withValues(alpha: 0.5))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row with confidence badge
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textDark,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 4),
                const Text('*',
                    style: TextStyle(
                        color: AppConstants.errorRed, fontSize: 14)),
              ],
              const Spacer(),
              _confidenceBadge(confidence),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  // ─── Display Field (Read-Only) ──────────────────────────────────────────────

  Widget _displayField({
    required String value,
    bool isPlaceholder = false,
    bool isAmount = false,
    required VoidCallback onEditTap,
  }) {
    return InkWell(
      onTap: onEditTap,
      borderRadius:
          BorderRadius.circular(AppConstants.borderRadiusSmall),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius:
              BorderRadius.circular(AppConstants.borderRadiusSmall),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: isAmount ? 18 : 16,
                  fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
                  color: isPlaceholder
                      ? AppConstants.textMediumGray
                      : isAmount
                          ? AppConstants.primaryGreen
                          : AppConstants.textDark,
                  fontStyle:
                      isPlaceholder ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 20,
              color: AppConstants.textMediumGray.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Inline Edit Field ──────────────────────────────────────────────────────

  Widget _inlineEditField({
    required TextEditingController controller,
    required TextInputType keyboardType,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            autofocus: true,
            style: const TextStyle(fontSize: 16, color: AppConstants.textDark),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    AppConstants.borderRadiusSmall),
                borderSide:
                    const BorderSide(color: AppConstants.primaryGreen),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    AppConstants.borderRadiusSmall),
                borderSide: const BorderSide(
                    color: AppConstants.primaryGreen, width: 2),
              ),
            ),
            onSubmitted: (_) => onConfirm(),
          ),
        ),
        const SizedBox(width: 8),
        // Cancel
        InkWell(
          onTap: onCancel,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppConstants.errorRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, size: 18, color: AppConstants.errorRed),
          ),
        ),
        const SizedBox(width: 6),
        // Confirm
        InkWell(
          onTap: onConfirm,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppConstants.primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 18, color: AppConstants.primaryGreen),
          ),
        ),
      ],
    );
  }

  // ─── Confidence Badge ───────────────────────────────────────────────────────

  Widget _confidenceBadge(double confidence) {
    if (confidence <= 0) return const SizedBox.shrink();

    final percent = (confidence * 100).toInt();
    Color bg;
    if (confidence >= 0.9) {
      bg = AppConstants.primaryGreen;
    } else if (confidence >= 0.7) {
      bg = AppConstants.warningAmber;
    } else {
      bg = AppConstants.errorRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$percent%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─── Bottom Action Buttons ──────────────────────────────────────────────────

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppConstants.paddingMedium,
        AppConstants.paddingMedium,
        AppConstants.paddingMedium,
        AppConstants.paddingMedium + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Edit Details (outlined)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                      Navigator.pushNamed(
                        context,
                        AppConstants.expenseEntryRoute,
                        arguments: ExpenseEntryArgs(
                          extractedData: _data,
                        ),
                      );
                    },
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Edit Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.primaryGreen,
                side: const BorderSide(
                    color: AppConstants.primaryGreen, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusSmall),
                ),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(width: AppConstants.paddingSmall),

          // Save Expense (filled)
          Expanded(
            child: FilledButton.icon(
              onPressed: (_canSave && !_isSaving) ? _saveExpense : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 20),
              label: Text(_isSaving ? 'Saving…' : 'Save Expense'),
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.primaryGreen,
                disabledBackgroundColor:
                    AppConstants.primaryGreen.withValues(alpha: 0.4),
                foregroundColor: Colors.white,
                disabledForegroundColor:
                    Colors.white.withValues(alpha: 0.7),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusSmall),
                ),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Category Helpers ───────────────────────────────────────────────────────

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
}
