import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import '../features/subscriptions/subscription.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  Future<void> schedule(Subscription subscription) async {
    await initialize();
    await cancel(subscription.notificationId);
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_enabled') ?? true)) return;

    final hour = prefs.getInt('reminder_hour') ?? 9;
    final scheduledLocal = _nextReminderDate(subscription, hour);
    final scheduled = tz.TZDateTime.from(scheduledLocal, tz.local);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'subscription_reminders',
        'Subscription reminders',
        channelDescription: 'Reminders before recurring subscription charges',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      subscription.notificationId,
      '${subscription.name} renews soon',
      'MYR ${subscription.price.toStringAsFixed(2)} is due ${_dueLabel(subscription.reminderDaysBefore)}.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: _matchComponents(subscription.recurrence),
      payload: subscription.id,
    );
    if (subscription.trialEndDate != null) {
      final trialReminder = DateTime(
        subscription.trialEndDate!.year,
        subscription.trialEndDate!.month,
        subscription.trialEndDate!.day,
        hour,
      ).subtract(const Duration(days: 3));
      if (trialReminder.isAfter(DateTime.now())) {
        await _plugin.zonedSchedule(
          subscription.notificationId ^ 0x40000000,
          '${subscription.name} trial ends soon',
          'Your free trial ends in 3 days.',
          tz.TZDateTime.from(trialReminder, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: subscription.id,
        );
      }
    }
  }

  Future<void> showTest() async {
    await initialize();
    await _plugin.show(
        2147483000,
        'Reminders are ready',
        'Subscription Guillotine can notify you before the next charge.',
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'subscription_reminders', 'Subscription reminders',
                channelDescription:
                    'Reminders before recurring subscription charges',
                importance: Importance.high,
                priority: Priority.high),
            iOS: DarwinNotificationDetails()));
  }

  Future<void> cancel(int notificationId) async {
    await initialize();
    await _plugin.cancel(notificationId);
    await _plugin.cancel(notificationId ^ 0x40000000);
  }

  DateTime _nextReminderDate(Subscription subscription, int hour) {
    var billing = subscription.billingDate;
    final now = DateTime.now();
    var reminder = DateTime(billing.year, billing.month, billing.day, hour)
        .subtract(Duration(days: subscription.reminderDaysBefore));
    while (!reminder.isAfter(now)) {
      billing = subscription.recurrence.nextDate(
        billing,
        preferredDay: subscription.billingDate.day,
      );
      reminder = DateTime(billing.year, billing.month, billing.day, hour)
          .subtract(Duration(days: subscription.reminderDaysBefore));
    }
    return reminder;
  }

  DateTimeComponents _matchComponents(Recurrence recurrence) {
    switch (recurrence) {
      case Recurrence.daily:
        return DateTimeComponents.time;
      case Recurrence.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case Recurrence.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
      case Recurrence.yearly:
        return DateTimeComponents.dateAndTime;
    }
  }

  String _dueLabel(int days) {
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }
}
