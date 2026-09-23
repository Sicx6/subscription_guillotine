import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/attachment_service.dart';
import 'charge_guard_service.dart';
import 'subscription.dart';
import 'subscription_providers.dart';

class SubscriptionDetailState {
  const SubscriptionDetailState({required this.events});

  final List<SubscriptionEvent> events;

  List<SubscriptionEvent> get payments =>
      events.where((event) => event.type == 'payment').toList();

  List<SubscriptionEvent> get evidence =>
      events.where((event) => event.type == 'cancellation_evidence').toList();
}

final subscriptionDetailProvider = StateNotifierProvider.autoDispose.family<
    SubscriptionDetailViewModel,
    AsyncValue<SubscriptionDetailState>,
    String>((ref, subscriptionId) {
  return SubscriptionDetailViewModel(ref, subscriptionId)..load();
});

class SubscriptionDetailViewModel
    extends StateNotifier<AsyncValue<SubscriptionDetailState>> {
  SubscriptionDetailViewModel(this.ref, this.subscriptionId)
      : super(const AsyncLoading());

  final Ref ref;
  final String subscriptionId;
  final _guard = const ChargeGuardService();

  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => SubscriptionDetailState(
          events: await ref
              .read(subscriptionRepositoryProvider)
              .getEvents(subscriptionId),
        ));
  }

  Future<ChargeAudit> logPayment({
    required Subscription subscription,
    required double amount,
    required DateTime paidAt,
    required String billingPeriod,
    required String imagePath,
    String? note,
    double? detectedAmount,
    String? detectedMerchant,
  }) async {
    final repository = ref.read(subscriptionRepositoryProvider);
    final history = await repository.getEvents(subscription.id);
    final audit = _guard.evaluate(
      subscription: subscription,
      billingPeriod: billingPeriod,
      history: history,
      detectedAmount: detectedAmount,
      detectedMerchant: detectedMerchant,
    );
    final receiptPath = await AttachmentService.preserve(
      imagePath,
      'payment_${subscription.id}',
      folderName: 'payment_receipts',
    );
    await AttachmentService.deleteIfExists(imagePath);
    try {
      await repository.addEvent(SubscriptionEvent(
        id: null,
        subscriptionId: subscription.id,
        type: 'payment',
        amount: amount,
        occurredAt: paidAt,
        note: note,
        billingPeriod: billingPeriod,
        receiptPath: receiptPath,
        auditStatus: audit.status.name,
        auditMessage: audit.message,
        detectedMerchant: detectedMerchant,
        expectedAmount: subscription.price,
      ));
    } catch (_) {
      await AttachmentService.deleteIfExists(receiptPath);
      rethrow;
    }
    await load();
    return audit;
  }

  Future<void> deleteEvent(SubscriptionEvent event) async {
    if (event.id == null) return;
    final removed =
        await ref.read(subscriptionRepositoryProvider).deleteEvent(event.id!);
    await AttachmentService.deleteIfExists(removed?.receiptPath);
    await load();
  }

  Future<void> markAuditReviewed(SubscriptionEvent event) async {
    if (event.id == null) return;
    await ref.read(subscriptionRepositoryProvider).updateEventAudit(
          event.id!,
          status: ChargeAuditStatus.reviewed.name,
          message: event.auditMessage,
        );
    await load();
  }

  Future<void> acceptDetectedPrice(
      Subscription subscription, SubscriptionEvent event) async {
    if (event.amount == null) return;
    await ref
        .read(subscriptionsProvider.notifier)
        .updatePrice(subscription, event.amount!);
    await markAuditReviewed(event);
  }

  Future<void> recordCheckIn({
    required Subscription subscription,
    required UsageLevel usage,
    required bool worthPrice,
    required bool subscribeAgain,
  }) async {
    await ref.read(subscriptionsProvider.notifier).recordCheckIn(
          subscription,
          usage: usage,
          worthPrice: worthPrice,
          subscribeAgain: subscribeAgain,
        );
    await load();
  }

  Future<void> addCancellationEvidence({
    required String imagePath,
    required String reference,
    required String note,
  }) async {
    final storedPath = await AttachmentService.preserve(
      imagePath,
      'cancellation_$subscriptionId',
      folderName: 'cancellation_evidence',
    );
    await AttachmentService.deleteIfExists(imagePath);
    try {
      await ref.read(subscriptionRepositoryProvider).addEvent(SubscriptionEvent(
            id: null,
            subscriptionId: subscriptionId,
            type: 'cancellation_evidence',
            amount: null,
            occurredAt: DateTime.now(),
            note: [
              if (reference.trim().isNotEmpty) 'Reference: ${reference.trim()}',
              if (note.trim().isNotEmpty) note.trim(),
            ].join(' · '),
            receiptPath: storedPath,
          ));
    } catch (_) {
      await AttachmentService.deleteIfExists(storedPath);
      rethrow;
    }
    await load();
  }
}
