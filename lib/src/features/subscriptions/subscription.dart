enum Recurrence {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  const Recurrence(this.label);
  final String label;

  double monthlyEquivalent(double price) {
    switch (this) {
      case Recurrence.daily:
        return price * 365 / 12;
      case Recurrence.weekly:
        return price * 52 / 12;
      case Recurrence.monthly:
        return price;
      case Recurrence.yearly:
        return price / 12;
    }
  }

  DateTime nextDate(DateTime date, {int? preferredDay}) {
    switch (this) {
      case Recurrence.daily:
        return date.add(const Duration(days: 1));
      case Recurrence.weekly:
        return date.add(const Duration(days: 7));
      case Recurrence.monthly:
        final targetMonth = DateTime(date.year, date.month + 2, 0);
        final anchorDay = preferredDay ?? date.day;
        final day = anchorDay > targetMonth.day ? targetMonth.day : anchorDay;
        return DateTime(targetMonth.year, targetMonth.month, day);
      case Recurrence.yearly:
        final targetYear = date.year + 1;
        final lastDay = DateTime(targetYear, date.month + 1, 0).day;
        final anchorDay = preferredDay ?? date.day;
        final day = anchorDay > lastDay ? lastDay : anchorDay;
        return DateTime(targetYear, date.month, day);
    }
  }

  static Recurrence fromStorage(Object? value) => values.firstWhere(
        (item) => item.name == value,
        orElse: () => Recurrence.monthly,
      );
}

class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.billingDate,
    required this.recurrence,
    required this.reminderDaysBefore,
    required this.notificationId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double price;
  final DateTime billingDate;
  final Recurrence recurrence;
  final int reminderDaysBefore;
  final int notificationId;
  final DateTime createdAt;

  double get monthlyPrice => recurrence.monthlyEquivalent(price);

  DateTime nextBillingDate([DateTime? from]) {
    final current = from ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    var next = billingDate;
    while (next.isBefore(today)) {
      next = recurrence.nextDate(next, preferredDay: billingDate.day);
    }
    return next;
  }

  factory Subscription.fromMap(Map<String, Object?> map) => Subscription(
        id: map['id']! as String,
        name: map['name']! as String,
        price: (map['price']! as num).toDouble(),
        billingDate: DateTime.parse(map['billing_date']! as String),
        recurrence: Recurrence.fromStorage(map['recurrence']),
        reminderDaysBefore: (map['reminder_days_before'] as num?)?.toInt() ?? 1,
        notificationId: (map['notification_id'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'billing_date': billingDate.toIso8601String(),
        'recurrence': recurrence.name,
        'reminder_days_before': reminderDaysBefore,
        'notification_id': notificationId,
        'created_at': createdAt.toIso8601String(),
      };
}
