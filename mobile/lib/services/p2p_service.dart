import 'package:flutter_webrtc/flutter_webrtc.dart';

/// P2P Service для Liberty Reach Messenger
/// 
/// Обеспечивает WebRTC соединение для прямого обмена сообщениями
/// между пользователями без посредников.
/// 
/// ## STUN/ICE Servers
/// Используем публичные STUN серверы для NAT traversal:
/// - Google STUN (primary)
/// - Mozilla STUN
/// - Nextcloud STUN
/// 
/// ## Пример использования:
/// ```dart
/// final p2pService = P2PService();
/// await p2pService.initialize();
/// final offer = await p2pService.createOffer();
/// ```
class P2PService {
  RTCPeerConnection? _peerConnection;
  
  /// 📡 STUN/ICE Servers для WebRTC
  /// 
  /// Эти серверы помогают установить P2P соединение через NAT
  /// Multiple серверы обеспечивают надёжность соединения
  static const List<Map<String, dynamic>> iceServers = [
    // Google STUN (primary) - самый надёжный
    {'urls': ['stun:stun.l.google.com:19302']},
    {'urls': ['stun:stun1.l.google.com:19302']},
    
    // Google STUN (backup ports)
    {'urls': ['stun:stun.l.google.com:19305']},
    {'urls': ['stun:stun2.l.google.com:19302']},
    
    // Mozilla STUN
    {'urls': ['stun:stun.services.mozilla.com']},
    
    // Nextcloud STUN (HTTPS port)
    {'urls': ['stun:stun.nextcloud.com:443']},
    
    // Twilio STUN (backup)
    {'urls': ['stun:global.stun.twilio.com:3478']},
  ];

  /// Конфигурация WebRTC
  static const Map<String, dynamic> rtcConfiguration = {
    'iceServers': iceServers,
    'iceTransportPolicy': 'all', // Разрешить и STUN и TURN
    'bundlePolicy': 'balanced',
    'rtcpMuxPolicy': 'require',
  };

  /// Инициализация P2P соединения
  Future<void> initialize() async {
    if (_peerConnection != null) {
      await _peerConnection!.close();
    }

    _peerConnection = await createPeerConnection(rtcConfiguration);
    
    // Обработчики событий
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        print('ICE candidate: ${candidate.candidate}');
      }
    };

    _peerConnection!.onConnectionStateChange = (state) {
      print('Connection state: $state');
    };

    _peerConnection!.onIceConnectionStateChange = (state) {
      print('ICE connection state: $state');
    };
  }

  /// Создание SDP offer для инициации соединения
  Future<RTCSessionDescription?> createOffer() async {
    if (_peerConnection == null) {
      throw Exception('P2PService not initialized');
    }

    // Создаем media stream для audio/video (опционально)
    final stream = await _createLocalStream();
    stream.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, stream);
    });

    // Создаем offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    return offer;
  }

  /// Создание SDP answer в ответ на offer
  Future<RTCSessionDescription?> createAnswer(RTCSessionDescription offer) async {
    if (_peerConnection == null) {
      throw Exception('P2PService not initialized');
    }

    await _peerConnection!.setRemoteDescription(offer);
    
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    
    return answer;
  }

  /// Установка remote description (offer или answer)
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (_peerConnection == null) {
      throw Exception('P2PService not initialized');
    }

    await _peerConnection!.setRemoteDescription(description);
  }

  /// Добавление ICE candidate от remote peer
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) {
      throw Exception('P2PService not initialized');
    }

    await _peerConnection!.addCandidate(candidate);
  }

  /// Создание локального media stream (audio/video)
  Future<MediaStream> _createLocalStream() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false, // Пока только аудио, видео можно включить позже
    });
    
    return stream;
  }

  /// Закрытие соединения
  Future<void> dispose() async {
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }
  }

  /// Проверка состояния соединения
  bool get isConnected => 
      _peerConnection?.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  /// Получение текущего состояния
  RTCPeerConnectionState? get connectionState => 
      _peerConnection?.connectionState;
}

/// Менеджер P2P соединений для нескольких пользователей
class P2PConnectionManager {
  final Map<String, P2PService> _connections = {};

  /// Создание нового соединения с пользователем
  Future<P2PService> createConnection(String userId) async {
    if (_connections.containsKey(userId)) {
      return _connections[userId]!;
    }

    final service = P2PService();
    await service.initialize();
    _connections[userId] = service;
    
    return service;
  }

  /// Получение существующего соединения
  P2PService? getConnection(String userId) {
    return _connections[userId];
  }

  /// Закрытие всех соединений
  Future<void> disposeAll() async {
    for (final service in _connections.values) {
      await service.dispose();
    }
    _connections.clear();
  }

  /// Закрытие конкретного соединения
  Future<void> closeConnection(String userId) async {
    final service = _connections.remove(userId);
    if (service != null) {
      await service.dispose();
    }
  }
}
