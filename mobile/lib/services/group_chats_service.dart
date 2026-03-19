import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../services/d1_api_service.dart';

/// 👥 Group Chats Service
///
/// Features:
/// - Create groups (up to 1000 members)
/// - Add/remove members
/// - Group roles (owner, admin, moderator, member)
/// - Group messages
/// - Invite links
/// - Group settings
///
/// Use cases:
/// - Family groups
/// - Work teams
/// - Communities
/// - Project collaboration
class GroupChatsService {
  static GroupChatsService? _instance;
  static GroupChatsService get instance {
    _instance ??= GroupChatsService._();
    return _instance!;
  }

  GroupChatsService._();

  final D1ApiService _d1Service = D1ApiService();
  final Dio _dio = Dio();
  final _uuid = const Uuid();

  /// Create a new group
  Future<Map<String, dynamic>?> createGroup({
    required String name,
    required String ownerId,
    String? description,
    String? avatarCid,
    bool isPublic = false,
  }) async {
    try {
      final groupId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Create group
      await _d1Service.execute('''
        INSERT INTO groups (
          id, name, description, avatar_cid, owner_id,
          created_at, member_count, is_public
        ) VALUES (?, ?, ?, ?, ?, ?, 1, ?)
      ''', [
        groupId,
        name,
        description ?? '',
        avatarCid,
        ownerId,
        now,
        isPublic ? 1 : 0,
      ]);

      // Add owner as member with owner role
      await _d1Service.execute('''
        INSERT INTO group_members (
          id, group_id, user_id, role, joined_at
        ) VALUES (?, ?, ?, 'owner', ?)
      ''', [_uuid.v4(), groupId, ownerId, now]);

      debugPrint('👥 Group created: $groupId');

      // Fetch and return the created group
      final groups = await _d1Service.query(
        'SELECT * FROM groups WHERE id = ?',
        [groupId],
      );

      return groups.isNotEmpty ? groups.first : null;
    } catch (e) {
      debugPrint('❌ Create group error: $e');
      return null;
    }
  }

  /// Get all groups for a user
  Future<List<Map<String, dynamic>>> getUserGroups(String userId) async {
    try {
      return await _d1Service.query('''
        SELECT 
          g.*,
          gm.role as user_role,
          gm.last_seen
        FROM groups g
        INNER JOIN group_members gm ON g.id = gm.group_id
        WHERE gm.user_id = ? AND gm.is_banned = 0
        ORDER BY g.updated_at DESC
      ''', [userId]);
    } catch (e) {
      debugPrint('❌ Get user groups error: $e');
      return [];
    }
  }

  /// Get group details
  Future<Map<String, dynamic>?> getGroup(String groupId) async {
    try {
      final groups = await _d1Service.query(
        'SELECT * FROM groups WHERE id = ?',
        [groupId],
      );
      return groups.isNotEmpty ? groups.first : null;
    } catch (e) {
      debugPrint('❌ Get group error: $e');
      return null;
    }
  }

  /// Get group members
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      return await _d1Service.query('''
        SELECT 
          gm.*,
          u.full_name,
          u.avatar_cid
        FROM group_members gm
        INNER JOIN users u ON gm.user_id = u.id
        WHERE gm.group_id = ? AND gm.is_banned = 0
        ORDER BY 
          CASE gm.role
            WHEN 'owner' THEN 1
            WHEN 'admin' THEN 2
            WHEN 'moderator' THEN 3
            ELSE 4
          END,
          gm.joined_at ASC
      ''', [groupId]);
    } catch (e) {
      debugPrint('❌ Get group members error: $e');
      return [];
    }
  }

  /// Add member to group
  Future<bool> addMember({
    required String groupId,
    required String userId,
    String role = 'member',
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _d1Service.execute('''
        INSERT INTO group_members (
          id, group_id, user_id, role, joined_at
        ) VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(group_id, user_id) DO UPDATE SET
          is_banned = 0,
          role = ?
      ''', [_uuid.v4(), groupId, userId, role, now, role]);

      // Update member count
      await _d1Service.execute('''
        UPDATE groups SET member_count = member_count + 1 WHERE id = ?
      ''', [groupId]);

      debugPrint('👥 Member added: $userId to group $groupId');
      return true;
    } catch (e) {
      debugPrint('❌ Add member error: $e');
      return false;
    }
  }

  /// Remove member from group
  Future<bool> removeMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _d1Service.execute('''
        DELETE FROM group_members
        WHERE group_id = ? AND user_id = ?
      ''', [groupId, userId]);

      // Update member count
      await _d1Service.execute('''
        UPDATE groups SET member_count = member_count - 1 WHERE id = ?
      ''', [groupId]);

      debugPrint('👥 Member removed: $userId from group $groupId');
      return true;
    } catch (e) {
      debugPrint('❌ Remove member error: $e');
      return false;
    }
  }

  /// Update member role
  Future<bool> updateMemberRole({
    required String groupId,
    required String userId,
    required String role,
  }) async {
    try {
      await _d1Service.execute('''
        UPDATE group_members SET role = ?
        WHERE group_id = ? AND user_id = ?
      ''', [role, groupId, userId]);

      debugPrint('👥 Member role updated: $userId to $role');
      return true;
    } catch (e) {
      debugPrint('❌ Update role error: $e');
      return false;
    }
  }

  /// Ban member from group
  Future<bool> banMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _d1Service.execute('''
        UPDATE group_members SET is_banned = 1
        WHERE group_id = ? AND user_id = ?
      ''', [groupId, userId]);

      debugPrint('👥 Member banned: $userId from group $groupId');
      return true;
    } catch (e) {
      debugPrint('❌ Ban member error: $e');
      return false;
    }
  }

  /// Get group messages
  Future<List<Map<String, dynamic>>> getGroupMessages({
    required String groupId,
    int limit = 50,
  }) async {
    try {
      return await _d1Service.query('''
        SELECT 
          gm.id,
          gm.group_id,
          gm.sender_id,
          gm.encrypted_text as text,
          gm.nonce,
          gm.signature,
          gm.message_type as type,
          gm.is_pinned,
          gm.created_at,
          gm.edited_at,
          u.full_name as sender_name,
          u.avatar_cid as sender_avatar
        FROM group_messages gm
        INNER JOIN users u ON gm.sender_id = u.id
        WHERE gm.group_id = ? AND gm.is_deleted = 0
        ORDER BY gm.created_at DESC
        LIMIT ?
      ''', [groupId, limit]);
    } catch (e) {
      debugPrint('❌ Get group messages error: $e');
      return [];
    }
  }

  /// Send message to group
  Future<Map<String, dynamic>?> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String encryptedText,
    required String nonce,
    String? signature,
    String messageType = 'text',
  }) async {
    try {
      final messageId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await _d1Service.execute('''
        INSERT INTO group_messages (
          id, group_id, sender_id, encrypted_text, nonce,
          signature, message_type, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        messageId,
        groupId,
        senderId,
        encryptedText,
        nonce,
        signature,
        messageType,
        now,
      ]);

      // Update group updated_at
      await _d1Service.execute('''
        UPDATE groups SET updated_at = ? WHERE id = ?
      ''', [now, groupId]);

      debugPrint('📤 Group message sent: $messageId');

      return {
        'id': messageId,
        'group_id': groupId,
        'sender_id': senderId,
        'text': encryptedText,
        'type': messageType,
        'created_at': now,
      };
    } catch (e) {
      debugPrint('❌ Send group message error: $e');
      return null;
    }
  }

  /// Generate invite link for group
  Future<String?> generateInviteLink(String groupId) async {
    try {
      final inviteId = _uuid.v4();
      final inviteCode = _uuid.v4().substring(0, 8); // Short code
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiresAt = DateTime.now()
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch;

      await _d1Service.execute('''
        INSERT INTO group_invites (
          id, group_id, invite_code, created_by,
          created_at, expires_at
        ) VALUES (?, ?, ?, ?, ?, ?)
      ''', [
        inviteId,
        groupId,
        inviteCode,
        groupId, // Will be replaced with actual user ID
        now,
        expiresAt,
      ]);

      // Return invite link (format: liberty://join?code=XXXXX)
      return 'liberty://join?code=$inviteCode';
    } catch (e) {
      debugPrint('❌ Generate invite link error: $e');
      return null;
    }
  }

  /// Join group via invite link
  Future<bool> joinGroupViaInvite({
    required String inviteCode,
    required String userId,
  }) async {
    try {
      // Get invite
      final invites = await _d1Service.query('''
        SELECT group_id, expires_at, max_uses, uses_count, is_active
        FROM group_invites WHERE invite_code = ?
      ''', [inviteCode]);

      if (invites.isEmpty) return false;

      final invite = invites.first;

      // Check if invite is valid
      final now = DateTime.now().millisecondsSinceEpoch;
      if ((invite['expires_at'] as int? ?? 0) < now) return false;
      if ((invite['is_active'] as int? ?? 0) == 0) return false;

      final maxUses = invite['max_uses'] as int?;
      final usesCount = invite['uses_count'] as int? ?? 0;
      if (maxUses != null && usesCount >= maxUses) return false;

      // Add user to group
      final groupId = invite['group_id'] as String;
      await addMember(groupId: groupId, userId: userId);

      // Increment uses count
      await _d1Service.execute('''
        UPDATE group_invites SET uses_count = uses_count + 1
        WHERE invite_code = ?
      ''', [inviteCode]);

      debugPrint('👥 User joined group via invite: $userId -> $groupId');
      return true;
    } catch (e) {
      debugPrint('❌ Join via invite error: $e');
      return false;
    }
  }

  /// Delete group (owner only)
  Future<bool> deleteGroup(String groupId) async {
    try {
      await _d1Service.execute(
        'DELETE FROM groups WHERE id = ?',
        [groupId],
      );
      debugPrint('🗑️ Group deleted: $groupId');
      return true;
    } catch (e) {
      debugPrint('❌ Delete group error: $e');
      return false;
    }
  }

  /// Update group settings
  Future<bool> updateGroupSettings({
    required String groupId,
    String? name,
    String? description,
    String? avatarCid,
    bool? isPublic,
  }) async {
    try {
      await _d1Service.execute('''
        UPDATE groups SET
          name = COALESCE(?, name),
          description = COALESCE(?, description),
          avatar_cid = COALESCE(?, avatar_cid),
          is_public = COALESCE(?, is_public),
          updated_at = strftime('%s', 'now') * 1000
        WHERE id = ?
      ''', [name, description, avatarCid, isPublic ? 1 : 0, groupId]);

      debugPrint('⚙️ Group settings updated: $groupId');
      return true;
    } catch (e) {
      debugPrint('❌ Update settings error: $e');
      return false;
    }
  }
}
