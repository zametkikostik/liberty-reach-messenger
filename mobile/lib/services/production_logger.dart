import 'package:flutter/foundation.dart';

/// 🚫 Production Logger - No Logs Policy
///
/// ТАКТИКА "NO LOGS":
/// - В релизной сборке все print() и логи отключены
/// - В debug-сборке логи работают нормально
/// - Никаких следов в логах Android/VDS
///
/// Использование:
/// ```dart
/// // Вместо print():
/// ProductionLogger.log('Сообщение');
/// 
/// // Вместо debugPrint():
/// ProductionLogger.debug('Отладочное сообщение');
/// 
/// // Вместо print() с ошибками:
/// ProductionLogger.error('Ошибка: $e');
/// ```
class ProductionLogger {
  /// Флаг: релизная ли сборка
  static bool get _isRelease => kReleaseMode;

  /// 🔇 Базовый лог (отключён в релизе)
  ///
  /// В debug: выводит сообщение
  /// В release: ничего не делает
  static void log(String message, {String tag = 'LibertyReach'}) {
    if (!_isRelease) {
      debugPrint('[$tag] $message');
    }
    // В релизе - тишина (никаких логов)
  }

  /// 🐛 Debug-лог (только для debug-сборки)
  ///
  /// В debug: выводит сообщение с префиксом "DEBUG"
  /// В release: ничего не делает
  static void debug(String message, {String tag = 'LibertyReach'}) {
    if (!_isRelease) {
      debugPrint('🐛 [$tag] DEBUG: $message');
    }
  }

  /// ❌ Error-лог (отключён в релизе)
  ///
  /// В debug: выводит ошибку
  /// В release: ничего не делает (никаких следов!)
  static void error(String message, {String tag = 'LibertyReach', dynamic error}) {
    if (!_isRelease) {
      debugPrint('❌ [$tag] ERROR: $message');
      if (error != null) {
        debugPrint('❌ [$tag] Exception: $error');
      }
    }
  }

  /// 🔐 Security-лог (всегда отключён, даже в debug!)
  ///
  /// НИКОГДА не логирует чувствительные операции:
  /// - Пароли
  /// - Ключи шифрования
  /// - Приватные данные
  ///
  /// Используйте для аудита безопасности (в будущем можно включить в secure log)
  static void security(String message, {String tag = 'SECURITY'}) {
    // Всегда тихо - даже в debug
    // Безопасность превыше всего
  }

  /// 📊 Info-лог (отключён в релизе)
  ///
  /// В debug: информационные сообщения
  /// В release: ничего не делает
  static void info(String message, {String tag = 'LibertyReach'}) {
    if (!_isRelease) {
      debugPrint('📊 [$tag] INFO: $message');
    }
  }

  /// ⚠️ Warning-лог (отключён в релизе)
  ///
  /// В debug: предупреждения
  /// В release: ничего не делает
  static void warning(String message, {String tag = 'LibertyReach'}) {
    if (!_isRelease) {
      debugPrint('⚠️ [$tag] WARNING: $message');
    }
  }

  /// 🧪 Test-лог (только для тестов)
  ///
  /// В debug: тестовые сообщения
  /// В release: ничего не делает
  static void test(String message, {String tag = 'TEST'}) {
    if (!_isRelease) {
      debugPrint('🧪 [$tag] $message');
    }
  }

  /// 🔥 Panic-лог (критические ошибки)
  ///
  /// В debug: выводит критические ошибки
  /// В release: ничего не делает (но можно включить для production monitoring)
  static void panic(String message, {String tag = 'PANIC', dynamic error}) {
    if (!_isRelease) {
      debugPrint('🔥 [$tag] CRITICAL: $message');
      if (error != null) {
        debugPrint('🔥 [$tag] Exception: $error');
      }
    }
  }

  /// 🎯 Assert-проверка (отключена в релизе)
  ///
  /// В debug: проверяет условие и логирует при неудаче
  /// В release: ничего не делает
  static void assertCheck(bool condition, String message, {String tag = 'ASSERT'}) {
    if (!_isRelease && !condition) {
      debugPrint('🎯 [$tag] ASSERT FAILED: $message');
    }
  }
}

/// 🚫 Extension для удобной замены print()
///
/// Использование:
/// ```dart
/// 'Сообщение'.secureLog();  // Ничего не делает в релизе
/// 'Debug'.secureDebug();    // Только в debug
/// ```
extension SecureLogExtension on String {
  /// Безопасный лог (отключён в релизе)
  void secureLog({String tag = 'LibertyReach'}) {
    ProductionLogger.log(this, tag: tag);
  }

  /// Debug-лог (только debug)
  void secureDebug({String tag = 'LibertyReach'}) {
    ProductionLogger.debug(this, tag: tag);
  }

  /// Error-лог (отключён в релизе)
  void secureError({String tag = 'LibertyReach', dynamic error}) {
    ProductionLogger.error(this, tag: tag, error: error);
  }

  /// Info-лог (отключён в релизе)
  void secureInfo({String tag = 'LibertyReach'}) {
    ProductionLogger.info(this, tag: tag);
  }
}
