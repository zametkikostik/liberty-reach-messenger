import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../services/d1_api_service.dart';

/// 📢 Broadcast Channels Service
///
/// Features:
/// - Create channels
/// - Subscribe/unsubscribe
/// - Post messages to channel
/// - View counts
/// - Pinned posts
/// - Channel admins
///
/// Use cases:
/// - News channels
/// - Company announcements
/// - Community updates
/// - Broadcast messaging
class ChannelsService {
  static ChannelsService? _instance;
  static ChannelsService get instance {
    _instance ??= ChannelsService._();
    return _instance!;
  }

  ChannelsService._();

  final D1ApiService _d1Service = D1ApiService();
  final _uuid = const Uuid();

  /// Create a new channel
  Future<Map<String, dynamic>?> createChannel({
    required String name,
    required String ownerId,
    String? description,
    String? avatarCid,
    bool isPublic = true,
  }) async {
    try {
      final channelId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Create channel
      await _d1Service.execute('''
        INSERT INTO channels (
          id, name, description, avatar_cid, owner_id,
          created_at, is_public
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [
        channelId,
        name,
        description ?? '',
        avatarCid,
        ownerId,
        now,
        isPublic ? 1 : 0,
      ]);

      // Add owner as subscriber and admin
      await _d1Service.execute('''
        INSERT INTO channel_subscribers (
          id, channel_id, user_id, subscribed_at, is_admin
        ) VALUES (?, ?, ?, ?, 1)
      ''', [_uuid.v4(), channelId, ownerId, now]);

      debugPrint('📢 Channel created: $channelId');

      // Fetch and return the created channel
      final channels = await _d1Service.query(
        'SELECT * FROM channels WHERE id = ?',
        [channelId],
      );

      return channels.isNotEmpty ? channels.first : null;
    } catch (e) {
      debugPrint('❌ Create channel error: $e');
      return null;
    }
  }

  /// Get all channels for a user (owned or subscribed)
  Future<List<Map<String, dynamic>>> getUserChannels(String userId) async {
    try {
      return await _d1Service.query('''
        SELECT 
          c.*,
          cs.is_admin as user_is_admin,
          cs.is_muted as user_is_muted
        FROM channels c
        INNER JOIN channel_subscribers cs ON c.id = cs.channel_id
        WHERE cs.user_id = ?
        ORDER BY c.updated_at DESC
      ''', [userId]);
    } catch (e) {
      debugPrint('❌ Get user channels error: $e');
      return [];
    }
  }

  /// Subscribe to channel
  Future<bool> subscribeToChannel({
    required String channelId,
    required String userId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _d1Service.execute('''
        INSERT INTO channel_subscribers (
          id, channel_id, user_id, subscribed_at
        ) VALUES (?, ?, ?, ?)
        ON CONFLICT(channel_id, user_id) DO UPDATE SET
          is_muted = 0
      ''', [_uuid.v4(), channelId, userId, now]);

      // Update subscriber count
      await _d1Service.execute('''
        UPDATE channels SET subscriber_count = subscriber_count + 1
        WHERE id = ?
      ''', [channelId]);

      debugPrint('✅ Subscribed to channel: $channelId');
      return true;
    } catch (e) {
      debugPrint('❌ Subscribe error: $e');
      return false;
    }
  }

  /// Unsubscribe from channel
  Future<bool> unsubscribeFromChannel({
    required String channelId,
    required String userId,
  }) async {
    try {
      await _d1Service.execute('''
        DELETE FROM channel_subscribers
        WHERE channel_id = ? AND user_id = ?
      ''', [channelId, userId]);

      // Update subscriber count
      await _d1Service.execute('''
        UPDATE channels SET subscriber_count = subscriber_count - 1
        WHERE id = ? AND subscriber_count > 0
      ''', [channelId]);

      debugPrint('✅ Unsubscribed from channel: $channelId');
      return true;
    } catch (e) {
      debugPrint('❌ Unsubscribe error: $e');
      return false;
    }
  }

  /// Post message to channel
  Future<Map<String, dynamic>?> postToChannel({
    required String channelId,
    required String authorId,
    required String content,
    String? mediaCid,
    String? mediaType,
    String? nonce,
  }) async {
    try {
      final postId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await _d1Service.execute('''
        INSERT INTO channel_posts (
          id, channel_id, author_id, content, media_cid,
          media_type, nonce, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        postId,
        channelId,
        authorId,
        content,
        mediaCid,
        mediaType,
        nonce ?? '',
        now,
      ]);

      // Update channel updated_at
      await _d1Service.execute('''
        UPDATE channels SET updated_at = ? WHERE id = ?
      ''', [now, channelId]);

      debugPrint('📢 Posted to channel: $postId');

      return {
        'id': postId,
        'channel_id': channelId,
        'author_id': authorId,
        'content': content,
        'created_at': now,
      };
    } catch (e) {
      debugPrint('❌ Post to channel error: $e');
      return null;
    }
  }

  /// Get channel posts
  Future<List<Map<String, dynamic>>> getChannelPosts({
    required String channelId,
    int limit = 50,
  }) async {
    try {
      return await _d1Service.query('''
        SELECT 
          cp.*,
          u.full_name as author_name,
          u.avatar_cid as author_avatar
        FROM channel_posts cp
        INNER JOIN users u ON cp.author_id = u.id
        WHERE cp.channel_id = ? AND cp.deleted_at IS NULL
        ORDER BY cp.created_at DESC
        LIMIT ?
      ''', [channelId, limit]);
    } catch (e) {
      debugPrint('❌ Get channel posts error: $e');
      return [];
    }
  }

  /// Track post view
  Future<void> trackPostView({
    required String postId,
    required String userId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert view (ignore if exists)
      await _d1Service.execute('''
        INSERT OR IGNORE INTO channel_post_views (
          id, post_id, user_id, viewed_at
        ) VALUES (?, ?, ?, ?)
      ''', [_uuid.v4(), postId, userId, now]);

      // Update view count
      await _d1Service.execute('''
        UPDATE channel_posts SET views_count = views_count + 1
        WHERE id = ?
      ''', [postId]);
    } catch (e) {
      debugPrint('❌ Track view error: $e');
    }
  }

  /// Pin post
  Future<bool> pinPost(String postId) async {
    try {
      await _d1Service.execute('''
        UPDATE channel_posts SET is_pinned = 1
        WHERE id = ?
      ''', [postId]);

      debugPrint('📌 Post pinned: $postId');
      return true;
    } catch (e) {
      debugPrint('❌ Pin post error: $e');
      return false;
    }
  }

  /// Unpin post
  Future<bool> unpinPost(String postId) async {
    try {
      await _d1Service.execute('''
        UPDATE channel_posts SET is_pinned = 0
        WHERE id = ?
      ''', [postId]);

      debugPrint('📌 Post unpinned: $postId');
      return true;
    } catch (e) {
      debugPrint('❌ Unpin post error: $e');
      return false;
    }
  }

  /// Get channel details
  Future<Map<String, dynamic>?> getChannel(String channelId) async {
    try {
      final channels = await _d1Service.query(
        'SELECT * FROM channels WHERE id = ?',
        [channelId],
      );
      return channels.isNotEmpty ? channels.first : null;
    } catch (e) {
      debugPrint('❌ Get channel error: $e');
      return null;
    }
  }

  /// Get subscriber count
  Future<int> getSubscriberCount(String channelId) async {
    try {
      final result = await _d1Service.query('''
        SELECT COUNT(*) as count FROM channel_subscribers
        WHERE channel_id = ?
      ''', [channelId]);

      if (result.isEmpty) return 0;
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('❌ Get subscriber count error: $e');
      return 0;
    }
  }

  /// Delete channel (owner only)
  Future<bool> deleteChannel(String channelId) async {
    try {
      await _d1Service.execute(
        'DELETE FROM channels WHERE id = ?',
        [channelId],
      );
      debugPrint('🗑️ Channel deleted: $channelId');
      return true;
    } catch (e) {
      debugPrint('❌ Delete channel error: $e');
      return false;
    }
  }
}
