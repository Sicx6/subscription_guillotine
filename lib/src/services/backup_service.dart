import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../features/subscriptions/subscription_repository.dart';

class BackupService {
  BackupService(this.repository);
  final SubscriptionRepository repository;

  Future<String> exportCsv() async {
    final data = await repository.exportData();
    final rows = <String>['Name,Price,Recurrence,Category,Status,Next billing'];
    for (final raw in data['subscriptions']! as List) {
      final row = raw as Map;
      rows.add([
        row['name'],
        row['price'],
        row['recurrence'],
        row['category'],
        row['status'],
        row['billing_date']
      ].map(_csv).join(','));
    }
    final path = await _write('subscription_guillotine.csv', rows.join('\n'));
    await Share.shareXFiles([XFile(path)],
        subject: 'Subscription Guillotine export');
    return path;
  }

  Future<String> exportEncrypted(String password) async {
    if (password.length < 6) throw ArgumentError('Use at least 6 characters.');
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final key = await Pbkdf2(
            macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256)
        .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    final box = await AesGcm.with256bits().encrypt(
        utf8.encode(jsonEncode(await repository.exportData())),
        secretKey: key,
        nonce: nonce);
    final envelope = jsonEncode({
      'format': 'sg-backup-1',
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes)
    });
    final path = await _write('subscription_guillotine.sgbak', envelope);
    await Share.shareXFiles([XFile(path)],
        subject: 'Encrypted subscription backup');
    return path;
  }

  Future<void> importEncrypted(String password) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path == null) return;
    final envelope =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    final salt = base64Decode(envelope['salt'] as String);
    final key = await Pbkdf2(
            macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256)
        .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    final clear = await AesGcm.with256bits().decrypt(
        SecretBox(base64Decode(envelope['cipher'] as String),
            nonce: base64Decode(envelope['nonce'] as String),
            mac: Mac(base64Decode(envelope['mac'] as String))),
        secretKey: key);
    await repository
        .importData(jsonDecode(utf8.decode(clear)) as Map<String, dynamic>);
  }

  Future<String> _write(String name, String contents) async {
    final root = await getApplicationDocumentsDirectory();
    final file = File(p.join(root.path, name));
    await file.writeAsString(contents, flush: true);
    return file.path;
  }

  String _csv(Object? value) => '"${value.toString().replaceAll('"', '""')}"';
}
