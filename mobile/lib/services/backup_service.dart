import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:crypto/crypto.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/digests/sha512.dart';

/// 🔐 Backup Service for Liberty Reach Messenger
///
/// Zero-Trust Backup Architecture:
/// - ALL backups encrypted BEFORE leaving device (E2EE)
/// - AES-256-GCM (Authenticated Encryption)
/// - PBKDF2 key derivation (100,000 iterations)
/// - Google Drive sees ONLY ciphertext
/// - Private key NEVER leaves device
///
/// Security Features:
/// - Random.secure() for all entropy
/// - Unique IV per encryption
/// - MAC for integrity verification
/// - Secure key derivation from private key
class BackupService {
  final Random _secureRandom = Random.secure();

  // ============================================================================
  // ENCRYPTION
  // ============================================================================

  /// Encrypt backup data with AES-256-GCM
  ///
  /// ## Parameters:
  /// - [jsonData]: JSON string with chat data (plaintext)
  /// - [privateKeyBase64]: User's private key (Base64, for key derivation)
  ///
  /// ## Returns:
  /// Map with encrypted data:
  /// ```json
  /// {
  ///   "salt": "<Base64>",
  ///   "iv": "<Base64>",
  ///   "data": "<Base64>",
  ///   "mac": "<Base64>",
  ///   "version": "1.0",
  ///   "timestamp": "<ISO8601>"
  /// }
  /// ```
  ///
  /// ## Security:
  /// - Salt: 16 bytes (Random.secure)
  /// - IV: 12 bytes (Random.secure, unique per encryption)
  /// - Key: 32 bytes (PBKDF2-SHA256, 100,000 iterations)
  /// - MAC: 16 bytes (GCM authentication tag)
  Future<Map<String, String>> encryptBackup({
    required String jsonData,
    required String privateKeyBase64,
  }) async {
    // 1. Generate random salt (16 bytes)
    final saltBytes = _generateSecureBytes(16);
    final salt = base64Encode(saltBytes);

    // 2. Derive key with PBKDF2 (100,000 iterations)
    final key = _deriveKey(privateKeyBase64, saltBytes);

    // 3. Generate random IV (12 bytes for GCM)
    final ivBytes = _generateSecureBytes(12);
    final iv = encrypt_pkg.IV(ivBytes);

    // 4. Encrypt with AES-256-GCM
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.gcm));
    final encrypted = encrypter.encrypt(jsonData, iv: iv);

    // 5. Return encrypted data with metadata
    return {
      'salt': salt,
      'iv': base64Encode(ivBytes),
      'data': base64Encode(encrypted.bytes),
      'mac': base64Encode(encrypted.mac.bytes),
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'algorithm': 'AES-256-GCM',
      'kdf': 'PBKDF2-SHA256',
      'iterations': 100000,
    };
  }

  // ============================================================================
  // DECRYPTION
  // ============================================================================

  /// Decrypt backup data
  ///
  /// ## Parameters:
  /// - [encryptedData]: Map with salt, iv, data, mac
  /// - [privateKeyBase64]: User's private key (same as encryption)
  ///
  /// ## Returns:
  /// Decrypted JSON string with chat data
  ///
  /// ## Security:
  /// - Verifies MAC before decryption
  /// - Returns null if MAC verification fails
  Future<String?> decryptBackup({
    required Map<String, String> encryptedData,
    required String privateKeyBase64,
  }) async {
    try {
      // 1. Extract parameters
      final salt = base64Decode(encryptedData['salt']!);
      final ivBytes = base64Decode(encryptedData['iv']!);
      final dataBytes = base64Decode(encryptedData['data']!);
      final macBytes = base64Decode(encryptedData['mac']!);

      // 2. Derive key (same process as encryption)
      final key = _deriveKey(privateKeyBase64, salt);

      // 3. Create IV and MAC
      final iv = encrypt_pkg.IV(ivBytes);
      final mac = encrypt_pkg.Mac(macBytes);

      // 4. Decrypt with MAC verification
      final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.gcm));
      final decrypted = encrypter.decrypt64(
        encryptedData['data']!,
        iv: iv,
        mac: mac,
      );

      return decrypted;

    } catch (e) {
      // Decryption failed (wrong key, tampered data, etc.)
      return null;
    }
  }

  // ============================================================================
  // EXPORT/IMPORT
  // ============================================================================

  /// Export backup to Google Drive compatible JSON
  ///
  /// Creates a file that can be uploaded to Google Drive
  /// The file is fully encrypted - Google cannot read contents
  Future<String> exportBackupFile({
    required String jsonData,
    required String privateKeyBase64,
  }) async {
    final encrypted = await encryptBackup(
      jsonData: jsonData,
      privateKeyBase64: privateKeyBase64,
    );

    // Create backup file structure
    final backupFile = jsonEncode({
      'liberty_backup': encrypted,
      'app': 'Liberty Reach Messenger',
      'version': '0.6.0',
      'encryption': 'AES-256-GCM',
      'note': 'This file is encrypted. Only the owner can decrypt it.',
    });

    return backupFile;
  }

  /// Import backup from Google Drive JSON file
  ///
  /// Decrypts the backup file and returns chat data
  Future<Map<String, dynamic>?> importBackupFile({
    required String backupJson,
    required String privateKeyBase64,
  }) async {
    try {
      final data = jsonDecode(backupJson);
      final backup = data['liberty_backup'] as Map<String, dynamic>;

      final decrypted = await decryptBackup(
        encryptedData: Map<String, String>.from(backup),
        privateKeyBase64: privateKeyBase64,
      );

      if (decrypted == null) return null;

      return {
        'messages': jsonDecode(decrypted),
        'timestamp': backup['timestamp'],
        'version': backup['version'],
      };
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // VALIDATION
  // ============================================================================

  /// Validate backup file structure
  static bool validateBackupStructure(Map<String, dynamic> backup) {
    if (!backup.containsKey('liberty_backup')) return false;
    
    final encrypted = backup['liberty_backup'];
    if (encrypted is! Map) return false;
    
    return encrypted.containsKey('encrypted_data') &&
           encrypted.containsKey('iv') &&
           encrypted.containsKey('salt') &&
           encrypted.containsKey('mac');
  }

  /// Get backup file size in bytes
  static int getBackupSize(String backupJson) {
    return utf8.encode(backupJson).length;
  }

  /// Format backup size for display
  static String formatBackupSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ============================================================================
  // INTERNAL HELPERS
  // ============================================================================

  /// Generate cryptographically secure random bytes
  List<int> _generateSecureBytes(int length) {
    return List<int>.generate(length, (_) => _secureRandom.nextInt(256));
  }

  /// Derive AES-256 key from private key using PBKDF2
  encrypt_pkg.Key _deriveKey(String privateKeyBase64, List<int> salt) {
    // Decode private key
    final privateKeyBytes = base64Decode(privateKeyBase64);

    // Hash private key with SHA-256
    final keyMaterial = sha256.convert(privateKeyBytes).bytes;

    // PBKDF2 with 100,000 iterations
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(
      Uint8List.fromList(keyMaterial),
      salt,
      100000, // High iterations for security
    ));

    // Derive 32-byte key for AES-256
    final derivedKey = pbkdf2.process(32);
    return encrypt_pkg.Key(derivedKey);
  }
}

/// Backup metadata for UI display
class BackupInfo {
  final String fileName;
  final int sizeBytes;
  final DateTime timestamp;
  final String version;
  final bool isEncrypted;

  BackupInfo({
    required this.fileName,
    required this.sizeBytes,
    required this.timestamp,
    required this.version,
    required this.isEncrypted,
  });

  String get formattedSize => BackupService.formatBackupSize(sizeBytes);
  
  String get formattedDate => '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  
  String get formattedTime => '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
}
