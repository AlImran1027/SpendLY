/// Reset Password Screen — allows users to set a new password via a reset token.
///
/// This screen is reached via a deep link (e.g. spendly://reset-password?token=xyz)
/// after the user requests a password reset from the Forgot Password screen.
/// The user does NOT need to be logged in.
///
/// Flow:
///   1. On load: verify the reset token (simulated 1.5 s delay).
///   2. If token invalid/expired → show full-screen error with "Request New Link".
///   3. If token valid → display the new-password form.
///   4. User enters + confirms new password → taps "Reset Password".
///   5. On success → show animated success screen with "Go to Login".
///   6. On error → show banner, keep form filled for retry.
///
/// States:
///   - **Verifying**: Spinner + "Verifying password reset link…"
///   - **Token Invalid**: Full-screen error, CTA to request new link
///   - **Form Empty**: Both fields empty, button disabled
///   - **Password Entered**: Strength indicator updates in real-time
///   - **All Valid**: Both filled + match + ≥ 8 chars → button enabled
///   - **Loading**: Spinner on button, all inputs disabled
///   - **Success**: Full-screen check icon, "Go to Login" / "Go to Home"
///   - **Error After Submit**: Banner with retry, form preserved
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../widgets/custom_text_field.dart';

// ═════════════════════════════════════════════════════════════════════════════
// ARGUMENTS
// ═════════════════════════════════════════════════════════════════════════════

/// Arguments passed to [ResetPasswordScreen] from the deep-link handler.
class ResetPasswordArgs {
  /// The password-reset token extracted from the deep link.
  final String token;

  const ResetPasswordArgs({required this.token});
}

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  // ─── Token verification ────────────────────────────────────────────────────
  _TokenState _tokenState = _TokenState.verifying;

  // ─── Form state ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;
  _ErrorType _errorType = _ErrorType.general;

  // ─── Password strength ─────────────────────────────────────────────────────
  int _strengthScore = 0; // 0 – 4
  bool _hasLength = false;
  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasDigit = false;
  bool _hasSpecial = false;

  // ─── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _staggerCtrl;
  late final AnimationController _successCtrl;
  late final AnimationController _errorScreenCtrl;
  late final AnimationController _verifyCtrl;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _errorScreenCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _verifyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _newPwCtrl.addListener(_evaluateStrength);
    _confirmPwCtrl.addListener(_rebuild);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifyCtrl.forward();
      _verifyToken();
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _successCtrl.dispose();
    _errorScreenCtrl.dispose();
    _verifyCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _rebuild() => setState(() {});

  /// Simulates token verification. Replace with real backend call.
  Future<void> _verifyToken() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Retrieve the token from route arguments (if provided).
    final args =
        ModalRoute.of(context)?.settings.arguments as ResetPasswordArgs?;
    final token = args?.token ?? '';

    // ── Demo triggers ──
    // "expired"  → expired token
    // "invalid"  → invalid token
    // empty      → invalid token
    // anything else → valid
    if (token.isEmpty || token == 'invalid') {
      setState(() => _tokenState = _TokenState.invalid);
      _errorScreenCtrl.forward();
    } else if (token == 'expired') {
      setState(() => _tokenState = _TokenState.expired);
      _errorScreenCtrl.forward();
    } else {
      setState(() => _tokenState = _TokenState.valid);
      _staggerCtrl.forward();
    }
  }

  /// Evaluates the new password's strength and updates the score.
  void _evaluateStrength() {
    final pw = _newPwCtrl.text;
    _hasLength = pw.length >= 8;
    _hasUpper = pw.contains(RegExp(r'[A-Z]'));
    _hasLower = pw.contains(RegExp(r'[a-z]'));
    _hasDigit = pw.contains(RegExp(r'[0-9]'));
    _hasSpecial =
        pw.contains(RegExp(r'[!@#\$%\^&\*\(\)\-_=\+\[\]\{\}\|;:,.<>\?/]'));

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

  /// Whether the Reset Password button should be enabled.
  bool get _canSubmit {
    if (_isLoading) return false;
    if (_newPwCtrl.text.isEmpty) return false;
    if (_confirmPwCtrl.text.isEmpty) return false;
    if (_newPwCtrl.text != _confirmPwCtrl.text) return false;
    if (_newPwCtrl.text.length < 8) return false;
    return true;
  }

  // ─── Validators ────────────────────────────────────────────────────────────

  String? _validateNew(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
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

  Future<void> _handleReset() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ── Simulate network call (replace with real API later) ──
      await Future.delayed(const Duration(seconds: 2));

      final password = _newPwCtrl.text;

      // Demo: simulate server error.
      if (password == 'servererror') {
        throw _ResetPasswordException(
          'An error occurred. Please try again or contact support.',
          _ErrorType.server,
        );
      }

      // Demo: simulate network error.
      if (password == 'networkerror') {
        throw _ResetPasswordException(
          'Connection error. Please check your internet and try again.',
          _ErrorType.network,
        );
      }

      if (!mounted) return;

      // ── Success ──
      setState(() {
        _isLoading = false;
        _tokenState = _TokenState.success;
      });
      _successCtrl.forward();
    } on _ResetPasswordException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _errorType = e.type;
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

  void _navigateToLogin() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppConstants.loginRoute,
      (route) => false,
    );
  }

  void _navigateToForgotPassword() {
    Navigator.pushReplacementNamed(
      context,
      AppConstants.forgotPasswordRoute,
    );
  }

  void _navigateToHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppConstants.homeRoute,
      (route) => false,
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
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: _tokenState == _TokenState.invalid ||
              _tokenState == _TokenState.expired
          ? AppBar(
              backgroundColor: AppConstants.backgroundColor,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon:
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: _navigateToLogin,
              ),
              title: const Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textDark,
                ),
              ),
            )
          : _tokenState == _TokenState.valid ||
                  _tokenState == _TokenState.success
              ? AppBar(
                  backgroundColor: AppConstants.backgroundColor,
                  elevation: 0,
                  leading: _tokenState == _TokenState.valid && !_isLoading
                      ? IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                          ),
                          onPressed: _navigateToLogin,
                        )
                      : const SizedBox.shrink(),
                )
              : null, // verifying state — no app bar
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  /// Routes to the correct body content based on the current token state.
  Widget _buildBody() {
    switch (_tokenState) {
      case _TokenState.verifying:
        return _buildVerifyingState();
      case _TokenState.invalid:
      case _TokenState.expired:
        return _buildTokenErrorState();
      case _TokenState.valid:
        return _buildFormState();
      case _TokenState.success:
        return _buildSuccessState();
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  VERIFYING STATE
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildVerifyingState() {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _verifyCtrl, curve: Curves.easeIn),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppConstants.primaryGreen.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              const Text(
                'Verifying password reset link…',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppConstants.textMediumGray,
                ),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              const Text(
                'Please wait a moment',
                style: TextStyle(
                  fontSize: 13,
                  color: AppConstants.textLightGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  TOKEN ERROR STATE (invalid / expired)
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildTokenErrorState() {
    final isExpired = _tokenState == _TokenState.expired;
    final heading = isExpired
        ? 'Reset Link Expired'
        : 'Reset Link Invalid';
    final message = isExpired
        ? 'This password reset link has expired. '
            'Reset links are valid for 24 hours.\n\n'
            'Please request a new one to continue.'
        : 'This password reset link is invalid or has already been used.\n\n'
            'Please request a new one.';

    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _errorScreenCtrl, curve: Curves.easeOut),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
            vertical: AppConstants.paddingXLarge,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Error icon ──
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
                      color: AppConstants.errorRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExpired
                          ? Icons.timer_off_outlined
                          : Icons.error_outline,
                      size: 56,
                      color: AppConstants.errorRed,
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.paddingLarge),

                // ── Heading ──
                Text(
                  heading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textDark,
                  ),
                ),

                const SizedBox(height: AppConstants.paddingMedium),

                // ── Message ──
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppConstants.textMediumGray,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: AppConstants.paddingXLarge),

                // ── Request New Link button ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToForgotPassword,
                    icon: const Icon(Icons.email_outlined, size: 20),
                    label: const Text(
                      'Request New Link',
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
                          AppConstants.borderRadiusSmall,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.paddingMedium),

                // ── Back to Login link ──
                TextButton(
                  onPressed: _navigateToLogin,
                  style: TextButton.styleFrom(
                    foregroundColor: AppConstants.infoBlue,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  FORM STATE (token valid)
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildFormState() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLarge,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppConstants.paddingMedium),

                      // ── 1. Branding header ──
                      FadeTransition(
                        opacity: _fadeAt(0),
                        child: SlideTransition(
                          position: _slideAt(0),
                          child: _buildBrandingHeader(),
                        ),
                      ),

                      const SizedBox(height: AppConstants.paddingLarge),

                      // ── 2. Error banner ──
                      if (_errorMessage != null) ...[
                        _buildErrorBanner(),
                        const SizedBox(height: AppConstants.paddingMedium),
                      ],

                      // ── 3. New Password field ──
                      FadeTransition(
                        opacity: _fadeAt(1),
                        child: SlideTransition(
                          position: _slideAt(1),
                          child: _buildNewPasswordField(),
                        ),
                      ),

                      // ── 4. Strength indicator + criteria ──
                      if (_newPwCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: AppConstants.paddingSmall),
                        FadeTransition(
                          opacity: _fadeAt(1),
                          child: _buildStrengthIndicator(),
                        ),
                        const SizedBox(height: AppConstants.paddingSmall),
                        FadeTransition(
                          opacity: _fadeAt(1),
                          child: _buildCriteriaChecklist(),
                        ),
                      ],

                      const SizedBox(height: AppConstants.paddingMedium),

                      // ── 5. Confirm Password field ──
                      FadeTransition(
                        opacity: _fadeAt(2),
                        child: SlideTransition(
                          position: _slideAt(2),
                          child: _buildConfirmPasswordField(),
                        ),
                      ),

                      const SizedBox(height: AppConstants.paddingMedium),

                      // ── 6. Info box ──
                      FadeTransition(
                        opacity: _fadeAt(3),
                        child: SlideTransition(
                          position: _slideAt(3),
                          child: _buildInfoBox(),
                        ),
                      ),

                      // Bottom clearance for sticky button
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── 7. Sticky reset button ──
        FadeTransition(
          opacity: _fadeAt(4),
          child: _buildResetButton(),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  SUCCESS STATE
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildSuccessState() {
    final fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.easeOut),
    );
    final slideUp = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: fadeIn,
      child: SlideTransition(
        position: slideUp,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLarge,
              vertical: AppConstants.paddingXLarge,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
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
                        color: AppConstants.primaryGreen
                            .withValues(alpha: 0.1),
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

                  // ── Heading ──
                  const Text(
                    'Password Reset Successful',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textDark,
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingMedium),

                  // ── Message ──
                  const Text(
                    'Your password has been successfully reset.\n'
                    'You can now log in with your new password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppConstants.textMediumGray,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingXLarge),

                  // ── Go to Login button ──
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToLogin,
                      icon: const Icon(Icons.login, size: 20),
                      label: const Text(
                        'Go to Login',
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
                            AppConstants.borderRadiusSmall,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingMedium),

                  // ── Go to Home (optional secondary) ──
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _navigateToHome,
                      icon: const Icon(Icons.home_outlined, size: 20),
                      label: const Text(
                        'Go to Home',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppConstants.textMediumGray,
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadiusSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  SUB-BUILDERS
  // ═════════════════════════════════════════════════════════════════════════

  // ─── Branding Header ──────────────────────────────────────────────────────

  Widget _buildBrandingHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppConstants.lightGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset,
              size: 40,
              color: AppConstants.primaryGreen,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          const Text(
            'Create New Password',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppConstants.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter a new password for your account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppConstants.textMediumGray,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error Banner ─────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    final isNetwork = _errorType == _ErrorType.network;

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
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          border: Border.all(
            color: AppConstants.errorRed.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: AppConstants.errorRed, size: 20),
            const SizedBox(width: AppConstants.paddingSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppConstants.errorRed,
                      fontSize: 12,
                    ),
                  ),
                  if (isNetwork) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() => _errorMessage = null);
                        _handleReset();
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
              child: const Icon(Icons.close,
                  color: AppConstants.errorRed, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Password Fields ──────────────────────────────────────────────────────

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
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _obscureNew
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            key: ValueKey(_obscureNew),
            color: AppConstants.textMediumGray,
            size: 22,
          ),
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
      label: 'Confirm Password *',
      hintText: 'Re-enter your password',
      prefixIcon: Icons.lock_outline,
      obscureText: _obscureConfirm,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      validator: _validateConfirm,
      enabled: !_isLoading,
      onFieldSubmitted: (_) {
        if (_canSubmit) _handleReset();
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
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                key: ValueKey(_obscureConfirm),
                color: AppConstants.textMediumGray,
                size: 22,
              ),
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
                  color:
                      filled ? _strengthColor : const Color(0xFFE0E0E0),
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
        _criterionRow(
            'Mix of uppercase and lowercase', _hasUpper && _hasLower),
        _criterionRow('Contains numbers', _hasDigit),
        _criterionRow(
            'Contains special characters (!@#\$%^&*)', _hasSpecial),
      ],
    );
  }

  Widget _criterionRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              met ? Icons.check_circle : Icons.circle_outlined,
              key: ValueKey('$text-$met'),
              size: 14,
              color: met
                  ? AppConstants.primaryGreen
                  : AppConstants.textLightGray,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: met
                  ? AppConstants.primaryGreen
                  : AppConstants.textMediumGray,
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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppConstants.infoBlue, size: 20),
          SizedBox(width: AppConstants.paddingSmall),
          Expanded(
            child: Text(
              'Use a strong password with uppercase, lowercase, numbers, '
              'and special characters to keep your account secure.',
              style: TextStyle(
                fontSize: 13,
                color: AppConstants.textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sticky Reset Button ─────────────────────────────────────────────────

  Widget _buildResetButton() {
    return Container(
      padding: EdgeInsets.only(
        left: AppConstants.paddingLarge,
        right: AppConstants.paddingLarge,
        top: AppConstants.paddingMedium,
        bottom: AppConstants.paddingMedium +
            MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _canSubmit ? _handleReset : null,
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
            _isLoading ? 'Resetting...' : 'Reset Password',
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
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusSmall),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER TYPES
// ═════════════════════════════════════════════════════════════════════════════

/// Possible states for the reset token verification.
enum _TokenState { verifying, invalid, expired, valid, success }

/// Error categories for the reset operation.
enum _ErrorType { general, network, server }

/// Typed exception for reset password errors.
class _ResetPasswordException implements Exception {
  final String message;
  final _ErrorType type;
  const _ResetPasswordException(this.message, this.type);
}
