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

enum SubscriptionCategory {
  entertainment('Entertainment'),
  software('Software'),
  utilities('Utilities'),
  fitness('Fitness'),
  education('Education'),
  other('Other');

  const SubscriptionCategory(this.label);
  final String label;
  static SubscriptionCategory fromStorage(Object? value) => values.firstWhere(
        (item) => item.name == value,
        orElse: () => other,
      );
}

enum SubscriptionStatus {
  active('Active'),
  planning('Planning to cancel'),
  requested('Cancellation requested'),
  cancelled('Cancelled');

  const SubscriptionStatus(this.label);
  final String label;
  static SubscriptionStatus fromStorage(Object? value) => values.firstWhere(
        (item) => item.name == value,
        orElse: () => active,
      );
}

enum UsageLevel {
  unknown('Not tracked'),
  rarely('Rarely'),
  sometimes('Sometimes'),
  often('Often');

  const UsageLevel(this.label);
  final String label;
  static UsageLevel fromStorage(Object? value) =>
      values.firstWhere((item) => item.name == value, orElse: () => unknown);
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
    this.category = SubscriptionCategory.other,
    this.status = SubscriptionStatus.active,
    this.trialEndDate,
    this.cancellationDate,
    this.cancellationReference,
    this.cancellationUrl,
    this.cancellationNotes,
    this.receiptPath,
    this.proofPath,
    this.isEssential = false,
    this.usageLevel = UsageLevel.unknown,
    this.cancellationLeadDays = 3,
  });

  final String id;
  final String name;
  final double price;
  final DateTime billingDate;
  final Recurrence recurrence;
  final int reminderDaysBefore;
  final int notificationId;
  final DateTime createdAt;
  final SubscriptionCategory category;
  final SubscriptionStatus status;
  final DateTime? trialEndDate;
  final DateTime? cancellationDate;
  final String? cancellationReference;
  final String? cancellationUrl;
  final String? cancellationNotes;
  final String? receiptPath;
  final String? proofPath;
  final bool isEssential;
  final UsageLevel usageLevel;
  final int cancellationLeadDays;

  double get monthlyPrice => recurrence.monthlyEquivalent(price);

  Subscription copyWith({
    String? name,
    double? price,
    DateTime? billingDate,
    Recurrence? recurrence,
    int? reminderDaysBefore,
    SubscriptionCategory? category,
    SubscriptionStatus? status,
    DateTime? trialEndDate,
    DateTime? cancellationDate,
    String? cancellationReference,
    String? cancellationUrl,
    String? cancellationNotes,
    String? receiptPath,
    String? proofPath,
    bool? isEssential,
    UsageLevel? usageLevel,
    int? cancellationLeadDays,
  }) =>
      Subscription(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        billingDate: billingDate ?? this.billingDate,
        recurrence: recurrence ?? this.recurrence,
        reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
        notificationId: notificationId,
        createdAt: createdAt,
        category: category ?? this.category,
        status: status ?? this.status,
        trialEndDate: trialEndDate ?? this.trialEndDate,
        cancellationDate: cancellationDate ?? this.cancellationDate,
        cancellationReference:
            cancellationReference ?? this.cancellationReference,
        cancellationUrl: cancellationUrl ?? this.cancellationUrl,
        cancellationNotes: cancellationNotes ?? this.cancellationNotes,
        receiptPath: receiptPath ?? this.receiptPath,
        proofPath: proofPath ?? this.proofPath,
        isEssential: isEssential ?? this.isEssential,
        usageLevel: usageLevel ?? this.usageLevel,
        cancellationLeadDays: cancellationLeadDays ?? this.cancellationLeadDays,
      );

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
        category: SubscriptionCategory.fromStorage(map['category']),
        status: SubscriptionStatus.fromStorage(map['status']),
        trialEndDate: _dateOrNull(map['trial_end_date']),
        cancellationDate: _dateOrNull(map['cancellation_date']),
        cancellationReference: map['cancellation_reference'] as String?,
        cancellationUrl: map['cancellation_url'] as String?,
        cancellationNotes: map['cancellation_notes'] as String?,
        receiptPath: map['receipt_path'] as String?,
        proofPath: map['proof_path'] as String?,
        isEssential: (map['is_essential'] as num?)?.toInt() == 1,
        usageLevel: UsageLevel.fromStorage(map['usage_level']),
        cancellationLeadDays:
            (map['cancellation_lead_days'] as num?)?.toInt() ?? 3,
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
        'category': category.name,
        'status': status.name,
        'trial_end_date': trialEndDate?.toIso8601String(),
        'cancellation_date': cancellationDate?.toIso8601String(),
        'cancellation_reference': cancellationReference,
        'cancellation_url': cancellationUrl,
        'cancellation_notes': cancellationNotes,
        'receipt_path': receiptPath,
        'proof_path': proofPath,
        'is_essential': isEssential ? 1 : 0,
        'usage_level': usageLevel.name,
        'cancellation_lead_days': cancellationLeadDays,
      };
}

DateTime? _dateOrNull(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

class SubscriptionEvent {
  const SubscriptionEvent(
      {required this.id,
      required this.subscriptionId,
      required this.type,
      required this.amount,
      required this.occurredAt,
      this.note,
      this.billingPeriod,
      this.receiptPath,
      this.auditStatus,
      this.auditMessage,
      this.detectedMerchant,
      this.expectedAmount});
  final int? id;
  final String subscriptionId;
  final String type;
  final double? amount;
  final DateTime occurredAt;
  final String? note;
  final String? billingPeriod;
  final String? receiptPath;
  final String? auditStatus;
  final String? auditMessage;
  final String? detectedMerchant;
  final double? expectedAmount;
  factory SubscriptionEvent.fromMap(Map<String, Object?> map) =>
      SubscriptionEvent(
          id: map['id'] as int?,
          subscriptionId: map['subscription_id']! as String,
          type: map['type']! as String,
          amount: (map['amount'] as num?)?.toDouble(),
          occurredAt: DateTime.parse(map['occurred_at']! as String),
          note: map['note'] as String?,
          billingPeriod: map['billing_period'] as String?,
          receiptPath: map['receipt_path'] as String?,
          auditStatus: map['audit_status'] as String?,
          auditMessage: map['audit_message'] as String?,
          detectedMerchant: map['detected_merchant'] as String?,
          expectedAmount: (map['expected_amount'] as num?)?.toDouble());
  Map<String, Object?> toMap() => {
        'id': id,
        'subscription_id': subscriptionId,
        'type': type,
        'amount': amount,
        'occurred_at': occurredAt.toIso8601String(),
        'note': note,
        'billing_period': billingPeriod,
        'receipt_path': receiptPath,
        'audit_status': auditStatus,
        'audit_message': auditMessage,
        'detected_merchant': detectedMerchant,
        'expected_amount': expectedAmount,
      };
}
