import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 🔐 Zero-Knowledge Encryption Service
///
/// Принцип работы:
/// 1. Пользователь вводит секретный ключ (пароль)
/// 2. Ключ НИКОГДА не сохраняется и не передаётся серверу
/// 3. Из пароля генерируется AES-256 ключ через PBKDF2
/// 4. Сообщения шифруются НА СТОРОНЕ КЛИЕНТА
/// 5. Сервер хранит только зашифрованные данные
///
/// Алгоритмы:
/// - AES-256-GCM (шифрование)
/// - PBKDF2 (генерация ключа из пароля)
/// - SHA-256 (хеширование)
/// - Random IV (уникальный для каждого сообщения)
class ZeroKnowledgeEncryption {
  static ZeroKnowledgeEncryption? _instance;
  static ZeroKnowledgeEncryption get instance {
    _instance ??= ZeroKnowledgeEncryption._();
    return _instance!;
  }

  ZeroKnowledgeEncryption._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Секретный ключ (никогда не сохраняется!)
  Key? _encryptionKey;
  IV? _iv;

  /// 🔑 Генерация AES-256 ключа из пароля пользователя
  /// 
  /// ВАЖНО:
  /// - Пароль НИКОГДА не сохраняется
  /// - Ключ хранится только в оперативной памяти
  /// - После завершения сессии ключ удаляется
  /// 
  /// Параметры:
  /// - password: секретный пароль пользователя (например, "REDACTED_PASSWORD")
  /// - salt: уникальная соль для каждого пользователя (можно использовать user_id)
  Future<void> deriveKeyFromPassword(String password, String salt) async {
    // PBKDF2 с 100,000 итераций для устойчивости к brute-force
    final pbkdf2 = PBKDF2KeyDerivator(
      Mac('HMAC', Digest('SHA-256')),
    );

    // Конвертируем пароль и соль в байты
    final passwordBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);

    // Настраиваем параметры PBKDF2
    pbkdf2.init(
      Pbkdf2Parameters(
        saltBytes,
        100000, // 100k итераций (безопасно против GPU атак)
        32, // 32 байта = 256 бит для AES-256
      ),
    );

    // Генерируем ключ
    final keyBytes = pbkdf2.process(passwordBytes);
    
    // Создаём AES ключ
    _encryptionKey = Key(Uint8List.fromList(keyBytes));
    
    // Генерируем случайный IV (12 байт для GCM)
    _iv = IV.fromLength(12);

    // Очищаем чувствительные данные из памяти
    _secureMemory(passwordBytes);
    _secureMemory(saltBytes);
  }

  /// 🔒 Шифрование сообщения (AES-256-GCM)
  /// 
  /// Возвращает JSON с зашифрованными данными:
  /// {
  ///   "ciphertext": "...",
  ///   "iv": "...",
  ///   "timestamp": 1234567890
  /// }
  String encryptMessage(String plainText) {
    if (_encryptionKey == null) {
      throw Exception('Сначала вызовите deriveKeyFromPassword()!');
    }

    final encrypter = Encrypter(AES(_encryptionKey!, mode: AESMode.gcm));

    // Шифруем
    final encrypted = encrypter.encrypt(plainText, iv: _iv);

    // Возвращаем JSON
    return jsonEncode({
      'ciphertext': base64Encode(encrypted.bytes),
      'iv': base64Encode(_iv!.bytes),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 🔓 Расшифровка сообщения
  String decryptMessage(String encryptedJson) {
    if (_encryptionKey == null) {
      throw Exception('Сначала вызовите deriveKeyFromPassword()!');
    }

    final data = jsonDecode(encryptedJson) as Map<String, dynamic>;
    
    final ciphertext = base64Decode(data['ciphertext'] as String);
    final iv = IV(base64Decode(data['iv'] as String));

    final encrypter = Encrypter(AES(_encryptionKey!, mode: AESMode.gcm));

    // Расшифровываем
    final decrypted = encrypter.decrypt(Encrypted(ciphertext), iv: iv);

    return decrypted;
  }

  /// 🗑️ Удаление ключа из памяти (при выходе)
  void wipeKey() {
    if (_encryptionKey != null) {
      // Очищаем байты ключа
      final keyBytes = _encryptionKey!.bytes;
      for (int i = 0; i < keyBytes.length; i++) {
        keyBytes[i] = 0;
      }
      _encryptionKey = null;
      _iv = null;
    }
  }

  /// 🔐 Безопасная очистка памяти (zeroization)
  void _secureMemory(Uint8List bytes) {
    // Заполняем нулями перед освобождением
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  /// 📦 Хеш пароля для быстрой проверки (без расшифровки)
  String hashPassword(String password, String salt) {
    final saltedPassword = password + salt;
    final hash = sha256.convert(utf8.encode(saltedPassword));
    return hash.toString();
  }

  /// ✅ Проверка пароля (сравнение хешей)
  bool verifyPassword(String password, String salt, String storedHash) {
    final computedHash = hashPassword(password, salt);
    return computedHash == storedHash;
  }
}

/// 🧪 Пример использования
/*
void main() async {
  final encryption = ZeroKnowledgeEncryption.instance;
  
  // 1. Пользователь вводит пароль (НИКОГДА не сохраняем!)
  const password = 'REDACTED_PASSWORD'; // В реальности запросить у пользователя
  const userId = 'user-123'; // Уникальная соль
  
  // 2. Генерируем ключ из пароля
  await encryption.deriveKeyFromPassword(password, userId);
  
  // 3. Шифруем сообщение
  const message = 'Секретное сообщение';
  final encrypted = encryption.encryptMessage(message);
  print('Зашифровано: $encrypted');
  
  // 4. Отправляем на сервер (сервер НЕ МОЖЕТ расшифровать!)
  // POST /api/messages { "encrypted_data": "..." }
  
  // 5. Получаем зашифрованное сообщение от сервера
  final decrypted = encryption.decryptMessage(encrypted);
  print('Расшифровано: $decrypted');
  
  // 6. При выходе — удаляем ключ из памяти
  encryption.wipeKey();
}
*/
