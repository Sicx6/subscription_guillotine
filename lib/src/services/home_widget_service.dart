import 'package:home_widget/home_widget.dart';

import '../features/subscriptions/decision_engine.dart';
import '../features/subscriptions/subscription.dart';

class HomeWidgetService {
  static Future<void> update(List<Subscription> items) async {
    try {
      final active = items
          .where((item) => item.status != SubscriptionStatus.cancelled)
          .toList()
        ..sort(
          (a, b) => a.nextBillingDate().compareTo(b.nextBillingDate()),
        );
      await HomeWidget.saveWidgetData(
          'active_count', '${active.length} active');
      await HomeWidget.saveWidgetData(
        'monthly_total',
        'MYR ${DecisionEngine.monthlyTotal(active).toStringAsFixed(2)} / month',
      );
      await HomeWidget.saveWidgetData(
        'next_charge',
        active.isEmpty
            ? 'No upcoming charges'
            : '${active.first.name} · MYR ${active.first.price.toStringAsFixed(2)}',
      );
      await HomeWidget.updateWidget(name: 'SubscriptionWidgetProvider');
    } catch (_) {
      // Android widget hosts are unavailable on other platforms and in tests.
    }
  }
}
