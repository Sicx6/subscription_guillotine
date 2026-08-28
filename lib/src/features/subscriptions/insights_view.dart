import 'package:flutter/material.dart';

import 'subscription.dart';

class InsightsView extends StatelessWidget {
  const InsightsView({super.key, required this.items});

  final List<Subscription> items;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]
      ..sort((a, b) => b.monthlyPrice.compareTo(a.monthlyPrice));
    final total = items.fold<double>(0, (sum, item) => sum + item.monthlyPrice);
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
                value: '${items.length}',
              ),
            ),
          ],
        ),
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
