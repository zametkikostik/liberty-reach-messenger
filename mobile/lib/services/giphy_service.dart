import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 🎬 Giphy Service — GIF Search & Picker
///
/// Features:
/// - Search GIFs by keyword
/// - Get trending GIFs
/// - Get GIF by ID
///
/// Setup:
/// 1. Get API key from https://developers.giphy.com/
/// 2. Add to .env.local: GIPHY_API_KEY=your_key
class GiphyService {
  static GiphyService? _instance;
  static GiphyService get instance {
    _instance ??= GiphyService._();
    return _instance!;
  }

  GiphyService._();

  final Dio _dio = Dio();
  String get _apiKey => dotenv.env['GIPHY_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.giphy.com/v1/gifs';

  /// Initialize Giphy client
  void init() {
    if (_apiKey.isEmpty) {
      debugPrint('⚠️ GIPHY_API_KEY not set in .env.local');
      return;
    }
    debugPrint('🎬 Giphy initialized');
  }

  /// Search GIFs
  Future<List<Map<String, dynamic>>> search({
    String query = 'happy',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (_apiKey.isEmpty) return [];

      final response = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'api_key': _apiKey,
          'q': query,
          'limit': limit,
          'offset': offset,
          'rating': 'pg',
        },
      );

      final data = response.data['data'] as List;
      return data.map((gif) => _parseGif(gif)).toList();
    } catch (e) {
      debugPrint('❌ Giphy search error: $e');
      return [];
    }
  }

  /// Get trending GIFs
  Future<List<Map<String, dynamic>>> getTrending({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (_apiKey.isEmpty) return [];

      final response = await _dio.get(
        '$_baseUrl/trending',
        queryParameters: {
          'api_key': _apiKey,
          'limit': limit,
          'offset': offset,
          'rating': 'pg',
        },
      );

      final data = response.data['data'] as List;
      return data.map((gif) => _parseGif(gif)).toList();
    } catch (e) {
      debugPrint('❌ Giphy trending error: $e');
      return [];
    }
  }

  /// Parse GIF data
  Map<String, dynamic> _parseGif(Map<String, dynamic> gif) {
    final images = gif['images'] as Map<String, dynamic>? ?? {};
    final original = images['original'] as Map<String, dynamic>? ?? {};
    final fixedHeight = images['fixed_height'] as Map<String, dynamic>? ?? {};
    final fixedHeightSmall = images['fixed_height_small'] as Map<String, dynamic>? ?? {};
    final previewGif = images['preview_gif'] as Map<String, dynamic>? ?? {};

    return {
      'id': gif['id'] ?? '',
      'title': gif['title'] ?? 'GIF',
      'url': original['url'] ?? '',
      'previewUrl': fixedHeightSmall['url'] ?? previewGif['url'] ?? '',
      'width': int.tryParse(original['width'] ?? '0') ?? 0,
      'height': int.tryParse(original['height'] ?? '0') ?? 0,
    };
  }

  /// Get GIF URL for display
  String getGifUrl(Map<String, dynamic> gif) {
    return gif['url'] ?? '';
  }

  /// Get GIF preview URL (smaller, for grid)
  String getGifPreviewUrl(Map<String, dynamic> gif) {
    return gif['previewUrl'] ?? '';
  }
}
