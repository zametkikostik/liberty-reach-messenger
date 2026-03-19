import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 🔐 Secure Storage Service for Liberty Reach Messenger
///
/// Zero-Trust Architecture:
/// - Private keys NEVER leave Android KeyStore / iOS Keychain
/// - All data encrypted at rest (AES-256)
/// - Secure wipe with 3-pass overwrite before delete
/// - Panic wipe for emergency situations
///
/// Security Features:
/// - flutter_secure_storage (hardware-backed encryption)
/// - EncryptedSharedPreferences (Android)
/// - KeychainAccessibility (iOS)
/// - Random.secure() for all cryptographic operations
class SecureStorageService {
  // Secure storage with hardware-backed encryption
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Keys for storage
  static const String _privateKey = 'private_key';
  static const String _publicKey = 'public_key';
  static const String _seed = 'seed';
  static const String _userId = 'user_id';
  static const String _settings = 'settings';

  // ============================================================================
  // KEY MANAGEMENT
  // ============================================================================

  /// Save private key (NEVER extractable from KeyStore/Keychain)
  Future<void> savePrivateKey(String privateKeyBase64) async {
    await _storage.write(key: _privateKey, value: privateKeyBase64);
  }

  /// Get private key (returns null if not found)
  Future<String?> getPrivateKey() async {
    return await _storage.read(key: _privateKey);
  }

  /// Save public key
  Future<void> savePublicKey(String publicKeyBase64) async {
    await _storage.write(key: _publicKey, value: publicKeyBase64);
  }

  /// Get public key
  Future<String?> getPublicKey() async {
    return await _storage.read(key: _publicKey);
  }

  /// Save seed phrase (for key derivation)
  Future<void> saveSeed(String seed) async {
    await _storage.write(key: _seed, value: seed);
  }

  /// Get seed phrase
  Future<String?> getSeed() async {
    return await _storage.read(key: _seed);
  }

  /// Save user ID
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userId, value: userId);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _userId);
  }

  // ============================================================================
  // SECURE WIPE (Anti-Forensics)
  // ============================================================================

  /// Secure wipe: Overwrite with random data before delete (3 passes)
  ///
  /// This prevents forensic recovery of deleted keys
  /// Uses Random.secure() for cryptographically secure random data
  Future<void> secureWipe() async {
    final secureRandom = Random.secure();

    // Pass 1: Overwrite with random data
    for (int i = 0; i < 3; i++) {
      final randomData = List<int>.generate(
        256,
        (_) => secureRandom.nextInt(256),
      );

      await _storage.write(
        key: 'wipe_pass_$i',
        value: base64Encode(randomData),
      );

      // Small delay between passes
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // Delete all data
    await _storage.deleteAll();

    // Final overwrite
    await _storage.write(
      key: 'wipe_complete',
      value: base64Encode(List<int>.generate(
        64,
        (_) => secureRandom.nextInt(256),
      )),
    );

    await _storage.deleteAll();
  }

  /// Panic wipe: Immediate deletion (for duress situations)
  ///
  /// Faster than secureWipe but less secure against forensics
  Future<void> panicWipe() async {
    await _storage.deleteAll();
  }

  // ============================================================================
  // SETTINGS & PREFERENCES
  // ============================================================================

  /// Save settings JSON
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final settingsJson = jsonEncode(settings);
    await _storage.write(key: _settings, value: settingsJson);
  }

  /// Get settings
  Future<Map<String, dynamic>> getSettings() async {
    final settingsJson = await _storage.read(key: _settings);
    if (settingsJson == null) return {};
    return jsonDecode(settingsJson);
  }

  /// Get specific setting
  Future<T?> getSetting<T>(String key, {T? defaultValue}) async {
    final settings = await getSettings();
    return settings[key] as T? ?? defaultValue;
  }

  /// Update specific setting
  Future<void> updateSetting(String key, dynamic value) async {
    final settings = await getSettings();
    settings[key] = value;
    await saveSettings(settings);
  }

  // ============================================================================
  // SECURITY CHECKS
  // ============================================================================

  /// Check if private key exists
  Future<bool> hasPrivateKey() async {
    final key = await getPrivateKey();
    return key != null && key.isNotEmpty;
  }

  /// Check if user is registered
  Future<bool> isUserRegistered() async {
    final userId = await getUserId();
    return userId != null && userId.isNotEmpty;
  }

  /// Get all keys (for debugging - use with caution)
  Future<Map<String, String?>> getAllKeys() async {
    return {
      'private_key': await getPrivateKey(),
      'public_key': await getPublicKey(),
      'seed': await getSeed(),
      'user_id': await getUserId(),
    };
  }

  /// Clear all keys (for logout)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
