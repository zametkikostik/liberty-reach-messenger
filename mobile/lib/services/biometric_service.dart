import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 🔐 Biometric Service
///
/// Биометрическая аутентификация (отпечаток/лицо)
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Доступна ли биометрия
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      debugPrint('Biometric check error: $e');
      return false;
    }
  }

  /// Типы биометрии
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Аутентификация
  Future<bool> authenticate({
    String reason = 'Authenticate to access Liberty Reach',
  }) async {
    try {
      if (!await isBiometricAvailable()) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Auth error: $e');
      return false;
    }
  }

  /// Включена ли биометрия
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _secureStorage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Включить биометрию
  Future<bool> enableBiometrics() async {
    try {
      final authenticated = await authenticate(
        reason: 'Enable biometric authentication',
      );
      if (authenticated) {
        await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Enable biometrics error: $e');
      return false;
    }
  }

  /// Выключить биометрию
  Future<void> disableBiometrics() async {
    await _secureStorage.write(key: _biometricEnabledKey, value: 'false');
  }

  /// Удалить все данные (panic wipe)
  Future<void> wipeAllSecureData() async {
    await _secureStorage.deleteAll();
  }

  /// Сохранить значение
  Future<void> storeValue(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// Получить значение
  Future<String?> getValue(String key) async {
    return await _secureStorage.read(key: key);
  }
}
