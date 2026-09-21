import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'subscription.dart';

class PaymentDraft {
  const PaymentDraft(
      {required this.amount,
      required this.paidAt,
      required this.billingPeriod,
      required this.note,
      required this.imagePath});
  final double amount;
  final DateTime paidAt;
  final String billingPeriod;
  final String? note;
  final String imagePath;
}

class LogPaymentDialog extends StatefulWidget {
  const LogPaymentDialog({super.key, required this.subscription});
  final Subscription subscription;
  @override
  State<LogPaymentDialog> createState() => _LogPaymentDialogState();
}

class _LogPaymentDialogState extends State<LogPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _period;
  final _note = TextEditingController();
  DateTime _paidAt = DateTime.now();
  String? _imagePath;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
        text: widget.subscription.price.toStringAsFixed(2));
    _period = TextEditingController(
        text: '${_months[_paidAt.month - 1]} ${_paidAt.year}');
  }

  Future<void> _pick(ImageSource source) async {
    final image = await ImagePicker().pickImage(source: source);
    if (image != null && mounted) setState(() => _imagePath = image.path);
  }

  Future<void> _chooseSource() async {
    await showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.pop(context);
                    _pick(ImageSource.camera);
                  }),
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pick(ImageSource.gallery);
                  }),
            ])));
  }

  Future<void> _chooseDate() async {
    final value = await showDatePicker(
        context: context,
        initialDate: _paidAt,
        firstDate: DateTime(2000),
        lastDate: DateTime.now());
    if (value != null) setState(() => _paidAt = value);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a receipt as payment proof.')));
      return;
    }
    Navigator.pop(
        context,
        PaymentDraft(
            amount: double.parse(_amount.text),
            paidAt: _paidAt,
            billingPeriod: _period.text.trim(),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            imagePath: _imagePath!));
  }

  @override
  void dispose() {
    _amount.dispose();
    _period.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Log payment'),
        content: SizedBox(
          width: 430,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'MYR ',
                    ),
                    validator: (value) =>
                        (double.tryParse(value ?? '') ?? 0) <= 0
                            ? 'Enter a valid amount'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _period,
                    decoration: const InputDecoration(
                      labelText: 'Billing period',
                      hintText: 'September 2026',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the billing period'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Payment date'),
                    subtitle: Text(_date(_paidAt)),
                    onTap: _chooseDate,
                  ),
                  const SizedBox(height: 8),
                  if (_imagePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_imagePath!),
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _chooseSource,
                    icon: const Icon(Icons.receipt_long),
                    label: Text(_imagePath == null
                        ? 'Add payment receipt'
                        : 'Replace receipt'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _note,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Note (optional)'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('Save payment'),
          ),
        ],
      );

  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
