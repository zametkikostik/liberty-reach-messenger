import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'production_logger.dart';

/// 🔐 Admin Access Service - Hidden Sovereign Portal
///
/// ТАКТИКА "СКРЫТЫЙ ПОРТАЛ":
/// - Sovereign Mode активируется через 7-кратный тап
/// - isAdmin/SovereignMode флаги хранятся ТОЛЬКО в RAM
/// - Мастер-пароль: REDACTED_PASSWORD
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
  
  // 🔐 MASTER PASSWORD
  static const String sovereignMasterPassword = 'REDACTED_PASSWORD';
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

  /// 👤 User Registration (новая регистрация)
  Future<bool> userRegister(String username, String password, String email) async {
    'User register: $username, $email'.secureDebug(tag: 'AUTH');
    
    // В реальности здесь будет сохранение в БД
    // Для демо - просто создаём сессию
    _username = username;
    _isUserLoggedIn = true;
    _isSovereignMode = false;
    
    notifyListeners();
    return true;
  }

  /// 🔐 Sovereign Mode Login (скрытый вход)
  Future<bool> activateSovereignMode(String password) async {
    if (password == sovereignMasterPassword) {
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
        _sovereignPasswordBytes![i] = (i * 31) & 0xFF;
      }
      
      // Pass 2: All zeros
      for (int i = 0; i < _sovereignPasswordBytes!.length; i++) {
        _sovereignPasswordBytes![i] = 0x00;
      }
      
      // Pass 3: All ones
      for (int i = 0; i < _sovereignPasswordBytes!.length; i++) {
        _sovereignPasswordBytes![i] = 0xFF;
      }
      
      // Pass 4: Final zeros
      for (int i = 0; i < _sovereignPasswordBytes!.length; i++) {
        _sovereignPasswordBytes![i] = 0x00;
      }
      
      _sovereignPasswordBytes = null;
    }
    _isSovereignMode = false;
  }

  /// 👆 Обработка 7-кратного тапа (HIDDEN SOVEREIGN PORTAL)
  ///
  /// 7 тапов за 3 секунды → активировать скрытый портал
  bool handleSecretTap() {
    final now = DateTime.now();
    
    // Сброс если прошло больше 3 секунд
    if (_lastTapTime == null || 
        now.difference(_lastTapTime!) > const Duration(seconds: 3)) {
      _tapCount = 0;
    }
    
    _tapCount++;
    _lastTapTime = now;
    
    '👆 Secret tap: $_tapCount/7'.secureDebug(tag: 'PORTAL');
    
    // 7 тапов → ОТКРЫТЬ ПОРТАЛ
    if (_tapCount >= 7) {
      _tapCount = 0;
      '🔐 HIDDEN SOVEREIGN PORTAL DETECTED'.secureDebug(tag: 'PORTAL');
      return true; // Показываем портал
    }
    
    return false;
  }

  /// ❌ Проверка пароля с 3-attempt rule
  int _failedAttempts = 0;
  
  bool checkPasswordAttempt(String password) {
    if (password == sovereignMasterPassword) {
      _failedAttempts = 0;
      return true;
    }
    
    _failedAttempts++;
    
    if (_failedAttempts >= maxFailedAttempts) {
      '🚨 PANIC WIPE: $_failedAttempts failed attempts'.secureError(tag: 'SOVEREIGN');
      _secureWipe();
      _failedAttempts = 0;
      throw SecurityException('PANIC WIPE: 3 failed attempts');
    }
    
    return false;
  }

  /// Сброс сессии при сворачивании
  void onAppPaused() {
    if (_isSovereignMode) {
      '🔥 App paused - Sovereign session FULL WIPE'.secureDebug(tag: 'SOVEREIGN');
      _secureWipe();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    logout();
    super.dispose();
  }
}
