import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 🗄️ D1 API Service
///
/// Cloudflare D1 Database REST API client.
/// 
/// Note: This uses direct D1 API access for development.
/// For production, use Cloudflare Worker as a proxy.
///
/// Security:
/// - API token stored in .env.local
/// - Never commit API token to Git
/// - All queries parameterized to prevent SQL injection
class D1ApiService {
  final Dio _dio = Dio();

  // Cloudflare API configuration
  String get _apiToken => dotenv.env['CLOUDFLARE_API_TOKEN'] ?? '';
  String get _accountId => dotenv.env['CLOUDFLARE_ACCOUNT_ID'] ?? '';
  String get _databaseId => dotenv.env['CLOUDFLARE_D1_DATABASE_ID'] ?? '';

  static const String _baseUrl = 'https://api.cloudflare.com/client/v4';

  /// Initialize D1 service
  Future<void> init() async {
    // Load .env if not already loaded
    if (dotenv.env.isEmpty) {
      await dotenv.load(fileName: ".env.local");
    }
    
    debugPrint('🗄️ D1 API initialized');
    debugPrint('   Account: ${_accountId.isEmpty ? 'NOT SET' : '✓'}');
    debugPrint('   Database: ${_databaseId.isEmpty ? 'NOT SET' : '✓'}');
    debugPrint('   API Token: ${_apiToken.isEmpty ? 'NOT SET' : '✓'}');
  }

  /// Execute SQL query on D1
  /// 
  /// Returns list of rows as Map<String, dynamic>
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<dynamic>? params,
  ]) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/accounts/$_accountId/d1/database/$_databaseId/query',
        data: {
          'sql': sql,
          'params': params ?? [],
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final result = response.data['result'] as List;
        final meta = response.data['meta'] as Map<String, dynamic>;
        
        // Get column names from meta
        final columns = meta['columns'] as List? ?? [];
        
        // Convert to list of maps
        return result.map<Map<String, dynamic>>((row) {
          final map = <String, dynamic>{};
          final rowList = row as List;
          for (int i = 0; i < columns.length; i++) {
            map[columns[i] as String] = rowList[i];
          }
          return map;
        }).toList();
      } else {
        throw Exception('D1 API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ D1 query error: $e');
      rethrow;
    }
  }

  /// Execute SQL without returning results
  Future<int> execute(String sql, [List<dynamic>? params]) async {
    try {
      final result = await query(sql, params);
      return result.length;
    } catch (e) {
      debugPrint('❌ D1 execute error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // USERS TABLE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get user by ID
  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final results = await query(
        'SELECT * FROM users WHERE id = ?',
        [userId],
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('❌ Get user error: $e');
      return null;
    }
  }

  /// Create or update user
  Future<bool> upsertUser({
    required String userId,
    required String publicKey,
    String? fullName,
    String? avatarCid,
    String? bio,
  }) async {
    try {
      await execute('''
        INSERT INTO users (id, public_key, full_name, avatar_cid, bio, created_at, last_seen)
        VALUES (?, ?, ?, ?, ?, strftime('%s', 'now') * 1000, strftime('%s', 'now') * 1000)
        ON CONFLICT(id) DO UPDATE SET
          full_name = excluded.full_name,
          avatar_cid = excluded.avatar_cid,
          bio = excluded.bio,
          last_seen = strftime('%s', 'now') * 1000
      ''', [
        userId,
        publicKey,
        fullName,
        avatarCid,
        bio,
      ]);
      return true;
    } catch (e) {
      debugPrint('❌ Upsert user error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGES TABLE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get messages for a chat (between two users)
  Future<List<Map<String, dynamic>>> getMessages({
    required String userId1,
    required String userId2,
    int limit = 50,
  }) async {
    try {
      return await query('''
        SELECT 
          id, sender_id, recipient_id as receiver_id, encrypted_text as text,
          nonce, signature, is_love_immutable, created_at, expires_at, deleted_at
        FROM messages
        WHERE (
          (sender_id = ? AND recipient_id = ?) OR
          (sender_id = ? AND recipient_id = ?)
        )
        AND (deleted_at IS NULL OR deleted_at = 0)
        ORDER BY created_at DESC
        LIMIT ?
      ''', [userId1, userId2, userId2, userId1, limit]);
    } catch (e) {
      debugPrint('❌ Get messages error: $e');
      return [];
    }
  }

  /// Send message
  Future<Map<String, dynamic>?> sendMessage({
    required String messageId,
    required String senderId,
    required String recipientId,
    required String encryptedText,
    required String nonce,
    String? signature,
    bool isLoveToken = false,
    int? expiresAt,
  }) async {
    try {
      final results = await query('''
        INSERT INTO messages (
          id, sender_id, recipient_id, encrypted_text, nonce,
          signature, is_love_immutable, created_at, expires_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, strftime('%s', 'now') * 1000, ?)
        RETURNING *
      ''', [
        messageId,
        senderId,
        recipientId,
        encryptedText,
        nonce,
        signature,
        isLoveToken ? 1 : 0,
        expiresAt,
      ]);
      
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('❌ Send message error: $e');
      return null;
    }
  }

  /// Delete message (soft delete)
  Future<bool> deleteMessage(String messageId) async {
    try {
      await execute('''
        UPDATE messages SET deleted_at = strftime('%s', 'now') * 1000
        WHERE id = ? AND is_love_immutable = 0
      ''', [messageId]);
      return true;
    } catch (e) {
      debugPrint('❌ Delete message error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT LIST OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get chat list for user
  Future<List<Map<String, dynamic>>> getChatList(String userId) async {
    try {
      return await query('''
        SELECT 
          u.id as user_id,
          u.full_name as name,
          u.avatar_cid,
          m.encrypted_text as last_message,
          m.created_at as timestamp,
          (
            SELECT COUNT(*) FROM messages m2
            WHERE m2.sender_id = u.id
            AND m2.recipient_id = ?
            AND m2.deleted_at IS NULL
            AND m2.created_at > (
              SELECT MAX(created_at) FROM messages
              WHERE sender_id = ? AND recipient_id = u.id
            )
          ) as unread
        FROM users u
        INNER JOIN messages m ON (
          (m.sender_id = u.id AND m.recipient_id = ?) OR
          (m.sender_id = ? AND m.recipient_id = u.id)
        )
        WHERE u.id != ?
        GROUP BY u.id
        ORDER BY m.created_at DESC
      ''', [userId, userId, userId, userId, userId]);
    } catch (e) {
      debugPrint('❌ Get chat list error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Test D1 connection
  Future<bool> testConnection() async {
    try {
      await query('SELECT 1');
      debugPrint('✅ D1 connection successful');
      return true;
    } catch (e) {
      debugPrint('❌ D1 connection failed: $e');
      return false;
    }
  }

  /// Get database size
  Future<int> getDatabaseSize() async {
    try {
      final results = await query(
        'SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()',
      );
      if (results.isNotEmpty) {
        return results.first['size'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Get database size error: $e');
      return 0;
    }
  }
}
