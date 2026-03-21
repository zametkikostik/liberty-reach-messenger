import 'dart:async';
import 'package:flutter/foundation.dart';

/// ⌨️ Typing Indicator Service
///
/// - Индикатор набора текста
/// - Статусы прочтения (read receipts)
/// - Онлайн/офлайн статус
class TypingIndicatorService extends ChangeNotifier {
  static TypingIndicatorService? _instance;
  static TypingIndicatorService get instance {
    _instance ??= TypingIndicatorService._();
    return _instance!;
  }

  TypingIndicatorService._();

  // 🔗 MethodChannel для P2P
  static const platform = MethodChannel('liberty_reach/typing');

  // Активные наборы
  final Map<String, Timer> _typingTimers = {};
  final Map<String, bool> _typingStatus = {};

  /// Начало набора текста
  void startTyping(String chatId) {
    _typingStatus[chatId] = true;
    notifyListeners();

    // Отправка статуса через P2P
    platform.invokeMethod('typingStart', {'chatId': chatId});

    // Авто-сброс через 5 секунд
    _typingTimers[chatId]?.cancel();
    _typingTimers[chatId] = Timer(const Duration(seconds: 5), () {
      stopTyping(chatId);
    });
  }

  /// Конец набора текста
  void stopTyping(String chatId) {
    _typingStatus[chatId] = false;
    _typingTimers[chatId]?.cancel();
    notifyListeners();

    platform.invokeMethod('typingStop', {'chatId': chatId});
  }

  /// Проверка: печатает ли контакт
  bool isTyping(String chatId) => _typingStatus[chatId] ?? false;

  /// Получение статуса прочтения
  Future<void> markAsRead(String messageId) async {
    await platform.invokeMethod('messageRead', {'messageId': messageId});
  }

  /// Получение статуса доставки
  Future<void> markAsDelivered(String messageId) async {
    await platform.invokeMethod('messageDelivered', {'messageId': messageId});
  }
}
