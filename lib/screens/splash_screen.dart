/// Splash Screen — the first screen displayed when Spendly launches.
///
/// Responsibilities:
/// - Display branding (logo, app name, tagline, version).
/// - Animate elements in with a staggered fade+slide effect.
/// - Check whether the user is already logged in via SharedPreferences.
/// - After a 3-second delay navigate to ether the Home dashboard or the
///   Login screen, replacing this route so the user cannot navigate back.
library;

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ─── Animation controller & individual animations ──────────────────────────
  late final AnimationController _animController;

  /// Logo fades in and slides down from above.
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;

  /// App name slides up from below and fades in.
  late final Animation<double> _nameFade;
  late final Animation<Offset> _nameSlide;

  /// Tagline simply fades in after the name.
  late final Animation<double> _taglineFade;

  /// Loading indicator fades in last.
  late final Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();

    // Total animation duration is 1.5 s; navigation happens independently
    // after 3 seconds via _initializeApp().
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // ── Logo: 0% → 50% of the animation timeline ──
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // ── App name: 25% → 65% ──
    _nameFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
      ),
    );
    _nameSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
      ),
    );

    // ── Tagline: 50% → 80% ──
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
      ),
    );

    // ── Loader: 70% → 100% ──
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    // Start animation and kick off the initialization timer.
    _animController.forward();
    _initializeApp();
  }

  /// Waits for the splash duration, checks login state, then navigates.
  Future<void> _initializeApp() async {
    // Run the splash delay and the login check concurrently so the total wait
    // is always exactly 3 seconds (or slightly more if prefs are slow).
    final results = await Future.wait([
      Future.delayed(
        const Duration(seconds: AppConstants.splashDurationSeconds),
      ),
      _checkLoginStatus(),
    ]);

    final bool isLoggedIn = results[1] as bool;

    // Guard against the widget being disposed while we were waiting
    // (e.g. the user rapidly left the screen).
    if (!mounted) return;

    // Navigate to the appropriate screen, replacing the splash route so the
    // user cannot press Back to return here.
    Navigator.pushReplacementNamed(
      context,
      isLoggedIn ? AppConstants.homeRoute : AppConstants.loginRoute,
    );
  }

  Future<bool> _checkLoginStatus() async {
    try {
      return AuthService.instance.isLoggedIn;
    } catch (e) {
      debugPrint('SplashScreen: Error reading login state — $e');
      return false;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Subtle white → very-light-green gradient background.
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConstants.backgroundColor,
              Color(0xFFE8F5E9), // very light green tint
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            return Stack(
              children: [
                // ── Centered branding column ──
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Logo ──
                      SlideTransition(
                        position: _logoSlide,
                        child: FadeTransition(
                          opacity: _logoFade,
                          child: _buildLogo(),
                        ),
                      ),

                      const SizedBox(height: AppConstants.paddingLarge),

                      // ── App Name ──
                      SlideTransition(
                        position: _nameSlide,
                        child: FadeTransition(
                          opacity: _nameFade,
                          child: const Text(
                            AppConstants.appName,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.darkGreen,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppConstants.paddingSmall),

                      // ── Tagline ──
                      FadeTransition(
                        opacity: _taglineFade,
                        child: const Text(
                          AppConstants.appTagline,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppConstants.textMediumGray,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppConstants.paddingXXLarge),

                      // ── Loading indicator ──
                      FadeTransition(
                        opacity: _loaderFade,
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppConstants.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Version number pinned to bottom ──
                Positioned(
                  bottom: AppConstants.paddingMedium,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _taglineFade,
                    child: const Text(
                      AppConstants.appVersion,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppConstants.textLightGray,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds the circular logo container with the receipt icon.
  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: AppConstants.lightGreen.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.receipt_long,
        size: 64,
        color: AppConstants.primaryGreen,
      ),
    );
  }
}
