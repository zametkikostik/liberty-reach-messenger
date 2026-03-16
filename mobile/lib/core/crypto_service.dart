import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// CryptoService для работы с Ed25519 ключами
class CryptoService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _publicKeyKey = 'ed25519_public_key';
  static const String _privateKeyKey = 'ed25519_private_key';
  
  final Ed25519 _algorithm = Ed25519();
  
  /// Получить публичный ключ в Base64 формате
  Future<String> getPublicKeyBase64() async {
    final existingPublicKey = await _secureStorage.read(key: _publicKeyKey);
    if (existingPublicKey != null) {
      return existingPublicKey;
    }
    
    // Генерируем новую пару ключей
    final keyPair = await _algorithm.newKeyPair();
    
    // Получаем публичный ключ через publicKey и его bytes
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBytes = publicKey.bytes;
    final publicKeyBase64 = base64Encode(publicKeyBytes);
    
    // Получаем приватный ключ
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final privateKeyBase64 = base64Encode(privateKeyBytes);
    
    // Сохраняем оба ключа
    await _secureStorage.write(key: _publicKeyKey, value: publicKeyBase64);
    await _secureStorage.write(key: _privateKeyKey, value: privateKeyBase64);
    
    return publicKeyBase64;
  }
  
  /// Получить приватный ключ (для подписи сообщений)
  Future<String?> getPrivateKeyBase64() async {
    return await _secureStorage.read(key: _privateKeyKey);
  }
  
  /// Подписать сообщение приватным ключом
  Future<String> signMessage(Uint8List message) async {
    final privateKeyBase64 = await getPrivateKeyBase64();
    if (privateKeyBase64 == null) {
      throw Exception('Private key not found. Generate key pair first.');
    }
    
    final privateKeyBytes = base64Decode(privateKeyBase64);
    final keyPair = SimpleKeyPairData(
      privateKeyBytes,
      publicKey: SimplePublicKey(
        base64Decode(await getPublicKeyBase64()),
        type: KeyPairType.ed25519,
      ),
      type: KeyPairType.ed25519,
    );
    
    final signature = await _algorithm.sign(
      message,
      keyPair: keyPair,
    );
    
    return base64Encode(signature.bytes);
  }
  
  /// Проверить, есть ли ключи
  Future<bool> hasKeys() async {
    final publicKey = await _secureStorage.read(key: _publicKeyKey);
    return publicKey != null;
  }
  
  /// Очистить ключи (для сброса)
  Future<void> clearKeys() async {
    await _secureStorage.delete(key: _publicKeyKey);
    await _secureStorage.delete(key: _privateKeyKey);
  }
}
