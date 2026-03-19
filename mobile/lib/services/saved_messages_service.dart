import 'package:flutter/foundation.dart';
import '../services/d1_api_service.dart';

/// 💾 Saved Messages Service
///
/// Features:
/// - Save messages to favorites
/// - Remove from favorites
/// - Get all saved messages
/// - Add tags to saved messages
/// - Search saved messages by tags
///
/// Use cases:
/// - Important information
/// - Reference materials
/// - Notes and reminders
/// - Useful links and files
class SavedMessagesService {
  static SavedMessagesService? _instance;
  static SavedMessagesService get instance {
    _instance ??= SavedMessagesService._();
    return _instance!;
  }

  SavedMessagesService._();

  final D1ApiService _d1Service = D1ApiService();

  /// Save message to favorites
  Future<bool> saveMessage({
    required String messageId,
    required String userId,
    List<String>? tags,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final tagsJson = tags != null ? tags.join(',') : '';

      // Insert into saved_messages table
      await _d1Service.execute('''
        INSERT INTO saved_messages (
          message_id, user_id, saved_at, tags
        ) VALUES (?, ?, ?, ?)
        ON CONFLICT(message_id, user_id) DO UPDATE SET
          saved_at = ?,
          tags = ?
      ''', [
        messageId,
        userId,
        now,
        tagsJson,
        now,
        tagsJson,
      ]);

      debugPrint('💾 Message saved: $messageId');
      return true;
    } catch (e) {
      debugPrint('❌ Save message error: $e');
      return false;
    }
  }

  /// Remove message from favorites
  Future<bool> removeMessage({
    required String messageId,
    required String userId,
  }) async {
    try {
      await _d1Service.execute('''
        DELETE FROM saved_messages
        WHERE message_id = ? AND user_id = ?
      ''', [messageId, userId]);

      debugPrint('💾 Message removed from saved: $messageId');
      return true;
    } catch (e) {
      debugPrint('❌ Remove message error: $e');
      return false;
    }
  }

  /// Get all saved messages for user
  Future<List<Map<String, dynamic>>> getSavedMessages({
    required String userId,
    int limit = 100,
  }) async {
    try {
      final messages = await _d1Service.query('''
        SELECT 
          sm.id,
          sm.message_id,
          sm.saved_at,
          sm.tags,
          m.sender_id,
          m.recipient_id,
          m.encrypted_text as text,
          m.nonce,
          m.signature,
          m.created_at
        FROM saved_messages sm
        INNER JOIN messages m ON sm.message_id = m.id
        WHERE sm.user_id = ?
        ORDER BY sm.saved_at DESC
        LIMIT ?
      ''', [userId, limit]);

      return messages;
    } catch (e) {
      debugPrint('❌ Get saved messages error: $e');
      return [];
    }
  }

  /// Search saved messages by tag
  Future<List<Map<String, dynamic>>> searchByTag({
    required String userId,
    required String tag,
  }) async {
    try {
      final messages = await _d1Service.query('''
        SELECT 
          sm.id,
          sm.message_id,
          sm.saved_at,
          sm.tags,
          m.sender_id,
          m.recipient_id,
          m.encrypted_text as text,
          m.nonce,
          m.created_at
        FROM saved_messages sm
        INNER JOIN messages m ON sm.message_id = m.id
        WHERE sm.user_id = ? AND sm.tags LIKE ?
        ORDER BY sm.saved_at DESC
      ''', [userId, '%$tag%']);

      return messages;
    } catch (e) {
      debugPrint('❌ Search by tag error: $e');
      return [];
    }
  }

  /// Get all tags for user
  Future<List<String>> getAllTags(String userId) async {
    try {
      final result = await _d1Service.query('''
        SELECT tags FROM saved_messages WHERE user_id = ? AND tags != ''
      ''', [userId]);

      final tagSet = <String>{};
      for (final row in result) {
        final tags = row['tags'] as String?;
        if (tags != null && tags.isNotEmpty) {
          tagSet.addAll(tags.split(','));
        }
      }

      return tagSet.toList();
    } catch (e) {
      debugPrint('❌ Get all tags error: $e');
      return [];
    }
  }

  /// Check if message is saved
  Future<bool> isSaved({
    required String messageId,
    required String userId,
  }) async {
    try {
      final result = await _d1Service.query('''
        SELECT id FROM saved_messages WHERE message_id = ? AND user_id = ?
      ''', [messageId, userId]);

      return result.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Check saved error: $e');
      return false;
    }
  }

  /// Get saved messages count
  Future<int> getCount(String userId) async {
    try {
      final result = await _d1Service.query('''
        SELECT COUNT(*) as count FROM saved_messages WHERE user_id = ?
      ''', [userId]);

      if (result.isEmpty) return 0;
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('❌ Get count error: $e');
      return 0;
    }
  }
}

/// 💾 Saved Message Widget
///
/// Displays saved message with tags
class SavedMessageCard extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  final List<String> tags;

  const SavedMessageCard({
    super.key,
    required this.message,
    required this.onRemove,
    required this.onTap,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.bookmark,
                  color: Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Saved Message',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Remove button
                IconButton(
                  icon: const Icon(
                    Icons.bookmark_remove,
                    color: Colors.white54,
                    size: 18,
                  ),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Message preview
            Text(
              message['text'] ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // Tags
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.withOpacity(0.9),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Timestamp
            const SizedBox(height: 6),
            Text(
              _formatSavedTime(message['saved_at']),
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSavedTime(int? timestamp) {
    if (timestamp == null) return '';
    
    final savedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(savedAt);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
