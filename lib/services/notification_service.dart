import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/split_request.dart';
import 'currency_service.dart';
import 'database_service.dart';
import '../utils/constants.dart';

// SharedPreferences key written by ProfileScreen's Notifications toggle.
const _kNotificationsEnabled = 'pref_notifications';

class NotificationService {
  static final instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'spendly_alerts';
  static const _channelName = 'Spending Alerts';
  static const _channelDesc = 'Budget, split-bill, and spending alerts from Spendly';

  // ─── Initialisation ──────────────────────────────────────────────────────

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

  // ─── FCM Setup ────────────────────────────────────────────────────────────

  /// Requests FCM permission and wires up foreground-message handling so FCM
  /// messages received while the app is open are shown as local notifications.
  ///
  /// Background / terminated-state FCM messages are handled by
  /// [firebaseMessagingBackgroundHandler] (top-level function in main.dart).
  Future<void> setupFcm() async {
    // Request FCM permission (iOS; on Android 13+ POST_NOTIFICATIONS handles it).
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Show FCM messages as local notifications when the app is in the foreground.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showFcmMessageAsLocal(message);
    });

    // When user taps an FCM notification that opened/resumed the app, the
    // in-app split-request card is already shown via the real-time stream,
    // so no extra navigation is needed here.
    FirebaseMessaging.onMessageOpenedApp.listen((_) {});
  }

  /// Shows an FCM [RemoteMessage] as a local notification if the in-app
  /// notifications toggle is enabled.
  Future<void> _showFcmMessageAsLocal(RemoteMessage message) async {
    if (!await isEnabled()) return;
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? 'Spendly';
    final body = notification.body ?? '';
    final id = message.messageId?.hashCode.abs() ?? DateTime.now().millisecond;

    await _send(id % 200000, title, body);
  }

  // ─── Settings gate ────────────────────────────────────────────────────────

  /// Returns true when the user has enabled notifications in Profile → Settings.
  /// Defaults to true so notifications work on fresh installs.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotificationsEnabled) ?? true;
  }

  // ─── Budget notifications ─────────────────────────────────────────────────

  /// Fetches current month's budgets + spending and sends push notifications
  /// for any over-budget or near-limit categories. Each alert is sent at most
  /// once per category per calendar month (tracked via SharedPreferences).
  Future<void> checkAndNotify() async {
    if (!await isEnabled()) return;
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
          final over =
              CurrencyService.instance.format(spent - budget, decimals: 0);
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

  // ─── Split notifications (local, in-app path) ─────────────────────────────

  /// Shows a local push notification for each pending split request the current
  /// user has not been notified about yet.
  ///
  /// The dedup key includes [SplitRequest.retriedAt] so that a retry by the
  /// initiator triggers a fresh notification even for the same split.
  ///
  /// NOTE: The in-app split-request card on the Home screen is shown regardless
  /// of this toggle — only the OS push notification is gated here.
  Future<void> notifySplitRequests(List<SplitRequest> pendingSplits) async {
    if (pendingSplits.isEmpty) return;
    if (!await isEnabled()) return;
    final prefs = await SharedPreferences.getInstance();

    for (final split in pendingSplits) {
      if (split.id == null) continue;

      final ts =
          (split.retriedAt ?? split.createdAt).millisecondsSinceEpoch;
      final prefKey = 'notif_split_${split.id}_$ts';

      if (prefs.getBool(prefKey) != true) {
        final fromLabel = split.initiatorName.isNotEmpty
            ? split.initiatorName
            : split.initiatorEmail;
        final amountStr =
            CurrencyService.instance.format(split.amountPerPerson);

        await _send(
          _splitNotifId(split.id!),
          'Split Request from $fromLabel',
          '${split.merchant} · Your share: $amountStr',
        );
        await prefs.setBool(prefKey, true);
      }
    }
  }

  /// Notifies the initiator that all recipients accepted. Deduplicated per split.
  Future<void> notifySplitFullyAccepted(SplitRequest split) async {
    if (split.id == null) return;
    if (!await isEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final prefKey = 'notif_split_accepted_${split.id}';
    if (prefs.getBool(prefKey) == true) return;

    final amountStr =
        CurrencyService.instance.format(split.amountPerPerson);
    await _send(
      _splitAcceptedNotifId(split.id!),
      'Split Accepted — ${split.merchant}',
      'Everyone accepted! Your share ($amountStr) was added to expenses.',
    );
    await prefs.setBool(prefKey, true);
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

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

  int _splitNotifId(String splitId) =>
      splitId.hashCode.abs() % 100000 + 1000;

  int _splitAcceptedNotifId(String splitId) =>
      splitId.hashCode.abs() % 100000 + 101000;
}
