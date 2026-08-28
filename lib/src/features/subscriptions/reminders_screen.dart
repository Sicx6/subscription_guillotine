import 'package:flutter/material.dart';

import 'subscription.dart';
import 'subscription_detail_sheet.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({
    super.key,
    required this.items,
    required this.onOpenSettings,
  });

  final List<Subscription> items;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final active = items
        .where((item) => item.status != SubscriptionStatus.cancelled)
        .toList()
      ..sort(
        (a, b) => a.nextBillingDate(today).compareTo(b.nextBillingDate(today)),
      );
    final trials = active.where((item) => item.trialEndDate != null).toList()
      ..sort((a, b) => a.trialEndDate!.compareTo(b.trialEndDate!));

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Upcoming charges and trial deadlines',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (trials.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionTitle('TRIALS'),
            const SizedBox(height: 8),
            ...trials.map(
              (item) => _ReminderTile(
                item: item,
                date: item.trialEndDate!,
                icon: Icons.hourglass_bottom,
                label: 'Trial ends',
              ),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('RENEWALS'),
          const SizedBox(height: 8),
          if (active.isEmpty)
            const _EmptyReminders()
          else
            ...active.map(
              (item) => _ReminderTile(
                item: item,
                date: item.nextBillingDate(today),
                icon: Icons.event_repeat,
                label: 'Renews',
              ),
            ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              onTap: () {
                Navigator.of(context).pop();
                onOpenSettings();
              },
              leading: const Icon(Icons.tune),
              title: const Text('Notification controls'),
              subtitle: const Text(
                'Reminder permission, time, and test notification are available in Settings.',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.item,
    required this.date,
    required this.icon,
    required this.label,
  });

  final Subscription item;
  final DateTime date;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = date.difference(today).inDays;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => SubscriptionDetailSheet(subscription: item),
        ),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(item.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$label ${_date(date)} · ${item.recurrence.label}'),
        trailing: Text(
          _daysLabel(days),
          textAlign: TextAlign.end,
          style: TextStyle(
            color: days <= 3 ? Theme.of(context).colorScheme.error : null,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _daysLabel(int days) {
    if (days < 0) return 'Past due';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
            ),
      );
}

class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.notifications_none, size: 48),
            SizedBox(height: 12),
            Text('No upcoming reminders'),
          ],
        ),
      );
}
