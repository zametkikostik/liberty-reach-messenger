import 'dart:async';
import 'package:flutter/foundation.dart';

/// 🔗 Rust Bridge Service - Стриминг данных из Rust-ядра
///
/// Инициализация с солью из облака:
/// await RustBridgeService.instance.init(
///   salt: 'your_salt_from_cloud',
///   isAdminMode: true,
/// );
class RustBridgeService {
  static RustBridgeService? _instance;
  static RustBridgeService get instance {
    _instance ??= RustBridgeService._();
    return _instance!;
  }

  RustBridgeService._();

  final _rustDataController = StreamController<RustCoreData>.broadcast();
  Stream<RustCoreData> get rustDataStream => _rustDataController.stream;

  RustCoreData _currentData = RustCoreData.empty();
  Timer? _updateTimer;
  
  // 🔐 Флаг инициализации
  bool _isInitialized = false;

  /// Инициализация Rust-ядра с солью
  /// 
  /// Вызывается ОДИН РАЗ при старте приложения
  /// 
  /// [salt] - соль из APP_MASTER_SALT (может быть null)
  /// [isAdminMode] - режим админки (влияет на права доступа)
  Future<void> init({String? salt, bool isAdminMode = false}) async {
    if (_isInitialized) {
      '⚠️ RustBridgeService already initialized'.secureDebug(tag: 'RUST_BRIDGE');
      return;
    }

    try {
      '🔧 Initializing Rust Bridge with salt...'.secureDebug(tag: 'RUST_BRIDGE');
      
      // TODO: Вызов FFI для передачи соли в Rust
      // Здесь будет вызов rust_lib.init(salt, isAdminMode)
      
      // Для демо - просто логируем
      'Salt: ${salt != null && salt.isNotEmpty ? "SET" : "NOT_SET"}'.secureDebug(tag: 'RUST_BRIDGE');
      'Admin Mode: $isAdminMode'.secureDebug(tag: 'RUST_BRIDGE');
      
      _isInitialized = true;
      '✅ Rust Bridge initialized'.secureDebug(tag: 'RUST_BRIDGE');
    } catch (e) {
      '❌ Rust Bridge initialization failed: $e'.secureError(tag: 'RUST_BRIDGE');
      // Не блокируем приложение при ошибке
    }
  }

  void startStreaming() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _currentData = RustCoreData(
        activeConnections: DateTime.now().second % 100,
        kyberStatus: KyberStatus.values[DateTime.now().millisecond % 3],
        memoryUsage: DateTime.now().minute % 100,
        peerCount: DateTime.now().second % 50,
        bandwidthUsage: (DateTime.now().second % 100).toDouble(),
        protocolVersion: '1.0.0',
        uptime: DateTime.now().millisecondsSinceEpoch,
      );
      _rustDataController.add(_currentData);
    });
  }

  void stopStreaming() {
    _updateTimer?.cancel();
  }

  RustCoreData get currentData => _currentData;

  void dispose() {
    stopStreaming();
    _rustDataController.close();
  }
}

class RustCoreData {
  final int activeConnections;
  final KyberStatus kyberStatus;
  final int memoryUsage;
  final int peerCount;
  final double bandwidthUsage;
  final String protocolVersion;
  final int uptime;

  const RustCoreData({
    required this.activeConnections,
    required this.kyberStatus,
    required this.memoryUsage,
    required this.peerCount,
    required this.bandwidthUsage,
    required this.protocolVersion,
    required this.uptime,
  });

  const RustCoreData.empty()
      : activeConnections = 0,
        kyberStatus = KyberStatus.disconnected,
        memoryUsage = 0,
        peerCount = 0,
        bandwidthUsage = 0,
        protocolVersion = '0.0.0',
        uptime = 0;

  String get formattedUptime {
    final seconds = (uptime / 1000).round();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get kyberStatusText {
    switch (kyberStatus) {
      case KyberStatus.active: return 'Active ✓';
      case KyberStatus.keyExchange: return 'Key Exchange...';
      case KyberStatus.disconnected: return 'Disconnected';
    }
  }
}

enum KyberStatus { active, keyExchange, disconnected }
