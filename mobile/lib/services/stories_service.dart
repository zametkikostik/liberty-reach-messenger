import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../services/d1_api_service.dart';

/// 📸 Stories Service — 24-Hour Stories
///
/// Features:
/// - Create story (image/video)
/// - Upload to IPFS with encryption
/// - Auto-delete after 24 hours
/// - View tracking
/// - Story replies
///
/// Architecture:
/// - Media stored in IPFS (encrypted)
/// - Metadata in D1
/// - Auto-delete trigger in D1
class StoriesService {
  final Dio _dio = Dio();
  final _uuid = const Uuid();
  final StorageService _storageService = StorageService();
  final D1ApiService _d1Service = D1ApiService();

  // Cloudflare Worker URL
  String get _baseUrl => dotenv.env['CLOUDFLARE_WORKER_URL'] ?? 
                        'https://liberty-reach-push.kostik.workers.dev';

  /// Create and upload story
  Future<Map<String, dynamic>?> createStory({
    required String userId,
    required XFile media,
    String? caption,
    bool isPublic = true,
  }) async {
    try {
      debugPrint('📸 Creating story...');

      // Crop image to 9:16 aspect ratio (vertical)
      final croppedFile = await _cropMedia(media.path);
      if (croppedFile == null) return null;

      // Upload to IPFS with encryption
      debugPrint('📦 Uploading to IPFS...');
      final uploadResult = await _storageService.uploadEncryptedFile(
        File(croppedFile.path),
      );
      
      final mediaCid = uploadResult['cid']!;
      final mediaNonce = uploadResult['nonce']!;

      // Generate story ID
      final storyId = _uuid.v4();
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      // Save to D1
      final story = await _d1Service.execute('''
        INSERT INTO stories (
          id, user_id, media_type, media_cid, media_nonce,
          caption, width, height, is_public,
          created_at, expires_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        RETURNING *
      ''', [
        storyId,
        userId,
        'image', // or 'video'
        mediaCid,
        mediaNonce,
        caption ?? '',
        1080, // width
        1920, // height
        isPublic ? 1 : 0,
        now.millisecondsSinceEpoch,
        expiresAt.millisecondsSinceEpoch,
      ]);

      debugPrint('✅ Story created: $storyId');
      
      return story?.isNotEmpty == true ? story!.first : null;
    } catch (e) {
      debugPrint('❌ Create story error: $e');
      return null;
    }
  }

  /// Crop media to 9:16 aspect ratio
  Future<CroppedFile?> _cropMedia(String path) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: path,
        aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Story',
            toolbarColor: const Color(0xFFFF0080),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Story',
          ),
        ],
      );
      return croppedFile;
    } catch (e) {
      debugPrint('❌ Crop error: $e');
      return null;
    }
  }

  /// Get active stories for user
  Future<List<Map<String, dynamic>>> getUserStories(String userId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final stories = await _d1Service.query('''
        SELECT 
          s.id, s.user_id, s.media_type, s.media_cid, s.media_nonce,
          s.caption, s.width, s.height, s.duration, s.is_public,
          s.view_count, s.created_at, s.expires_at,
          u.full_name as user_name, u.avatar_cid as user_avatar
        FROM stories s
        LEFT JOIN users u ON s.user_id = u.id
        WHERE s.user_id = ?
          AND s.expires_at > ?
          AND (s.deleted_at IS NULL OR s.deleted_at = 0)
        ORDER BY s.created_at DESC
      ''', [userId, now]);

      return stories;
    } catch (e) {
      debugPrint('❌ Get user stories error: $e');
      return [];
    }
  }

  /// Get all active stories from contacts
  Future<List<Map<String, dynamic>>> getContactStories(String userId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final stories = await _d1Service.query('''
        SELECT 
          s.id, s.user_id, s.media_type, s.media_cid, s.media_nonce,
          s.caption, s.width, s.height, s.duration, s.is_public,
          s.view_count, s.created_at, s.expires_at,
          u.full_name as user_name, u.avatar_cid as user_avatar
        FROM stories s
        INNER JOIN users u ON s.user_id = u.id
        WHERE s.user_id != ?
          AND s.is_public = 1
          AND s.expires_at > ?
          AND (s.deleted_at IS NULL OR s.deleted_at = 0)
        ORDER BY s.created_at DESC
      ''', [userId, now]);

      // Group by user
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final story in stories) {
        final uid = story['user_id'] as String;
        grouped.putIfAbsent(uid, () => []);
        grouped[uid]!.add(story);
      }

      return grouped.entries.map((entry) => {
        'user_id': entry.key,
        'user_name': entry.value.first['user_name'],
        'user_avatar': entry.value.first['user_avatar'],
        'stories': entry.value,
        'has_unviewed': entry.value.any((s) => s['view_count'] == 0),
      }).toList();
    } catch (e) {
      debugPrint('❌ Get contact stories error: $e');
      return [];
    }
  }

  /// View story (track view)
  Future<void> viewStory(String storyId, String viewerId) async {
    try {
      final viewId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Check if already viewed
      final existing = await _d1Service.query('''
        SELECT id FROM story_views WHERE story_id = ? AND viewer_id = ?
      ''', [storyId, viewerId]);

      if (existing.isEmpty) {
        // Record view
        await _d1Service.execute('''
          INSERT INTO story_views (id, story_id, viewer_id, viewed_at)
          VALUES (?, ?, ?, ?)
        ''', [viewId, storyId, viewerId, now]);

        // Increment view count
        await _d1Service.execute('''
          UPDATE stories SET view_count = view_count + 1 WHERE id = ?
        ''', [storyId]);
      }
    } catch (e) {
      debugPrint('❌ View story error: $e');
    }
  }

  /// Reply to story
  Future<bool> replyToStory({
    required String storyId,
    required String userId,
    required String replyText,
  }) async {
    try {
      final replyId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await _d1Service.execute('''
        INSERT INTO story_replies (id, story_id, user_id, reply_text, created_at)
        VALUES (?, ?, ?, ?, ?)
      ''', [replyId, storyId, userId, replyText, now]);

      debugPrint('✅ Story reply sent');
      return true;
    } catch (e) {
      debugPrint('❌ Reply to story error: $e');
      return false;
    }
  }

  /// Delete story
  Future<bool> deleteStory(String storyId) async {
    try {
      await _d1Service.execute('''
        UPDATE stories SET deleted_at = strftime('%s', 'now') * 1000
        WHERE id = ?
      ''', [storyId]);

      debugPrint('✅ Story deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Delete story error: $e');
      return false;
    }
  }

  /// Get story views
  Future<List<Map<String, dynamic>>> getStoryViews(String storyId) async {
    try {
      return await _d1Service.query('''
        SELECT 
          sv.viewed_at,
          u.id as user_id,
          u.full_name as user_name,
          u.avatar_cid as user_avatar
        FROM story_views sv
        INNER JOIN users u ON sv.viewer_id = u.id
        WHERE sv.story_id = ?
        ORDER BY sv.viewed_at DESC
      ''', [storyId]);
    } catch (e) {
      debugPrint('❌ Get story views error: $e');
      return [];
    }
  }

  /// Get story replies
  Future<List<Map<String, dynamic>>> getStoryReplies(String storyId) async {
    try {
      return await _d1Service.query('''
        SELECT 
          sr.id, sr.reply_text, sr.created_at,
          u.id as user_id,
          u.full_name as user_name,
          u.avatar_cid as user_avatar
        FROM story_replies sr
        INNER JOIN users u ON sr.user_id = u.id
        WHERE sr.story_id = ?
        ORDER BY sr.created_at ASC
      ''', [storyId]);
    } catch (e) {
      debugPrint('❌ Get story replies error: $e');
      return [];
    }
  }

  /// Pick image for story
  Future<XFile?> pickStoryImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      return image;
    } catch (e) {
      debugPrint('❌ Pick image error: $e');
      return null;
    }
  }

  /// Check if user has active stories
  Future<bool> hasActiveStories(String userId) async {
    final stories = await getUserStories(userId);
    return stories.isNotEmpty;
  }
}
