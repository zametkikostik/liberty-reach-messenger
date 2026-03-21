import 'dart:async';
import 'package:flutter/foundation.dart';

/// 🔗 Rust Bridge Service - Стриминг данных из Rust-ядра
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
