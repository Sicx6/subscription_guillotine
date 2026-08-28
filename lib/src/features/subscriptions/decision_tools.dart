import 'package:flutter/material.dart';
import 'decision_engine.dart';
import 'subscription.dart';

class SavingsSimulatorScreen extends StatefulWidget {
  const SavingsSimulatorScreen({super.key, required this.items});
  final List<Subscription> items;
  @override
  State<SavingsSimulatorScreen> createState() => _SimulatorState();
}

class _SimulatorState extends State<SavingsSimulatorScreen> {
  final selected = <String>{};
  @override
  Widget build(BuildContext context) {
    final active = widget.items
        .where((s) => s.status != SubscriptionStatus.cancelled)
        .toList();
    final current = DecisionEngine.monthlyTotal(active);
    final saved = active
        .where((s) => selected.contains(s.id))
        .fold<double>(0, (sum, s) => sum + s.monthlyPrice);
    return Scaffold(
        appBar: AppBar(title: const Text('What-if savings')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          _ResultCard(title: 'If you cut ${selected.length}', lines: [
            'New monthly spend: MYR ${(current - saved).toStringAsFixed(2)}',
            'Annual savings: MYR ${(saved * 12).toStringAsFixed(2)}',
            'Five-year savings: MYR ${(saved * 60).toStringAsFixed(2)}'
          ]),
          const SizedBox(height: 16),
          ...active.map((s) => CheckboxListTile(
              value: selected.contains(s.id),
              title: Text(s.name),
              subtitle: Text('MYR ${s.monthlyPrice.toStringAsFixed(2)}/mo'),
              onChanged: (v) => setState(() =>
                  v == true ? selected.add(s.id) : selected.remove(s.id))))
        ]));
  }
}

class GuillotineModeScreen extends StatefulWidget {
  const GuillotineModeScreen({super.key, required this.items});
  final List<Subscription> items;
  @override
  State<GuillotineModeScreen> createState() => _ModeState();
}

class _ModeState extends State<GuillotineModeScreen> {
  int index = 0;
  final cuts = <Subscription>[];
  final later = <Subscription>[];
  void choose(Subscription s, String choice) {
    if (choice == 'cut') cuts.add(s);
    if (choice == 'later') later.add(s);
    setState(() => index++);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where((s) => s.status != SubscriptionStatus.cancelled)
        .toList();
    if (index >= items.length) {
      final saved = cuts.fold<double>(0, (a, s) => a + s.monthlyPrice);
      return Scaffold(
          appBar: AppBar(title: const Text('Review complete')),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.content_cut, size: 64),
                    const SizedBox(height: 18),
                    Text('${cuts.length} selected to cut',
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text(
                        'Potential savings: MYR ${(saved * 12).toStringAsFixed(2)}/year'),
                    Text('${later.length} saved for later review'),
                    const SizedBox(height: 20),
                    FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'))
                  ]))));
    }
    final s = items[index];
    return Scaffold(
        appBar:
            AppBar(title: Text('Guillotine Mode ${index + 1}/${items.length}')),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              CircleAvatar(
                  radius: 38,
                  child: Text(s.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28))),
              const SizedBox(height: 20),
              Text(s.name, style: Theme.of(context).textTheme.headlineMedium),
              Text('MYR ${s.monthlyPrice.toStringAsFixed(2)}/month'),
              Text('MYR ${(s.monthlyPrice * 12).toStringAsFixed(2)}/year'),
              const Spacer(),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => choose(s, 'keep'),
                        child: const Text('Keep'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => choose(s, 'later'),
                        child: const Text('Later'))),
                const SizedBox(width: 8),
                Expanded(
                    child: FilledButton(
                        onPressed: () => choose(s, 'cut'),
                        child: const Text('Cut')))
              ])
            ])));
  }
}

class HealthReportScreen extends StatelessWidget {
  const HealthReportScreen({super.key, required this.items});
  final List<Subscription> items;
  @override
  Widget build(BuildContext context) {
    final active =
        items.where((s) => s.status != SubscriptionStatus.cancelled).toList();
    final cancelled =
        items.where((s) => s.status == SubscriptionStatus.cancelled).toList();
    final spend = DecisionEngine.monthlyTotal(active);
    final saved = cancelled.fold<double>(0, (a, s) => a + s.monthlyPrice);
    final categories = <SubscriptionCategory, double>{};
    for (final s in active) {
      categories[s.category] = (categories[s.category] ?? 0) + s.monthlyPrice;
    }
    final top = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
        appBar: AppBar(title: const Text('Monthly health report')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('This month', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          _ResultCard(title: 'Overview', lines: [
            '${active.length} active subscriptions',
            'MYR ${spend.toStringAsFixed(2)} monthly spend',
            'MYR ${(spend * 12).toStringAsFixed(2)} annual projection',
            'MYR ${saved.toStringAsFixed(2)} saved monthly'
          ]),
          const SizedBox(height: 16),
          _ResultCard(title: 'Signals', lines: [
            '${active.where((s) => s.trialEndDate != null).length} active trials',
            '${active.where((s) => s.usageLevel == UsageLevel.rarely).length} rarely used',
            top.isEmpty
                ? 'No category data'
                : '${top.first.key.label} is the largest category'
          ])
        ]));
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.title, required this.lines});
  final String title;
  final List<String> lines;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...lines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 6), child: Text(line)))
          ])));
}
