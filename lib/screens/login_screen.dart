/// Login Screen — email / password authentication for Spendly.
///
/// Layout (top → bottom):
///   1. Logo + app name (compact branding header)
///   2. Welcome text
///   3. Email text field with validation
///   4. Password text field with show/hide toggle & validation
///   5. "Forgot Password?" link (right-aligned)
///   6. Login button with loading state
///   7. Divider with "OR"
///   8. "Create Account" outlined button
///
/// Functional behaviour:
///   - Validates email format and password length (≥ 6 chars) on submit.
///   - Shows inline validation errors per field.
///   - Shows a general error banner when login fails.
///   - Displays a circular loader on the Login button while authenticating.
///   - On success, saves login state to SharedPreferences and navigates to
///     the Home dashboard with pushReplacementNamed.
///   - "Create Account" pushes the Registration screen.
///   - "Forgot Password?" shows a bottom-sheet placeholder (TODO).
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ─── Form state ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // ─── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // ─── Validation helpers ────────────────────────────────────────────────────

  /// Validates that [value] is a well-formed email address.
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    // Simple but effective email regex
    final emailRegex = RegExp(r'^[\w\-.+]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates that [value] meets the minimum password length.
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  /// Handles the login flow:
  ///   1. Validate form
  ///   2. Show loading state
  ///   3. Simulate authentication (will be replaced with real API call)
  ///   4. Save login state
  ///   5. Navigate to Home
  Future<void> _handleLogin() async {
    // Clear any previous error
    setState(() => _errorMessage = null);

    // Validate all fields
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ── Simulate network delay (replace with real auth later) ──
      await Future.delayed(const Duration(seconds: 2));

      // TODO: Replace with actual authentication API call
      // final response = await AuthService.login(
      //   email: _emailController.text.trim(),
      //   password: _passwordController.text,
      // );

      // ── Simulated credential check ──
      // For now, accept any valid-format email/password combo.
      // In production this would hit the FastAPI backend.
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Example: reject a specific combo to demo error state
      if (email == 'test@fail.com' && password == 'failme') {
        throw Exception('Invalid email or password');
      }

      // ── Persist login state ──
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefIsLoggedIn, true);
      // Only initialise name/email on the very first login — never overwrite
      // profile edits the user may have made in a previous session.
      if (prefs.getString(AppConstants.prefUserEmail) == null) {
        await prefs.setString(AppConstants.prefUserEmail, email);
      }
      if (prefs.getString(AppConstants.prefUserName) == null) {
        await prefs.setString(AppConstants.prefUserName, email.split('@').first);
      }

      if (!mounted) return;

      // ── Navigate to Home, replacing login route ──
      Navigator.pushReplacementNamed(context, AppConstants.homeRoute);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Navigates to the Forgot Password screen.
  void _handleForgotPassword() {
    Navigator.pushNamed(context, AppConstants.forgotPasswordRoute);
  }

  /// Navigates to the registration screen.
  void _handleCreateAccount() {
    Navigator.pushNamed(context, AppConstants.registerRoute);
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingLarge,
                ),
                child: ConstrainedBox(
                  // Constrain width on tablets / landscape
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: AppConstants.paddingXLarge),

                      // ── 1. Branding header ──
                      _buildHeader(),

                      const SizedBox(height: AppConstants.paddingXXLarge),

                      // ── 2. Welcome text ──
                      _buildWelcomeText(),

                      const SizedBox(height: AppConstants.paddingLarge),

                      // ── 3. Error banner (if any) ──
                      if (_errorMessage != null) ...[
                        _buildErrorBanner(),
                        const SizedBox(height: AppConstants.paddingMedium),
                      ],

                      // ── 4. Login form ──
                      _buildForm(),

                      const SizedBox(height: AppConstants.paddingXLarge),

                      // ── 5. Divider ──
                      _buildDivider(),

                      const SizedBox(height: AppConstants.paddingLarge),

                      // ── 6. Create Account button ──
                      _buildCreateAccountButton(),

                      const SizedBox(height: AppConstants.paddingXLarge),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sub-builders ──────────────────────────────────────────────────────────

  /// Logo icon + app name in a compact row.
  Widget _buildHeader() {
    return Column(
      children: [
        // Circular logo container (same style as splash)
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppConstants.lightGreen.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.receipt_long,
            size: 48,
            color: AppConstants.primaryGreen,
          ),
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        const Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppConstants.darkGreen,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  /// "Welcome back" heading + subtitle.
  Widget _buildWelcomeText() {
    return const Column(
      children: [
        Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppConstants.textDark,
          ),
        ),
        SizedBox(height: AppConstants.paddingSmall),
        Text(
          'Sign in to continue tracking your expenses',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppConstants.textMediumGray,
          ),
        ),
      ],
    );
  }

  /// Animated error banner shown when login fails.
  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.errorRed.withValues(alpha: 0.08),
        borderRadius:
            BorderRadius.circular(AppConstants.borderRadiusSmall),
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
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppConstants.errorRed,
                fontSize: 13,
              ),
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
    );
  }

  /// Email + password fields, forgot-password link, and login button.
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Email field ──
          CustomTextField(
            controller: _emailController,
            label: 'Email Address',
            hintText: 'you@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: _validateEmail,
            enabled: !_isLoading,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_passwordFocusNode);
            },
          ),

          const SizedBox(height: AppConstants.paddingMedium),

          // ── Password field ──
          CustomTextField(
            controller: _passwordController,
            label: 'Password',
            hintText: '••••••••',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: _validatePassword,
            enabled: !_isLoading,
            onFieldSubmitted: (_) => _handleLogin(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppConstants.textMediumGray,
                size: 22,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),

          const SizedBox(height: AppConstants.paddingSmall),

          // ── Forgot Password link ──
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _handleForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: AppConstants.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingSmall,
                  vertical: 4,
                ),
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // ── Login button ──
          PrimaryButton(
            text: 'Login',
            onPressed: _handleLogin,
            isLoading: _isLoading,
            icon: Icons.login,
          ),
        ],
      ),
    );
  }

  /// Horizontal divider with centred "OR" text.
  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppConstants.textLightGray)),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
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
    );
  }

  /// Outlined "Create Account" button that navigates to registration.
  Widget _buildCreateAccountButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleCreateAccount,
        icon: const Icon(Icons.person_add_outlined, size: 20),
        label: const Text('Create Account'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppConstants.primaryGreen,
          side: const BorderSide(
            color: AppConstants.primaryGreen,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
