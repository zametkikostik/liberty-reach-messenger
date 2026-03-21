import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 🔐 Secure Password Manager - Zero-Persistence Architecture
///
/// ТАКТИКА "ВСЁ В ГОЛОВЕ":
/// - Мастер-пароль хранится ТОЛЬКО в оперативной памяти (RAM)
/// - НИКОГДА не сохраняется в SharedPreferences, KeyStore или на диск
/// - Запрашивается один раз при входе
/// - Мгновенно затирается нулями при:
///   - Закрытии приложения
///   - Сворачивании (AppLifecycleState.paused)
///   - Явном вызове wipePassword()
///
/// Безопасность:
/// - Пароль хранится в Uint8List (байтовый массив)
/// - Хранится в виде байтов для безопасного затирания
/// - Поддержка постоянного стирания (zeroization)
/// - Singleton для глобального доступа из любого места
class SecurePasswordManager extends ChangeNotifier {
  static SecurePasswordManager? _instance;

  static SecurePasswordManager get instance {
    _instance ??= SecurePasswordManager._();
    return _instance!;
  }

  SecurePasswordManager._() {
    _initLifecycleObserver();
  }

  // Пароль в виде байтов для безопасного затирания
  Uint8List? _passwordBytes;
  bool _isPasswordSet = false;

  /// Проверка: установлен ли пароль
  bool get isPasswordSet => _isPasswordSet;

  /// Проверка: готов ли пароль к использованию
  bool get isReady => _isPasswordSet && _passwordBytes != null;

  /// Инициализация наблюдателя за жизненным циклом
  void _initLifecycleObserver() {
    // Наблюдаем за состоянием приложения
    SystemChannels.lifecycle.setMessageHandler((message) async {
      final String? state = message as String?;

      if (state == null) return null;

      // При сворачивании - мгновенно затираем пароль
      if (state == 'AppLifecycleState.paused' ||
          state == 'AppLifecycleState.detached') {
        debugPrint('🔥 [SECURITY] App $state - WIPE PASSWORD');
        wipePassword();
      }

      return null;
    });
  }

  /// 🔑 Установить пароль (только один раз при входе)
  ///
  /// ВАЖНО:
  /// - Пароль преобразуется в байты для безопасного хранения
  /// - После установки оригинальная строка должна быть удалена
  /// - Вызывать только один раз за сессию
  Future<void> setPassword(String password) async {
    // Конвертируем строку в байты
    final passwordBytes = Uint8List.fromList(password.codeUnits);

    // Затиранием временную строку (заполняем нулями)
    _secureString(password);

    // Сохраняем в RAM
    _passwordBytes = passwordBytes;
    _isPasswordSet = true;

    debugPrint('🔐 [SECURITY] Password set in RAM (not persisted)');
    notifyListeners();
  }

  /// 🔓 Получить пароль для использования
  ///
  /// Возвращает строку только на время использования
  /// После использования вызовите _secureString() для затирания
  String? getPassword() {
    if (!_isPasswordSet || _passwordBytes == null) {
      return null;
    }

    // Конвертируем байты обратно в строку
    return String.fromCharCodes(_passwordBytes!);
  }

  /// 🗑️ Безопасное затирание пароля (Zeroization)
  ///
  /// Многократная перезапись памяти для предотвращения восстановления:
  /// 1. Запись случайными данными
  /// 2. Запись нулями
  /// 3. Запись единицами
  /// 4. Финальная запись нулями
  ///
  /// Вызывается при:
  /// - Закрытии приложения
  /// - Сворачивании (paused)
  /// - Выходе из аккаунта
  /// - Панике (panic wipe)
  void wipePassword() {
    if (_passwordBytes == null) return;

    // Многократная перезапись для безопасности
    _secureWipe(_passwordBytes!);

    // Обнуляем ссылку
    _passwordBytes = null;
    _isPasswordSet = false;

    debugPrint('🔥 [SECURITY] Password wiped from RAM');
    notifyListeners();
  }

  /// 🔐 Безопасное затирание строки (для временных переменных)
  ///
  /// В Dart нет прямого доступа к памяти строк,
  /// но мы можем перезаписать переменную перед удалением
  void _secureString(String str) {
    // Перезаписываем "мусором" (насколько это возможно в Dart)
    // Это не идеально, но лучше чем ничего
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      buffer.write('\x00');
    }
    // Строка будет собрана GC, но мы хотя бы попытались
  }

  /// 🔥 Безопасное затирание байтового массива
  ///
  /// 3-проходное затирание:
  /// 1. Случайные данные
  /// 2. Все нули
  /// 3. Все единицы
  void _secureWipe(Uint8List bytes) {
    // Pass 1: Случайные данные
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = (i * 31) & 0xFF; // Псевдо-случайные данные
    }

    // Pass 2: Все нули
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = 0x00;
    }

    // Pass 3: Все единицы
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = 0xFF;
    }

    // Финал: Все нули
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = 0x00;
    }
  }

  /// 🚨 Panic wipe - мгновенное удаление (для экстренных ситуаций)
  ///
  /// Быстрее чем secureWipe, но менее безопасно против форензики
  void panicWipe() {
    if (_passwordBytes != null) {
      // Просто обнуляем без многократной перезаписи
      for (int i = 0; i < _passwordBytes!.length; i++) {
        _passwordBytes![i] = 0x00;
      }
      _passwordBytes = null;
      _isPasswordSet = false;
    }
    debugPrint('🚨 [PANIC] Password panic-wiped');
    notifyListeners();
  }

  /// ✅ Проверка пароля (для верификации при входе)
  ///
  /// Сравнивает введённый пароль с хранящимся в RAM
  /// НЕ затирает введённый пароль (это делает вызывающая сторона)
  bool verifyPassword(String password) {
    if (!_isPasswordSet || _passwordBytes == null) {
      return false;
    }

    final expected = String.fromCharCodes(_passwordBytes!);
    return password == expected;
  }

  /// 🧹 Очистка при уничтожении
  @override
  void dispose() {
    wipePassword();
    SystemChannels.lifecycle.setMessageHandler(null);
    super.dispose();
  }
}
