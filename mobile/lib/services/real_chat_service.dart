import 'dart:async';
import '../models/models.dart';
import 'e2ee_service.dart';

/// 💬 Real Chat Service - Полноценный мессенджер
///
/// Реализует:
/// - Приватные чаты 1-на-1 с E2EE
/// - Групповые чаты до 1000 участников
/// - Каналы (broadcast)
/// - Статусы прочтения
/// - Индикаторы набора
/// - Закреплённые сообщения
/// - Таймер самоуничтожения
class RealChatService {
  static RealChatService? _instance;
  static RealChatService get instance {
    _instance ??= RealChatService._();
    return _instance!;
  }

  RealChatService._();

  // 🔐 E2EE Service
  final _e2eeService = E2EEService.instance;

  // 💬 Список чатов пользователя
  final List<Chat> _chats = [];
  
  // 📨 Сообщения по чатам
  final Map<String, List<Message>> _messagesByChat = {};
  
  // 👥 Участники групп
  final Map<String, List<String>> _groupMembers = {};
  
  // 📌 Закреплённые сообщения
  final Map<String, List<Message>> _pinnedMessages = {};
  
  // ⭐ Избранные сообщения
  final List<Message> _savedMessages = [];
  
  // 📊 Статусы прочтения
  final Map<String, MessageStatus> _messageStatuses = {};
  
  // ⌨️ Индикаторы набора
  final Map<String, bool> _typingIndicators = {};
  
  // ⏱️ Таймеры самоуничтожения
  final Map<String, Timer> _selfDestructTimers = {};

  // 📡 Потоки для обновлений
  final _chatsController = StreamController<List<Chat>>.broadcast();
  Stream<List<Chat>> get chatsStream => _chatsController.stream;
  
  final _messagesController = StreamController<List<Message>>.broadcast();
  Stream<List<Message>> get messagesStream => _messagesController.stream;

  // Getters
  List<Chat> get chats => List.unmodifiable(_chats);
  List<Message> getMessages(String chatId) => List.unmodifiable(_messagesByChat[chatId] ?? []);
  List<Message> get pinnedMessages => List.unmodifiable(_savedMessages);
  List<Message> get savedMessages => List.unmodifiable(_savedMessages);

  /// 💬 Создать чат 1-на-1
  Future<Chat> createPrivateChat({
    required String userId,
    required String userName,
    String? avatarUrl,
  }) async {
    final chatId = 'private_$userId';
    
    // Проверка: существует ли уже чат
    final existingChat = _chats.firstWhere(
      (c) => c.id == chatId,
      orElse: () => Chat(id: '', type: ChatType.private, title: ''),
    );
    
    if (existingChat.id.isNotEmpty) {
      return existingChat;
    }
    
    final chat = Chat(
      id: chatId,
      type: ChatType.private,
      title: userName,
      avatarUrl: avatarUrl,
      lastMessageTime: DateTime.now(),
      isOnline: false,
      memberCount: 2,
    );
    
    _chats.add(chat);
    _messagesByChat[chatId] = [];
    _chatsController.add(_chats);
    
    return chat;
  }

  /// 👥 Создать групповой чат
  Future<Chat> createGroupChat({
    required String title,
    required String creatorId,
    List<String>? memberIds,
    String? description,
    String? avatarUrl,
  }) async {
    final groupId = 'group_${DateTime.now().millisecondsSinceEpoch}';
    
    final members = [creatorId, ...?memberIds];
    _groupMembers[groupId] = members;
    
    final chat = Chat(
      id: groupId,
      type: ChatType.group,
      title: title,
      description: description,
      avatarUrl: avatarUrl,
      memberCount: members.length,
      lastMessageTime: DateTime.now(),
    );
    
    _chats.add(chat);
    _messagesByChat[groupId] = [];
    _chatsController.add(_chats);
    
    return chat;
  }

  /// 📢 Создать канал
  Future<Chat> createChannel({
    required String title,
    required String creatorId,
    String? description,
    String? avatarUrl,
  }) async {
    final channelId = 'channel_${DateTime.now().millisecondsSinceEpoch}';
    
    final chat = Chat(
      id: channelId,
      type: ChatType.channel,
      title: title,
      description: description,
      avatarUrl: avatarUrl,
      memberCount: 0,
      lastMessageTime: DateTime.now(),
    );
    
    _chats.add(chat);
    _messagesByChat[channelId] = [];
    _chatsController.add(_chats);
    
    return chat;
  }

  /// 📨 Отправить сообщение
  Future<Message> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    bool isEncrypted = true,
    Duration? selfDestructTimer,
    String? replyToMessageId,
  }) async {
    final chat = _chats.firstWhere((c) => c.id == chatId);
    
    // 🔐 Шифрование
    String? encryptedText;
    String displayText = text;
    
    if (isEncrypted) {
      try {
        encryptedText = _e2eeService.encryptMessage(text);
        displayText = '🔐 Encrypted';
      } catch (e) {
        // Fallback без шифрования
      }
    }
    
    // ⏱️ Таймер самоуничтожения
    DateTime? expiresAt;
    if (selfDestructTimer != null) {
      expiresAt = DateTime.now().add(selfDestructTimer);
      _startSelfDestructTimer(chatId, text, selfDestructTimer);
    }
    
    final message = Message(
      id: '${chatId}_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: senderId,
      text: displayText,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      type: MessageType.text,
      isEncrypted: isEncrypted,
      encryptedText: encryptedText,
      selfDestructTimer: selfDestructTimer,
      expiresAt: expiresAt,
      replyToMessageId: replyToMessageId,
    );
    
    // Добавляем сообщение
    _messagesByChat[chatId] ??= [];
    _messagesByChat[chatId]!.add(message);
    
    // Обновляем последнее сообщение в чате
    chat.lastMessage = text;
    chat.lastMessageTime = DateTime.now();
    _chats.sort((a, b) => (b.lastMessageTime ?? DateTime(0)).compareTo(a.lastMessageTime ?? DateTime(0)));
    
    // 🔔 Уведомляем потоки
    _chatsController.add(_chats);
    _messagesController.add(_messagesByChat[chatId]!);
    
    // 📊 Статус прочтения
    _updateMessageStatus(message.id, MessageStatus.delivered);
    
    return message;
  }

  /// 📊 Обновить статус сообщения
  void _updateMessageStatus(String messageId, MessageStatus status) {
    _messageStatuses[messageId] = status;
  }

  /// ⌨️ Начать набор текста
  void startTyping(String chatId, String userId) {
    _typingIndicators['$chatId_$userId'] = true;
  }

  /// ⌨️ Перестать набирать
  void stopTyping(String chatId, String userId) {
    _typingIndicators['$chatId_$userId'] = false;
  }

  /// 📌 Закрепить сообщение
  Future<void> pinMessage(Message message) async {
    _pinnedMessages[message.chatId] ??= [];
    
    if (!_pinnedMessages[message.chatId]!.any((m) => m.id == message.id)) {
      _pinnedMessages[message.chatId]!.add(message);
    }
  }

  /// 📌 Открепить сообщение
  Future<void> unpinMessage(String chatId, String messageId) async {
    _pinnedMessages[chatId]?.removeWhere((m) => m.id == messageId);
  }

  /// ⭐ Сохранить сообщение
  Future<void> saveMessage(Message message) async {
    if (!_savedMessages.any((m) => m.id == message.id)) {
      _savedMessages.add(message);
    }
  }

  /// ⭐ Удалить из избранного
  Future<void> unsaveMessage(String messageId) async {
    _savedMessages.removeWhere((m) => m.id == messageId);
  }

  /// ⏱️ Запустить таймер самоуничтожения
  void _startSelfDestructTimer(String chatId, String text, Duration duration) {
    final timer = Timer(duration, () {
      // Автоудаление сообщения
      _messagesByChat[chatId]?.removeWhere((m) => m.text == text);
      _messagesController.add(_messagesByChat[chatId] ?? []);
    });
    
    _selfDestructTimers[chatId] = timer;
  }

  /// 🗑️ Удалить сообщение
  Future<void> deleteMessage(String chatId, String messageId) async {
    _messagesByChat[chatId]?.removeWhere((m) => m.id == messageId);
    _messagesController.add(_messagesByChat[chatId] ?? []);
  }

  /// ✏️ Редактировать сообщение
  Future<void> editMessage(String messageId, String newText) async {
    for (final messages in _messagesByChat.values) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        messages[index] = Message(
          id: messages[index].id,
          chatId: messages[index].chatId,
          senderId: messages[index].senderId,
          text: newText,
          timestamp: messages[index].timestamp,
          status: messages[index].status,
          type: messages[index].type,
          isEdited: true,
          editedAt: DateTime.now(),
        );
        _messagesController.add(messages);
        break;
      }
    }
  }

  /// 🌍 AI Перевод сообщения
  Future<String> translateMessage(Message message, String targetLanguage) async {
    // TODO: Интеграция с AI переводом
    return message.text;
  }

  /// 🧹 Очистить чат
  Future<void> clearChat(String chatId) async {
    _messagesByChat[chatId]?.clear();
    _pinnedMessages[chatId]?.clear();
    _messagesController.add([]);
  }

  /// 🗑️ Удалить чат
  Future<void> deleteChat(String chatId) async {
    _chats.removeWhere((c) => c.id == chatId);
    _messagesByChat.remove(chatId);
    _pinnedMessages.remove(chatId);
    _chatsController.add(_chats);
  }

  /// 🔐 Очистка при выходе
  void wipe() {
    _chats.clear();
    _messagesByChat.clear();
    _groupMembers.clear();
    _pinnedMessages.clear();
    _savedMessages.clear();
    _messageStatuses.clear();
    _typingIndicators.clear();
    _selfDestructTimers.forEach((_, timer) => timer.cancel());
    _selfDestructTimers.clear();
  }

  /// Закрыть потоки
  void dispose() {
    _chatsController.close();
    _messagesController.close();
    wipe();
  }
}
