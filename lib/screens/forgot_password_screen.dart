/// Forgot Password Screen — email-based password reset for Spendly.
///
/// Layout (top → bottom):
///   1. AppBar with back button and "Forgot Password" title
///   2. Branding header (lock icon, heading, subtext)
///   3. Email input field with real-time validation & green checkmark
///   4. Info box with helpful guidance
///   5. "Send Reset Link" sticky button with loading state
///   6. "OR" divider + "Back to Login" link
///
/// States:
///   - **Default**: Empty email, send button disabled
///   - **Valid Email**: Green checkmark, button enabled
///   - **Invalid Email**: Red error, button disabled
///   - **Loading**: Spinner on button, inputs disabled
///   - **Success**: Success screen with check icon, countdown, resend
///   - **Email Not Found**: Error banner, form remains editable
///   - **Network Error**: Error banner with retry
///
/// After successful submission, a success screen is shown with a
/// countdown timer. After 30 seconds, a "Send Again" button appears.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  // ─── Form state ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isEmailValid = false;
  bool _showSuccess = false;
  String? _errorMessage;
  int _resendAttempts = 0;

  // ─── Resend countdown ──────────────────────────────────────────────────────
  Timer? _countdownTimer;
  int _countdownSeconds = 30;
  bool _canResend = false;

  // ─── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _staggerCtrl;
  late final AnimationController _successCtrl;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _emailController.addListener(_onEmailChanged);

    // Kick off entrance animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _staggerCtrl.forward();
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _successCtrl.dispose();
    _emailController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ─── Email validation ──────────────────────────────────────────────────────

  /// Regex for basic email format validation.
  static final _emailRegex = RegExp(r'^[\w\-.+]+@[\w\-]+\.[a-zA-Z]{2,}$');

  void _onEmailChanged() {
    final valid = _emailRegex.hasMatch(_emailController.text.trim());
    if (valid != _isEmailValid) {
      setState(() => _isEmailValid = valid);
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> _handleSendResetLink() async {
    // Clear previous error
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ── Simulate network call (replace with real API later) ──
      await Future.delayed(const Duration(seconds: 2));

      final email = _emailController.text.trim();

      // Demo: reject a specific email to show "not found" error state.
      if (email == 'notfound@example.com') {
        throw Exception('Email address not found. Please check and try again.');
      }

      // Demo: simulate network error.
      if (email == 'error@example.com') {
        throw Exception(
            'Connection error. Please check your internet and try again.');
      }

      if (!mounted) return;

      // ── Success ──
      setState(() {
        _isLoading = false;
        _showSuccess = true;
        _resendAttempts++;
      });

      _successCtrl.forward(from: 0);
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownSeconds = 30;
    _canResend = false;
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdownSeconds--;
        if (_countdownSeconds <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _handleResend() {
    if (_resendAttempts >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum resend attempts reached. Try again later.'),
          backgroundColor: AppConstants.warningAmber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _showSuccess = false;
      _canResend = false;
    });
    _countdownTimer?.cancel();

    // Re-trigger send immediately.
    _handleSendResetLink();
  }

  void _handleBackToLogin() {
    Navigator.pop(context);
  }

  // ─── Stagger animation helpers ─────────────────────────────────────────────

  Animation<double> _fadeAt(int index) {
    final start = (index * 0.12).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );
  }

  Animation<Offset> _slideAt(int index) {
    final start = (index * 0.12).clamp(0.0, 0.6);
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
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _isLoading ? null : _handleBackToLogin,
        ),
        title: const Text(
          'Forgot Password',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppConstants.textDark,
          ),
        ),
      ),
      body: SafeArea(
        child: _showSuccess ? _buildSuccessScreen() : _buildFormScreen(),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // FORM SCREEN
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildFormScreen() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLarge,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
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

                  const SizedBox(height: AppConstants.paddingXLarge),

                  // ── 2. Error banner (if any) ──
                  if (_errorMessage != null) ...[
                    _buildErrorBanner(),
                    const SizedBox(height: AppConstants.paddingMedium),
                  ],

                  // ── 3. Email field ──
                  FadeTransition(
                    opacity: _fadeAt(1),
                    child: SlideTransition(
                      position: _slideAt(1),
                      child: _buildEmailField(),
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingMedium),

                  // ── 4. Info box ──
                  FadeTransition(
                    opacity: _fadeAt(2),
                    child: SlideTransition(
                      position: _slideAt(2),
                      child: _buildInfoBox(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── 5. Sticky bottom section ──
        FadeTransition(
          opacity: _fadeAt(3),
          child: SlideTransition(
            position: _slideAt(3),
            child: _buildBottomSection(),
          ),
        ),
      ],
    );
  }

  // ─── Branding Header ──────────────────────────────────────────────────────

  Widget _buildBrandingHeader() {
    return Center(
      child: Column(
        children: [
          // Lock icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppConstants.lightGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset,
              size: 28,
              color: AppConstants.primaryGreen,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          const Text(
            'Reset Your Password',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppConstants.textDark,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          const Text(
            "We'll send you a link to reset your password",
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
    final isNetwork = _errorMessage?.contains('Connection') ?? false;

    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: const Offset(0, -1), end: Offset.zero),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, offset, child) {
        return FractionalTranslation(
          translation: offset,
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 0),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          border: Border.all(
            color: AppConstants.errorRed.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isNetwork ? Icons.warning_amber_rounded : Icons.error_outline,
              color: AppConstants.errorRed,
              size: 20,
            ),
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
                        _handleSendResetLink();
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
              child: const Icon(
                Icons.close,
                color: AppConstants.errorRed,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Email Field ──────────────────────────────────────────────────────────

  Widget _buildEmailField() {
    return Form(
      key: _formKey,
      child: CustomTextField(
        controller: _emailController,
        label: 'Email Address',
        hintText: 'Enter your registered email',
        prefixIcon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        validator: _validateEmail,
        enabled: !_isLoading,
        onFieldSubmitted: (_) {
          if (_isEmailValid) _handleSendResetLink();
        },
        suffixIcon: _isEmailValid
            ? TweenAnimationBuilder<double>(
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
              )
            : null,
      ),
    );
  }

  // ─── Info Box ─────────────────────────────────────────────────────────────

  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F6),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: AppConstants.primaryGreen,
            size: 20,
          ),
          SizedBox(width: AppConstants.paddingSmall),
          Expanded(
            child: Text(
              "We'll send password reset instructions to your email. "
              'Check your inbox and spam folder.',
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

  // ─── Bottom Section (Button + Footer) ─────────────────────────────────────

  Widget _buildBottomSection() {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Send Reset Link button ──
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed:
                  (_isEmailValid && !_isLoading) ? _handleSendResetLink : null,
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
                  : const Icon(Icons.mail_outlined, size: 20),
              label: Text(
                _isLoading ? 'Sending...' : 'Send Reset Link',
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

          const SizedBox(height: AppConstants.paddingMedium),

          // ── Divider + back to login ──
          const Row(
            children: [
              Expanded(child: Divider(color: AppConstants.textLightGray)),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMedium),
                child: Text(
                  'OR',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppConstants.textMediumGray,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppConstants.textLightGray)),
            ],
          ),

          const SizedBox(height: AppConstants.paddingSmall),

          TextButton(
            onPressed: _isLoading ? null : _handleBackToLogin,
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.infoBlue,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingSmall,
                vertical: 4,
              ),
            ),
            child: const Text(
              'Back to Login',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // SUCCESS SCREEN
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildSuccessScreen() {
    final email = _emailController.text.trim();

    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _successCtrl, curve: Curves.easeIn),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingLarge,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppConstants.paddingXLarge),

                  // ── Success icon with bounce ──
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(scale: value, child: child);
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

                  // ── Heading ──
                  const Text(
                    'Check Your Email',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textDark,
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingMedium),

                  // ── Message ──
                  Text(
                    "We've sent a password reset link to $email. "
                    'Click the link to reset your password.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppConstants.textMediumGray,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingSmall),

                  // ── Expiry note ──
                  const Text(
                    'Link expires in 24 hours',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppConstants.textLightGray,
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingXLarge),

                  // ── Back to Login CTA ──
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _handleBackToLogin,
                      icon: const Icon(Icons.login, size: 20),
                      label: const Text(
                        'Back to Login',
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

                  const SizedBox(height: AppConstants.paddingMedium),

                  // ── Resend section ──
                  _buildResendSection(),

                  const SizedBox(height: AppConstants.paddingMedium),

                  // ── Didn't receive hint ──
                  const Text(
                    "Didn't receive? Check spam folder or try another email",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppConstants.textLightGray,
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingXLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Resend Section ───────────────────────────────────────────────────────

  Widget _buildResendSection() {
    if (_canResend) {
      // ── "Send Again" button (visible after 30 s) ──
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity, child: child);
        },
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _handleResend,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(
              'Send Again',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppConstants.primaryGreen,
              side: const BorderSide(
                  color: AppConstants.primaryGreen, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
            ),
          ),
        ),
      );
    }

    // ── Countdown ──
    return Text(
      'Resend in $_countdownSeconds seconds...',
      style: const TextStyle(
        fontSize: 12,
        color: AppConstants.textMediumGray,
      ),
    );
  }
}
