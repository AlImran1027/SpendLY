/// Change Password Screen — allows authenticated users to update their password.
///
/// Layout (top → bottom):
///   1. AppBar with back button and "Change Password" title
///   2. Security header (shield icon, heading, subtext)
///   3. Current password field with show/hide toggle
///   4. New password field with real-time strength indicator
///   5. Password strength bar (4 segments) + criteria checklist
///   6. Confirm password field with match validation
///   7. Info box with security guidance
///   8. Sticky bottom action bar (Cancel / Update Password)
///
/// States:
///   - **Default**: All fields empty, update button disabled
///   - **Partial**: Some fields filled, button still disabled
///   - **All Valid**: All filled + match + not same as current → button enabled
///   - **Loading**: Spinner on button, all inputs disabled
///   - **Success**: Modal overlay with check icon, auto-dismiss 3 s
///   - **Current Incorrect**: Error banner, form preserved
///   - **Same as Current**: Warning banner
///   - **Network Error**: Error banner with retry
///
/// Entry point: Profile Screen → "Change Password" option.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/custom_text_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with TickerProviderStateMixin {
  // ─── Form state ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;
  bool _formDirty = false;
  String? _errorMessage;
  _ErrorType _errorType = _ErrorType.general;

  // ─── Password strength ─────────────────────────────────────────────────────
  int _strengthScore = 0; // 0 – 4
  bool _hasLength = false;
  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasDigit = false;
  bool _hasSpecial = false;

  // ─── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _staggerCtrl;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _currentPwCtrl.addListener(_markDirty);
    _newPwCtrl.addListener(() {
      _markDirty();
      _evaluateStrength();
    });
    _confirmPwCtrl.addListener(_markDirty);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _staggerCtrl.forward();
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _markDirty() {
    if (!_formDirty) setState(() => _formDirty = true);
    setState(() {}); // rebuild to update button state
  }

  /// Evaluates the new password's strength and updates the score.
  void _evaluateStrength() {
    final pw = _newPwCtrl.text;
    _hasLength = pw.length >= 8;
    _hasUpper = pw.contains(RegExp(r'[A-Z]'));
    _hasLower = pw.contains(RegExp(r'[a-z]'));
    _hasDigit = pw.contains(RegExp(r'[0-9]'));
    _hasSpecial = pw.contains(RegExp(r'[!@#\$%\^&\*\(\)\-_=\+\[\]\{\}\|;:,.<>\?/]'));

    int score = 0;
    if (_hasLength) score++;
    if (_hasUpper && _hasLower) score++;
    if (_hasDigit) score++;
    if (_hasSpecial) score++;

    setState(() => _strengthScore = score);
  }

  String get _strengthLabel {
    if (_newPwCtrl.text.isEmpty) return '';
    switch (_strengthScore) {
      case 0:
        return 'Weak';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      default:
        return 'Strong';
    }
  }

  Color get _strengthColor {
    switch (_strengthScore) {
      case 0:
      case 1:
        return AppConstants.errorRed;
      case 2:
        return AppConstants.warningAmber;
      case 3:
        return AppConstants.infoBlue;
      default:
        return AppConstants.primaryGreen;
    }
  }

  /// Whether the Update Password button should be enabled.
  bool get _canSubmit {
    if (_isLoading) return false;
    if (_currentPwCtrl.text.isEmpty) return false;
    if (_newPwCtrl.text.isEmpty) return false;
    if (_confirmPwCtrl.text.isEmpty) return false;
    if (_newPwCtrl.text != _confirmPwCtrl.text) return false;
    if (_newPwCtrl.text.length < 6) return false;
    return true;
  }

  // ─── Validators ────────────────────────────────────────────────────────────

  String? _validateCurrent(String? value) {
    if (value == null || value.isEmpty) {
      return 'Current password is required';
    }
    return null;
  }

  String? _validateNew(String? value) {
    if (value == null || value.isEmpty) {
      return 'New password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (value == _currentPwCtrl.text) {
      return 'New password must be different from current';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your new password';
    }
    if (value != _newPwCtrl.text) {
      return "Passwords don't match";
    }
    return null;
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> _handleUpdate() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    // Extra check: new password same as current
    if (_newPwCtrl.text == _currentPwCtrl.text) {
      setState(() {
        _errorMessage =
            'New password must be different from your current password.';
        _errorType = _ErrorType.samePassword;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.changePassword(
        _currentPwCtrl.text,
        _newPwCtrl.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSuccessModal();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      _ErrorType errorType;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Current password is incorrect. Please try again.';
          errorType = _ErrorType.incorrectCurrent;
        case 'network-request-failed':
          message =
              'Connection error. Please check your internet and try again.';
          errorType = _ErrorType.network;
        default:
          message = 'Failed to update password (${e.code}). Please try again.';
          errorType = _ErrorType.general;
      }
      setState(() {
        _errorMessage = message;
        _errorType = errorType;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _errorType = _ErrorType.general;
        _isLoading = false;
      });
    }
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) {
        // Auto-dismiss after 3 seconds.
        Timer(const Duration(seconds: 3), () {
          if (ctx.mounted && Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
            if (mounted) Navigator.of(context).pop(true);
          }
        });

        return _SuccessModal(
          onBackToProfile: () {
            Navigator.of(ctx).pop(); // close dialog
            Navigator.of(context).pop(true); // return to profile
          },
        );
      },
    );
  }

  void _handleCancel() {
    if (_formDirty) {
      _showUnsavedChangesDialog();
    } else {
      Navigator.pop(context);
    }
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        title: Text(
          'Discard Changes?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'You have unsaved changes. Are you sure you want to leave?',
          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Stay',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  // ─── Stagger animation helpers ─────────────────────────────────────────────

  Animation<double> _fadeAt(int index) {
    final start = (index * 0.1).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );
  }

  Animation<Offset> _slideAt(int index) {
    final start = (index * 0.1).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
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

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_formDirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _formDirty) _showUnsavedChangesDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: _isLoading ? null : _handleCancel,
          ),
          title: Text(
            'Change Password',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingLarge,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppConstants.paddingMedium),

                          // ── 1. Security header ──
                          FadeTransition(
                            opacity: _fadeAt(0),
                            child: SlideTransition(
                              position: _slideAt(0),
                              child: _buildSecurityHeader(),
                            ),
                          ),

                          const SizedBox(height: AppConstants.paddingLarge),

                          // ── 2. Error / warning banner ──
                          if (_errorMessage != null) ...[
                            _buildErrorBanner(),
                            const SizedBox(height: AppConstants.paddingMedium),
                          ],

                          // ── 3. Current password ──
                          FadeTransition(
                            opacity: _fadeAt(1),
                            child: SlideTransition(
                              position: _slideAt(1),
                              child: _buildCurrentPasswordField(),
                            ),
                          ),

                          const SizedBox(height: AppConstants.paddingMedium),

                          // ── 4. New password ──
                          FadeTransition(
                            opacity: _fadeAt(2),
                            child: SlideTransition(
                              position: _slideAt(2),
                              child: _buildNewPasswordField(),
                            ),
                          ),

                          // ── 5. Strength indicator + criteria ──
                          if (_newPwCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: AppConstants.paddingSmall),
                            FadeTransition(
                              opacity: _fadeAt(2),
                              child: _buildStrengthIndicator(),
                            ),
                            const SizedBox(height: AppConstants.paddingSmall),
                            FadeTransition(
                              opacity: _fadeAt(2),
                              child: _buildCriteriaChecklist(),
                            ),
                          ],

                          const SizedBox(height: AppConstants.paddingMedium),

                          // ── 6. Confirm password ──
                          FadeTransition(
                            opacity: _fadeAt(3),
                            child: SlideTransition(
                              position: _slideAt(3),
                              child: _buildConfirmPasswordField(),
                            ),
                          ),

                          const SizedBox(height: AppConstants.paddingMedium),

                          // ── 7. Info box ──
                          FadeTransition(
                            opacity: _fadeAt(4),
                            child: SlideTransition(
                              position: _slideAt(4),
                              child: _buildInfoBox(),
                            ),
                          ),

                          // Bottom clearance for sticky buttons
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── 8. Sticky action buttons ──
              FadeTransition(
                opacity: _fadeAt(5),
                child: _buildActionBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Security Header ──────────────────────────────────────────────────────

  Widget _buildSecurityHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppConstants.lightGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 28,
              color: AppConstants.primaryGreen,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Text(
            'Update Your Password',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep your account secure with a strong password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error Banner ─────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    final isNetwork = _errorType == _ErrorType.network;
    final isSame = _errorType == _ErrorType.samePassword;

    final bgColor = isSame ? const Color(0xFFFFF3E0) : const Color(0xFFFFEBEE);
    final fgColor =
        isSame ? AppConstants.warningAmber : AppConstants.errorRed;
    final icon =
        isSame ? Icons.warning_amber_rounded : Icons.error_outline;

    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: const Offset(0, -1), end: Offset.zero),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, offset, child) {
        return FractionalTranslation(translation: offset, child: child);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          border: Border.all(color: fgColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: fgColor, size: 20),
            const SizedBox(width: AppConstants.paddingSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: fgColor, fontSize: 12),
                  ),
                  if (isNetwork) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() => _errorMessage = null);
                        _handleUpdate();
                      },
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: AppConstants.infoBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _errorMessage = null),
              child: Icon(Icons.close, color: fgColor, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Password Fields ──────────────────────────────────────────────────────

  Widget _buildCurrentPasswordField() {
    return CustomTextField(
      controller: _currentPwCtrl,
      label: 'Current Password *',
      hintText: 'Enter your current password',
      prefixIcon: Icons.lock_outline,
      obscureText: _obscureCurrent,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.next,
      validator: _validateCurrent,
      enabled: !_isLoading,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureCurrent
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 22,
        ),
        onPressed: () {
          setState(() => _obscureCurrent = !_obscureCurrent);
        },
      ),
    );
  }

  Widget _buildNewPasswordField() {
    return CustomTextField(
      controller: _newPwCtrl,
      label: 'New Password *',
      hintText: 'Create a strong password',
      prefixIcon: Icons.lock_outline,
      obscureText: _obscureNew,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.next,
      validator: _validateNew,
      enabled: !_isLoading,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureNew
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 22,
        ),
        onPressed: () {
          setState(() => _obscureNew = !_obscureNew);
        },
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    final matches = _confirmPwCtrl.text.isNotEmpty &&
        _confirmPwCtrl.text == _newPwCtrl.text;

    return CustomTextField(
      controller: _confirmPwCtrl,
      label: 'Confirm New Password *',
      hintText: 'Re-enter your new password',
      prefixIcon: Icons.lock_outline,
      obscureText: _obscureConfirm,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      validator: _validateConfirm,
      enabled: !_isLoading,
      onFieldSubmitted: (_) {
        if (_canSubmit) _handleUpdate();
      },
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (matches)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: const Icon(
                Icons.check_circle,
                color: AppConstants.primaryGreen,
                size: 22,
              ),
            ),
          IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 22,
            ),
            onPressed: () {
              setState(() => _obscureConfirm = !_obscureConfirm);
            },
          ),
        ],
      ),
    );
  }

  // ─── Strength Indicator ───────────────────────────────────────────────────

  Widget _buildStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4-segment bar
        Row(
          children: List.generate(4, (i) {
            final filled = i < _strengthScore;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: filled
                      ? _strengthColor
                      : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        // Label
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _strengthColor,
          ),
          child: Text(_strengthLabel),
        ),
      ],
    );
  }

  // ─── Criteria Checklist ───────────────────────────────────────────────────

  Widget _buildCriteriaChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _criterionRow('At least 8 characters', _hasLength),
        _criterionRow('Mix of uppercase and lowercase', _hasUpper && _hasLower),
        _criterionRow('Contains numbers', _hasDigit),
        _criterionRow('Contains special characters (!@#\$%^&*)', _hasSpecial),
      ],
    );
  }

  Widget _criterionRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: met ? AppConstants.primaryGreen : AppConstants.textLightGray,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: met ? AppConstants.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Info Box ─────────────────────────────────────────────────────────────

  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppConstants.infoBlue, size: 20),
          const SizedBox(width: AppConstants.paddingSmall),
          Expanded(
            child: Text(
              'Use a strong password with a mix of uppercase, lowercase, '
              'numbers, and special characters to keep your account secure.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sticky Action Bar ────────────────────────────────────────────────────

  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.only(
        left: AppConstants.paddingLarge,
        right: AppConstants.paddingLarge,
        top: AppConstants.paddingMedium,
        bottom: AppConstants.paddingMedium +
            MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel button
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : _handleCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadiusSmall),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),

          const SizedBox(width: 8),

          // Update Password button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _canSubmit ? _handleUpdate : null,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check, size: 20),
              label: Text(
                _isLoading ? 'Updating...' : 'Update Password',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppConstants.primaryGreen.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white70,
                minimumSize: const Size(0, 56),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadiusSmall),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER TYPES
// ═════════════════════════════════════════════════════════════════════════════

enum _ErrorType { general, incorrectCurrent, samePassword, network }

// ═════════════════════════════════════════════════════════════════════════════
// SUCCESS MODAL
// ═════════════════════════════════════════════════════════════════════════════

class _SuccessModal extends StatelessWidget {
  const _SuccessModal({required this.onBackToProfile});

  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingXLarge),
        child: Material(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          color: Theme.of(context).colorScheme.surface,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingXLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Bounce icon ──
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color:
                          AppConstants.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 64,
                      color: AppConstants.primaryGreen,
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.paddingLarge),

                Text(
                  'Password Updated',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: AppConstants.paddingSmall),

                Text(
                  "Your password has been successfully changed.\nYou're all set!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: AppConstants.paddingLarge),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onBackToProfile,
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text(
                      'Back to Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppConstants.borderRadiusSmall),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
