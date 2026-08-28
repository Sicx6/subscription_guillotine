import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../subscriptions/subscription_providers.dart';
import '../subscriptions/subscription.dart';
import 'receipt_scanner_service.dart';
import '../../services/attachment_service.dart';

class ConfirmationScreen extends ConsumerStatefulWidget {
  const ConfirmationScreen({super.key, required this.result});

  final ReceiptScanResult result;

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _date;
  Recurrence _recurrence = Recurrence.monthly;
  int _reminderDaysBefore = 1;
  SubscriptionCategory _category = SubscriptionCategory.other;
  final _trialDate = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.result.draft;
    _name = TextEditingController(text: draft.serviceName ?? '');
    _price = TextEditingController(
      text: draft.price == null ? '' : draft.price!.toStringAsFixed(2),
    );
    _date = TextEditingController(
      text: draft.billingDate == null ? '' : _formatDate(draft.billingDate!),
    );
    _recurrence = draft.suggestedRecurrence ?? Recurrence.monthly;
    _category = draft.suggestedCategory ?? SubscriptionCategory.other;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  DateTime? _parseDate(String value) {
    final parts = value.split('/');
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
      final receiptPath =
          await AttachmentService.preserve(widget.result.imagePath, 'receipt');
      await ref.read(subscriptionsProvider.notifier).add(
            name: _name.text,
            price: double.parse(_price.text),
            billingDate: _parseDate(_date.text)!,
            recurrence: _recurrence,
            reminderDaysBefore: _reminderDaysBefore,
            category: _category,
            trialEndDate: _trialDate.text.trim().isEmpty
                ? null
                : _parseDate(_trialDate.text),
            receiptPath: receiptPath,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save subscription: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _date.dispose();
    _trialDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONFIRM DETAILS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(widget.result.imagePath),
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),
          Text('Detected details',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Check every field before saving. Missing details are intentionally left blank.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (widget.result.draft.signals.isNotEmpty) ...[
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.result.draft.signals
                    .map((signal) => Chip(label: Text(signal)))
                    .toList()),
            const SizedBox(height: 16),
          ],
          if (widget.result.draft.serviceName == null ||
              widget.result.draft.price == null ||
              widget.result.draft.billingDate == null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Some details could not be detected. Complete the blank fields manually.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Service name',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the service name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Price',
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
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Billing date',
                    hintText: 'DD/MM/YYYY',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  validator: (value) =>
                      _parseDate(value ?? '') == null ? 'Use DD/MM/YYYY' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Recurrence>(
                  value: _recurrence,
                  decoration: const InputDecoration(
                    labelText: 'Repeats',
                    prefixIcon: Icon(Icons.repeat),
                  ),
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
                  decoration: const InputDecoration(
                    labelText: 'Reminder',
                    prefixIcon: Icon(Icons.notifications_outlined),
                  ),
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
                  decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined)),
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
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                      labelText: 'Trial ends (optional)',
                      hintText: 'DD/MM/YYYY',
                      prefixIcon: Icon(Icons.hourglass_bottom)),
                  validator: (value) => value == null ||
                          value.trim().isEmpty ||
                          _parseDate(value) != null
                      ? null
                      : 'Use DD/MM/YYYY',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? 'Saving…' : 'Confirm subscription'),
          ),
        ],
      ),
    );
  }
}
