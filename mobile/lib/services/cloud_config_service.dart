import 'dart:io';
import 'package:flutter/foundation.dart';
import 'rust_bridge_service.dart';
import 'production_logger.dart';

/// 🔐 Cloud Configuration Service
///
/// Управление мастер-ключами из облака (GitHub Secrets /环境变量):
/// - ADMIN_MASTER_KEY — для админ-панели
/// - APP_MASTER_SALT — для инициализации P2P-ноды
///
/// ⚠️ КЛЮЧИ ПЕРЕДАЮТСЯ ТОЛЬКО ЧЕРЕЗ --dart-define:
///   flutter build apk --dart-define=ADMIN_MASTER_KEY=your_key \
///                     --dart-define=APP_MASTER_SALT=your_salt
///
/// Если ключи не заданы (пустые или NOT_SET):
/// - Приложение работает как обычный мессенджер
/// - Админка полностью заблокирована
/// - P2P-нода инициализируется с дефолтными параметрами
class CloudConfigService {
  static CloudConfigService? _instance;
  static CloudConfigService get instance {
    _instance ??= CloudConfigService._();
    return _instance!;
  }

  CloudConfigService._();

  // 🔐 Мастер-ключи из dart-define
  String? _adminMasterKey;
  String? _appMasterSalt;
  
  // Флаг инициализации
  bool _isInitialized = false;

  // 🔐 Геттеры (только чтение)
  String? get adminMasterKey => _adminMasterKey;
  String? get appMasterSalt => _appMasterSalt;
  bool get isInitialized => _isInitialized;

  /// Проверка: установлен ли ADMIN_MASTER_KEY
  bool get isAdminKeySet => _adminMasterKey != null && 
                            _adminMasterKey!.isNotEmpty && 
                            _adminMasterKey != 'NOT_SET';

  /// Проверка: установлен ли APP_MASTER_SALT
  bool get isSaltSet => _appMasterSalt != null && 
                        _appMasterSalt!.isNotEmpty && 
                        _appMasterSalt != 'NOT_SET';

  /// Инициализация ключей при старте приложения
  /// 
  /// Вызывается ОДИН РАЗ в main() перед runApp()
  /// 
  /// [adminKey] — из String.fromEnvironment('ADMIN_MASTER_KEY')
  /// [salt] — из String.fromEnvironment('APP_MASTER_SALT')
  Future<bool> initialize({
    required String adminKey,
    required String salt,
  }) async {
    if (_isInitialized) {
      '⚠️ CloudConfigService already initialized'.secureDebug(tag: 'CLOUD_CONFIG');
      return false;
    }

    try {
      // Сохраняем ключи в RAM (никогда не логируем!)
      _adminMasterKey = adminKey;
      _appMasterSalt = salt;

      '✅ CloudConfigService initialized'.secureDebug(tag: 'CLOUD_CONFIG');
      
      // Логируем только факт инициализации (не значения!)
      'ADMIN_MASTER_KEY: ${isAdminKeySet ? "SET" : "NOT_SET"}'.secureDebug(tag: 'CLOUD_CONFIG');
      'APP_MASTER_SALT: ${isSaltSet ? "SET" : "NOT_SET"}'.secureDebug(tag: 'CLOUD_CONFIG');

      // Инициализация Rust-ядра с солью
      if (isSaltSet) {
        await _initializeRustBridge(salt);
      } else {
        '⚠️ APP_MASTER_SALT not set, using default P2P config'.secureDebug(tag: 'CLOUD_CONFIG');
        await _initializeRustBridge(null);
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      '❌ CloudConfigService initialization failed: $e'.secureError(tag: 'CLOUD_CONFIG');
      return false;
    }
  }

  /// Инициализация Rust Bridge с солью
  Future<void> _initializeRustBridge(String? salt) async {
    try {
      '🔧 Initializing Rust Bridge...'.secureDebug(tag: 'CLOUD_CONFIG');
      
      // Передаём соль в Rust-ядро через FFI
      await RustBridgeService.instance.init(
        salt: salt,
        isAdminMode: isAdminKeySet,
      );

      '✅ Rust Bridge initialized'.secureDebug(tag: 'CLOUD_CONFIG');
    } catch (e) {
      '❌ Rust Bridge initialization failed: $e'.secureError(tag: 'CLOUD_CONFIG');
      // Не блокируем запуск приложения при ошибке Rust
    }
  }

  /// Проверка ADMIN_MASTER_KEY
  /// 
  /// Возвращает true только если ключ совпадает с установленным
  bool verifyAdminKey(String key) {
    if (!isAdminKeySet) {
      '❌ ADMIN_MASTER_KEY not configured'.secureError(tag: 'CLOUD_CONFIG');
      return false;
    }

    final isValid = key == _adminMasterKey;
    '🔐 Admin key verification: ${isValid ? "SUCCESS" : "FAILED"}'.secureDebug(tag: 'CLOUD_CONFIG');
    return isValid;
  }

  /// Очистка ключей из памяти (при выходе)
  void wipe() {
    '🔐 Wiping CloudConfigService keys'.secureDebug(tag: 'CLOUD_CONFIG');
    _adminMasterKey = null;
    _appMasterSalt = null;
    _isInitialized = false;
  }
}
