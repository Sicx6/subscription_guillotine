import 'package:flutter/material.dart';

import 'subscription.dart';
import 'decision_engine.dart';
import 'decision_tools.dart';

class InsightsView extends StatelessWidget {
  const InsightsView({super.key, required this.items});

  final List<Subscription> items;

  @override
  Widget build(BuildContext context) {
    final active = items
        .where((item) => item.status != SubscriptionStatus.cancelled)
        .toList();
    final cancelled = items
        .where((item) => item.status == SubscriptionStatus.cancelled)
        .toList();
    final sorted = [...active]
      ..sort((a, b) => b.monthlyPrice.compareTo(a.monthlyPrice));
    final total =
        active.fold<double>(0, (sum, item) => sum + item.monthlyPrice);
    final savings =
        cancelled.fold<double>(0, (sum, item) => sum + item.monthlyPrice);
    final highest = sorted.isEmpty ? 0.0 : sorted.first.monthlyPrice;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text('Insights', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'A simple view of where your subscription budget goes.',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Monthly spend',
                value: 'MYR ${total.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Metric(
                label: 'Active plans',
                value: '${active.length}',
              ),
            ),
          ],
        ),
        if (savings > 0) ...[
          const SizedBox(height: 12),
          _Metric(
              label: 'Saved by cancelling',
              value: 'MYR ${savings.toStringAsFixed(2)}/mo'),
        ],
        const SizedBox(height: 24),
        Text('Decision tools', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
            child: Column(children: [
          ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('What-if savings'),
              subtitle: const Text('Preview monthly and long-term savings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SavingsSimulatorScreen(items: items)))),
          ListTile(
              leading: const Icon(Icons.content_cut),
              title: const Text('Guillotine Mode'),
              subtitle: const Text('Review every subscription one by one'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => GuillotineModeScreen(items: items)))),
          ListTile(
              leading: const Icon(Icons.assessment_outlined),
              title: const Text('Monthly health report'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HealthReportScreen(items: items)))),
        ])),
        const SizedBox(height: 24),
        Text('Guillotine Scores',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<FinancialProfile>(
            future: FinancialProfile.load(),
            builder: (_, snapshot) {
              final profile = snapshot.data;
              if (profile == null) return const LinearProgressIndicator();
              final ranked = active
                  .map((s) =>
                      MapEntry(s, DecisionEngine.score(s, active, profile)))
                  .toList()
                ..sort((a, b) => b.value.value.compareTo(a.value.value));
              return Column(
                  children: ranked
                      .map((entry) => Card(
                          child: ExpansionTile(
                              title: Text(entry.key.name),
                              subtitle: Text(entry.value.label),
                              trailing: CircleAvatar(
                                  child: Text('${entry.value.value}')),
                              children: entry.value.reasons
                                  .map((reason) => ListTile(
                                      dense: true,
                                      title: Text(reason.label),
                                      trailing: Text(
                                          '${reason.points > 0 ? '+' : ''}${reason.points}')))
                                  .toList())))
                      .toList());
            }),
        const SizedBox(height: 28),
        Text('Spending by service',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        if (sorted.isEmpty)
          const _NoInsights()
        else
          ...sorted.map(
            (item) => _SpendingBar(
              item: item,
              fraction: highest == 0 ? 0 : item.monthlyPrice / highest,
            ),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
              ),
            ],
          ),
        ),
      );
}

class _SpendingBar extends StatelessWidget {
  const _SpendingBar({required this.item, required this.fraction});
  final Subscription item;
  final double fraction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 12),
                Text('MYR ${item.monthlyPrice.toStringAsFixed(2)}/mo',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 9,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      );
}

class _NoInsights extends StatelessWidget {
  const _NoInsights();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Add a subscription to see your spending breakdown.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
}
