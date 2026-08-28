import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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

    final scheduledLocal = _nextReminderDate(subscription);
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
  }

  Future<void> cancel(int notificationId) async {
    await initialize();
    await _plugin.cancel(notificationId);
  }

  DateTime _nextReminderDate(Subscription subscription) {
    var billing = subscription.billingDate;
    final now = DateTime.now();
    var reminder = DateTime(billing.year, billing.month, billing.day, 9)
        .subtract(Duration(days: subscription.reminderDaysBefore));
    while (!reminder.isAfter(now)) {
      billing = subscription.recurrence.nextDate(
        billing,
        preferredDay: subscription.billingDate.day,
      );
      reminder = DateTime(billing.year, billing.month, billing.day, 9)
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
