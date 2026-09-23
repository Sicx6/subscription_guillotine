import 'subscription.dart';

enum ChargeAuditStatus { matched, review, duplicate, unreadable, reviewed }

class ChargeAudit {
  const ChargeAudit({required this.status, required this.messages});

  final ChargeAuditStatus status;
  final List<String> messages;

  String get message => messages.join(' ');
}

class ChargeGuardService {
  const ChargeGuardService();

  ChargeAudit evaluate({
    required Subscription subscription,
    required String billingPeriod,
    required List<SubscriptionEvent> history,
    double? detectedAmount,
    String? detectedMerchant,
  }) {
    final messages = <String>[];
    var status = ChargeAuditStatus.matched;

    final duplicate = history.any((event) =>
        event.type == 'payment' &&
        event.billingPeriod?.trim().toLowerCase() ==
            billingPeriod.trim().toLowerCase());
    if (duplicate) {
      status = ChargeAuditStatus.duplicate;
      messages.add('A payment already exists for $billingPeriod.');
    }

    if (detectedAmount == null) {
      if (status == ChargeAuditStatus.matched) {
        status = ChargeAuditStatus.unreadable;
      }
      messages.add('The receipt amount could not be read automatically.');
    } else {
      final difference = detectedAmount - subscription.price;
      if (difference.abs() >= .01) {
        if (status == ChargeAuditStatus.matched) {
          status = ChargeAuditStatus.review;
        }
        final percent =
            subscription.price == 0 ? 0 : difference / subscription.price * 100;
        messages.add(
          'Expected MYR ${subscription.price.toStringAsFixed(2)}, detected MYR ${detectedAmount.toStringAsFixed(2)} (${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%).',
        );
      }
    }

    final merchant = detectedMerchant?.trim();
    if (merchant != null &&
        merchant.isNotEmpty &&
        !_similar(merchant, subscription.name)) {
      if (status == ChargeAuditStatus.matched) {
        status = ChargeAuditStatus.review;
      }
      messages.add('Receipt merchant appears as "$merchant".');
    }

    if (messages.isEmpty) {
      messages.add('Receipt matches the expected charge.');
    }
    return ChargeAudit(status: status, messages: messages);
  }

  bool _similar(String left, String right) {
    final a = _normalize(left);
    final b = _normalize(right);
    if (a.isEmpty || b.isEmpty) return true;
    return a.contains(b) || b.contains(a);
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '')
      .replaceAll(RegExp(r'receipt|invoice|payment'), '');
}
