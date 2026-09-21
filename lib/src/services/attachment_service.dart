import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AttachmentService {
  static Future<String> preserve(String sourcePath, String prefix,
      {String? folderName}) async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(folderName == null
        ? p.join(root.path, 'attachments')
        : p.join(root.path, 'attachments', folderName));
    await folder.create(recursive: true);
    final target = p.join(
        folder.path, '${prefix}_${DateTime.now().microsecondsSinceEpoch}.jpg');
    final compressed = await FlutterImageCompress.compressAndGetFile(
        sourcePath, target,
        quality: 82, minWidth: 1600, minHeight: 1600);
    return compressed?.path ?? (await File(sourcePath).copy(target)).path;
  }

  static Future<void> deleteIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
