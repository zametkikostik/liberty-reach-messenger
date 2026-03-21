/// 💬 Message Model (Extended)
class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;
  final MessageType type;
  
  // 🔐 E2EE
  final bool isEncrypted;
  final String? encryptedText;
  
  // ✏️ Редактирование
  final bool isEdited;
  final DateTime? editedAt;
  
  // 💬 Ответы (reply to)
  final String? replyToMessageId;
  final String? replyToSenderId;
  
  // ⏱️ Таймер самоуничтожения
  final Duration? selfDestructTimer;
  final DateTime? expiresAt;
  
  // 📎 Вложения
  final List<Attachment> attachments;
  
  // 👍 Реакции
  final Map<String, int> reactions;
  
  // 🌍 AI перевод
  final String? originalText;
  final String? translatedText;
  final String? detectedLanguage;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.type = MessageType.text,
    this.isEncrypted = false,
    this.encryptedText,
    this.isEdited = false,
    this.editedAt,
    this.replyToMessageId,
    this.replyToSenderId,
    this.selfDestructTimer,
    this.expiresAt,
    this.attachments = const [],
    this.reactions = const {},
    this.originalText,
    this.translatedText,
    this.detectedLanguage,
  });

  /// Проверка: сообщение удалено по таймеру
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

enum MessageStatus { sending, sent, delivered, read, failed }
enum MessageType { text, image, video, audio, file, sticker, gif }

/// 📎 Attachment
class Attachment {
  final String id;
  final String url;
  final String mimeType;
  final int size;
  final String? thumbnailUrl;

  const Attachment({
    required this.id,
    required this.url,
    required this.mimeType,
    required this.size,
    this.thumbnailUrl,
  });
}

/// 👥 Chat Types
enum ChatType {
  private,      // 1-на-1
  group,        // до 1000 участников
  channel,      // broadcast
}

/// 💬 Chat Model (Extended)
class Chat {
  final String id;
  final ChatType type;
  final String title;
  final String? description;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final int memberCount;
  final bool isOnline;
  final bool isPinned;
  
  // 👨‍👩‍👧 Семейный статус
  final FamilyStatus? familyStatus;
  
  // 🎨 Обои
  final String? wallpaperUrl;
  final bool isSyncedWallpaper;

  const Chat({
    required this.id,
    this.type = ChatType.private,
    required this.title,
    this.description,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.memberCount = 1,
    this.isOnline = false,
    this.isPinned = false,
    this.familyStatus,
    this.wallpaperUrl,
    this.isSyncedWallpaper = false,
  });

  String get initials {
    final names = title.trim().split(' ');
    if (names.isEmpty) return '?';
    if (names.length == 1) return names[0].substring(0, 2).toUpperCase();
    return '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase();
  }
}

enum FamilyStatus {
  single,
  dating,
  engaged,
  married,
  inRelationship,
}

/// 👤 Contact Model (Extended)
class Contact {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final bool isOnline;
  final String? status;
  final DateTime? lastSeen;
  final FamilyStatus? familyStatus;

  const Contact({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.isOnline = false,
    this.status,
    this.lastSeen,
    this.familyStatus,
  });
}

/// 📞 Call Model
class Call {
  final String id;
  final String contactId;
  final CallType type;
  final CallStatus status;
  final DateTime startTime;
  final Duration? duration;

  const Call({
    required this.id,
    required this.contactId,
    required this.type,
    required this.status,
    required this.startTime,
    this.duration,
  });
}

enum CallType { audio, video, conference }
enum CallStatus { incoming, outgoing, missed, accepted, ended }
