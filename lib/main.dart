/// Spendly — Intelligent Receipt-Based Expense Tracking System.
///
/// Entry point. Configures the Material 3 theme, defines named routes,
/// and launches the splash screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_nav_shell.dart';
import 'screens/receipt_capture_screen.dart';
import 'screens/receipt_preview_screen.dart';
import 'screens/extraction_results_screen.dart';
import 'screens/expense_entry_screen.dart';
import 'screens/expense_detail_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for consistent receipt-capture UX.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Style the system status bar to match the app's light background.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const SpendlyApp());
}

/// Root widget of the Spendly application.
class SpendlyApp extends StatelessWidget {
  const SpendlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // ── Theme ──────────────────────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryGreen,
          primary: AppConstants.primaryGreen,
          error: AppConstants.errorRed,
          surface: AppConstants.backgroundColor,
        ),
        scaffoldBackgroundColor: AppConstants.backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConstants.backgroundColor,
          foregroundColor: AppConstants.textDark,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      // ── Routing ────────────────────────────────────────────────────────────
      initialRoute: AppConstants.splashRoute,
      routes: {
        AppConstants.splashRoute: (_) => const SplashScreen(),
        AppConstants.loginRoute: (_) => const LoginScreen(),
        AppConstants.registerRoute: (_) => const RegisterScreen(),
        AppConstants.homeRoute: (_) => const MainNavShell(),
        AppConstants.receiptCaptureRoute: (_) => const ReceiptCaptureScreen(),
        AppConstants.receiptPreviewRoute: (_) => const ReceiptPreviewScreen(),
        AppConstants.extractionResultsRoute: (_) => const ExtractionResultsScreen(),
        AppConstants.expenseEntryRoute: (_) => const ExpenseEntryScreen(),
        AppConstants.expenseDetailRoute: (_) => const ExpenseDetailScreen(),
        AppConstants.forgotPasswordRoute: (_) => const ForgotPasswordScreen(),
        AppConstants.changePasswordRoute: (_) => const ChangePasswordScreen(),
        AppConstants.resetPasswordRoute: (_) => const ResetPasswordScreen(),
      },
    );
  }
}
