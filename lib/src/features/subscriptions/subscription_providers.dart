import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription.dart';
import 'subscription_repository.dart';
import '../../services/notification_service.dart';
import '../../services/home_widget_service.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (_) => SubscriptionRepository(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService.instance,
);

final subscriptionsProvider =
    AsyncNotifierProvider<SubscriptionsNotifier, List<Subscription>>(
  SubscriptionsNotifier.new,
);

class SubscriptionsNotifier extends AsyncNotifier<List<Subscription>> {
  @override
  Future<List<Subscription>> build() async {
    final items = await ref.read(subscriptionRepositoryProvider).getAll();
    await HomeWidgetService.update(items);
    return items;
  }

  Future<bool> add({
    required String name,
    required double price,
    required DateTime billingDate,
    required Recurrence recurrence,
    required int reminderDaysBefore,
    SubscriptionCategory category = SubscriptionCategory.other,
    DateTime? trialEndDate,
    String? receiptPath,
    bool isEssential = false,
    UsageLevel usageLevel = UsageLevel.unknown,
  }) async {
    final repository = ref.read(subscriptionRepositoryProvider);
    final now = DateTime.now();
    final subscription = Subscription(
      id: '${now.microsecondsSinceEpoch}',
      name: name.trim(),
      price: price,
      billingDate: billingDate,
      recurrence: recurrence,
      reminderDaysBefore: reminderDaysBefore,
      notificationId: now.microsecondsSinceEpoch.remainder(0x7fffffff),
      createdAt: now,
      category: category,
      trialEndDate: trialEndDate,
      receiptPath: receiptPath,
      isEssential: isEssential,
      usageLevel: usageLevel,
    );
    await repository.insert(subscription);
    state = AsyncData(await repository.getAll());
    await HomeWidgetService.update(state.value!);
    final notifications = ref.read(notificationServiceProvider);
    try {
      final permitted = await notifications.requestPermission();
      if (!permitted) return false;
      await notifications.schedule(subscription);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateSubscription({
    required Subscription subscription,
    required String name,
    required double price,
    required DateTime billingDate,
    required Recurrence recurrence,
    required int reminderDaysBefore,
    required SubscriptionCategory category,
    required SubscriptionStatus status,
    DateTime? trialEndDate,
    DateTime? cancellationDate,
    String? cancellationReference,
    String? cancellationUrl,
    String? cancellationNotes,
    String? proofPath,
    required bool isEssential,
    required UsageLevel usageLevel,
  }) async {
    final repository = ref.read(subscriptionRepositoryProvider);
    final updated = Subscription(
      id: subscription.id,
      name: name.trim(),
      price: price,
      billingDate: billingDate,
      recurrence: recurrence,
      reminderDaysBefore: reminderDaysBefore,
      notificationId: subscription.notificationId,
      createdAt: subscription.createdAt,
      category: category,
      status: status,
      trialEndDate: trialEndDate,
      cancellationDate: cancellationDate,
      cancellationReference: cancellationReference,
      cancellationUrl: cancellationUrl,
      cancellationNotes: cancellationNotes,
      receiptPath: subscription.receiptPath,
      proofPath: proofPath ?? subscription.proofPath,
      isEssential: isEssential,
      usageLevel: usageLevel,
    );
    if (subscription.price != price) {
      await repository.addEvent(SubscriptionEvent(
        id: null,
        subscriptionId: subscription.id,
        type: 'price_change',
        amount: price,
        occurredAt: DateTime.now(),
        note: 'Changed from MYR ${subscription.price.toStringAsFixed(2)}',
      ));
    }
    if (subscription.status != status) {
      await repository.addEvent(SubscriptionEvent(
        id: null,
        subscriptionId: subscription.id,
        type: 'status',
        amount: null,
        occurredAt: DateTime.now(),
        note: status.label,
      ));
    }
    await repository.update(updated);
    state = AsyncData(await repository.getAll());
    await HomeWidgetService.update(state.value!);
    final notifications = ref.read(notificationServiceProvider);
    try {
      if (updated.status == SubscriptionStatus.cancelled) {
        await notifications.cancel(updated.notificationId);
        return true;
      }
      final permitted = await notifications.requestPermission();
      if (!permitted) return false;
      await notifications.schedule(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logPayment(Subscription subscription) async {
    await ref.read(subscriptionRepositoryProvider).addEvent(SubscriptionEvent(
          id: null,
          subscriptionId: subscription.id,
          type: 'payment',
          amount: subscription.price,
          occurredAt: DateTime.now(),
          note: subscription.recurrence.label,
        ));
  }

  Future<void> delete(String id) async {
    final repository = ref.read(subscriptionRepositoryProvider);
    final existing = await repository.getAll();
    var notificationId = id.hashCode & 0x7fffffff;
    for (final subscription in existing) {
      if (subscription.id == id) {
        notificationId = subscription.notificationId;
        break;
      }
    }
    await repository.delete(id);
    state = AsyncData(await repository.getAll());
    await HomeWidgetService.update(state.value!);
    try {
      await ref.read(notificationServiceProvider).cancel(notificationId);
    } catch (_) {
      // The local record is authoritative; a notification failure must not
      // restore a subscription the user deliberately deleted.
    }
  }
}
