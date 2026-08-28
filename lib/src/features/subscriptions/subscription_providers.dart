import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription.dart';
import 'subscription_repository.dart';
import '../../services/notification_service.dart';

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
  Future<List<Subscription>> build() =>
      ref.read(subscriptionRepositoryProvider).getAll();

  Future<bool> add({
    required String name,
    required double price,
    required DateTime billingDate,
    required Recurrence recurrence,
    required int reminderDaysBefore,
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
    );
    await repository.insert(subscription);
    state = AsyncData(await repository.getAll());
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
    );
    await repository.update(updated);
    state = AsyncData(await repository.getAll());
    final notifications = ref.read(notificationServiceProvider);
    try {
      final permitted = await notifications.requestPermission();
      if (!permitted) return false;
      await notifications.schedule(updated);
      return true;
    } catch (_) {
      return false;
    }
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
    try {
      await ref.read(notificationServiceProvider).cancel(notificationId);
    } catch (_) {
      // The local record is authoritative; a notification failure must not
      // restore a subscription the user deliberately deleted.
    }
  }
}
