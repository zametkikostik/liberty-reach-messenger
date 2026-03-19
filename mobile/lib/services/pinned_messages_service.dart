import 'package:flutter/foundation.dart';
import '../services/d1_api_service.dart';

/// 📌 Pinned Messages Service
///
/// Features:
/// - Pin messages to top of chat
/// - Unpin messages
/// - Get all pinned messages for chat
/// - Pin/unpin with D1 sync
///
/// Use cases:
/// - Important announcements
/// - Group rules
/// - Key information
/// - Reference materials
class PinnedMessagesService {
  static PinnedMessagesService? _instance;
  static PinnedMessagesService get instance {
    _instance ??= PinnedMessagesService._();
    return _instance!;
  }

  PinnedMessagesService._();

  final D1ApiService _d1Service = D1ApiService();

  /// Pin a message
  Future<bool> pinMessage({
    required String messageId,
    required String chatId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Update message in D1
      await _d1Service.execute('''
        UPDATE messages 
        SET is_pinned = 1, pinned_at = ?
        WHERE id = ?
      ''', [now, messageId]);

      debugPrint('📌 Message pinned: $messageId');
      return true;
    } catch (e) {
      debugPrint('❌ Pin message error: $e');
      return false;
    }
  }

  /// Unpin a message
  Future<bool> unpinMessage(String messageId) async {
    try {
      await _d1Service.execute('''
        UPDATE messages 
        SET is_pinned = 0, pinned_at = NULL
        WHERE id = ?
      ''', [messageId]);

      debugPrint('📌 Message unpinned: $messageId');
      return true;
    } catch (e) {
      debugPrint('❌ Unpin message error: $e');
      return false;
    }
  }

  /// Get all pinned messages for a chat
  Future<List<Map<String, dynamic>>> getPinnedMessages({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final messages = await _d1Service.query('''
        SELECT 
          id, sender_id, recipient_id, encrypted_text as text,
          nonce, signature, is_pinned, pinned_at, created_at
        FROM messages
        WHERE (
          (sender_id = ? AND recipient_id = ?) OR
          (sender_id = ? AND recipient_id = ?)
        )
        AND is_pinned = 1
        AND (deleted_at IS NULL OR deleted_at = 0)
        ORDER BY pinned_at ASC
      ''', [userId1, userId2, userId2, userId1]);

      return messages;
    } catch (e) {
      debugPrint('❌ Get pinned messages error: $e');
      return [];
    }
  }

  /// Check if message is pinned
  Future<bool> isPinned(String messageId) async {
    try {
      final messages = await _d1Service.query('''
        SELECT is_pinned FROM messages WHERE id = ?
      ''', [messageId]);

      if (messages.isEmpty) return false;
      return messages.first['is_pinned'] == 1;
    } catch (e) {
      debugPrint('❌ Check pinned error: $e');
      return false;
    }
  }

  /// Get pinned message count for chat
  Future<int> getPinnedCount({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final messages = await _d1Service.query('''
        SELECT COUNT(*) as count FROM messages
        WHERE (
          (sender_id = ? AND recipient_id = ?) OR
          (sender_id = ? AND recipient_id = ?)
        )
        AND is_pinned = 1
        AND (deleted_at IS NULL OR deleted_at = 0)
      ''', [userId1, userId2, userId2, userId1]);

      if (messages.isEmpty) return 0;
      return messages.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('❌ Get pinned count error: $e');
      return 0;
    }
  }
}

/// 📌 Pinned Message Widget
///
/// Displays pinned message at top of chat
class PinnedMessageBanner extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onUnpin;
  final VoidCallback onTap;

  const PinnedMessageBanner({
    super.key,
    required this.message,
    required this.onUnpin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.amber.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Pin icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.push_pin,
                color: Colors.amber,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Message preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pinned Message',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message['text'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Unpin button
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white54,
                size: 20,
              ),
              onPressed: onUnpin,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
