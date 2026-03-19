import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../services/d1_api_service.dart';

/// 👍 Emoji Reactions Service
///
/// Features:
/// - Add reaction to message
/// - Remove reaction from message
/// - Get all reactions for message
/// - Get user's reactions
/// - Reaction count by type
///
/// Supported reactions:
/// ❤️ Love, 👍 Like, 😂 Laugh, 😮 Wow, 😢 Sad, 😡 Angry
class EmojiReactionsService {
  static EmojiReactionsService? _instance;
  static EmojiReactionsService get instance {
    _instance ??= EmojiReactionsService._();
    return _instance!;
  }

  EmojiReactionsService._();

  final D1ApiService _d1Service = D1ApiService();
  final _uuid = const Uuid();

  // Predefined reactions
  static const List<String> defaultReactions = [
    '❤️', // Love
    '👍', // Like
    '😂', // Laugh
    '😮', // Wow
    '😢', // Sad
    '😡', // Angry
  ];

  /// Add reaction to message
  Future<bool> addReaction({
    required String messageId,
    required String userId,
    required String reactionType,
  }) async {
    try {
      final reactionId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await _d1Service.execute('''
        INSERT INTO message_reactions (
          id, message_id, user_id, reaction_type, created_at
        ) VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(message_id, user_id, reaction_type) DO NOTHING
      ''', [reactionId, messageId, userId, reactionType, now]);

      debugPrint('👍 Reaction added: $reactionType to $messageId');
      return true;
    } catch (e) {
      debugPrint('❌ Add reaction error: $e');
      return false;
    }
  }

  /// Remove reaction from message
  Future<bool> removeReaction({
    required String messageId,
    required String userId,
    required String reactionType,
  }) async {
    try {
      await _d1Service.execute('''
        DELETE FROM message_reactions
        WHERE message_id = ? AND user_id = ? AND reaction_type = ?
      ''', [messageId, userId, reactionType]);

      debugPrint('👎 Reaction removed: $reactionType from $messageId');
      return true;
    } catch (e) {
      debugPrint('❌ Remove reaction error: $e');
      return false;
    }
  }

  /// Toggle reaction (add if not exists, remove if exists)
  Future<bool> toggleReaction({
    required String messageId,
    required String userId,
    required String reactionType,
  }) async {
    try {
      // Check if reaction exists
      final existing = await _d1Service.query('''
        SELECT id FROM message_reactions
        WHERE message_id = ? AND user_id = ? AND reaction_type = ?
      ''', [messageId, userId, reactionType]);

      if (existing.isNotEmpty) {
        // Remove existing reaction
        return await removeReaction(
          messageId: messageId,
          userId: userId,
          reactionType: reactionType,
        );
      } else {
        // Add new reaction
        return await addReaction(
          messageId: messageId,
          userId: userId,
          reactionType: reactionType,
        );
      }
    } catch (e) {
      debugPrint('❌ Toggle reaction error: $e');
      return false;
    }
  }

  /// Get all reactions for a message
  Future<List<Map<String, dynamic>>> getMessageReactions(String messageId) async {
    try {
      return await _d1Service.query('''
        SELECT 
          mr.id,
          mr.message_id,
          mr.user_id,
          mr.reaction_type,
          mr.created_at,
          u.full_name as user_name,
          u.avatar_cid as user_avatar
        FROM message_reactions mr
        INNER JOIN users u ON mr.user_id = u.id
        WHERE mr.message_id = ?
        ORDER BY mr.created_at ASC
      ''', [messageId]);
    } catch (e) {
      debugPrint('❌ Get reactions error: $e');
      return [];
    }
  }

  /// Get reactions grouped by type with count
  Future<Map<String, Map<String, dynamic>>> getReactionsByType(String messageId) async {
    try {
      final reactions = await getMessageReactions(messageId);
      
      final grouped = <String, Map<String, dynamic>>{};
      
      for (final reaction in reactions) {
        final type = reaction['reaction_type'] as String;
        
        if (!grouped.containsKey(type)) {
          grouped[type] = {
            'count': 0,
            'users': [],
            'userAvatars': [],
          };
        }
        
        grouped[type]!['count'] = (grouped[type]!['count'] as int) + 1;
        (grouped[type]!['users'] as List).add(reaction['user_name']);
        (grouped[type]!['userAvatars'] as List).add(reaction['user_avatar']);
      }
      
      return grouped;
    } catch (e) {
      debugPrint('❌ Get reactions by type error: $e');
      return {};
    }
  }

  /// Check if user has reacted with specific emoji
  Future<bool> hasUserReacted({
    required String messageId,
    required String userId,
    required String reactionType,
  }) async {
    try {
      final result = await _d1Service.query('''
        SELECT id FROM message_reactions
        WHERE message_id = ? AND user_id = ? AND reaction_type = ?
      ''', [messageId, userId, reactionType]);
      
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Check reaction error: $e');
      return false;
    }
  }

  /// Get user's reactions for a message
  Future<List<String>> getUserReactions({
    required String messageId,
    required String userId,
  }) async {
    try {
      final reactions = await _d1Service.query('''
        SELECT reaction_type FROM message_reactions
        WHERE message_id = ? AND user_id = ?
      ''', [messageId, userId]);
      
      return reactions.map((r) => r['reaction_type'] as String).toList();
    } catch (e) {
      debugPrint('❌ Get user reactions error: $e');
      return [];
    }
  }

  /// Add reaction to group message
  Future<bool> addGroupReaction({
    required String groupMessageId,
    required String userId,
    required String reactionType,
  }) async {
    try {
      final reactionId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await _d1Service.execute('''
        INSERT INTO group_message_reactions (
          id, group_message_id, user_id, reaction_type, created_at
        ) VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(group_message_id, user_id, reaction_type) DO NOTHING
      ''', [reactionId, groupMessageId, userId, reactionType, now]);

      debugPrint('👍 Group reaction added: $reactionType to $groupMessageId');
      return true;
    } catch (e) {
      debugPrint('❌ Add group reaction error: $e');
      return false;
    }
  }

  /// Get group message reactions
  Future<List<Map<String, dynamic>>> getGroupMessageReactions(String groupMessageId) async {
    try {
      return await _d1Service.query('''
        SELECT 
          gmr.id,
          gmr.group_message_id,
          gmr.user_id,
          gmr.reaction_type,
          gmr.created_at,
          u.full_name as user_name,
          u.avatar_cid as user_avatar
        FROM group_message_reactions gmr
        INNER JOIN users u ON gmr.user_id = u.id
        WHERE gmr.group_message_id = ?
        ORDER BY gmr.created_at ASC
      ''', [groupMessageId]);
    } catch (e) {
      debugPrint('❌ Get group reactions error: $e');
      return [];
    }
  }
}

/// 👍 Reaction Summary Model
class ReactionSummary {
  final String emoji;
  final int count;
  final bool hasUserReacted;
  final List<String> userNames;

  ReactionSummary({
    required this.emoji,
    required this.count,
    required this.hasUserReacted,
    required this.userNames,
  });

  factory ReactionSummary.fromMap(Map<String, dynamic> map) {
    return ReactionSummary(
      emoji: map['emoji'] as String,
      count: map['count'] as int,
      hasUserReacted: map['hasUserReacted'] as bool,
      userNames: List<String>.from(map['userNames'] ?? []),
    );
  }
}
