import 'package:shared_preferences/shared_preferences.dart';
import 'subscription.dart';

class FinancialProfile {
  const FinancialProfile(
      {required this.monthlyIncome,
      required this.essentialCommitments,
      required this.targetBudget});
  final double monthlyIncome;
  final double essentialCommitments;
  final double targetBudget;
  double get disposableIncome =>
      (monthlyIncome - essentialCommitments).clamp(0, double.infinity);
  static Future<FinancialProfile> load() async {
    final p = await SharedPreferences.getInstance();
    return FinancialProfile(
        monthlyIncome: p.getDouble('monthly_income') ?? 0,
        essentialCommitments: p.getDouble('essential_commitments') ?? 0,
        targetBudget: p.getDouble('subscription_budget') ?? 0);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('monthly_income', monthlyIncome);
    await p.setDouble('essential_commitments', essentialCommitments);
    await p.setDouble('subscription_budget', targetBudget);
  }
}

class ScoreReason {
  const ScoreReason(this.label, this.points);
  final String label;
  final int points;
}

class GuillotineScore {
  const GuillotineScore(this.value, this.reasons);
  final int value;
  final List<ScoreReason> reasons;
  String get label => value >= 70
      ? 'Strongly review'
      : value >= 45
          ? 'Review'
          : value >= 25
              ? 'Consider'
              : 'Likely keep';
}

class DecisionEngine {
  static GuillotineScore score(
      Subscription item, List<Subscription> all, FinancialProfile profile) {
    final reasons = <ScoreReason>[];
    if (item.isEssential)
      reasons.add(const ScoreReason('Marked essential', -35));
    switch (item.usageLevel) {
      case UsageLevel.rarely:
        reasons.add(const ScoreReason('Rarely used', 25));
        break;
      case UsageLevel.sometimes:
        reasons.add(const ScoreReason('Used sometimes', 8));
        break;
      case UsageLevel.often:
        reasons.add(const ScoreReason('Used often', -15));
        break;
      case UsageLevel.unknown:
        reasons.add(const ScoreReason('Usage not tracked', 5));
        break;
    }
    final duplicates = all
        .where((other) =>
            other.id != item.id &&
            other.status != SubscriptionStatus.cancelled &&
            other.category == item.category)
        .length;
    if (duplicates > 0)
      reasons.add(ScoreReason(
          '$duplicates other ${item.category.label.toLowerCase()} subscription${duplicates == 1 ? '' : 's'}',
          (duplicates * 8).clamp(0, 24)));
    if (profile.disposableIncome > 0) {
      final burden = item.monthlyPrice / profile.disposableIncome * 100;
      if (burden >= 5)
        reasons.add(ScoreReason(
            '${burden.toStringAsFixed(1)}% of disposable income',
            burden >= 10 ? 25 : 15));
    }
    if (profile.targetBudget > 0 &&
        item.monthlyPrice > profile.targetBudget * .25) {
      reasons.add(const ScoreReason('Uses over 25% of target budget', 15));
    }
    if (item.trialEndDate != null)
      reasons.add(const ScoreReason('Trial subscription', 8));
    final raw = reasons.fold<int>(20, (sum, reason) => sum + reason.points);
    return GuillotineScore(raw.clamp(0, 100), reasons);
  }

  static double monthlyTotal(Iterable<Subscription> items) => items
      .where((item) => item.status != SubscriptionStatus.cancelled)
      .fold(0, (sum, item) => sum + item.monthlyPrice);
}
