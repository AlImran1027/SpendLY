/// Profile Screen — user account, settings, help & support, and session management.
///
/// This is a root tab screen inside [MainNavShell] (bottom-nav "Profile" tab).
/// The user must be authenticated to reach this screen.
///
/// Layout (top → bottom, scrollable):
///   1. AppBar — title "Profile"
///   2. Profile card — avatar (initials), name, email, member-since
///   3. Quick stats — Total Expenses, Total Spent, Active Budgets
///   4. Account section — Change Password, Email Address, Delete Account
///   5. Settings section — Notifications, Currency, Date Format, Dark Mode, Language
///   6. Help & Support — FAQ, Contact Support, About, Terms, Privacy Policy
///   7. Session section — Log Out button
///
/// Functional behaviour:
///   - Reads user info from SharedPreferences on load.
///   - Settings toggles (notifications, dark mode) saved to SharedPreferences.
///   - Selector modals for currency, date format, and language.
///   - "Change Password" navigates to the Change Password screen.
///   - "Log Out" clears session and navigates to Login.
///   - "Delete Account" uses a multi-step confirmation flow.
///   - Staggered entrance animations for sections.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  // ─── User data ─────────────────────────────────────────────────────────────
  String _userName = '';
  String _userEmail = '';
  final String _memberSince = 'Jan 2025';

  // ─── Settings state ────────────────────────────────────────────────────────
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedCurrency = 'Indian Rupee (Rs.)';
  String _selectedDateFormat = 'DD/MM/YYYY';
  String _selectedLanguage = 'English';

  // ─── Stats (placeholder values — replace with DB query) ────────────────────
  final int _totalExpenses = 127;
  final String _totalSpent = 'Rs. 45,320';
  final int _activeBudgets = 6;

  // ─── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _staggerCtrl;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _loadUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _staggerCtrl.forward();
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  // ─── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString(AppConstants.prefUserName) ?? 'User';
      _userEmail =
          prefs.getString(AppConstants.prefUserEmail) ?? 'user@example.com';
      _notificationsEnabled = prefs.getBool(_prefNotifications) ?? true;
      _darkModeEnabled = prefs.getBool(_prefDarkMode) ?? false;
      _selectedCurrency =
          prefs.getString(_prefCurrency) ?? 'Indian Rupee (Rs.)';
      _selectedDateFormat =
          prefs.getString(_prefDateFormat) ?? 'DD/MM/YYYY';
      _selectedLanguage = prefs.getString(_prefLanguage) ?? 'English';
    });
  }

  // ─── Preference keys ──────────────────────────────────────────────────────
  static const _prefNotifications = 'pref_notifications';
  static const _prefDarkMode = 'pref_dark_mode';
  static const _prefCurrency = 'pref_currency';
  static const _prefDateFormat = 'pref_date_format';
  static const _prefLanguage = 'pref_language';

  // ─── Stagger helpers ──────────────────────────────────────────────────────

  Animation<double> _fadeAt(int index) {
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.3).clamp(0.0, 1.0);
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );
  }

  Animation<Offset> _slideAt(int index) {
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.3).clamp(0.0, 1.0);
    return Tween<Offset>(
      begin: const Offset(0, 0.12),
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppConstants.textDark,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Profile Card ──
            FadeTransition(
              opacity: _fadeAt(0),
              child: SlideTransition(
                position: _slideAt(0),
                child: _buildProfileCard(),
              ),
            ),

            // ── 2. Quick Stats ──
            FadeTransition(
              opacity: _fadeAt(1),
              child: SlideTransition(
                position: _slideAt(1),
                child: _buildQuickStats(),
              ),
            ),

            // ── 3. Account Section ──
            FadeTransition(
              opacity: _fadeAt(2),
              child: SlideTransition(
                position: _slideAt(2),
                child: _buildAccountSection(),
              ),
            ),

            // ── 4. Settings Section ──
            FadeTransition(
              opacity: _fadeAt(3),
              child: SlideTransition(
                position: _slideAt(3),
                child: _buildSettingsSection(),
              ),
            ),

            // ── 5. Help & Support ──
            FadeTransition(
              opacity: _fadeAt(4),
              child: SlideTransition(
                position: _slideAt(4),
                child: _buildHelpSection(),
              ),
            ),

            // ── 6. Session (Logout) ──
            FadeTransition(
              opacity: _fadeAt(5),
              child: SlideTransition(
                position: _slideAt(5),
                child: _buildSessionSection(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  PROFILE CARD
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildProfileCard() {
    final initials = _userName.isNotEmpty
        ? _userName
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : 'U';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Avatar ──
          GestureDetector(
            onTap: _handleChangeAvatar,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppConstants.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // ── Info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _userEmail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppConstants.textMediumGray,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Joined $_memberSince',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppConstants.textLightGray,
                  ),
                ),
              ],
            ),
          ),

          // ── Edit button ──
          IconButton(
            onPressed: _handleEditProfile,
            icon: const Icon(
              Icons.edit_outlined,
              color: AppConstants.primaryGreen,
              size: 24,
            ),
            tooltip: 'Edit Profile',
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  QUICK STATS
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Your Stats',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppConstants.textDark,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.receipt_long,
                  iconBg: AppConstants.primaryGreen,
                  value: '$_totalExpenses',
                  label: 'Total Expenses',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconBg: AppConstants.infoBlue,
                  value: _totalSpent,
                  label: 'Total Spent',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.track_changes,
                  iconBg: AppConstants.warningAmber,
                  value: '$_activeBudgets',
                  label: 'Active Budgets',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  ACCOUNT SECTION
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildAccountSection() {
    return _SectionCard(
      title: 'Account',
      children: [
        _SettingsRow(
          icon: Icons.lock_outline,
          iconColor: AppConstants.primaryGreen,
          label: 'Change Password',
          onTap: _handleChangePassword,
          showDivider: true,
        ),
        _SettingsRow(
          icon: Icons.email_outlined,
          iconColor: AppConstants.primaryGreen,
          label: 'Email Address',
          trailing: Text(
            _userEmail,
            style: const TextStyle(
              fontSize: 12,
              color: AppConstants.textLightGray,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          onTap: _handleChangeEmail,
          showDivider: true,
        ),
        _SettingsRow(
          icon: Icons.delete_outline,
          iconColor: AppConstants.errorRed,
          label: 'Delete Account',
          labelColor: AppConstants.errorRed,
          subtitle: 'Permanently delete your account',
          onTap: _handleDeleteAccount,
          showDivider: false,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  SETTINGS SECTION
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildSettingsSection() {
    return _SectionCard(
      title: 'Settings',
      children: [
        _SettingsRow(
          icon: Icons.notifications_outlined,
          iconColor: AppConstants.primaryGreen,
          label: 'Notifications',
          trailing: Switch.adaptive(
            value: _notificationsEnabled,
            onChanged: _handleNotificationsToggle,
            activeTrackColor: AppConstants.primaryGreen.withValues(alpha: 0.5),
          ),
          showDivider: true,
        ),
        _SettingsRow(
          icon: Icons.currency_rupee,
          iconColor: AppConstants.primaryGreen,
          label: 'Currency',
          trailing: Text(
            _selectedCurrency,
            style: const TextStyle(
              fontSize: 12,
              color: AppConstants.textLightGray,
            ),
          ),
          onTap: _handleCurrencySelect,
          showDivider: true,
        ),
        _SettingsRow(
          icon: Icons.calendar_today_outlined,
          iconColor: AppConstants.primaryGreen,
          label: 'Date Format',
          trailing: Text(
            _selectedDateFormat,
            style: const TextStyle(
              fontSize: 12,
              color: AppConstants.textLightGray,
            ),
          ),
          onTap: _handleDateFormatSelect,
          showDivider: true,
        ),
        _SettingsRow(
          icon: Icons.dark_mode_outlined,
          iconColor: AppConstants.primaryGreen,
          label: 'Dark Mode',
          trailing: Switch.adaptive(
            value: _darkModeEnabled,
            onChanged: _handleDarkModeToggle,
            activeTrackColor: AppConstants.primaryGreen.withValues(alpha: 0.5),
          ),
          showDivider: true,
        ),
        _SettingsRow(
          icon: Icons.language,
          iconColor: AppConstants.primaryGreen,
          label: 'Language',
          trailing: Text(
            _selectedLanguage,
            style: const TextStyle(
              fontSize: 12,
              color: AppConstants.textLightGray,
            ),
          ),
          onTap: _handleLanguageSelect,
          showDivider: false,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  HELP & SUPPORT SECTION
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildHelpSection() {
    return _SectionCard(
      title: 'Help & Support',
      children: [
        _SettingsRow(
          icon: Icons.help_outline,
          iconColor: AppConstants.infoBlue,
          label: 'Frequently Asked Questions',
          onTap: _handleFAQ,
          showDivider: true,
        ),
        _SettingsRow(
          icon: Icons.mail_outline,
          iconColor: AppConstants.infoBlue,
          label: 'Contact Support',
          subtitle: 'Reach out to our support team',
          onTap: _handleContactSupport,
          showDivider: true,
        ),
        _SettingsRow(
          icon: Icons.info_outline,
          iconColor: AppConstants.infoBlue,
          label: 'About Spendly',
          onTap: _handleAbout,
          showDivider: true,
        ),
        _SettingsRow(
          icon: Icons.description_outlined,
          iconColor: AppConstants.infoBlue,
          label: 'Terms & Conditions',
          onTap: _handleTerms,
          showDivider: true,
        ),
        _SettingsRow(
          icon: Icons.shield_outlined,
          iconColor: AppConstants.infoBlue,
          label: 'Privacy Policy',
          onTap: _handlePrivacyPolicy,
          showDivider: false,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  SESSION (LOGOUT) SECTION
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildSessionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Session',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppConstants.textDark,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusSmall),
              border: Border.all(
                color: AppConstants.errorRed.withValues(alpha: 0.4),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusSmall),
              child: InkWell(
                onTap: _handleLogout,
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: AppConstants.errorRed, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── App version ──
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
              child: Text(
                '${AppConstants.appName} ${AppConstants.appVersion}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppConstants.textLightGray,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  ACTIONS
  // ═════════════════════════════════════════════════════════════════════════

  // ── Profile ────────────────────────────────────────────────────────────────

  void _handleChangeAvatar() {
    // TODO: Open image picker for avatar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile picture change coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleEditProfile() {
    // TODO: Navigate to Edit Profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit profile coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Account ────────────────────────────────────────────────────────────────

  void _handleChangePassword() {
    Navigator.pushNamed(context, AppConstants.changePasswordRoute);
  }

  void _handleChangeEmail() {
    // TODO: Navigate to Change Email screen or show modal
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email change coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleDeleteAccount() {
    _showDeleteAccountStep1();
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Future<void> _handleNotificationsToggle(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefNotifications, value);
  }

  Future<void> _handleDarkModeToggle(bool value) async {
    setState(() => _darkModeEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDarkMode, value);
    // TODO: Apply dark theme to app
  }

  void _handleCurrencySelect() {
    _showSelectorModal(
      title: 'Select Currency',
      items: _currencies,
      selectedValue: _selectedCurrency,
      onSelected: (value) async {
        setState(() => _selectedCurrency = value);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefCurrency, value);
      },
    );
  }

  void _handleDateFormatSelect() {
    _showSelectorModal(
      title: 'Select Date Format',
      items: _dateFormats,
      selectedValue: _selectedDateFormat,
      onSelected: (value) async {
        setState(() => _selectedDateFormat = value);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefDateFormat, value);
      },
    );
  }

  void _handleLanguageSelect() {
    _showSelectorModal(
      title: 'Select Language',
      items: _languages,
      selectedValue: _selectedLanguage,
      onSelected: (value) async {
        setState(() => _selectedLanguage = value);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefLanguage, value);
      },
    );
  }

  // ── Help ───────────────────────────────────────────────────────────────────

  void _handleFAQ() {
    // TODO: Open FAQ screen or web view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('FAQ coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleContactSupport() {
    // TODO: Open email client with support address
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact support coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleAbout() {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppConstants.lightGreen.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.receipt_long,
          size: 28,
          color: AppConstants.primaryGreen,
        ),
      ),
      children: const [
        Text(
          'Spendly is an intelligent receipt-based expense tracking app '
          'that helps you manage your finances effortlessly.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  void _handleTerms() {
    // TODO: Open terms & conditions web view / modal
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terms & conditions coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handlePrivacyPolicy() {
    // TODO: Open privacy policy web view / modal
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy policy coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Session ────────────────────────────────────────────────────────────────

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        title: const Text(
          'Log Out?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppConstants.textDark,
          ),
        ),
        content: const Text(
          'You will be logged out of your account. Are you sure?',
          style: TextStyle(fontSize: 14, color: AppConstants.textMediumGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppConstants.textMediumGray),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _performLogout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefIsLoggedIn);
    await prefs.remove(AppConstants.prefUserEmail);
    await prefs.remove(AppConstants.prefUserName);
    await prefs.remove(AppConstants.prefUserId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logged out successfully'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppConstants.loginRoute,
      (route) => false,
    );
  }

  // ── Delete Account (multi-step) ────────────────────────────────────────────

  void _showDeleteAccountStep1() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppConstants.errorRed, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Account?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textDark,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'This action cannot be undone. All your expenses, budgets, '
          'and data will be permanently deleted.',
          style: TextStyle(
            fontSize: 14,
            color: AppConstants.errorRed,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppConstants.textMediumGray),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteAccountStep2();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountStep2() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final canDelete =
                controller.text.trim().toUpperCase() == 'DELETE';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusMedium),
              ),
              title: const Text(
                'Confirm Deletion',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textDark,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please type DELETE to confirm account deletion.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppConstants.textMediumGray,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Type DELETE',
                      hintStyle: const TextStyle(
                        color: AppConstants.textLightGray,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusSmall,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusSmall,
                        ),
                        borderSide: const BorderSide(
                          color: AppConstants.errorRed,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppConstants.textMediumGray),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.errorRed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppConstants.errorRed.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadiusSmall,
                      ),
                    ),
                  ),
                  onPressed: canDelete
                      ? () async {
                          Navigator.pop(ctx);
                          await _performDeleteAccount();
                        }
                      : null,
                  child: const Text('Delete Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performDeleteAccount() async {
    // TODO: Call backend to delete account + all data
    // Simulate network call
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(AppConstants.primaryGreen),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    Navigator.pop(context); // close loading

    // Clear all user data
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account deleted successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppConstants.loginRoute,
      (route) => false,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  SELECTOR MODAL
  // ═════════════════════════════════════════════════════════════════════════

  void _showSelectorModal({
    required String title,
    required List<String> items,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.borderRadiusLarge),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
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
                const SizedBox(height: 16),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),

                // Options
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final isSelected = item == selectedValue;
                      return ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected
                              ? AppConstants.primaryGreen
                              : AppConstants.textLightGray,
                          size: 22,
                        ),
                        title: Text(
                          item,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? AppConstants.primaryGreen
                                : AppConstants.textDark,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check,
                                color: AppConstants.primaryGreen,
                                size: 20,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelected(item);
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  DATA LISTS
  // ═════════════════════════════════════════════════════════════════════════

  static const _currencies = [
    'Indian Rupee (Rs.)',
    'US Dollar (\$)',
    'Euro (€)',
    'British Pound (£)',
    'Japanese Yen (¥)',
    'Canadian Dollar (C\$)',
    'Australian Dollar (A\$)',
    'Swiss Franc (CHF)',
    'Chinese Yuan (¥)',
    'Saudi Riyal (SAR)',
    'UAE Dirham (AED)',
    'Pakistani Rupee (PKR)',
    'Bangladeshi Taka (BDT)',
  ];

  static const _dateFormats = [
    'DD/MM/YYYY',
    'MM/DD/YYYY',
    'YYYY-MM-DD',
    'DD MMM YYYY',
    'MMM DD, YYYY',
  ];

  static const _languages = [
    'English',
    'Hindi',
    'Urdu',
    'Spanish',
    'French',
    'Arabic',
    'Bengali',
  ];
}

// ═════════════════════════════════════════════════════════════════════════════
// REUSABLE SECTION CARD
// ═════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppConstants.textDark,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusSmall),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SETTINGS ROW
// ═════════════════════════════════════════════════════════════════════════════

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final bool hasChevron = onTap != null && trailing == null;
    final bool isSwitch = trailing is Switch;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isSwitch ? null : onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Icon
                  Icon(icon, color: iconColor, size: 24),
                  const SizedBox(width: 12),

                  // Label + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            color: labelColor ?? AppConstants.textDark,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppConstants.textLightGray,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Trailing widget or chevron
                  ?trailing,
                  if (hasChevron)
                    const Icon(
                      Icons.chevron_right,
                      color: AppConstants.textLightGray,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 52, color: Color(0xFFE0E0E0)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STAT CARD
// ═════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(AppConstants.borderRadiusSmall),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconBg),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppConstants.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppConstants.textLightGray,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
