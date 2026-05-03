/// Split Bill Screen — lets the current user split a Food/Restaurant expense
/// with other Spendly users by searching their registered email addresses.
///
/// Entry point: pushed from [ExpenseEntryScreen] via [AppConstants.splitBillRoute]
/// with [SplitBillArgs] as route arguments.
///
/// Flow:
///   1. User picks a split count (2–10) with the stepper.
///   2. User types an email → live prefix-matched suggestions from Firestore.
///   3. Tapping a suggestion adds the person as a chip (capped at splitCount - 1).
///   4. "Split & Send" saves the initiator's share as an expense and creates
///      a split request that recipients see in their Home screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/expense.dart';
import '../models/user_profile.dart';
import '../services/currency_service.dart';
import '../services/split_bill_service.dart';
import '../utils/constants.dart';

// ─── Route arguments ──────────────────────────────────────────────────────────

class SplitBillArgs {
  final String merchant;
  final String category;
  final double totalAmount;
  final DateTime date;
  final String paymentMethod;
  final String notes;
  final String imagePath;
  final double? aiConfidence;
  final List<ExpenseItem> items;

  const SplitBillArgs({
    required this.merchant,
    required this.category,
    required this.totalAmount,
    required this.date,
    required this.paymentMethod,
    this.notes = '',
    this.imagePath = '',
    this.aiConfidence,
    required this.items,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  // ─── Args ─────────────────────────────────────────────────────────────────
  SplitBillArgs? _args;
  bool _argsRead = false;

  // ─── Email input ──────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();

  // ─── State ────────────────────────────────────────────────────────────────
  int _splitCount = 2; // min 2, max 10; user sets this explicitly
  final List<UserProfile> _selectedUsers = [];
  List<UserProfile> _suggestions = [];
  bool _loadingSuggestions = false;
  bool _isSending = false;
  String? _searchError;

  Timer? _debounce;

  // ─── Computed ─────────────────────────────────────────────────────────────

  int get _maxRecipients => _splitCount - 1;
  bool get _recipientsFull => _selectedUsers.length >= _maxRecipients;

  double get _amountEach =>
      _args == null ? 0 : _args!.totalAmount / _splitCount;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    _args = ModalRoute.of(context)?.settings.arguments as SplitBillArgs?;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Split count stepper ──────────────────────────────────────────────────

  void _decreaseSplit() {
    if (_splitCount <= 2) return;
    setState(() {
      _splitCount--;
      // Remove excess recipients if count dropped below current selections
      while (_selectedUsers.length > _maxRecipients) {
        _selectedUsers.removeLast();
      }
      _suggestions = [];
      _searchError = null;
    });
  }

  void _increaseSplit() {
    if (_splitCount >= 10) return;
    setState(() => _splitCount++);
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  void _onEmailChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _searchError = null;
      if (value.trim().isEmpty) {
        _suggestions = [];
        _loadingSuggestions = false;
        return;
      }
      _loadingSuggestions = true;
    });

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      List<UserProfile> results = [];
      String? error;
      try {
        results = await SplitBillService.instance.searchUsers(value.trim());
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('permission-denied') || msg.contains('permission_denied')) {
          error = 'Search not set up yet. Ask the admin to configure Firestore rules.';
        } else if (msg.contains('unavailable') || msg.contains('network')) {
          error = 'No internet connection. Please check your network.';
        } else {
          error = 'Search failed. Please try again.';
        }
      }

      if (!mounted) return;

      final filtered = results
          .where((u) => !_selectedUsers.any((s) => s.uid == u.uid))
          .toList();

      setState(() {
        _suggestions = filtered;
        _loadingSuggestions = false;
        if (error != null) {
          _searchError = error;
        } else if (filtered.isEmpty && value.trim().isNotEmpty) {
          _searchError = 'No Spendly account found for this email.';
        }
      });
    });
  }

  void _addUser(UserProfile user) {
    if (_selectedUsers.any((u) => u.uid == user.uid)) return;
    if (_recipientsFull) return;
    setState(() {
      _selectedUsers.add(user);
      _suggestions = [];
      _searchError = null;
      _emailCtrl.clear();
    });
    _emailFocus.requestFocus();
  }

  void _removeUser(UserProfile user) {
    setState(() => _selectedUsers.removeWhere((u) => u.uid == user.uid));
  }

  // ─── Split & Send ─────────────────────────────────────────────────────────

  Future<void> _send() async {
    if (_selectedUsers.isEmpty || _isSending || _args == null) return;
    setState(() => _isSending = true);

    try {
      await SplitBillService.instance.createSplitRequest(
        merchant: _args!.merchant,
        category: _args!.category,
        date: _args!.date,
        paymentMethod: _args!.paymentMethod,
        notes: _args!.notes,
        imagePath: _args!.imagePath,
        aiConfidence: _args!.aiConfidence,
        items: _args!.items,
        originalTotal: _args!.totalAmount,
        recipients: _selectedUsers,
        splitCount: _splitCount,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send split: $e'),
          backgroundColor: AppConstants.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.call_split, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Bill split $_splitCount ways and sent!'),
            ),
          ],
        ),
        backgroundColor: AppConstants.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_args == null) {
      return const Scaffold(
        body: Center(child: Text('Missing split bill data.')),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReceiptCard(),
                  const SizedBox(height: AppConstants.paddingMedium),
                  _buildSplitCountSelector(),
                  const SizedBox(height: AppConstants.paddingMedium),
                  _buildToField(),
                  if (_loadingSuggestions) _buildLoadingRow(),
                  if (!_loadingSuggestions && _suggestions.isNotEmpty)
                    _buildSuggestionsList(),
                  if (!_loadingSuggestions &&
                      _suggestions.isEmpty &&
                      _searchError != null)
                    _buildSearchError(),
                  const SizedBox(height: AppConstants.paddingMedium),
                  if (_selectedUsers.isNotEmpty) _buildSplitSummary(),
                ],
              ),
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Split Bill',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  // ─── Receipt card ─────────────────────────────────────────────────────────

  Widget _buildReceiptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppConstants.primaryGreen, AppConstants.darkGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryGreen.withValues(alpha: 0.3),
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
              const Icon(Icons.restaurant_outlined,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _args!.merchant,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd MMM yyyy').format(_args!.date),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Total Bill',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Text(
                CurrencyService.instance.format(_args!.totalAmount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Split count stepper ──────────────────────────────────────────────────

  Widget _buildSplitCountSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.call_split,
              size: 20, color: AppConstants.primaryGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Split how many ways?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          // Decrease button
          _StepperButton(
            icon: Icons.remove,
            enabled: _splitCount > 2,
            onTap: _decreaseSplit,
          ),
          const SizedBox(width: 12),
          // Count display
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Text(
              '$_splitCount',
              key: ValueKey(_splitCount),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppConstants.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Increase button
          _StepperButton(
            icon: Icons.add,
            enabled: _splitCount < 10,
            onTap: _increaseSplit,
          ),
        ],
      ),
    );
  }

  // ─── To: field ────────────────────────────────────────────────────────────

  Widget _buildToField() {
    final remaining = _maxRecipients - _selectedUsers.length;
    final isFull = _recipientsFull;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(
          color: _emailFocus.hasFocus
              ? AppConstants.primaryGreen
              : const Color(0xFFE0E0E0),
          width: _emailFocus.hasFocus ? 2 : 1,
        ),
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
          // "To:" label row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Text(
                  'To:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isFull
                        ? 'All $_maxRecipients ${_maxRecipients == 1 ? 'person' : 'people'} added'
                        : 'Add $remaining more ${remaining == 1 ? 'person' : 'people'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isFull
                          ? AppConstants.primaryGreen
                          : Theme.of(context).colorScheme.outline,
                      fontWeight:
                          isFull ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (_selectedUsers.isNotEmpty)
                  Text(
                    '${_selectedUsers.length}/$_maxRecipients',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppConstants.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          // Chips row
          if (_selectedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    _selectedUsers.map((u) => _buildUserChip(u)).toList(),
              ),
            ),

          // Search input — hidden when recipients full
          if (!isFull)
            TextField(
              controller: _emailCtrl,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type email address...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppConstants.primaryGreen,
                  size: 20,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
              onChanged: _onEmailChanged,
              onSubmitted: (_) {
                if (_suggestions.length == 1) _addUser(_suggestions.first);
              },
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildUserChip(UserProfile user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppConstants.primaryGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppConstants.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              user.displayName.isNotEmpty ? user.displayName : user.email,
              style: const TextStyle(
                fontSize: 13,
                color: AppConstants.primaryGreen,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeUser(user),
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppConstants.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Suggestions list ─────────────────────────────────────────────────────

  Widget _buildLoadingRow() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppConstants.primaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Searching...',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: _suggestions.asMap().entries.map((entry) {
          final i = entry.key;
          final user = entry.value;
          return Column(
            children: [
              InkWell(
                onTap: () => _addUser(user),
                borderRadius: BorderRadius.vertical(
                  top: i == 0
                      ? const Radius.circular(
                          AppConstants.borderRadiusSmall)
                      : Radius.zero,
                  bottom: i == _suggestions.length - 1
                      ? const Radius.circular(
                          AppConstants.borderRadiusSmall)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppConstants.primaryGreen
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            user.initials,
                            style: const TextStyle(
                              color: AppConstants.primaryGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (user.displayName.isNotEmpty)
                              Text(
                                user.displayName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize:
                                    user.displayName.isNotEmpty ? 12 : 14,
                                color: user.displayName.isNotEmpty
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.add_circle_outline,
                        color: AppConstants.primaryGreen,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (i < _suggestions.length - 1)
                Divider(
                  height: 1,
                  indent: 58,
                  color: Colors.grey.withValues(alpha: 0.15),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchError() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _searchError!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Split summary ────────────────────────────────────────────────────────

  Widget _buildSplitSummary() {
    final names = [
      'You',
      ..._selectedUsers
          .map((u) => u.displayName.isNotEmpty ? u.displayName : u.email),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(
          color: AppConstants.primaryGreen.withValues(alpha: 0.3),
        ),
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
          Row(
            children: [
              const Icon(Icons.call_split,
                  size: 18, color: AppConstants.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Split $_splitCount ways',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            names.join(' · '),
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Each person pays',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                CurrencyService.instance.format(_amountEach),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Bottom actions ───────────────────────────────────────────────────────

  Widget _buildBottomActions() {
    final canSend = _selectedUsers.isNotEmpty && !_isSending;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppConstants.paddingMedium,
        AppConstants.paddingMedium,
        AppConstants.paddingMedium,
        AppConstants.paddingMedium + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
          Expanded(
            child: OutlinedButton(
              onPressed:
                  _isSending ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side:
                    const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
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

          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: canSend ? _send : null,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(_isSending ? 'Sending…' : 'Split & Send'),
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
}

// ─── Stepper button widget ────────────────────────────────────────────────────

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? AppConstants.primaryGreen.withValues(alpha: 0.12)
              : const Color(0xFFF0F0F0),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? AppConstants.primaryGreen
              : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
