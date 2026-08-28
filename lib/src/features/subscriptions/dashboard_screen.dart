import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../scan/scan_screen.dart';
import 'edit_subscription_dialog.dart';
import 'insights_view.dart';
import 'settings_view.dart';
import 'subscription.dart';
import 'subscription_providers.dart';
import 'subscription_detail_sheet.dart';
import 'reminders_screen.dart';

enum DashboardSort { nextBilling, category }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _tab = 0;
  String _query = '';
  DashboardSort _sort = DashboardSort.nextBilling;

  @override
  Widget build(BuildContext context) {
    final subscriptions = ref.watch(subscriptionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Guillotine',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: _tab == 0
            ? [
                IconButton(
                  onPressed: () {
                    final items = subscriptions.value ?? const <Subscription>[];
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RemindersScreen(
                          items: items,
                          onOpenSettings: () {
                            if (mounted) setState(() => _tab = 2);
                          },
                        ),
                      ),
                    );
                  },
                  tooltip: 'Notifications',
                  icon: const Icon(Icons.notifications_none),
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: subscriptions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          message: '$error',
          onRetry: () => ref.invalidate(subscriptionsProvider),
        ),
        data: (items) => IndexedStack(
          index: _tab,
          children: [
            _HomeView(
              items: items,
              query: _query,
              onQueryChanged: (value) => setState(() => _query = value),
              sort: _sort,
              onSortChanged: (value) => setState(() => _sort = value),
              onRefresh: () => ref.refresh(subscriptionsProvider.future),
            ),
            InsightsView(items: items),
            const SettingsView(),
          ],
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
              ),
              tooltip: 'Scan receipt',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.bar_chart),
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Insights',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.settings),
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.items,
    required this.query,
    required this.onQueryChanged,
    required this.onRefresh,
    required this.sort,
    required this.onSortChanged,
  });

  final List<Subscription> items;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final Future<void> Function() onRefresh;
  final DashboardSort sort;
  final ValueChanged<DashboardSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final active = items
        .where((item) => item.status != SubscriptionStatus.cancelled)
        .toList();
    final cancelled = items
        .where((item) => item.status == SubscriptionStatus.cancelled)
        .toList();
    final upcoming = active.toList()
      ..sort(
        (a, b) => a.nextBillingDate(today).compareTo(b.nextBillingDate(today)),
      );
    final next = upcoming.isEmpty ? null : upcoming.first;
    final filtered = active
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList()
      ..sort(sort == DashboardSort.category
          ? (a, b) {
              final category = a.category.label.compareTo(b.category.label);
              return category != 0 ? category : a.name.compareTo(b.name);
            }
          : (a, b) =>
              a.nextBillingDate(today).compareTo(b.nextBillingDate(today)));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _MonthlySummary(items: active, cancelled: cancelled),
          ...active.where((item) {
            final days = item.trialEndDate?.difference(today).inDays;
            return days != null && days >= 0 && days <= 7;
          }).map((item) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                    child: ListTile(
                  leading: const Icon(Icons.hourglass_bottom),
                  title: Text('${item.name} trial ends soon'),
                  subtitle: Text(_date(item.trialEndDate!)),
                )),
              )),
          const SizedBox(height: 24),
          TextField(
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              hintText: 'Search subscriptions',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 28),
            const _SectionLabel('UP NEXT'),
            const SizedBox(height: 10),
            _NextCharge(item: next),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(child: _SectionLabel('ALL SUBSCRIPTIONS')),
              Text('${filtered.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(width: 4),
              PopupMenuButton<DashboardSort>(
                initialValue: sort,
                tooltip: 'Sort subscriptions',
                icon: const Icon(Icons.sort),
                onSelected: onSortChanged,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: DashboardSort.nextBilling,
                    child: Text('Sort by next billing'),
                  ),
                  PopupMenuItem(
                    value: DashboardSort.category,
                    child: Text('Sort by category'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (active.isEmpty && cancelled.isEmpty)
            const _EmptyState()
          else if (filtered.isEmpty)
            const _NoSearchResults()
          else
            ..._subscriptionRows(filtered, sort),
          if (cancelled.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionLabel('CANCELLED'),
            ...cancelled.map((item) => _SubscriptionRow(item: item)),
          ],
        ],
      ),
    );
  }
}

List<Widget> _subscriptionRows(
  List<Subscription> items,
  DashboardSort sort,
) {
  if (sort == DashboardSort.nextBilling) {
    return items.map((item) => _SubscriptionRow(item: item)).toList();
  }

  final rows = <Widget>[];
  for (final category in SubscriptionCategory.values) {
    final categoryItems = items
        .where((subscription) => subscription.category == category)
        .toList();
    if (categoryItems.isEmpty) continue;
    rows.add(
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Row(
          children: [
            Expanded(child: _SectionLabel(category.label.toUpperCase())),
            Text('${categoryItems.length}'),
          ],
        ),
      ),
    );
    rows.addAll(
      categoryItems.map((item) => _SubscriptionRow(item: item)),
    );
  }
  return rows;
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({required this.items, required this.cancelled});
  final List<Subscription> items;
  final List<Subscription> cancelled;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.monthlyPrice);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final soon = items.where((item) {
      final days = item.nextBillingDate(today).difference(today).inDays;
      return days >= 0 && days <= 7;
    });
    final dueSoon = soon.fold<double>(0, (sum, item) => sum + item.price);
    final savings =
        cancelled.fold<double>(0, (sum, item) => sum + item.monthlyPrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MYR ${total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                )),
        const SizedBox(height: 2),
        Text(
          'monthly subscriptions',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (savings > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('MYR ${savings.toStringAsFixed(2)} saved each month',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 10),
        Text(
          '${items.length} active  ·  MYR ${dueSoon.toStringAsFixed(2)} due in 7 days',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _NextCharge extends StatelessWidget {
  const _NextCharge({required this.item});
  final Subscription item;

  @override
  Widget build(BuildContext context) {
    final nextBillingDate = item.nextBillingDate();
    final days = _daysUntil(nextBillingDate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _ServiceAvatar(name: item.name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('MYR ${item.price.toStringAsFixed(2)}'),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_date(nextBillingDate),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(_dayLabel(days),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _SubscriptionAction { edit, delete }

class _SubscriptionRow extends ConsumerWidget {
  const _SubscriptionRow({required this.item});
  final Subscription item;

  Future<void> _edit(BuildContext context) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditSubscriptionDialog(subscription: item),
    );
    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription updated.')),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete subscription?'),
        content: Text('Delete ${item.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(subscriptionsProvider.notifier).delete(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription deleted.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete subscription: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextBillingDate = item.nextBillingDate();
    final days = _daysUntil(nextBillingDate);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => SubscriptionDetailSheet(subscription: item)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        leading: _ServiceAvatar(name: item.name),
        title: Text(item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'MYR ${item.price.toStringAsFixed(2)} / ${item.recurrence.label.toLowerCase()}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_date(nextBillingDate)),
                Text(
                  _dayLabel(days),
                  style: TextStyle(
                    fontSize: 12,
                    color: days <= 3
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            PopupMenuButton<_SubscriptionAction>(
              tooltip: 'Subscription actions',
              onSelected: (action) async {
                if (action == _SubscriptionAction.edit) {
                  await _edit(context);
                } else {
                  await _delete(context, ref);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _SubscriptionAction.edit,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
                PopupMenuItem(
                  value: _SubscriptionAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceAvatar extends StatelessWidget {
  const _ServiceAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase()),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 52),
        child: Column(
          children: [
            Icon(Icons.content_cut,
                size: 52,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            const Text('No subscriptions yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            const Text('Tap + to scan your first receipt.'),
          ],
        ),
      );
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('No matching subscriptions.')),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load subscriptions\n$message',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

int _daysUntil(DateTime value) {
  final now = DateTime.now();
  return value.difference(DateTime(now.year, now.month, now.day)).inDays;
}

String _dayLabel(int days) {
  if (days < 0) return 'past due';
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  return 'in $days days';
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
