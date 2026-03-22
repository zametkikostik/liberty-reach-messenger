import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 🔐 E2EE Service
class E2EEService {
  static E2EEService? _instance;
  static E2EEService get instance {
    _instance ??= E2EEService._();
    return _instance!;
  }

  E2EEService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Key? _aesKey;
  IV? _iv;

  Future<void> deriveKeyFromPassword(String password, String salt) async {
    final hash = sha256.convert(utf8.encode('$password$salt'));
    _aesKey = Key(Uint8List.fromList(hash.bytes));
    _iv = IV.fromLength(16);
    await _storage.write(key: 'salt', value: salt);
  }

  String encryptMessage(String plainText) {
    if (_aesKey == null) throw Exception('Key not initialized');
    final encrypter = Encrypter(AES(_aesKey!, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return jsonEncode({
      'ciphertext': base64Encode(encrypted.bytes),
      'iv': base64Encode(_iv!.bytes),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  String decryptMessage(String encryptedJson) {
    if (_aesKey == null) throw Exception('Key not initialized');
    final data = jsonDecode(encryptedJson) as Map<String, dynamic>;
    final encrypter = Encrypter(AES(_aesKey!, mode: AESMode.gcm));
    final ciphertext = base64Decode(data['ciphertext'] as String);
    final iv = IV(base64Decode(data['iv'] as String));
    return encrypter.decrypt(Encrypted(ciphertext), iv: iv);
  }

  void wipeKeys() {
    _aesKey = null;
    _iv = null;
  }
}
