import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'currency_service.dart';
import 'database_service.dart';
import '../utils/constants.dart';

class NotificationService {
  static final instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'spendly_alerts';
  static const _channelName = 'Spending Alerts';
  static const _channelDesc = 'Budget and spending alerts from Spendly';

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Fetches current month's budgets + spending and sends push notifications
  /// for any over-budget or near-limit categories. Each alert is sent at most
  /// once per category per calendar month (tracked via SharedPreferences).
  Future<void> checkAndNotify() async {
    final now = DateTime.now();
    final budgets =
        await DatabaseService.instance.getBudgets(now.year, now.month);
    if (budgets.isEmpty) return;

    final categoryTotals =
        await DatabaseService.instance.getCategoryTotals(now.year, now.month);

    final prefs = await SharedPreferences.getInstance();
    final monthKey = '${now.year}_${now.month}';

    int notifId = 0;

    for (final entry in budgets.entries) {
      final category = entry.key;
      final budget = entry.value;
      if (budget <= 0) continue;

      final spent = categoryTotals[category] ?? 0;
      final fraction = spent / budget;

      if (spent > budget) {
        final prefKey = 'notif_over_${category}_$monthKey';
        if (prefs.getBool(prefKey) != true) {
          final over = CurrencyService.instance
              .format(spent - budget, decimals: 0);
          await _send(
            notifId++,
            '$category Over Budget',
            'You\'re $over over your monthly limit.',
          );
          await prefs.setBool(prefKey, true);
        }
      } else if (fraction >= AppConstants.budgetWarningThreshold) {
        final prefKey = 'notif_near_${category}_$monthKey';
        if (prefs.getBool(prefKey) != true) {
          await _send(
            notifId++,
            '$category Near Limit',
            '${(fraction * 100).toInt()}% of your budget used this month.',
          );
          await prefs.setBool(prefKey, true);
        }
      }
    }
  }

  Future<void> _send(int id, String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(id, title, body, details);
  }
}
