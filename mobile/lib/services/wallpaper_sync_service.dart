import 'dart:async';
import '../models/models.dart';

/// 🎨 Wallpaper Sync Service
///
/// Синхронизация обоев между собеседниками
class WallpaperSyncService {
  static WallpaperSyncService? _instance;
  static WallpaperSyncService get instance {
    _instance ??= WallpaperSyncService._();
    return _instance!;
  }

  WallpaperSyncService._();

  // Текущие обои пользователя
  String? _currentWallpaperUrl;
  
  // Синхронизированные обои по чатам
  final Map<String, String> _syncedWallpapers = {};
  
  // Подписка на обновления
  final _wallpaperController = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get wallpaperStream => _wallpaperController.stream;

  // Getters
  String? get currentWallpaperUrl => _currentWallpaperUrl;
  Map<String, String> get syncedWallpapers => Map.unmodifiable(_syncedWallpapers);

  /// Установить обои
  Future<bool> setWallpaper({
    required String wallpaperUrl,
    String? chatId,
    bool syncWithPartner = false,
  }) async {
    _currentWallpaperUrl = wallpaperUrl;
    
    if (chatId != null && syncWithPartner) {
      _syncedWallpapers[chatId] = wallpaperUrl;
      _wallpaperController.add(_syncedWallpapers);
      
      // TODO: Отправить обои партнёру через P2P
      print('🎨 Wallpaper synced with chat $chatId');
    }
    
    print('🎨 Wallpaper set: $wallpaperUrl');
    return true;
  }

  /// Получить обои для чата
  String? getWallpaperForChat(String chatId) {
    return _syncedWallpapers[chatId] ?? _currentWallpaperUrl;
  }

  /// Синхронизировать обои с партнёром
  Future<bool> syncWithPartner({
    required String chatId,
    required String partnerUserId,
  }) async {
    final wallpaperUrl = _syncedWallpapers[chatId] ?? _currentWallpaperUrl;
    
    if (wallpaperUrl == null) return false;
    
    // TODO: Отправить обои партнёру через P2P Gossipsub
    print('🎨 Syncing wallpaper with $partnerUserId');
    return true;
  }

  /// Принять обои от партнёра
  Future<bool> acceptPartnerWallpaper({
    required String chatId,
    required String wallpaperUrl,
  }) async {
    _syncedWallpapers[chatId] = wallpaperUrl;
    _wallpaperController.add(_syncedWallpapers);
    
    print('🎨 Accepted wallpaper from partner for chat $chatId');
    return true;
  }

  /// Удалить синхронизацию для чата
  Future<bool> removeSyncForChat(String chatId) async {
    _syncedWallpapers.remove(chatId);
    _wallpaperController.add(_syncedWallpapers);
    
    print('🎨 Removed sync for chat $chatId');
    return true;
  }

  /// Очистить данные
  void wipe() {
    _currentWallpaperUrl = null;
    _syncedWallpapers.clear();
    _wallpaperController.close();
  }
}
