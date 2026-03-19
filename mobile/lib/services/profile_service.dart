import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 👤 Profile Service - Human Identity
///
/// Manages user profile data:
/// - display_name: User's public display name
/// - bio: Short biography/description
/// - avatar_cid: IPFS CID for avatar image
///
/// Data is synced with Cloudflare D1 database.
class ProfileService {
  // Cloudflare Worker URL
  static const String _baseUrl = 'https://liberty-reach-push.kostik.workers.dev';
  
  final Dio _dio = Dio();
  
  // Local cache keys
  static const String _displayNameKey = 'profile_display_name';
  static const String _bioKey = 'profile_bio';
  static const String _avatarCidKey = 'profile_avatar_cid';
  
  // Local cache
  String? _cachedDisplayName;
  String? _cachedBio;
  String? _cachedAvatarCid;

  /// Initialize profile from local storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedDisplayName = prefs.getString(_displayNameKey);
      _cachedBio = prefs.getString(_bioKey);
      _cachedAvatarCid = prefs.getString(_avatarCidKey);
      
      debugPrint('👤 Profile initialized: ${_cachedDisplayName ?? "Anonymous"}');
    } catch (e) {
      debugPrint('❌ Profile init error: $e');
    }
  }

  /// Get current display name
  String? get displayName => _cachedDisplayName;

  /// Get current bio
  String? get bio => _cachedBio;

  /// Get current avatar CID
  String? get avatarCid => _cachedAvatarCid;

  /// Save profile to D1 and local storage
  Future<Map<String, dynamic>> saveProfile({
    String? displayName,
    String? bio,
    String? avatarCid,
  }) async {
    try {
      // Update local cache
      if (displayName != null) {
        _cachedDisplayName = displayName.trim().isEmpty ? null : displayName.trim();
        await _saveLocal(_displayNameKey, _cachedDisplayName);
      }
      
      if (bio != null) {
        _cachedBio = bio.trim();
        await _saveLocal(_bioKey, _cachedBio);
      }
      
      if (avatarCid != null) {
        _cachedAvatarCid = avatarCid.trim().isEmpty ? null : avatarCid.trim();
        await _saveLocal(_avatarCidKey, _cachedAvatarCid);
      }

      // Sync with D1
      final response = await _dio.post(
        '$_baseUrl/profile',
        data: {
          'display_name': _cachedDisplayName,
          'bio': _cachedBio,
          'avatar_cid': _cachedAvatarCid,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      debugPrint('✅ Profile saved to D1');
      return response.data;
    } catch (e) {
      debugPrint('❌ Save profile error: $e');
      // Return local data even if D1 sync fails
      return {
        'display_name': _cachedDisplayName,
        'bio': _cachedBio,
        'avatar_cid': _cachedAvatarCid,
      };
    }
  }

  /// Fetch profile from D1
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final response = await _dio.get('$_baseUrl/profile/$userId');
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        
        // Update local cache
        _cachedDisplayName = data['display_name'];
        _cachedBio = data['bio'];
        _cachedAvatarCid = data['avatar_cid'];
        
        await _saveLocal(_displayNameKey, _cachedDisplayName);
        await _saveLocal(_bioKey, _cachedBio);
        await _saveLocal(_avatarCidKey, _cachedAvatarCid);
        
        debugPrint('✅ Profile fetched from D1');
        return data;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Fetch profile error: $e');
      return null;
    }
  }

  /// Update display name only
  Future<void> setDisplayName(String name) async {
    await saveProfile(displayName: name);
  }

  /// Update bio only
  Future<void> setBio(String bioText) async {
    await saveProfile(bio: bioText);
  }

  /// Update avatar CID only
  Future<void> setAvatarCid(String cid) async {
    await saveProfile(avatarCid: cid);
  }

  /// Clear all profile data
  Future<void> clearProfile() async {
    _cachedDisplayName = null;
    _cachedBio = null;
    _cachedAvatarCid = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_displayNameKey);
    await prefs.remove(_bioKey);
    await prefs.remove(_avatarCidKey);
    
    debugPrint('🗑️ Profile cleared');
  }

  /// Save to local storage
  Future<void> _saveLocal(String key, String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    } catch (e) {
      debugPrint('❌ Local save error: $e');
    }
  }

  /// Get initials from display name
  String get initials {
    if (_cachedDisplayName == null || _cachedDisplayName!.isEmpty) {
      return '?';
    }
    
    final names = _cachedDisplayName!.trim().split(' ');
    if (names.isEmpty) return '?';
    
    if (names.length == 1) {
      return names[0].substring(0, 1).toUpperCase();
    }
    
    return '${names[0].substring(0, 1)}${names[names.length - 1].substring(0, 1)}'.toUpperCase();
  }

  /// Check if profile is complete
  bool get isComplete {
    return _cachedDisplayName != null && _cachedDisplayName!.isNotEmpty;
  }
}
