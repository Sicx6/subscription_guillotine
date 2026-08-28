import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription.dart';
import 'subscription_providers.dart';

class EditSubscriptionDialog extends ConsumerStatefulWidget {
  const EditSubscriptionDialog({super.key, required this.subscription});

  final Subscription subscription;

  @override
  ConsumerState<EditSubscriptionDialog> createState() =>
      _EditSubscriptionDialogState();
}

class _EditSubscriptionDialogState
    extends ConsumerState<EditSubscriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _date;
  late Recurrence _recurrence;
  late int _reminderDaysBefore;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.subscription.name);
    _price = TextEditingController(
      text: widget.subscription.price.toStringAsFixed(2),
    );
    _date = TextEditingController(
        text: _formatDate(widget.subscription.billingDate));
    _recurrence = widget.subscription.recurrence;
    _reminderDaysBefore = widget.subscription.reminderDaysBefore;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  DateTime? _parseDate(String value) {
    final parts = value.trim().split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.day == day && date.month == month && date.year == year
        ? date
        : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(subscriptionsProvider.notifier).updateSubscription(
            subscription: widget.subscription,
            name: _name.text,
            price: double.parse(_price.text),
            billingDate: _parseDate(_date.text)!,
            recurrence: _recurrence,
            reminderDaysBefore: _reminderDaysBefore,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update subscription: $error')),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit subscription'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Service name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the service name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  enabled: !_saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Recurring price',
                    prefixText: 'MYR  ',
                  ),
                  validator: (value) {
                    final price = double.tryParse(value ?? '');
                    return price == null || price <= 0
                        ? 'Enter a valid price'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _date,
                  enabled: !_saving,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Next billing date',
                    hintText: 'DD/MM/YYYY',
                  ),
                  validator: (value) =>
                      _parseDate(value ?? '') == null ? 'Use DD/MM/YYYY' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Recurrence>(
                  value: _recurrence,
                  decoration: const InputDecoration(labelText: 'Repeats'),
                  items: Recurrence.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                            () => _recurrence = value ?? Recurrence.monthly,
                          ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _reminderDaysBefore,
                  decoration: const InputDecoration(labelText: 'Reminder'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Same day')),
                    DropdownMenuItem(value: 1, child: Text('1 day before')),
                    DropdownMenuItem(value: 3, child: Text('3 days before')),
                    DropdownMenuItem(value: 7, child: Text('7 days before')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                            () => _reminderDaysBefore = value ?? 1,
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save changes'),
        ),
      ],
    );
  }
}
