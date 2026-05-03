import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global theme mode notifier. [MaterialApp] listens to this via
/// [ValueListenableBuilder] so the entire app re-themes on toggle without
/// needing a state-management library.
class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _prefKey = 'pref_dark_mode';

  final ValueNotifier<ThemeMode> notifier = ValueNotifier(ThemeMode.light);

  bool get isDark => notifier.value == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    notifier.value = (prefs.getBool(_prefKey) ?? false)
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  Future<void> setDark(bool dark) async {
    notifier.value = dark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, dark);
  }
}
