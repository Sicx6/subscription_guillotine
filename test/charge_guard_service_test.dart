import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_guillotine/src/features/subscriptions/charge_guard_service.dart';
import 'package:subscription_guillotine/src/features/subscriptions/subscription.dart';

void main() {
  const guard = ChargeGuardService();
  final subscription = Subscription(
    id: 'youtube',
    name: 'YouTube Premium',
    price: 17.90,
    billingDate: DateTime(2026, 9, 25),
    recurrence: Recurrence.monthly,
    reminderDaysBefore: 3,
    notificationId: 1,
    createdAt: DateTime(2026, 1, 1),
  );

  test('matching receipt is accepted', () {
    final result = guard.evaluate(
      subscription: subscription,
      billingPeriod: 'September 2026',
      history: const [],
      detectedAmount: 17.90,
      detectedMerchant: 'YouTube Premium',
    );

    expect(result.status, ChargeAuditStatus.matched);
  });

  test('price increase is explained for review', () {
    final result = guard.evaluate(
      subscription: subscription,
      billingPeriod: 'September 2026',
      history: const [],
      detectedAmount: 20.90,
      detectedMerchant: 'YouTube Premium',
    );

    expect(result.status, ChargeAuditStatus.review);
    expect(result.message, contains('+16.8%'));
  });

  test('same billing period is marked as duplicate', () {
    final result = guard.evaluate(
      subscription: subscription,
      billingPeriod: 'September 2026',
      history: [
        SubscriptionEvent(
          id: 1,
          subscriptionId: 'youtube',
          type: 'payment',
          amount: 17.90,
          occurredAt: DateTime(2026, 9, 20),
          billingPeriod: 'September 2026',
        ),
      ],
      detectedAmount: 17.90,
      detectedMerchant: 'YouTube Premium',
    );

    expect(result.status, ChargeAuditStatus.duplicate);
  });
}
