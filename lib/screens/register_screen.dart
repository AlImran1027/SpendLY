/// Registration Screen — create a new Spendly account.
///
/// Layout (top → bottom):
///   1. Back button + header ("Create Account")
///   2. Subtitle text
///   3. Full name field
///   4. Email field with format validation
///   5. Password field with strength indicator
///   6. Confirm password field with match validation
///   7. Terms & conditions checkbox
///   8. "Sign Up" button with loading state
///   9. "Already have an account? Login" link
///
/// Validation rules:
///   - Name: non-empty, ≥ 2 characters
///   - Email: non-empty, valid format
///   - Password: ≥ 6 chars, real-time strength meter
///   - Confirm password: must match password
///   - Terms checkbox: must be checked
///
/// On success the user's details are persisted via SharedPreferences
/// and the app navigates to /home with pushReplacementNamed.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ─── Form state ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  /// Password strength: 0 = none, 1 = weak, 2 = fair, 3 = good, 4 = strong
  int _passwordStrength = 0;

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  // ─── Password strength calculator ──────────────────────────────────────────

  /// Evaluates password strength on a 0-4 scale based on:
  ///   +1 for length ≥ 6
  ///   +1 for containing uppercase letters
  ///   +1 for containing digits
  ///   +1 for containing special characters
  void _evaluatePasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 6) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength++;

    setState(() => _passwordStrength = password.isEmpty ? 0 : strength);
  }

  /// Returns a label for the current strength level.
  String get _strengthLabel {
    switch (_passwordStrength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }

  /// Returns a colour for the current strength level.
  Color get _strengthColor {
    switch (_passwordStrength) {
      case 1:
        return AppConstants.errorRed;
      case 2:
        return AppConstants.warningAmber;
      case 3:
        return AppConstants.infoBlue;
      case 4:
        return AppConstants.primaryGreen;
      default:
        return AppConstants.textLightGray;
    }
  }

  // ─── Validation helpers ────────────────────────────────────────────────────

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    final emailRegex = RegExp(r'^[\w\-.+]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  /// Handles the registration flow:
  ///   1. Validate all form fields
  ///   2. Ensure T&C accepted
  ///   3. Show loading spinner
  ///   4. Simulate API call (replace with real backend later)
  ///   5. Persist user session
  ///   6. Navigate to Home
  Future<void> _handleSignUp() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    // Ensure terms checkbox is checked
    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = 'Please agree to the Terms & Conditions';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── Simulate network delay (replace with real registration later) ──
      await Future.delayed(const Duration(seconds: 2));

      // TODO: Replace with actual registration API call
      // final response = await AuthService.register(
      //   name: _nameController.text.trim(),
      //   email: _emailController.text.trim(),
      //   password: _passwordController.text,
      // );

      final name = _nameController.text.trim();
      final email = _emailController.text.trim();

      // Example: reject a specific email to demo error state
      if (email == 'taken@example.com') {
        throw Exception('An account with this email already exists');
      }

      // ── Persist login state ──
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefIsLoggedIn, true);
      await prefs.setString(AppConstants.prefUserEmail, email);
      await prefs.setString(AppConstants.prefUserName, name);

      if (!mounted) return;

      // ── Show success snackbar and navigate ──
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account created successfully!'),
          backgroundColor: AppConstants.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusSmall),
          ),
        ),
      );

      Navigator.pushReplacementNamed(context, AppConstants.homeRoute);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Pops back to the login screen.
  void _handleAlreadyHaveAccount() {
    Navigator.pop(context);
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      // AppBar with back arrow
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppConstants.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── 1. Header ──
                      _buildHeader(),

                      const SizedBox(height: AppConstants.paddingLarge),

                      // ── 2. Error banner ──
                      if (_errorMessage != null) ...[
                        _buildErrorBanner(),
                        const SizedBox(height: AppConstants.paddingMedium),
                      ],

                      // ── 3. Form ──
                      _buildForm(),

                      const SizedBox(height: AppConstants.paddingMedium),

                      // ── 4. Terms & Conditions ──
                      _buildTermsCheckbox(),

                      const SizedBox(height: AppConstants.paddingLarge),

                      // ── 5. Sign Up button ──
                      PrimaryButton(
                        text: 'Sign Up',
                        onPressed: _handleSignUp,
                        isLoading: _isLoading,
                        icon: Icons.person_add,
                      ),

                      const SizedBox(height: AppConstants.paddingLarge),

                      // ── 6. Already have account link ──
                      _buildAlreadyHaveAccountLink(),

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

  /// Page title + subtitle.
  Widget _buildHeader() {
    return Column(
      children: [
        // Circular icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppConstants.lightGreen.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_add_outlined,
            size: 36,
            color: AppConstants.primaryGreen,
          ),
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppConstants.darkGreen,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        const Text(
          'Start tracking your expenses smartly',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppConstants.textMediumGray,
          ),
        ),
      ],
    );
  }

  /// Dismissible error banner.
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

  /// All four input fields + password strength indicator.
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Full name ──
          CustomTextField(
            controller: _nameController,
            label: 'Full Name',
            hintText: 'John Doe',
            prefixIcon: Icons.person_outline,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: _validateName,
            enabled: !_isLoading,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_emailFocusNode);
            },
          ),

          const SizedBox(height: AppConstants.paddingMedium),

          // ── Email ──
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

          // ── Password ──
          CustomTextField(
            controller: _passwordController,
            label: 'Password',
            hintText: '••••••••',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: _validatePassword,
            enabled: !_isLoading,
            onChanged: _evaluatePasswordStrength,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_confirmFocusNode);
            },
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

          // ── Password strength indicator ──
          if (_passwordController.text.isNotEmpty) ...[
            const SizedBox(height: AppConstants.paddingSmall),
            _buildPasswordStrengthIndicator(),
          ],

          const SizedBox(height: AppConstants.paddingMedium),

          // ── Confirm password ──
          CustomTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hintText: '••••••••',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            validator: _validateConfirmPassword,
            enabled: !_isLoading,
            onFieldSubmitted: (_) => _handleSignUp(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppConstants.textMediumGray,
                size: 22,
              ),
              onPressed: () {
                setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Four-segment animated strength bar with label.
  Widget _buildPasswordStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Segmented bar ──
        Row(
          children: List.generate(4, (index) {
            final isActive = index < _passwordStrength;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: 4,
                margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: isActive
                      ? _strengthColor
                      : AppConstants.textLightGray.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 4),

        // ── Label ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password strength:',
              style: TextStyle(
                fontSize: 12,
                color: AppConstants.textMediumGray,
              ),
            ),
            Text(
              _strengthLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _strengthColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Terms & conditions checkbox row.
  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: _isLoading
                ? null
                : (value) {
                    setState(() {
                      _agreedToTerms = value ?? false;
                      // Clear the T&C error if they just checked the box
                      if (_agreedToTerms && _errorMessage != null) {
                        _errorMessage = null;
                      }
                    });
                  },
            activeColor: AppConstants.primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(
              color: _errorMessage != null && !_agreedToTerms
                  ? AppConstants.errorRed
                  : AppConstants.textMediumGray,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(width: AppConstants.paddingSmall),
        Expanded(
          child: GestureDetector(
            onTap: _isLoading
                ? null
                : () {
                    setState(() {
                      _agreedToTerms = !_agreedToTerms;
                      if (_agreedToTerms && _errorMessage != null) {
                        _errorMessage = null;
                      }
                    });
                  },
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: AppConstants.textMediumGray,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: TextStyle(
                      color: AppConstants.primaryGreen,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: AppConstants.primaryGreen,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: AppConstants.primaryGreen,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: AppConstants.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "Already have an account? Login" text + button.
  Widget _buildAlreadyHaveAccountLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account?',
          style: TextStyle(
            fontSize: 14,
            color: AppConstants.textMediumGray,
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _handleAlreadyHaveAccount,
          style: TextButton.styleFrom(
            foregroundColor: AppConstants.primaryGreen,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingSmall,
            ),
          ),
          child: const Text(
            'Login',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
