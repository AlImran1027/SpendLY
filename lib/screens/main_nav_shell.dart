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
import 'analytics_screen.dart';
import 'profile_screen.dart';

class MainNavShell extends StatefulWidget {
  const MainNavShell({super.key});

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  int _currentIndex = 0;

  /// The four tab screens. Using IndexedStack keeps each screen alive when
  /// the user switches tabs, preserving scroll position and state.
  /// Budget is accessible via the edit button on the Home spending card.
  final List<Widget> _screens = const [
    HomeScreen(),
    ExpensesScreen(),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _openReceiptCapture,
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_a_photo_outlined, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom App Bar with notch for centre FAB ──────────────────────────
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppConstants.backgroundColor,
        elevation: 8,
        padding: EdgeInsets.zero,
        height: 70,
        child: Row(
          children: [
            // ── Left: Home, Expenses ──
            _NavItem(
              index: 0,
              currentIndex: _currentIndex,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              onTap: _onTabTapped,
            ),
            _NavItem(
              index: 1,
              currentIndex: _currentIndex,
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long,
              label: 'Expenses',
              onTap: _onTabTapped,
            ),
            // ── Centre gap for FAB notch ──
            const Expanded(child: SizedBox()),
            // ── Right: Analytics, Profile ──
            _NavItem(
              index: 2,
              currentIndex: _currentIndex,
              icon: Icons.analytics_outlined,
              selectedIcon: Icons.analytics,
              label: 'Analytics',
              onTap: _onTabTapped,
            ),
            _NavItem(
              index: 3,
              currentIndex: _currentIndex,
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Profile',
              onTap: _onTabTapped,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Nav item widget ──────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? AppConstants.primaryGreen.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                size: 22,
                color: selected
                    ? AppConstants.primaryGreen
                    : AppConstants.textMediumGray,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? AppConstants.primaryGreen
                    : AppConstants.textMediumGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
