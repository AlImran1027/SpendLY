/// Main Navigation Shell — wraps the five primary tabs of Spendly.
///
/// This is the root widget after authentication. It provides:
///   - A 5-tab bottom navigation bar (Home, Expenses, Budget, Analytics, Profile)
///   - An IndexedStack to preserve state across tab switches
///   - A prominent centre FAB for receipt capture (camera)
///
/// The [HomeRoute] in main.dart should point here instead of a standalone
/// HomeScreen, so all tabbed screens share one scaffold.
library;

import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'receipt_capture_screen.dart';
import 'home_screen.dart';
import 'expenses_screen.dart';
import 'budget_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';

class MainNavShell extends StatefulWidget {
  const MainNavShell({super.key});

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  int _currentIndex = 0;

  /// The five tab screens. Using IndexedStack keeps each screen alive when
  /// the user switches tabs, preserving scroll position and state.
  final List<Widget> _screens = const [
    HomeScreen(),
    ExpensesScreen(),
    BudgetScreen(),
    AnalyticsScreen(),
    ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  /// Opens the receipt capture flow (camera / gallery picker).
  /// This is triggered by the centre FAB.
  void _openReceiptCapture() {
    // TODO: Navigate to receipt capture screen
    // For now show a placeholder bottom sheet.
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.borderRadiusLarge),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppConstants.textLightGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingLarge),
                const Text(
                  'Add Expense',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textDark,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingLarge),

                // Option: Camera
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadiusMedium,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppConstants.primaryGreen,
                    ),
                  ),
                  title: const Text(
                    'Scan Receipt',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Take a photo of your receipt'),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppConstants.textMediumGray,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      AppConstants.receiptCaptureRoute,
                      arguments: CaptureSource.camera,
                    );
                  },
                ),
                const SizedBox(height: AppConstants.paddingSmall),

                // Option: Gallery
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppConstants.infoBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadiusMedium,
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: AppConstants.infoBlue,
                    ),
                  ),
                  title: const Text(
                    'Upload from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Choose an existing photo'),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppConstants.textMediumGray,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      AppConstants.receiptCaptureRoute,
                      arguments: CaptureSource.gallery,
                    );
                  },
                ),
                const SizedBox(height: AppConstants.paddingSmall),

                // Option: Manual entry
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppConstants.warningAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadiusMedium,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: AppConstants.warningAmber,
                    ),
                  ),
                  title: const Text(
                    'Manual Entry',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Enter expense details manually'),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppConstants.textMediumGray,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      AppConstants.expenseEntryRoute,
                    );
                  },
                ),

                const SizedBox(height: AppConstants.paddingMedium),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // ── Floating Action Button — receipt capture ──────────────────────────
      floatingActionButton: FloatingActionButton.large(
        onPressed: _openReceiptCapture,
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_a_photo_outlined, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom Navigation Bar ─────────────────────────────────────────────
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        backgroundColor: AppConstants.backgroundColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppConstants.primaryGreen.withValues(alpha: 0.12),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppConstants.primaryGreen),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon:
                Icon(Icons.receipt_long, color: AppConstants.primaryGreen),
            label: 'Expenses',
          ),
          // Spacer for centre FAB
          NavigationDestination(
            icon: SizedBox.shrink(),
            label: '',
            enabled: false,
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon:
                Icon(Icons.analytics, color: AppConstants.primaryGreen),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppConstants.primaryGreen),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
