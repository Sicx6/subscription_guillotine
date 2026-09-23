import 'package:flutter/material.dart';

import 'subscription.dart';

class RenewalCheckInDraft {
  const RenewalCheckInDraft({
    required this.usage,
    required this.worthPrice,
    required this.subscribeAgain,
  });

  final UsageLevel usage;
  final bool worthPrice;
  final bool subscribeAgain;
}

class RenewalCheckInDialog extends StatefulWidget {
  const RenewalCheckInDialog({super.key, required this.subscription});

  final Subscription subscription;

  @override
  State<RenewalCheckInDialog> createState() => _RenewalCheckInDialogState();
}

class _RenewalCheckInDialogState extends State<RenewalCheckInDialog> {
  late UsageLevel _usage = widget.subscription.usageLevel;
  bool _worthPrice = true;
  bool _subscribeAgain = true;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Renewal check-in'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UsageLevel>(
                value: _usage,
                decoration: const InputDecoration(
                  labelText: 'How often did you use it?',
                ),
                items: UsageLevel.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _usage = value ?? UsageLevel.unknown),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Was it worth the price?'),
                value: _worthPrice,
                onChanged: (value) => setState(() => _worthPrice = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Would you subscribe again today?'),
                value: _subscribeAgain,
                onChanged: (value) => setState(() => _subscribeAgain = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              RenewalCheckInDraft(
                usage: _usage,
                worthPrice: _worthPrice,
                subscribeAgain: _subscribeAgain,
              ),
            ),
            child: const Text('Save check-in'),
          ),
        ],
      );
}
