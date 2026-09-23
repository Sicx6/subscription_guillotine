import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cancellation_evidence_dialog.dart';
import 'charge_guard_service.dart';
import 'subscription.dart';
import 'decision_engine.dart';
import 'log_payment_dialog.dart';
import 'renewal_check_in_dialog.dart';
import 'subscription_detail_view_model.dart';
import 'subscription_providers.dart';

class SubscriptionDetailSheet extends ConsumerStatefulWidget {
  const SubscriptionDetailSheet({super.key, required this.subscription});
  final Subscription subscription;
  @override
  ConsumerState<SubscriptionDetailSheet> createState() => _State();
}

class _State extends ConsumerState<SubscriptionDetailSheet> {
  Future<void> _logPayment() async {
    final draft = await showDialog<PaymentDraft>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LogPaymentDialog(subscription: widget.subscription));
    if (draft == null) return;
    final audit = await ref
        .read(subscriptionDetailProvider(widget.subscription.id).notifier)
        .logPayment(
          subscription: widget.subscription,
          amount: draft.amount,
          paidAt: draft.paidAt,
          billingPeriod: draft.billingPeriod,
          imagePath: draft.imagePath,
          note: draft.note,
          detectedAmount: draft.detectedAmount,
          detectedMerchant: draft.detectedMerchant,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(audit.message)),
      );
    }
  }

  Future<void> _deleteEvent(SubscriptionEvent event) async {
    if (event.id == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete payment?'),
                content: const Text(
                    'The payment record and its receipt will be removed from this device.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'))
                ]));
    if (confirmed != true) return;
    await ref
        .read(subscriptionDetailProvider(widget.subscription.id).notifier)
        .deleteEvent(event);
  }

  Future<void> _openReceipt(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt file is unavailable.')));
      }
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
            child: InteractiveViewer(
                child: Image.file(file, fit: BoxFit.contain))));
  }

  Future<void> _addEvidence() async {
    final draft = await showDialog<CancellationEvidenceDraft>(
      context: context,
      builder: (_) => const CancellationEvidenceDialog(),
    );
    if (draft == null) return;
    await ref
        .read(subscriptionDetailProvider(widget.subscription.id).notifier)
        .addCancellationEvidence(
          imagePath: draft.imagePath,
          reference: draft.reference,
          note: draft.note,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cancellation evidence saved.')));
    }
  }

  Future<void> _checkIn() async {
    final draft = await showDialog<RenewalCheckInDraft>(
      context: context,
      builder: (_) => RenewalCheckInDialog(subscription: widget.subscription),
    );
    if (draft == null) return;
    await ref
        .read(subscriptionDetailProvider(widget.subscription.id).notifier)
        .recordCheckIn(
          subscription: widget.subscription,
          usage: draft.usage,
          worthPrice: draft.worthPrice,
          subscribeAgain: draft.subscribeAgain,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Renewal check-in saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions = ref.watch(subscriptionsProvider).valueOrNull;
    final s = subscriptions?.firstWhere(
          (item) => item.id == widget.subscription.id,
          orElse: () => widget.subscription,
        ) ??
        widget.subscription;
    final detail = ref.watch(subscriptionDetailProvider(s.id));
    final deadline =
        s.nextBillingDate().subtract(Duration(days: s.cancellationLeadDays));
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_busy_outlined),
                    title: const Text('Cancellation deadline'),
                    subtitle: Text(
                      '${_date(deadline)} · ${s.cancellationLeadDays} days before renewal',
                    ),
                  ),
                  detail.maybeWhen(
                    data: (value) => _PriceCreepCard(
                      subscription: s,
                      events: value.events,
                    ),
                    orElse: () => const SizedBox.shrink(),
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
                    FilledButton.tonalIcon(
                        onPressed: _checkIn,
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Renewal check-in')),
                    if ((s.cancellationUrl ?? '').isNotEmpty)
                      FilledButton.tonalIcon(
                          onPressed: () async {
                            final uri = Uri.tryParse(s.cancellationUrl!);
                            if (uri != null) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Cancel online')),
                    OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(
                              text:
                                  'Please cancel my ${s.name} subscription and confirm the effective cancellation date.'));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Cancellation message copied.')));
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy message')),
                    OutlinedButton.icon(
                        onPressed: _addEvidence,
                        icon: const Icon(Icons.attachment),
                        label: const Text('Add cancellation evidence')),
                  ]),
                  detail.maybeWhen(
                    data: (value) => value.evidence.isEmpty
                        ? const SizedBox.shrink()
                        : Card(
                            margin: const EdgeInsets.only(top: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cancellation evidence vault',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  ...value.evidence.map((event) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading:
                                            const Icon(Icons.verified_outlined),
                                        title: Text(_date(event.occurredAt)),
                                        subtitle: Text(event.note ??
                                            'Cancellation confirmation'),
                                        trailing: const Icon(
                                            Icons.open_in_full_outlined),
                                        onTap: event.receiptPath == null
                                            ? null
                                            : () => _openReceipt(
                                                event.receiptPath!),
                                      )),
                                ],
                              ),
                            ),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
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
                  detail.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) =>
                          Text('Could not load history: $error'),
                      data: (value) {
                        final events = value.events;
                        if (events.isEmpty) {
                          return const Text('No activity recorded yet.');
                        }
                        return Column(
                            children: events
                                .map((event) => ListTile(
                                    onTap: event.receiptPath == null
                                        ? null
                                        : () =>
                                            _openReceipt(event.receiptPath!),
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(_eventIcon(event)),
                                    title: Text(event.billingPeriod ??
                                        event.type.replaceAll('_', ' ')),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text([
                                          _date(event.occurredAt),
                                          if ((event.note ?? '').isNotEmpty)
                                            event.note!,
                                        ].join(' · ')),
                                        if ((event.auditMessage ?? '')
                                            .isNotEmpty)
                                          Text(
                                            event.auditMessage!,
                                            style: TextStyle(
                                              color: _auditColor(
                                                  context, event.auditStatus),
                                            ),
                                          ),
                                        if (_needsAuditAction(event))
                                          Wrap(
                                            spacing: 6,
                                            children: [
                                              TextButton(
                                                onPressed: () => ref
                                                    .read(
                                                        subscriptionDetailProvider(
                                                                s.id)
                                                            .notifier)
                                                    .markAuditReviewed(event),
                                                child: const Text('Reviewed'),
                                              ),
                                              if (event.amount != null &&
                                                  event.amount !=
                                                      event.expectedAmount)
                                                TextButton(
                                                  onPressed: () => ref
                                                      .read(
                                                          subscriptionDetailProvider(
                                                                  s.id)
                                                              .notifier)
                                                      .acceptDetectedPrice(
                                                          s, event),
                                                  child: const Text(
                                                      'Use as new price'),
                                                ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (event.receiptPath != null)
                                            const Icon(
                                                Icons.receipt_long_outlined),
                                          if (event.amount != null)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 8),
                                                child: Text(
                                                    'MYR ${event.amount!.toStringAsFixed(2)}')),
                                          if (event.type == 'payment' ||
                                              event.type ==
                                                  'cancellation_evidence')
                                            IconButton(
                                                tooltip: 'Delete payment',
                                                onPressed: () =>
                                                    _deleteEvent(event),
                                                icon: const Icon(
                                                    Icons.delete_outline)),
                                        ])))
                                .toList());
                      }),
                ]));
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  IconData _eventIcon(SubscriptionEvent event) {
    switch (event.type) {
      case 'payment':
        return Icons.payments_outlined;
      case 'price_change':
        return Icons.trending_up;
      case 'check_in':
        return Icons.fact_check_outlined;
      case 'cancellation_evidence':
        return Icons.verified_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  bool _needsAuditAction(SubscriptionEvent event) =>
      event.type == 'payment' &&
      event.auditStatus != null &&
      event.auditStatus != ChargeAuditStatus.matched.name &&
      event.auditStatus != ChargeAuditStatus.reviewed.name;

  Color? _auditColor(BuildContext context, String? status) {
    if (status == ChargeAuditStatus.matched.name ||
        status == ChargeAuditStatus.reviewed.name) {
      return Colors.green;
    }
    if (status == null) return null;
    return Theme.of(context).colorScheme.error;
  }
}

class _PriceCreepCard extends StatelessWidget {
  const _PriceCreepCard({
    required this.subscription,
    required this.events,
  });

  final Subscription subscription;
  final List<SubscriptionEvent> events;

  @override
  Widget build(BuildContext context) {
    final prices = events
        .where((event) =>
            (event.type == 'payment' || event.type == 'price_change') &&
            event.amount != null)
        .toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    if (prices.length < 2) return const SizedBox.shrink();

    final first = prices.first.amount!;
    final latest = prices.last.amount!;
    final increase = latest - first;
    final annualImpact = increase * 12;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price-creep timeline',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...prices.take(6).map((event) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(event.billingPeriod ??
                            '${event.occurredAt.month}/${event.occurredAt.year}'),
                      ),
                      Text('MYR ${event.amount!.toStringAsFixed(2)}'),
                    ],
                  ),
                )),
            if (increase.abs() >= .01) ...[
              const Divider(),
              Text(
                '${increase > 0 ? 'Increase' : 'Decrease'}: MYR ${increase.abs().toStringAsFixed(2)} · ${increase > 0 ? '+' : '-'}MYR ${annualImpact.abs().toStringAsFixed(2)} per year',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
