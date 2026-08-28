import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AttachmentService {
  static Future<String> preserve(String sourcePath, String prefix) async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(root.path, 'attachments'));
    await folder.create(recursive: true);
    final extension =
        p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final target = p.join(folder.path,
        '${prefix}_${DateTime.now().microsecondsSinceEpoch}$extension');
    return (await File(sourcePath).copy(target)).path;
  }
}
