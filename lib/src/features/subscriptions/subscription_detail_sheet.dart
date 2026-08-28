import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/attachment_service.dart';
import 'subscription.dart';
import 'subscription_providers.dart';
import 'decision_engine.dart';

class SubscriptionDetailSheet extends ConsumerStatefulWidget {
  const SubscriptionDetailSheet({super.key, required this.subscription});
  final Subscription subscription;
  @override
  ConsumerState<SubscriptionDetailSheet> createState() => _State();
}

class _State extends ConsumerState<SubscriptionDetailSheet> {
  late Future<List<SubscriptionEvent>> _events;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _events = ref
      .read(subscriptionRepositoryProvider)
      .getEvents(widget.subscription.id);

  Future<void> _logPayment() async {
    await ref
        .read(subscriptionsProvider.notifier)
        .logPayment(widget.subscription);
    setState(_reload);
  }

  Future<void> _proof() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final path =
        await AttachmentService.preserve(image.path, 'cancellation_proof');
    final s = widget.subscription;
    await ref.read(subscriptionsProvider.notifier).updateSubscription(
        subscription: s,
        name: s.name,
        price: s.price,
        billingDate: s.billingDate,
        recurrence: s.recurrence,
        reminderDaysBefore: s.reminderDaysBefore,
        category: s.category,
        status: s.status,
        trialEndDate: s.trialEndDate,
        cancellationDate: s.cancellationDate,
        cancellationReference: s.cancellationReference,
        cancellationUrl: s.cancellationUrl,
        cancellationNotes: s.cancellationNotes,
        proofPath: path,
        isEssential: s.isEssential,
        usageLevel: s.usageLevel);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cancellation proof attached.')));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subscription;
    return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        minChildSize: .5,
        maxChildSize: .95,
        builder: (_, controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(s.name,
                            style: Theme.of(context).textTheme.headlineSmall)),
                    Chip(label: Text(s.status.label))
                  ]),
                  Text(
                      '${s.category.label} · ${s.recurrence.label} · MYR ${s.price.toStringAsFixed(2)}'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cost projection',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                              'MYR ${(s.monthlyPrice * 12).toStringAsFixed(2)} per year'),
                          Text(
                              'MYR ${(s.monthlyPrice * 60).toStringAsFixed(2)} over 5 years'),
                          FutureBuilder<FinancialProfile>(
                            future: FinancialProfile.load(),
                            builder: (_, snapshot) {
                              final disposable =
                                  snapshot.data?.disposableIncome ?? 0;
                              return disposable <= 0
                                  ? const SizedBox.shrink()
                                  : Text(
                                      '${(s.monthlyPrice / disposable * 100).toStringAsFixed(1)}% of disposable income');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (s.trialEndDate != null)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.hourglass_bottom),
                        title: const Text('Trial ends'),
                        subtitle: Text(_date(s.trialEndDate!))),
                  if (s.receiptPath != null &&
                      File(s.receiptPath!).existsSync()) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(s.receiptPath!),
                            height: 180, fit: BoxFit.cover))
                  ],
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.tonalIcon(
                        onPressed: _logPayment,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Log payment')),
                    if ((s.cancellationUrl ?? '').isNotEmpty)
                      FilledButton.tonalIcon(
                          onPressed: () async {
                            final uri = Uri.tryParse(s.cancellationUrl!);
                            if (uri != null)
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Cancel online')),
                    OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(
                              text:
                                  'Please cancel my ${s.name} subscription and confirm the effective cancellation date.'));
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Cancellation message copied.')));
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy message')),
                    OutlinedButton.icon(
                        onPressed: _proof,
                        icon: const Icon(Icons.attachment),
                        label: const Text('Attach proof')),
                  ]),
                  if ((s.cancellationNotes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Cancellation notes',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(s.cancellationNotes!)
                  ],
                  const SizedBox(height: 24),
                  Text('History',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FutureBuilder<List<SubscriptionEvent>>(
                      future: _events,
                      builder: (_, snapshot) {
                        final events = snapshot.data ?? const [];
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (events.isEmpty)
                          return const Text('No activity recorded yet.');
                        return Column(
                            children: events
                                .map((event) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(event.type == 'payment'
                                        ? Icons.payments_outlined
                                        : event.type == 'price_change'
                                            ? Icons.trending_up
                                            : Icons.flag_outlined),
                                    title:
                                        Text(event.type.replaceAll('_', ' ')),
                                    subtitle: Text(
                                        event.note ?? _date(event.occurredAt)),
                                    trailing: event.amount == null
                                        ? null
                                        : Text(
                                            'MYR ${event.amount!.toStringAsFixed(2)}')))
                                .toList());
                      }),
                ]));
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
