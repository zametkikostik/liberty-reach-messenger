import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 👤 Profile Provider
///
/// Manages user profile metadata:
/// - full_name: User's display name
/// - avatar_cid: IPFS CID for avatar image
/// - bio: Short description
/// - Theme preferences
///
/// Data is stored locally and synced with D1 when online.
class ProfileProvider extends ChangeNotifier {
  static const String _profileKey = 'user_profile_v1';

  String? _fullName;
  String? _avatarCid;
  String _bio = '';
  bool _isProfileComplete = false;

  // Getters
  String? get fullName => _fullName;
  String? get avatarCid => _avatarCid;
  String get bio => _bio;
  bool get isProfileComplete => _isProfileComplete;

  /// Get avatar URL for Pinata gateway
  String? get avatarUrl {
    if (_avatarCid == null || _avatarCid!.isEmpty) return null;
    return 'https://gateway.pinata.cloud/ipfs/$_avatarCid';
  }

  /// Get initials from full name (for avatar placeholder)
  String get initials {
    if (_fullName == null || _fullName!.isEmpty) return '?';
    
    final names = _fullName!.trim().split(' ');
    if (names.isEmpty) return '?';
    
    if (names.length == 1) {
      return names[0].substring(0, 1).toUpperCase();
    }
    
    return '${names[0].substring(0, 1)}${names[names.length - 1].substring(0, 1)}'.toUpperCase();
  }

  /// Initialize profile from local storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_profileKey);
      
      if (profileJson != null) {
        final profile = jsonDecode(profileJson) as Map<String, dynamic>;
        _fullName = profile['full_name'];
        _avatarCid = profile['avatar_cid'];
        _bio = profile['bio'] ?? '';
        _isProfileComplete = _fullName != null && _fullName!.isNotEmpty;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Profile init error: $e');
    }
  }

  /// Update full name
  Future<void> setFullName(String name) async {
    _fullName = name.trim().isEmpty ? null : name.trim();
    _isProfileComplete = _fullName != null && _fullName!.isNotEmpty;
    await _saveProfile();
    notifyListeners();
  }

  /// Update avatar CID
  Future<void> setAvatarCid(String cid) async {
    _avatarCid = cid.isEmpty ? null : cid;
    await _saveProfile();
    notifyListeners();
  }

  /// Update bio
  Future<void> setBio(String bio) async {
    _bio = bio;
    await _saveProfile();
    notifyListeners();
  }

  /// Clear profile
  Future<void> clearProfile() async {
    _fullName = null;
    _avatarCid = null;
    _bio = '';
    _isProfileComplete = false;
    await _saveProfile();
    notifyListeners();
  }

  /// Save profile to local storage
  Future<void> _saveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = {
        'full_name': _fullName,
        'avatar_cid': _avatarCid,
        'bio': _bio,
      };
      await prefs.setString(_profileKey, jsonEncode(profile));
    } catch (e) {
      debugPrint('Profile save error: $e');
    }
  }

  /// Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'full_name': _fullName,
      'avatar_cid': _avatarCid,
      'bio': _bio,
    };
  }

  /// Load from D1 response
  Future<void> loadFromJson(Map<String, dynamic> json) async {
    _fullName = json['full_name'];
    _avatarCid = json['avatar_cid'];
    _bio = json['bio'] ?? '';
    _isProfileComplete = _fullName != null && _fullName!.isNotEmpty;
    await _saveProfile();
    notifyListeners();
  }
}
