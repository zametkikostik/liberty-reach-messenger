import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class BackupService {
  final algorithm = AesGcm.with256bits();

  Future<Map<String, String>> encryptBackup({
    required String jsonData,
    required String privateKeyBase64,
  }) async {
    final secretKey = SecretKey(base64Decode(privateKeyBase64));
    final nonce = algorithm.newNonce();
    
    final message = utf8.encode(jsonData);
    final secretBox = await algorithm.encrypt(
      message,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'nonce': base64Encode(secretBox.nonce),
      'data': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<String?> decryptBackup({
    required Map<String, String> encryptedData,
    required String privateKeyBase64,
  }) async {
    try {
      final secretKey = SecretKey(base64Decode(privateKeyBase64));
      final secretBox = SecretBox(
        base64Decode(encryptedData['data']!),
        nonce: base64Decode(encryptedData['nonce']!),
        mac: Mac(base64Decode(encryptedData['mac']!)),
      );

      final clearText = await algorithm.decrypt(secretBox, secretKey: secretKey);
      return utf8.decode(clearText);
    } catch (e) {
      debugPrint('Decryption error: $e');
      return null;
    }
  }
}
