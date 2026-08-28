import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../subscriptions/subscription.dart';

class ReceiptDraft {
  const ReceiptDraft(
      {this.serviceName,
      this.price,
      this.billingDate,
      this.suggestedRecurrence,
      this.suggestedCategory,
      this.signals = const []});

  final String? serviceName;
  final double? price;
  final DateTime? billingDate;
  final Recurrence? suggestedRecurrence;
  final SubscriptionCategory? suggestedCategory;
  final List<String> signals;
}

class ReceiptParser {
  static final _pricePattern = RegExp(
    r'(?:RM|MYR|Total)?\s*[:$]?\s*(\d+\.\d{2})',
    caseSensitive: false,
  );
  static final _datePattern = RegExp(
    r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})',
  );

  ReceiptDraft parse(RecognizedText recognizedText) {
    final blocks = [...recognizedText.blocks]
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    final lines = blocks.expand((block) => block.lines).toList();

    String? name;
    if (blocks.isNotEmpty && blocks.first.lines.isNotEmpty) {
      final candidate = blocks.first.lines.first.text.trim();
      if (candidate.isNotEmpty) name = candidate;
    }

    double? price;
    for (final line in lines.reversed) {
      final match = _pricePattern.firstMatch(line.text.replaceAll(',', '.'));
      if (match != null) {
        price = double.tryParse(match.group(1)!);
        if (price != null) break;
      }
    }

    DateTime? date;
    for (final line in lines) {
      final match = _datePattern.firstMatch(line.text);
      if (match == null) continue;
      final day = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      var year = int.tryParse(match.group(3)!);
      if (day == null || month == null || year == null) continue;
      if (year < 100) year += 2000;
      final candidate = DateTime(year, month, day);
      if (candidate.year == year &&
          candidate.month == month &&
          candidate.day == day) {
        date = candidate;
        break;
      }
    }

    final raw = recognizedText.text.toLowerCase();
    Recurrence? recurrence;
    if (raw.contains('yearly') || raw.contains('annual'))
      recurrence = Recurrence.yearly;
    else if (raw.contains('weekly'))
      recurrence = Recurrence.weekly;
    else if (raw.contains('daily'))
      recurrence = Recurrence.daily;
    else if (raw.contains('monthly') || raw.contains('per month'))
      recurrence = Recurrence.monthly;
    SubscriptionCategory? category;
    if (RegExp(r'netflix|spotify|youtube|stream|cinema').hasMatch(raw)) {
      category = SubscriptionCategory.entertainment;
    } else if (RegExp(r'gym|fitness|workout').hasMatch(raw)) {
      category = SubscriptionCategory.fitness;
    } else if (RegExp(r'software|cloud|hosting|license').hasMatch(raw)) {
      category = SubscriptionCategory.software;
    } else if (RegExp(r'electric|water|internet|mobile|utility')
        .hasMatch(raw)) {
      category = SubscriptionCategory.utilities;
    } else if (RegExp(r'course|school|education|learning').hasMatch(raw)) {
      category = SubscriptionCategory.education;
    }
    final signals = <String>[];
    if (RegExp(r'free trial|trial ends|trial period').hasMatch(raw))
      signals.add('Trial wording detected');
    if (RegExp(r'discount|promo|promotion|save ').hasMatch(raw))
      signals.add('Discount wording detected');
    if (RegExp(r'auto.?renew|recurring|subscription').hasMatch(raw))
      signals.add('Recurring payment wording detected');
    if (RegExp(r'\btax\b|sst|gst').hasMatch(raw))
      signals.add('Tax wording detected');
    return ReceiptDraft(
        serviceName: name,
        price: price,
        billingDate: date,
        suggestedRecurrence: recurrence,
        suggestedCategory: category,
        signals: signals);
  }
}
