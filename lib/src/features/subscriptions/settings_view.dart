import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/backup_service.dart';
import 'subscription_providers.dart';
import 'decision_engine.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});
  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  bool _notifications = true;
  int _reminderHour = 9;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool('notifications_enabled') ?? true;
    if (mounted) {
      setState(() {
        _notifications = value;
        _reminderHour = prefs.getInt('reminder_hour') ?? 9;
      });
    }
  }

  BackupService get _backup =>
      BackupService(ref.read(subscriptionRepositoryProvider));

  Future<String?> _password(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(title),
                content: TextField(
                    controller: controller,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Password',
                        helperText: 'At least 6 characters')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: const Text('Continue'))
                ]));
    controller.dispose();
    return result;
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not complete action: $error')));
    }
  }

  Future<void> _financialProfile() async {
    final current = await FinancialProfile.load();
    final income = TextEditingController(
        text: current.monthlyIncome == 0 ? '' : '${current.monthlyIncome}');
    final commitments = TextEditingController(
        text: current.essentialCommitments == 0
            ? ''
            : '${current.essentialCommitments}');
    final budget = TextEditingController(
        text: current.targetBudget == 0 ? '' : '${current.targetBudget}');
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Financial profile'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: income,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Monthly income', prefixText: 'MYR ')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: commitments,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Essential commitments',
                          prefixText: 'MYR ')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: budget,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Target subscription budget',
                          prefixText: 'MYR ')),
                  const SizedBox(height: 8),
                  const Text(
                      'Stored only on this device and excluded from CSV.')
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () async {
                        await FinancialProfile(
                                monthlyIncome:
                                    double.tryParse(income.text) ?? 0,
                                essentialCommitments:
                                    double.tryParse(commitments.text) ?? 0,
                                targetBudget: double.tryParse(budget.text) ?? 0)
                            .save();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Save'))
                ]));
    income.dispose();
    commitments.dispose();
    budget.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        Card(
            child: Column(children: [
          ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Financial profile'),
              subtitle: const Text('Income, commitments, and target budget'),
              onTap: _financialProfile),
          SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Renewal reminders'),
              value: _notifications,
              onChanged: (value) async {
                setState(() => _notifications = value);
                (await SharedPreferences.getInstance())
                    .setBool('notifications_enabled', value);
              }),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Reminder time'),
            trailing: DropdownButton<int>(
              value: _reminderHour,
              items: const [
                DropdownMenuItem(value: 9, child: Text('9:00 AM')),
                DropdownMenuItem(value: 12, child: Text('12:00 PM')),
                DropdownMenuItem(value: 18, child: Text('6:00 PM')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _reminderHour = value);
                await (await SharedPreferences.getInstance())
                    .setInt('reminder_hour', value);
              },
            ),
          ),
          ListTile(
              leading: const Icon(Icons.notification_add_outlined),
              title: const Text('Test notification'),
              onTap: () => _run(() async {
                    if (await ref
                        .read(notificationServiceProvider)
                        .requestPermission()) {
                      await ref.read(notificationServiceProvider).showTest();
                    }
                  }, 'Test notification sent.')),
          const ListTile(
              leading: Icon(Icons.dark_mode_outlined),
              title: Text('Appearance'),
              subtitle: Text('Follows your device theme')),
        ])),
        const SizedBox(height: 18),
        Text('YOUR DATA', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Card(
            child: Column(children: [
          ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('Export CSV'),
              onTap: () => _run(() async {
                    await _backup.exportCsv();
                  }, 'CSV export created.')),
          ListTile(
              leading: const Icon(Icons.enhanced_encryption_outlined),
              title: const Text('Create encrypted backup'),
              onTap: () async {
                final password = await _password('Backup password');
                if (password != null)
                  _run(() async {
                    await _backup.exportEncrypted(password);
                  }, 'Encrypted backup created.');
              }),
          ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore encrypted backup'),
              onTap: () async {
                final password = await _password('Backup password');
                if (password != null)
                  _run(() async {
                    await _backup.importEncrypted(password);
                    ref.invalidate(subscriptionsProvider);
                  }, 'Backup restored.');
              }),
          const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Private by design'),
              subtitle: Text('Receipts and subscriptions stay on this device')),
        ])),
      ]);
}
