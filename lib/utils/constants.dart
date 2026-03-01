/// App-wide constants for the Spendly application.
///
/// Contains color definitions, text styles, spacing values, route names,
/// expense categories, and other configuration used throughout the app.
library;

import 'package:flutter/material.dart';

class AppConstants {
  // ─── APP INFO ───────────────────────────────────────────────────────────────
  static const String appName = 'Spendly';
  static const String appTagline = 'Smart Expense Tracking';
  static const String appVersion = 'v1.0.0';

  // ─── COLORS ─────────────────────────────────────────────────────────────────
  /// Primary green — trust & financial health
  static const Color primaryGreen = Color(0xFF2E7D32);

  /// Light green — success states, accents
  static const Color lightGreen = Color(0xFF66BB6A);

  /// Dark green — headers, emphasis
  static const Color darkGreen = Color(0xFF1B5E20);

  /// Background color
  static const Color backgroundColor = Color(0xFFFFFFFF);

  /// Primary text color
  static const Color textDark = Color(0xFF424242);

  /// Secondary / subtitle text color
  static const Color textMediumGray = Color(0xFF757575);

  /// Light text color — captions, version numbers
  static const Color textLightGray = Color(0xFFBDBDBD);

  /// Warning — budget thresholds
  static const Color warningAmber = Color(0xFFFF9800);

  /// Error — validation, over-budget
  static const Color errorRed = Color(0xFFF44336);

  /// Info — tips, informational banners
  static const Color infoBlue = Color(0xFF2196F3);

  // ─── SPACING ────────────────────────────────────────────────────────────────
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  static const double paddingXXLarge = 40.0;

  // ─── BORDER RADIUS ─────────────────────────────────────────────────────────
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;

  // ─── ELEVATION ──────────────────────────────────────────────────────────────
  static const double elevationSmall = 2.0;
  static const double elevationMedium = 4.0;

  // ─── ROUTE NAMES ────────────────────────────────────────────────────────────
  static const String splashRoute = '/splash';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String receiptCaptureRoute = '/receipt-capture';
  static const String receiptPreviewRoute = '/receipt-preview';
  static const String extractionResultsRoute = '/extraction-results';
  static const String expenseEntryRoute = '/expense-entry';
  static const String expensesRoute = '/expenses';
  static const String budgetRoute = '/budget';
  static const String analyticsRoute = '/analytics';
  static const String profileRoute = '/profile';
  static const String expenseDetailRoute = '/expense-detail';

  // ─── EXPENSE CATEGORIES ─────────────────────────────────────────────────────
  static const List<String> expenseCategories = [
    'Groceries',
    'Food/Restaurant',
    'Medicine',
    'Clothes',
    'Hardware',
    'Cosmetics',
    'Entertainment',
    'Others',
  ];

  // ─── SHARED PREFERENCES KEYS ───────────────────────────────────────────────
  static const String prefIsLoggedIn = 'isLoggedIn';
  static const String prefUserId = 'userId';
  static const String prefUserName = 'userName';
  static const String prefUserEmail = 'userEmail';

  // ─── SPLASH SCREEN ─────────────────────────────────────────────────────────
  static const int splashDurationSeconds = 3;

  // ─── BUDGET THRESHOLDS ──────────────────────────────────────────────────────
  static const double budgetWarningThreshold = 0.80; // 80%
  static const double budgetCriticalThreshold = 1.00; // 100%

  // Private constructor — prevent instantiation
  AppConstants._();
}
