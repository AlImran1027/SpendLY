/// Spendly — Intelligent Receipt-Based Expense Tracking System.
///
/// Entry point. Configures the Material 3 theme, defines named routes,
/// and launches the splash screen.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_nav_shell.dart';
import 'screens/receipt_capture_screen.dart';
import 'screens/receipt_preview_screen.dart';
import 'screens/extraction_results_screen.dart';
import 'screens/expense_entry_screen.dart';
import 'screens/expense_detail_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/split_bill_screen.dart';
import 'services/currency_service.dart';
import 'services/gemini_service.dart';
import 'services/lm_studio_service.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';

/// Top-level FCM background/terminated-state handler.
///
/// This function runs in a separate isolate when an FCM message arrives and
/// the app is in the background or fully terminated. It must be a top-level
/// (non-class) function annotated with @pragma('vm:entry-point').
///
/// Firebase shows the notification in the system tray automatically when the
/// message has a 'notification' payload — no local-notification code is needed
/// here. This handler just ensures Firebase is initialised in the isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // The OS renders the notification automatically from the FCM payload.
  // Nothing else is needed for background / terminated state.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  // Register the background FCM handler BEFORE any other Firebase calls.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Load persisted settings before the first frame.
  await Future.wait([
    CurrencyService.instance.load(),
    GeminiService.instance.load(),
    LMStudioService.instance.load(),
    NotificationService.instance.init(),
  ]);

  // Request local-notification OS permission and set up FCM.
  await NotificationService.instance.requestPermission();
  await NotificationService.instance.setupFcm();

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
        AppConstants.budgetRoute: (_) => const BudgetScreen(),
        AppConstants.forgotPasswordRoute: (_) => const ForgotPasswordScreen(),
        AppConstants.changePasswordRoute: (_) => const ChangePasswordScreen(),
        AppConstants.resetPasswordRoute: (_) => const ResetPasswordScreen(),
        AppConstants.splitBillRoute: (_) => const SplitBillScreen(),
      },
    );
  }
}
