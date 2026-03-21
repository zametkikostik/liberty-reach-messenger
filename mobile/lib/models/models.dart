/// 💬 Message Model
class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });
}

enum MessageStatus { sending, sent, delivered, read, failed }

/// 👤 Chat Model
class Chat {
  final String id;
  final String contactId;
  final String contactFullName;
  final String? contactUsername;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  const Chat({
    required this.id,
    required this.contactId,
    required this.contactFullName,
    this.contactUsername,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  String get initials {
    final names = contactFullName.trim().split(' ');
    if (names.isEmpty) return '?';
    if (names.length == 1) return names[0].substring(0, 1).toUpperCase();
    return '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase();
  }
}
