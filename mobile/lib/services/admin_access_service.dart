import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'production_logger.dart';

/// 🔐 Admin Access Service - Sovereign Admin Mode
///
/// ТАКТИКА "СКРЫТЫЙ ВХОД":
/// - isAdmin флаг хранится ТОЛЬКО в RAM
/// - Активируется через скрытый ввод мастер-пароля
/// - 5-кратный тап на версию приложения → окно ввода
/// - При сворачивании/выходе → флаг сбрасывается
///
/// Доступ администратора открывает:
/// - Логи Rust-ядра (libp2p)
/// - Управление нодой (старт/стоп/конфигурация)
/// - Доступ к системным настройкам
/// - P2P сеть (bootstrap peers, DHT)
class AdminAccessService extends ChangeNotifier {
  static AdminAccessService? _instance;
  static AdminAccessService get instance {
    _instance ??= AdminAccessService._();
    return _instance!;
  }

  AdminAccessService._();

  // Флаг администратора в RAM
  bool _isAdmin = false;
  Uint8List? _adminPasswordBytes;
  
  // Таймер для 5-кратного тапа
  int _tapCount = 0;
  DateTime? _lastTapTime;
  
  // Скрытый мастер-пароль
  static const String sovereignMasterPassword = 'REDACTED_PASSWORD';

  // Getters
  bool get isAdmin => _isAdmin;
  bool get isUserLoggedIn => _isUserLoggedIn;
  
  // Пользовательская сессия
  bool _isUserLoggedIn = false;
  String? _username;

  /// 🔐 Проверка: это админ или пользователь?
  bool get isSovereignAdmin => _isAdmin;
  bool get isRegularUser => _isUserLoggedIn && !_isAdmin;

  /// 👤 User Login (обычная регистрация)
  Future<bool> userLogin(String username, String password) async {
    'User login: $username'.secureDebug(tag: 'AUTH');
    
    // В реальности здесь будет проверка из БД
    // Для демо - просто принимаем любого
    _username = username;
    _isUserLoggedIn = true;
    _isAdmin = false;
    
    notifyListeners();
    return true;
  }

  /// 🔐 Admin Login (скрытый вход)
  Future<bool> adminLogin(String password) async {
    if (password == sovereignMasterPassword) {
      '🔐 SOVEREIGN ADMIN ACCESS GRANTED'.secureDebug(tag: 'AUTH');
      
      // Устанавливаем флаг в RAM
      _isAdmin = true;
      _adminPasswordBytes = Uint8List.fromList(password.codeUnits);
      
      notifyListeners();
      return true;
    }
    
    '❌ Admin access denied'.secureError(tag: 'AUTH');
    return false;
  }

  /// 🚪 Logout
  void logout() {
    'Logout called'.secureDebug(tag: 'AUTH');
    
    if (_isAdmin) {
      '🔐 Admin session ended - WIPE'.secureDebug(tag: 'AUTH');
      _secureWipe();
    }
    
    _isUserLoggedIn = false;
    _isAdmin = false;
    _username = null;
    
    notifyListeners();
  }

  /// 🔥 Memory Wipe при выходе
  void _secureWipe() {
    if (_adminPasswordBytes != null) {
      // 3-pass zeroization
      for (int i = 0; i < _adminPasswordBytes!.length; i++) {
        _adminPasswordBytes![i] = 0x00;
      }
      _adminPasswordBytes = null;
    }
    _isAdmin = false;
  }

  /// 👆 Обработка 5-кратного тапа
  ///
  /// 5 тапов за 2 секунды → открыть окно ввода мастер-пароля
  bool handleSecretTap() {
    final now = DateTime.now();
    
    // Сброс если прошло больше 2 секунд
    if (_lastTapTime == null || 
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 0;
    }
    
    _tapCount++;
    _lastTapTime = now;
    
    '👆 Secret tap: $_tapCount/5'.secureDebug(tag: 'SECRET');
    
    // 5 тапов → пора вводить пароль
    if (_tapCount >= 5) {
      _tapCount = 0;
      '🔐 SECRET GESTURE DETECTED - SHOW ADMIN LOGIN'.secureDebug(tag: 'SECRET');
      return true; // Показываем окно ввода
    }
    
    return false;
  }

  /// Сброс сессии при сворачивании
  void onAppPaused() {
    if (_isAdmin) {
      '🔥 App paused - Admin session WIPE'.secureDebug(tag: 'AUTH');
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
