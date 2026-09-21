import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_guillotine/src/features/subscriptions/subscription.dart';

void main() {
  group('Recurrence', () {
    test('normalizes prices to a monthly equivalent', () {
      expect(Recurrence.daily.monthlyEquivalent(12), 365);
      expect(Recurrence.weekly.monthlyEquivalent(12), 52);
      expect(Recurrence.monthly.monthlyEquivalent(12), 12);
      expect(Recurrence.yearly.monthlyEquivalent(120), 10);
    });

    test('monthly recurrence clamps to the last valid day', () {
      expect(
        Recurrence.monthly.nextDate(DateTime(2025, 1, 31)),
        DateTime(2025, 2, 28),
      );
    });

    test('yearly recurrence handles leap day', () {
      expect(
        Recurrence.yearly.nextDate(DateTime(2024, 2, 29)),
        DateTime(2025, 2, 28),
      );
    });
  });

  test('subscription rolls an old anchor forward', () {
    final subscription = Subscription(
      id: '1',
      name: 'Example',
      price: 10,
      billingDate: DateTime(2025, 1, 15),
      recurrence: Recurrence.monthly,
      reminderDaysBefore: 1,
      notificationId: 1,
      createdAt: DateTime(2025, 1, 1),
    );

    expect(
      subscription.nextBillingDate(DateTime(2025, 3, 1)),
      DateTime(2025, 3, 15),
    );
  });

  test('month-end anchor is restored after a shorter month', () {
    final subscription = Subscription(
      id: '2',
      name: 'Month end',
      price: 10,
      billingDate: DateTime(2025, 1, 31),
      recurrence: Recurrence.monthly,
      reminderDaysBefore: 1,
      notificationId: 2,
      createdAt: DateTime(2025, 1, 1),
    );

    expect(
      subscription.nextBillingDate(DateTime(2025, 3, 1)),
      DateTime(2025, 3, 31),
    );
  });

  test('payment event preserves billing period and receipt path', () {
    final event = SubscriptionEvent(
      id: 7,
      subscriptionId: 'subscription-1',
      type: 'payment',
      amount: 54.90,
      occurredAt: DateTime(2026, 9, 21),
      note: 'Paid by card',
      billingPeriod: 'September 2026',
      receiptPath: r'C:\app\attachments\payment_receipts\receipt.jpg',
    );

    final restored = SubscriptionEvent.fromMap(event.toMap());

    expect(restored.billingPeriod, 'September 2026');
    expect(restored.receiptPath, event.receiptPath);
    expect(restored.amount, 54.90);
  });
}
