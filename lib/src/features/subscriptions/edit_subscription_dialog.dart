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
  late final TextEditingController _trialDate;
  late final TextEditingController _cancelUrl;
  late final TextEditingController _cancelReference;
  late final TextEditingController _cancelNotes;
  late Recurrence _recurrence;
  late SubscriptionCategory _category;
  late SubscriptionStatus _status;
  late bool _isEssential;
  late UsageLevel _usageLevel;
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
    _category = widget.subscription.category;
    _status = widget.subscription.status;
    _isEssential = widget.subscription.isEssential;
    _usageLevel = widget.subscription.usageLevel;
    _reminderDaysBefore = widget.subscription.reminderDaysBefore;
    _trialDate = TextEditingController(
      text: widget.subscription.trialEndDate == null
          ? ''
          : _formatDate(widget.subscription.trialEndDate!),
    );
    _cancelUrl =
        TextEditingController(text: widget.subscription.cancellationUrl ?? '');
    _cancelReference = TextEditingController(
      text: widget.subscription.cancellationReference ?? '',
    );
    _cancelNotes = TextEditingController(
        text: widget.subscription.cancellationNotes ?? '');
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
            category: _category,
            status: _status,
            trialEndDate: _trialDate.text.trim().isEmpty
                ? null
                : _parseDate(_trialDate.text),
            cancellationDate: _status == SubscriptionStatus.cancelled
                ? widget.subscription.cancellationDate ?? DateTime.now()
                : null,
            cancellationReference: _cancelReference.text.trim(),
            cancellationUrl: _cancelUrl.text.trim(),
            cancellationNotes: _cancelNotes.text.trim(),
            isEssential: _isEssential,
            usageLevel: _usageLevel,
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
    _trialDate.dispose();
    _cancelUrl.dispose();
    _cancelReference.dispose();
    _cancelNotes.dispose();
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
                const SizedBox(height: 12),
                DropdownButtonFormField<SubscriptionCategory>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: SubscriptionCategory.values
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text(value.label)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() =>
                          _category = value ?? SubscriptionCategory.other),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _trialDate,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                      labelText: 'Trial ends (optional)',
                      hintText: 'DD/MM/YYYY'),
                  validator: (value) => value == null ||
                          value.trim().isEmpty ||
                          _parseDate(value) != null
                      ? null
                      : 'Use DD/MM/YYYY',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SubscriptionStatus>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: SubscriptionStatus.values
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text(value.label)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _status = value ?? SubscriptionStatus.active),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Essential subscription'),
                  subtitle: const Text('Reduces its Guillotine Score'),
                  value: _isEssential,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isEssential = value),
                ),
                DropdownButtonFormField<UsageLevel>(
                  value: _usageLevel,
                  decoration:
                      const InputDecoration(labelText: 'How often used'),
                  items: UsageLevel.values
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                            () => _usageLevel = value ?? UsageLevel.unknown,
                          ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cancelUrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.url,
                  decoration:
                      const InputDecoration(labelText: 'Cancellation URL'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cancelReference,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                      labelText: 'Cancellation reference'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cancelNotes,
                  enabled: !_saving,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Cancellation notes'),
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
