import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'receipt_parser.dart';

class ReceiptScanResult {
  const ReceiptScanResult({required this.imagePath, required this.draft});

  final String imagePath;
  final ReceiptDraft draft;
}

class ReceiptScannerService {
  final _picker = ImagePicker();
  final _parser = ReceiptParser();

  Future<ReceiptScanResult?> scan(ImageSource source) async {
    final selected = await _picker.pickImage(source: source);
    if (selected == null) return null;

    final sourceFile = File(selected.path);
    final separator = Platform.pathSeparator;
    final directory = sourceFile.parent.path;
    final compressedPath =
        '$directory${separator}receipt_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      sourceFile.path,
      compressedPath,
      quality: 82,
      minWidth: 1440,
      minHeight: 1440,
    );
    final imagePath = compressed?.path ?? sourceFile.path;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return ReceiptScanResult(
        imagePath: imagePath,
        draft: _parser.parse(text),
      );
    } finally {
      await recognizer.close();
    }
  }
}
