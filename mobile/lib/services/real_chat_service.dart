import 'dart:async';
import '../models/models.dart';
import 'e2ee_service.dart';

/// 💬 Real Chat Service - Полноценный мессенджер
class RealChatService {
  static RealChatService? _instance;
  static RealChatService get instance {
    _instance ??= RealChatService._();
    return _instance!;
  }

  RealChatService._();

  final _e2eeService = E2EEService.instance;
  final List<Chat> _chats = [];
  final Map<String, List<Message>> _messagesByChat = {};
  final Map<String, List<String>> _groupMembers = {};
  final Map<String, List<Message>> _pinnedMessages = {};
  final List<Message> _savedMessages = [];
  final Map<String, MessageStatus> _messageStatuses = {};
  final Map<String, bool> _typingIndicators = {};
  final Map<String, Timer> _selfDestructTimers = {};

  final _chatsController = StreamController<List<Chat>>.broadcast();
  Stream<List<Chat>> get chatsStream => _chatsController.stream;
  
  final _messagesController = StreamController<List<Message>>.broadcast();
  Stream<List<Message>> get messagesStream => _messagesController.stream;

  List<Chat> get chats => List.unmodifiable(_chats);
  List<Message> getMessages(String chatId) => List.unmodifiable(_messagesByChat[chatId] ?? []);
  List<Message> get savedMessages => List.unmodifiable(_savedMessages);

  /// 💬 Создать чат 1-на-1
  Future<Chat> createPrivateChat({
    required String userId,
    required String userName,
    String? avatarUrl,
  }) async {
    final chatId = 'private_$userId';
    
    final existingChat = _chats.firstWhere(
      (c) => c.id == chatId,
      orElse: () => Chat(id: '', type: ChatType.private, title: ''),
    );
    
    if (existingChat.id.isNotEmpty) return existingChat;
    
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
    _groupMembers[groupId] = [creatorId, ...?memberIds];
    
    final chat = Chat(
      id: groupId,
      type: ChatType.group,
      title: title,
      description: description,
      avatarUrl: avatarUrl,
      memberCount: _groupMembers[groupId]!.length,
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
    String? encryptedText;
    String displayText = text;
    
    if (isEncrypted) {
      try {
        encryptedText = _e2eeService.encryptMessage(text);
        displayText = '🔐 Encrypted';
      } catch (e) {}
    }
    
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
    
    _messagesByChat[chatId] ??= [];
    _messagesByChat[chatId]!.add(message);
    
    // Обновляем чат
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      final chat = _chats[chatIndex];
      final updatedChat = Chat(
        id: chat.id,
        type: chat.type,
        title: chat.title,
        lastMessage: text,
        lastMessageTime: DateTime.now(),
        isOnline: chat.isOnline,
        memberCount: chat.memberCount,
        avatarUrl: chat.avatarUrl,
        description: chat.description,
        unreadCount: chat.unreadCount,
        isPinned: chat.isPinned,
        familyStatus: chat.familyStatus,
        wallpaperUrl: chat.wallpaperUrl,
        isSyncedWallpaper: chat.isSyncedWallpaper,
      );
      _chats[chatIndex] = updatedChat;
      _chats.sort((a, b) => (b.lastMessageTime ?? DateTime(0)).compareTo(a.lastMessageTime ?? DateTime(0)));
    }
    
    _chatsController.add(_chats);
    _messagesController.add(_messagesByChat[chatId]!);
    _messageStatuses[message.id] = MessageStatus.delivered;
    
    return message;
  }

  void startTyping(String chatId, String userId) {
    _typingIndicators['$chatId_$userId'] = true;
  }

  void stopTyping(String chatId, String userId) {
    _typingIndicators['$chatId_$userId'] = false;
  }

  Future<void> pinMessage(Message message) async {
    _pinnedMessages[message.chatId] ??= [];
    if (!_pinnedMessages[message.chatId]!.any((m) => m.id == message.id)) {
      _pinnedMessages[message.chatId]!.add(message);
    }
  }

  Future<void> unpinMessage(String chatId, String messageId) async {
    _pinnedMessages[chatId]?.removeWhere((m) => m.id == messageId);
  }

  Future<void> saveMessage(Message message) async {
    if (!_savedMessages.any((m) => m.id == message.id)) {
      _savedMessages.add(message);
    }
  }

  Future<void> unsaveMessage(String messageId) async {
    _savedMessages.removeWhere((m) => m.id == messageId);
  }

  void _startSelfDestructTimer(String chatId, String text, Duration duration) {
    final timer = Timer(duration, () {
      _messagesByChat[chatId]?.removeWhere((m) => m.text == text);
      _messagesController.add(_messagesByChat[chatId] ?? []);
    });
    _selfDestructTimers[chatId] = timer;
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    _messagesByChat[chatId]?.removeWhere((m) => m.id == messageId);
    _messagesController.add(_messagesByChat[chatId] ?? []);
  }

  Future<void> editMessage(String messageId, String newText) async {
    for (final messages in _messagesByChat.values) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final old = messages[index];
        messages[index] = Message(
          id: old.id, chatId: old.chatId, senderId: old.senderId,
          text: newText, timestamp: old.timestamp, status: old.status,
          type: old.type, isEncrypted: old.isEncrypted,
          encryptedText: old.encryptedText, isEdited: true,
          editedAt: DateTime.now(),
        );
        _messagesController.add(messages);
        break;
      }
    }
  }

  Future<void> clearChat(String chatId) async {
    _messagesByChat[chatId]?.clear();
    _pinnedMessages[chatId]?.clear();
    _messagesController.add([]);
  }

  Future<void> deleteChat(String chatId) async {
    _chats.removeWhere((c) => c.id == chatId);
    _messagesByChat.remove(chatId);
    _pinnedMessages.remove(chatId);
    _chatsController.add(_chats);
  }

  void wipe() {
    _chats.clear();
    _messagesByChat.clear();
    _groupMembers.clear();
    _pinnedMessages.clear();
    _savedMessages.clear();
    _messageStatuses.clear();
    _typingIndicators.clear();
    _selfDestructTimers.forEach((_, t) => t.cancel());
    _selfDestructTimers.clear();
  }

  void dispose() {
    _chatsController.close();
    _messagesController.close();
    wipe();
  }
}
