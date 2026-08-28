import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptDraft {
  const ReceiptDraft({this.serviceName, this.price, this.billingDate});

  final String? serviceName;
  final double? price;
  final DateTime? billingDate;
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

    return ReceiptDraft(serviceName: name, price: price, billingDate: date);
  }
}
