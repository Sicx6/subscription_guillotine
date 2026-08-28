import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_guillotine/src/features/subscriptions/decision_engine.dart';
import 'package:subscription_guillotine/src/features/subscriptions/subscription.dart';

Subscription sample(String id,
        {bool essential = false,
        UsageLevel usage = UsageLevel.unknown,
        SubscriptionCategory category = SubscriptionCategory.entertainment}) =>
    Subscription(
        id: id,
        name: 'Service $id',
        price: 60,
        billingDate: DateTime(2026, 9, 1),
        recurrence: Recurrence.monthly,
        reminderDaysBefore: 1,
        notificationId: id.hashCode & 0x7fffffff,
        createdAt: DateTime(2026),
        isEssential: essential,
        usageLevel: usage,
        category: category);

void main() {
  const profile = FinancialProfile(
      monthlyIncome: 3000, essentialCommitments: 2000, targetBudget: 150);

  test('rarely used duplicate scores higher than an essential frequent service',
      () {
    final rare = sample('rare', usage: UsageLevel.rarely);
    final duplicate = sample('duplicate');
    final essential = sample('essential',
        essential: true,
        usage: UsageLevel.often,
        category: SubscriptionCategory.utilities);
    expect(
        DecisionEngine.score(rare, [rare, duplicate, essential], profile).value,
        greaterThan(DecisionEngine.score(
                essential, [rare, duplicate, essential], profile)
            .value));
  });

  test('burden uses disposable income', () {
    final item = sample('burden');
    final score = DecisionEngine.score(item, [item], profile);
    expect(
        score.reasons
            .any((reason) => reason.label.contains('disposable income')),
        isTrue);
  });
}
