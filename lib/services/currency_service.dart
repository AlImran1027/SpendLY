/// Global currency setting service.
///
/// Exposes the currently-selected currency symbol across the app and
/// notifies listeners when it changes so every screen updates its
/// display without requiring a full-tree rebuild.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService extends ChangeNotifier {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  static const String _prefKey = 'pref_currency';
  static const String defaultLabel = 'Rupee (Rs.)';

  /// Label → symbol map for every supported currency.
  static const Map<String, String> currencyMap = {
    'Rupee (Rs.)': 'Rs.',
    'US Dollar (\$)': '\$',
    'Euro (€)': '€',
    'British Pound (£)': '£',
    'Japanese Yen (¥)': '¥',
    'Chinese Yuan (¥)': '¥',
    'Indian Rupee (₹)': '₹',
    'Bangladeshi Taka (৳)': '৳',
    'Australian Dollar (A\$)': 'A\$',
    'Canadian Dollar (C\$)': 'C\$',
    'Swiss Franc (CHF)': 'CHF',
    'Singapore Dollar (S\$)': 'S\$',
    'UAE Dirham (AED)': 'AED',
    'Saudi Riyal (SAR)': 'SAR',
  };

  String _label = defaultLabel;

  /// Human-readable label (e.g. "US Dollar (\$)").
  String get label => _label;

  /// Currency symbol (e.g. "\$", "Rs.", "€").
  String get symbol => currencyMap[_label] ?? 'Rs.';

  /// Load persisted selection from SharedPreferences. Call before runApp().
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && currencyMap.containsKey(saved)) {
      _label = saved;
    }
  }

  /// Persist + broadcast a new currency selection.
  Future<void> setCurrency(String newLabel) async {
    if (!currencyMap.containsKey(newLabel) || newLabel == _label) return;
    _label = newLabel;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, newLabel);
    notifyListeners();
  }

  /// Format a numeric amount with the current symbol.
  /// e.g. 1234.5 → "Rs. 1,234.50"
  String format(double amount, {int decimals = 2}) {
    final formatted = _formatWithCommas(amount, decimals);
    return '$symbol $formatted';
  }

  static String _formatWithCommas(double amount, int decimals) {
    final isNeg = amount < 0;
    final absVal = amount.abs();
    final parts = absVal.toStringAsFixed(decimals).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '';

    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    final withCommas = buf.toString();
    final full = decPart.isEmpty ? withCommas : '$withCommas.$decPart';
    return isNeg ? '-$full' : full;
  }
}
