/// Manual Expense Entry & Correction Form — full-featured expense editor.
///
/// Serves four entry points:
///   1. **New manual entry** — empty form from FAB → "Manual Entry"
///   2. **AI pre-filled** — from Extraction Results → "Edit Details"
///      (receives [ExpenseEntryArgs] with [ExtractedReceiptData])
///   3. **Edit existing** — from Expenses list (receives [ExpenseEntryArgs]
///      with an existing expense id — to be wired once SQLite is in place)
///   4. **Empty from Expenses tab** — same as #1
///
/// Features:
///   - Merchant name with autocomplete suggestions
///   - Date picker (no future dates)
///   - Category bottom-sheet selector (8 categories with icons)
///   - Dynamic items list (add / delete / auto-subtotal)
///   - Payment method choice chips
///   - Notes field with character counter
///   - Auto-calculated total amount card
///   - Real-time validation with inline error messages
///   - Sticky bottom action bar (Cancel / Save)
///   - Unsaved-changes guard on back / cancel
///   - Staggered entrance animations
///   - Delete support in edit mode
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/expense.dart';
import '../models/extracted_receipt_data.dart';
import '../services/currency_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

// ─── Route Arguments ──────────────────────────────────────────────────────────

/// Packages optional arguments for the expense-entry route.
///
/// - [extractedData]: Pre-fill the form from AI extraction results.
/// - [isEditMode]: If true, shows "Edit Expense" title & delete action.
/// - [existingExpenseId]: ID for loading / updating an existing expense (SQLite).
class ExpenseEntryArgs {
  final ExtractedReceiptData? extractedData;
  final bool isEditMode;
  final String? existingExpenseId;

  const ExpenseEntryArgs({
    this.extractedData,
    this.isEditMode = false,
    this.existingExpenseId,
  });
}

// ─── Item model used only inside this form ────────────────────────────────────

/// Lightweight model for each line-item row in the form.
class _FormItem {
  final TextEditingController nameCtrl; // Item name 
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final GlobalKey<FormFieldState<String>> nameKey;
  final GlobalKey<FormFieldState<String>> qtyKey;
  final GlobalKey<FormFieldState<String>> priceKey;

  _FormItem()
      : nameCtrl = TextEditingController(),
        qtyCtrl = TextEditingController(text: '1'), // default quantity is 1
        priceCtrl = TextEditingController(),
        nameKey = GlobalKey<FormFieldState<String>>(),
        qtyKey = GlobalKey<FormFieldState<String>>(),
        priceKey = GlobalKey<FormFieldState<String>>();

  _FormItem.fromExtracted(ExtractedItem item)
      : nameCtrl = TextEditingController(text: item.name),
        qtyCtrl = TextEditingController(
          text: item.quantity.toStringAsFixed(
              item.quantity.truncateToDouble() == item.quantity ? 0 : 1),
        ),
        priceCtrl = TextEditingController(
          text: item.unitPrice > 0 ? item.unitPrice.toStringAsFixed(2) : '',
        ),
        nameKey = GlobalKey<FormFieldState<String>>(),
        qtyKey = GlobalKey<FormFieldState<String>>(),
        priceKey = GlobalKey<FormFieldState<String>>();

  double get quantity => double.tryParse(qtyCtrl.text) ?? 0;
  double get unitPrice => double.tryParse(priceCtrl.text) ?? 0;
  double get subtotal => quantity * unitPrice;

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class ExpenseEntryScreen extends StatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen>
    with TickerProviderStateMixin {
  // ─── Form ─────────────────────────────────────────────────────────────────

  final _formKey = GlobalKey<FormState>();

  final _merchantCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _merchantFocus = FocusNode();
  final _notesFocus = FocusNode();

  DateTime? _selectedDate;
  String _selectedCategory = 'Others';
  String _paymentMethod = 'Cash';

  /// Dynamic list of item rows.
  final List<_FormItem> _items = [];

  // ─── Mode Flags ───────────────────────────────────────────────────────────

  bool _isEditMode = false;
  bool _isPreFilled = false;
  bool _isSaving = false;
  bool _formDirty = false; // tracks unsaved changes
  bool _argsRead = false;

  String? _existingExpenseId;
  ExtractedReceiptData? _extractedData;

  // ─── Autocomplete Suggestions ─────────────────────────────────────────────

  /// In production this would come from SQLite; for now use demo data.
  static const _merchantSuggestions = [
    'Metro Supermarket',
    'McDonald\'s',
    'Starbucks',
    'Walmart',
    'Amazon',
    'Target',
    'CVS Pharmacy',
    'Shell Gas Station',
    'Uber Eats',
    'Netflix',
  ];

  // ─── Animation ────────────────────────────────────────────────────────────

  late AnimationController _staggerCtrl;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Start with one empty item row.
    _items.add(_FormItem());

    // Mark form as dirty on any text change.
    _merchantCtrl.addListener(_markDirty);
    _notesCtrl.addListener(_markDirty);
  }

  @override
  void didChangeDependencies() { 
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;  

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ExpenseEntryArgs) {
      _isEditMode = args.isEditMode;
      _existingExpenseId = args.existingExpenseId;

      if (args.extractedData != null) {
        _extractedData = args.extractedData;
        _prefillFromExtraction(args.extractedData!);
        _isPreFilled = true;
      }
    }

    // Kick entrance animations after build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _staggerCtrl.forward();
    });
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _notesCtrl.dispose();
    _merchantFocus.dispose();
    _notesFocus.dispose();
    _staggerCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  // ─── Pre-fill ─────────────────────────────────────────────────────────────

  void _prefillFromExtraction(ExtractedReceiptData data) {
    _merchantCtrl.text = data.merchantName;
    _selectedDate = data.date;
    _selectedCategory = data.category;
    _paymentMethod = data.paymentMethod;

    // Replace the default empty item with extracted items.
    for (final item in _items) {
      item.dispose();
    }
    _items.clear();

    if (data.items.isNotEmpty) {
      for (final extracted in data.items) {
        _items.add(_FormItem.fromExtracted(extracted));
      }
    } else {
      _items.add(_FormItem());
    }

    // Listen to new item controllers.
    for (final item in _items) {
      item.nameCtrl.addListener(_markDirty);
      item.qtyCtrl.addListener(_onItemChanged);
      item.priceCtrl.addListener(_onItemChanged);
    }

    _formDirty = false; // initial load is not a user change
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _markDirty() {
    if (!_formDirty) setState(() => _formDirty = true);
  }

  void _onItemChanged() {
    _markDirty();
    setState(() {}); // refresh total
  }

  /// Calculates the sum of all item subtotals.
  double get _totalAmount {
    double total = 0;
    for (final item in _items) {
      total += item.subtotal;
    }
    return total;
  }

  /// Whether all required fields are filled enough to enable Save.
  bool get _canSave {
    if (_merchantCtrl.text.trim().length < 2) return false;
    if (_selectedDate == null) return false;
    if (_items.isEmpty) return false;
    for (final item in _items) {
      if (item.nameCtrl.text.trim().isEmpty) return false;
      if (item.quantity < 1) return false;
      if (item.unitPrice <= 0) return false;
    }
    return _totalAmount > 0;
  }

  // ─── Item Management ──────────────────────────────────────────────────────

  void _addItem() {
    final item = _FormItem();
    item.nameCtrl.addListener(_markDirty);
    item.qtyCtrl.addListener(_onItemChanged);
    item.priceCtrl.addListener(_onItemChanged);
    setState(() => _items.add(item));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return; // keep at least one
    setState(() {
      _items[index].dispose();
      _items.removeAt(index); // remove item from list and refresh total
    });
    _onItemChanged();
  }

  // ─── Date Picker ──────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
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
        _selectedDate = picked;
        _formDirty = true;
      });
    }
  }

  // ─── Category Picker ──────────────────────────────────────────────────────

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.borderRadiusLarge),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
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
                    color: AppConstants.textDark,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                ...AppConstants.expenseCategories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _catColor(cat).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_catIcon(cat),
                          color: _catColor(cat), size: 20),
                    ),
                    title: Text(
                      cat,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? AppConstants.primaryGreen
                            : AppConstants.textDark,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: AppConstants.primaryGreen, size: 22)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                        _formDirty = true;
                      });
                      Navigator.pop(ctx);
                    },
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

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_canSave || _isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final expenseItems = _items
        .map((f) => ExpenseItem(
              name: f.nameCtrl.text.trim(),
              quantity: f.quantity,
              unitPrice: f.unitPrice,
              subtotal: f.subtotal,
            ))
        .toList();

    final expense = Expense(
      id: _isEditMode ? _existingExpenseId : null,
      merchantName: _merchantCtrl.text.trim(),
      category: _selectedCategory,
      totalAmount: _totalAmount,
      date: _selectedDate!,
      paymentMethod: _paymentMethod,
      notes: _notesCtrl.text.trim(),
      imagePath: _extractedData?.imagePath ?? '',
      aiConfidence: _isPreFilled ? _extractedData?.totalConfidence : null,
      createdAt: now,
      modifiedAt: now,
      items: expenseItems,
    );

    try {
      if (_isEditMode && _existingExpenseId != null) {
        await DatabaseService.instance.updateExpense(expense);
      } else {
        await DatabaseService.instance.insertExpense(expense);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save expense. Please try again.'),
          backgroundColor: AppConstants.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    Navigator.popUntil(context, (route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isEditMode
                    ? 'Expense updated successfully!'
                    : 'Expense saved successfully!',
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Delete (edit mode only) ──────────────────────────────────────────────

  Future<void> _deleteExpense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        title: const Text('Delete this expense?'),
        content: const Text(
          'This action cannot be undone. The expense will be permanently removed.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_existingExpenseId != null) {
      await DatabaseService.instance.deleteExpense(_existingExpenseId!);
    }
    if (!mounted) return;

    Navigator.popUntil(context, (route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Expense deleted')),
          ],
        ),
        backgroundColor: AppConstants.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
      ),
    );
  }

  // ─── Unsaved-changes guard ────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (!_formDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. If you leave now, your changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMedium,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pre-fill badge
                      if (_isPreFilled) _buildPreFillBadge(),

                      const SizedBox(height: AppConstants.paddingSmall),

                      // ── Form fields (staggered) ──
                      _stagger(0, _buildMerchantField()),
                      _stagger(1, _buildDateField()),
                      _stagger(2, _buildCategoryField()),
                      _stagger(3, _buildItemsSection()),
                      _stagger(4, _buildPaymentMethodField()),
                      _stagger(5, _buildNotesField()),
                      _stagger(6, _buildTotalCard()),

                      const SizedBox(height: AppConstants.paddingMedium),
                    ],
                  ),
                ),
              ),

              // ── Sticky bottom actions ──
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Stagger animation helper ─────────────────────────────────────────────

  Widget _stagger(int index, Widget child) {
    final begin = (index * 0.08).clamp(0.0, 0.6);
    final end = (begin + 0.4).clamp(0.0, 1.0);

    final slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    ));
    final fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(begin, end, curve: Curves.easeIn),
    ));

    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: fade, child: child),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppConstants.backgroundColor,
      foregroundColor: AppConstants.textDark,
      title: Text(
        _isEditMode ? 'Edit Expense' : 'Add Expense',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () async {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) Navigator.of(context).pop();
        },
      ),
      actions: [
        if (_isEditMode)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppConstants.errorRed),
            tooltip: 'Delete expense',
            onPressed: _deleteExpense,
          ),
      ],
    );
  }

  // ─── Pre-fill badge ───────────────────────────────────────────────────────

  Widget _buildPreFillBadge() {
    return Container(
      margin: const EdgeInsets.only(top: AppConstants.paddingSmall),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 16, color: AppConstants.primaryGreen),
          SizedBox(width: 6),
          Text(
            'Auto-filled from receipt',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppConstants.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1 ─ MERCHANT NAME
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMerchantField() {
    return _fieldWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Merchant Name', required: true),
          const SizedBox(height: 8),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: _merchantCtrl.text),
            optionsBuilder: (value) {
              if (value.text.isEmpty) return const [];
              return _merchantSuggestions.where(
                (s) => s.toLowerCase().contains(value.text.toLowerCase()),
              );
            },
            onSelected: (value) {
              _merchantCtrl.text = value;
              _markDirty();
            },
            fieldViewBuilder: (context, ctrl, focus, onSubmit) {
              // Sync the external controller.
              ctrl.addListener(() {
                if (_merchantCtrl.text != ctrl.text) {
                  _merchantCtrl.text = ctrl.text;
                }
              });
              return TextFormField(
                controller: ctrl,
                focusNode: focus,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  hint: 'e.g., Walmart, McDonald\'s, Clinic',
                  icon: Icons.store_outlined,
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Merchant name is required';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => onSubmit(),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusSmall),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (ctx, i) {
                        final opt = options.elementAt(i);
                        return InkWell(
                          onTap: () => onSelected(opt),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Text(opt,
                                style: const TextStyle(fontSize: 15)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2 ─ DATE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDateField() {
    final display = _selectedDate != null
        ? DateFormat('dd MMM yyyy').format(_selectedDate!)
        : '';

    return _fieldWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Date', required: true),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: TextFormField(
                decoration: _inputDecoration(
                  hint: 'Select date',
                  icon: Icons.calendar_today_outlined,
                  suffixIcon: Icons.arrow_drop_down,
                ),
                controller: TextEditingController(text: display),
                validator: (_) {
                  if (_selectedDate == null) return 'Date is required';
                  if (_selectedDate!.isAfter(DateTime.now())) {
                    return 'Date cannot be in the future';
                  }
                  return null;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3 ─ CATEGORY
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCategoryField() {
    return _fieldWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Category', required: true),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showCategoryPicker,
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusSmall),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _catColor(_selectedCategory).withValues(alpha: 0.06),
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
                border: Border.all(
                  color:
                      _catColor(_selectedCategory).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(_catIcon(_selectedCategory),
                      size: 24, color: _catColor(_selectedCategory)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedCategory,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _catColor(_selectedCategory),
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down,
                      color: AppConstants.textMediumGray.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4 ─ ITEMS LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildItemsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      padding: const EdgeInsets.all(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Items', required: true),
          const SizedBox(height: 12),

          // Item cards
          ...List.generate(_items.length, (i) => _buildItemCard(i)),

          const SizedBox(height: 8),

          // + Add Item button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon( 
              onPressed: _addItem, // add new item row
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Add Item'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.primaryGreen,
                side: const BorderSide(color: AppConstants.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusSmall),
                ),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    final subtotal = item.subtotal;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius:
              BorderRadius.circular(AppConstants.borderRadiusSmall),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: item # + delete
            Row(
              children: [
                Text(
                  'Item ${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textMediumGray,
                  ),
                ),
                const Spacer(),
                if (_items.length > 1)
                  InkWell(
                    onTap: () => _removeItem(index),// delete item
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppConstants.errorRed.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 18, color: AppConstants.errorRed),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Item name
            TextFormField(
              key: item.nameKey,
              controller: item.nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                hint: 'e.g., Laptop, Apples, Antibiotics',
                icon: Icons.receipt_outlined,
                dense: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Item name required';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Quantity + Price row
            Row(
              children: [
                // Quantity
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: item.qtyKey,
                    controller: item.qtyCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration(
                      hint: 'Qty',
                      icon: Icons.numbers,
                      dense: true,
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) return 'Min 1';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Unit price
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: item.priceKey,
                    controller: item.priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: _inputDecoration(
                      hint: 'Unit Price',
                      icon: Icons.attach_money,
                      dense: true,
                    ),
                    validator: (v) {
                      final p = double.tryParse(v ?? '');
                      if (p == null || p <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            // Subtotal
            if (subtotal > 0) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Subtotal: ${CurrencyService.instance.format(subtotal)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.primaryGreen,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5 ─ PAYMENT METHOD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPaymentMethodField() {// not really a "field" but more of a selection chip group
    const methods = <String, IconData>{
      'Cash': Icons.money,
      'Card': Icons.credit_card,
      'Digital Wallet': Icons.account_balance_wallet_outlined,
      'Other': Icons.more_horiz,
    };

    return _fieldWrapper( 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Payment Method'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: methods.entries.map((e) {
              final selected = _paymentMethod == e.key;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(e.value,
                        size: 18,
                        color: selected
                            ? AppConstants.primaryGreen
                            : AppConstants.textMediumGray),
                    const SizedBox(width: 6),
                    Text(e.key),
                  ],
                ),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _paymentMethod = e.key;
                    _formDirty = true;
                  });
                },
                selectedColor:
                    AppConstants.primaryGreen.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? AppConstants.primaryGreen
                      : AppConstants.textDark,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusSmall),
                  side: BorderSide(
                    color: selected
                        ? AppConstants.primaryGreen
                        : const Color(0xFFE0E0E0),
                  ),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 6 ─ NOTES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildNotesField() {
    return _fieldWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _label('Notes'),
              const SizedBox(width: 6),
              const Text(
                '(Optional)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppConstants.textLightGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesCtrl,
            focusNode: _notesFocus,
            maxLines: null,
            minLines: 3,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: _inputDecoration(
              hint: 'Add any additional details, special notes, etc.',
              icon: Icons.note_outlined,
            ).copyWith(
              counterStyle: const TextStyle(
                fontSize: 10,
                color: AppConstants.textLightGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOTAL AMOUNT CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F6),
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(color: AppConstants.primaryGreen),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Total Amount',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppConstants.textDark,
            ),
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              CurrencyService.instance.format(_totalAmount),
              key: ValueKey<double>(_totalAmount),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppConstants.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM ACTIONS (sticky)
  // ═══════════════════════════════════════════════════════════════════════════

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
          // Cancel (outlined)
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      final shouldPop = await _onWillPop();
                      if (shouldPop && mounted) Navigator.of(context).pop();
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.textDark,
                side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusSmall),
                ),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text('Cancel'),
            ),
          ),

          const SizedBox(width: AppConstants.paddingSmall),

          // Save (filled)
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: (_canSave && !_isSaving) ? _save : null,
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
                disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Wraps a form section in a white card with shadow.
  Widget _fieldWrapper({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      padding: const EdgeInsets.all(12),
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
      child: child,
    );
  }

  /// Section label with optional red asterisk for required fields.
  Widget _label(String text, {bool required = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppConstants.textDark,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*',
              style: TextStyle(
                  color: AppConstants.errorRed,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  /// Standard themed [InputDecoration] for text form fields.
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    IconData? suffixIcon,
    bool dense = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppConstants.textLightGray,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: AppConstants.primaryGreen, size: 22),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: AppConstants.textMediumGray)
          : null,
      filled: true,
      fillColor: Colors.white,
      isDense: dense,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusSmall),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusSmall),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusSmall),
        borderSide: const BorderSide(
            color: AppConstants.primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusSmall),
        borderSide: const BorderSide(color: AppConstants.errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusSmall),
        borderSide:
            const BorderSide(color: AppConstants.errorRed, width: 2),
      ),
    );
  }

  // ─── Category helpers (shared with extraction results screen) ─────────────

  IconData _catIcon(String cat) {
    switch (cat) {
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

  Color _catColor(String cat) {
    switch (cat) {
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
