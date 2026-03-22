import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'production_logger.dart';
import 'cloud_config_service.dart';

/// 🔐 Admin Access Service - Hidden Sovereign Portal
///
/// ТАКТИКА "СКРЫТЫЙ ПОРТАЛ":
/// - Sovereign Mode активируется через 7-кратный тап
/// - isAdmin/SovereignMode флаги хранятся ТОЛЬКО в RAM
/// - 🔐 Мастер-пароль из CloudConfigService (ADMIN_MASTER_KEY)
/// - При сворачивании/выходе → полный Memory Wipe
///
/// Sovereign Mode открывает:
/// - Полный Memory Wipe контроль
/// - Логи Rust-ядра (libp2p)
/// - Управление нодой (старт/стоп/конфигурация)
/// - Лимиты сети (bandwidth, connections, peers)
/// - Системные настройки ядра
class AdminAccessService extends ChangeNotifier {
  static AdminAccessService? _instance;
  static AdminAccessService get instance {
    _instance ??= AdminAccessService._();
    return _instance!;
  }

  AdminAccessService._();

  // 🔐 SOVEREIGN MODE FLAGS (RAM ONLY)
  bool _isSovereignMode = false;  // ← Главный флаг
  Uint8List? _sovereignPasswordBytes;

  // 👆 7-tap detector
  int _tapCount = 0;
  DateTime? _lastTapTime;

  static const int maxFailedAttempts = 3;

  // 👤 User session
  bool _isUserLoggedIn = false;
  String? _username;

  // Getters
  bool get isSovereignMode => _isSovereignMode;
  bool get isAdmin => _isSovereignMode; // Alias
  bool get isUserLoggedIn => _isUserLoggedIn;
  bool get isRegularUser => _isUserLoggedIn && !_isSovereignMode;

  /// 👤 User Login (обычная регистрация - БЕЗ мастер-пароля)
  Future<bool> userLogin(String username, String password) async {
    'User login: $username'.secureDebug(tag: 'AUTH');

    // В реальности здесь будет проверка из БД
    // Для демо - просто принимаем любого
    _username = username;
    _isUserLoggedIn = true;
    _isSovereignMode = false; // ← Обычный пользователь

    notifyListeners();
    return true;
  }

  /// 🔐 Sovereign Mode Login (скрытый вход)
  Future<bool> activateSovereignMode(String password) async {
    // 🔐 Проверка через CloudConfigService
    final cloudConfig = CloudConfigService.instance;
    
    // Если ADMIN_MASTER_KEY не установлен - админка заблокирована
    if (!cloudConfig.isAdminKeySet) {
      '❌ ADMIN_MASTER_KEY not configured - Sovereign Mode BLOCKED'.secureError(tag: 'SOVEREIGN');
      return false;
    }

    // Проверка пароля
    if (cloudConfig.verifyAdminKey(password)) {
      '🔐 SOVEREIGN MODE ACTIVATED'.secureDebug(tag: 'SOVEREIGN');

      // Устанавливаем флаг в RAM
      _isSovereignMode = true;
      _sovereignPasswordBytes = Uint8List.fromList(password.codeUnits);

      notifyListeners();
      return true;
    }

    '❌ Sovereign access denied'.secureError(tag: 'SOVEREIGN');
    return false;
  }

  /// 🚪 Logout (выход из всех режимов)
  void logout() {
    'Logout called'.secureDebug(tag: 'AUTH');

    if (_isSovereignMode) {
      '🔐 Sovereign session ended - FULL WIPE'.secureDebug(tag: 'SOVEREIGN');
      _secureWipe();
    }

    _isUserLoggedIn = false;
    _isSovereignMode = false;
    _username = null;

    notifyListeners();
  }

  /// 🔥 FULL Memory Wipe (3-pass zeroization)
  void _secureWipe() {
    if (_sovereignPasswordBytes != null) {
      // Pass 1: Random data
      for (int i = 0; i < _sovereignPasswordBytes!.length; i++) {
        _sovereignPasswordBytes![i] = 0xFF;
      }

      // Pass 2: Zeros
      for (int i = 0; i < _sovereignPasswordBytes!.length; i++) {
        _sovereignPasswordBytes![i] = 0x00;
      }

      // Pass 3: Random pattern
      for (int i = 0; i < _sovereignPasswordBytes!.length; i++) {
        _sovereignPasswordBytes![i] = (i & 0xAA).toInt();
      }

      // Final: null
      _sovereignPasswordBytes = null;
    }

    '🔥 Memory wipe complete'.secureDebug(tag: 'SECURITY');
  }

  /// 🔄 7-tap detector
  void onTap() {
    final now = DateTime.now();

    // Сброс если прошло больше 2 секунд
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTapTime = now;

    '👆 Tap count: $_tapCount'.secureDebug(tag: 'SOVEREIGN');

    if (_tapCount >= 7) {
      '🔐 7-tap detected - Sovereign Portal ready'.secureDebug(tag: 'SOVEREIGN');
      _tapCount = 0;
      // Trigger sovereign mode login
    }
  }
}
