import 'dart:async';
import '../models/models.dart';

/// ⏰ Scheduled Messages Service
///
/// Управление отложенными сообщениями:
/// - Планирование отправки сообщений
/// - Отправка по таймеру
/// - Повторные сообщения (рекуррентные)
class ScheduledMessagesService {
  static ScheduledMessagesService? _instance;
  static ScheduledMessagesService get instance {
    _instance ??= ScheduledMessagesService._();
    return _instance!;
  }

  ScheduledMessagesService._();

  /// Очередь отложенных сообщений
  final List<ScheduledMessage> _scheduledMessages = [];

  /// Таймер для проверки очереди
  Timer? _checkTimer;

  /// Запланировать сообщение
  Future<ScheduledMessage> scheduleMessage({
    required String chatId,
    required String text,
    required DateTime sendAt,
    String? encryptedText,
    bool isEncrypted = false,
    RecurrenceType? recurrence,
  }) async {
    final scheduledMessage = ScheduledMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: chatId,
      text: text,
      sendAt: sendAt,
      encryptedText: encryptedText,
      isEncrypted: isEncrypted,
      recurrence: recurrence,
      createdAt: DateTime.now(),
      status: ScheduledMessageStatus.scheduled,
    );

    _scheduledMessages.add(scheduledMessage);
    _startTimer();

    return scheduledMessage;
  }

  /// Отменить отправку
  Future<bool> cancelMessage(String messageId) async {
    final index = _scheduledMessages.indexWhere((m) => m.id == messageId);
    if (index == -1) return false;

    _scheduledMessages[index] = ScheduledMessage(
      id: _scheduledMessages[index].id,
      chatId: _scheduledMessages[index].chatId,
      text: _scheduledMessages[index].text,
      sendAt: _scheduledMessages[index].sendAt,
      encryptedText: _scheduledMessages[index].encryptedText,
      isEncrypted: _scheduledMessages[index].isEncrypted,
      recurrence: _scheduledMessages[index].recurrence,
      createdAt: _scheduledMessages[index].createdAt,
      status: ScheduledMessageStatus.cancelled,
    );

    return true;
  }

  /// Получить все запланированные сообщения
  List<ScheduledMessage> getScheduledMessages() {
    return List.unmodifiable(_scheduledMessages);
  }

  /// Получить сообщения для чата
  List<ScheduledMessage> getMessagesForChat(String chatId) {
    return _scheduledMessages
        .where((m) => m.chatId == chatId && m.status == ScheduledMessageStatus.scheduled)
        .toList();
  }

  /// Запустить таймер проверки
  void _startTimer() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkQueue();
    });
  }

  /// Проверка очереди на готовые к отправке сообщения
  Future<void> _checkQueue() async {
    final now = DateTime.now();
    final readyMessages = _scheduledMessages.where((m) =>
      m.status == ScheduledMessageStatus.scheduled &&
      m.sendAt.isBefore(now)
    ).toList();

    for (final message in readyMessages) {
      await _sendMessage(message);
    }
  }

  /// Отправка сообщения (вызывается когда пришло время)
  Future<void> _sendMessage(ScheduledMessage message) async {
    // Обновляем статус
    final index = _scheduledMessages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;

    _scheduledMessages[index] = ScheduledMessage(
      id: _scheduledMessages[index].id,
      chatId: _scheduledMessages[index].chatId,
      text: _scheduledMessages[index].text,
      sendAt: _scheduledMessages[index].sendAt,
      encryptedText: _scheduledMessages[index].encryptedText,
      isEncrypted: _scheduledMessages[index].isEncrypted,
      recurrence: _scheduledMessages[index].recurrence,
      createdAt: _scheduledMessages[index].createdAt,
      status: ScheduledMessageStatus.sent,
      sentAt: DateTime.now(),
    );

    // Если рекуррентное - создаём следующее
    if (message.recurrence != null) {
      await _createRecurrence(message);
    }

    // TODO: Вызвать отправку через P2P
    print('📤 Sending scheduled message: ${message.text}');
  }

  /// Создание рекуррентного сообщения
  Future<void> _createRecurrence(ScheduledMessage message) async {
    if (message.recurrence == null) return;

    DateTime nextSendAt;
    switch (message.recurrence!) {
      case RecurrenceType.daily:
        nextSendAt = message.sendAt.add(const Duration(days: 1));
        break;
      case RecurrenceType.weekly:
        nextSendAt = message.sendAt.add(const Duration(days: 7));
        break;
      case RecurrenceType.monthly:
        nextSendAt = DateTime(
          message.sendAt.year,
          message.sendAt.month + 1,
          message.sendAt.day,
          message.sendAt.hour,
          message.sendAt.minute,
        );
        break;
    }

    await scheduleMessage(
      chatId: message.chatId,
      text: message.text,
      sendAt: nextSendAt,
      encryptedText: message.encryptedText,
      isEncrypted: message.isEncrypted,
      recurrence: message.recurrence,
    );
  }

  /// Очистка всех сообщений
  void wipe() {
    _scheduledMessages.clear();
    _checkTimer?.cancel();
  }

  /// Очистка старых сообщений
  void cleanupOldMessages() {
    final now = DateTime.now();
    _scheduledMessages.removeWhere((m) =>
      m.status == ScheduledMessageStatus.sent &&
      m.sentAt != null &&
      now.difference(m.sentAt!).inDays > 30
    );
  }
}

/// ⏱️ Отложенное сообщение
class ScheduledMessage {
  final String id;
  final String chatId;
  final String text;
  final DateTime sendAt;
  final String? encryptedText;
  final bool isEncrypted;
  final RecurrenceType? recurrence;
  final DateTime createdAt;
  final ScheduledMessageStatus status;
  final DateTime? sentAt;

  const ScheduledMessage({
    required this.id,
    required this.chatId,
    required this.text,
    required this.sendAt,
    this.encryptedText,
    this.isEncrypted = false,
    this.recurrence,
    required this.createdAt,
    this.status = ScheduledMessageStatus.scheduled,
    this.sentAt,
  });

  /// Время до отправки
  Duration get timeUntilSend => sendAt.difference(DateTime.now());

  /// Готово ли к отправке
  bool get isReadyToSend => timeUntilSend.isNegative;
}

/// 🔄 Типы повторения
enum RecurrenceType {
  daily,    // Ежедневно
  weekly,   // Еженедельно
  monthly,  // Ежемесячно
}

/// 📊 Статус отложенного сообщения
enum ScheduledMessageStatus {
  scheduled, // Запланировано
  sent,      // Отправлено
  cancelled, // Отменено
  failed,    // Ошибка
}
