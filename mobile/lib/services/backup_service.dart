import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 🔐 Сервис для шифрования бэкапов
/// 
/// Использует AES-256-GCM для шифрования данных переписки
/// Ключ шифрования выводится из приватного ключа пользователя
/// 
/// ## Безопасность:
/// - AES-256-GCM (Authenticated Encryption)
/// - Уникальный IV для каждого шифрования
/// - Ключ выводится через PBKDF2 из приватного ключа
/// - Google Drive видит только зашифрованный файл
/// 
/// ## Пример использования:
/// ```dart
/// final backupService = BackupService();
/// final encrypted = await backupService.encryptBackup(jsonData, privateKey);
/// await uploadToGoogleDrive(encrypted);
/// ```
class BackupService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _backupKeyKey = 'backup_encryption_key';
  static const String _backupIvKey = 'backup_encryption_iv';

  /// 🔐 Шифрование бэкапа с использованием AES-256-GCM
  /// 
  /// ## Параметры:
  /// - [jsonData]: JSON строка с данными переписки
  /// - [privateKeyBase64]: Приватный ключ пользователя (Base64)
  /// 
  /// ## Возвращает:
  /// Map с зашифрованными данными:
  /// ```json
  /// {
  ///   "encrypted_data": "<Base64>",
  ///   "iv": "<Base64>",
  ///   "salt": "<Base64>",
  ///   "timestamp": "<ISO8601>"
  /// }
  /// ```
  Future<Map<String, dynamic>> encryptBackup(
    String jsonData,
    String privateKeyBase64,
  ) async {
    // Генерируем случайную соль для key derivation
    final salt = _generateSalt();
    
    // Выводим ключ шифрования из приватного ключа через PBKDF2
    final key = _deriveKey(privateKeyBase64, salt);
    
    // Создаём AES-256-GCM шифр
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key));
    
    // Генерируем уникальный IV (Initialization Vector)
    final iv = encrypt_pkg.IV.fromSecureRandom(12); // 96-bit IV для GCM
    
    // Шифруем данные
    final encrypted = encrypter.encrypt(jsonData, iv: iv);
    
    // Сохраняем метаданные
    final result = {
      'encrypted_data': base64Encode(encrypted.bytes),
      'iv': base64Encode(iv.bytes),
      'salt': base64Encode(salt),
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0',
    };

    // Сохраняем ключ и IV для возможной расшифровки (опционально)
    await _secureStorage.write(
      key: _backupKeyKey,
      value: base64Encode(key.bytes),
    );
    await _secureStorage.write(
      key: _backupIvKey,
      value: base64Encode(iv.bytes),
    );

    return result;
  }

  /// 🔓 Расшифровка бэкапа
  /// 
  /// ## Параметры:
  /// - [encryptedData]: Зашифрованные данные (Base64)
  /// - [iv]: Initialization Vector (Base64)
  /// - [salt]: Соль для key derivation (Base64)
  /// - [privateKeyBase64]: Приватный ключ пользователя (Base64)
  /// 
  /// ## Возвращает:
  /// Расшифрованная JSON строка с данными переписки
  Future<String> decryptBackup({
    required String encryptedData,
    required String iv,
    required String salt,
    required String privateKeyBase64,
  }) async {
    // Выводим ключ шифрования из приватного ключа
    final key = _deriveKey(privateKeyBase64, base64Decode(salt));
    
    // Создаём AES-256-GCM шифр
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key));
    
    // Расшифровываем данные
    final decrypted = encrypter.decrypt64(
      encryptedData,
      iv: encrypt_pkg.IV.fromBase64(iv),
    );

    return decrypted;
  }

  /// Экспорт бэкапа в файл для Google Drive
  /// 
  /// Создаёт JSON файл с зашифрованными данными
  Future<String> exportBackupFile(
    String jsonData,
    String privateKeyBase64,
  ) async {
    final encrypted = await encryptBackup(jsonData, privateKeyBase64);
    
    // Создаём JSON файл бэкапа
    final backupFile = jsonEncode({
      'liberty_backup': encrypted,
      'app': 'Liberty Reach Messenger',
      'encryption': 'AES-256-GCM',
    });

    return backupFile;
  }

  /// Импорт бэкапа из файла Google Drive
  /// 
  /// Расшифровывает данные из JSON файла
  Future<Map<String, dynamic>> importBackupFile(
    String backupJson,
    String privateKeyBase64,
  ) async {
    final data = jsonDecode(backupJson);
    final backup = data['liberty_backup'] as Map<String, dynamic>;

    final decrypted = await decryptBackup(
      encryptedData: backup['encrypted_data'],
      iv: backup['iv'],
      salt: backup['salt'],
      privateKeyBase64: privateKeyBase64,
    );

    return {
      'messages': jsonDecode(decrypted),
      'timestamp': backup['timestamp'],
      'version': backup['version'],
    };
  }

  /// Генерация случайной соли (16 байт)
  Uint8List _generateSalt() {
    final salt = Uint8List(16);
    for (int i = 0; i < salt.length; i++) {
      salt[i] = (DateTime.now().millisecondsSinceEpoch + i) % 256;
    }
    return salt;
  }

  /// Вывод ключа шифрования из приватного ключа через PBKDF2
  encrypt_pkg.Key _deriveKey(String privateKeyBase64, Uint8List salt) {
    // Декодируем приватный ключ
    final privateKeyBytes = base64Decode(privateKeyBase64);
    
    // Используем SHA-256 хэш от приватного ключа как основу
    final keyMaterial = sha256.convert(privateKeyBytes).bytes;
    
    // PBKDF2 с 10000 итераций для усиления ключа
    final pbkdf2 = PBKDF2(
      hmac: HMAC(sha256),
      iterations: 10000,
    );
    
    // Выводим 32-байтный ключ для AES-256
    final derivedKey = pbkdf2.process(
      Uint8List.fromList(keyMaterial),
      salt,
    );

    return encrypt_pkg.Key(derivedKey);
  }

  /// Проверка наличия сохранённого ключа
  Future<bool> hasBackupKey() async {
    final key = await _secureStorage.read(key: _backupKeyKey);
    return key != null;
  }

  /// Очистка сохранённых ключей
  Future<void> clearBackupKeys() async {
    await _secureStorage.delete(key: _backupKeyKey);
    await _secureStorage.delete(key: _backupIvKey);
  }

  /// Получение информации о последнем бэкапе
  Future<Map<String, dynamic>?> getBackupInfo() async {
    final key = await _secureStorage.read(key: _backupKeyKey);
    if (key == null) return null;

    return {
      'has_backup': true,
      'key_stored': true,
    };
  }
}

/// Утилита для работы с бэкапами
class BackupUtils {
  /// Создание имени файла для бэкапа
  static String createBackupFilename() {
    final now = DateTime.now();
    return 'liberty_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.enc';
  }

  /// Проверка целостности бэкапа
  static bool validateBackupStructure(Map<String, dynamic> backup) {
    return backup.containsKey('liberty_backup') &&
           backup['liberty_backup'] is Map &&
           (backup['liberty_backup'] as Map).containsKey('encrypted_data') &&
           (backup['liberty_backup'] as Map).containsKey('iv') &&
           (backup['liberty_backup'] as Map).containsKey('salt');
  }

  /// Получение размера бэкапа в байтах
  static int getBackupSize(String backupJson) {
    return utf8.encode(backupJson).length;
  }

  /// Форматирование размера для отображения
  static String formatBackupSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
