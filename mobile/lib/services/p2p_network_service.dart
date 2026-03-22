import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'e2ee_service.dart';

/// 📡 P2P Network Service - Decentralized Messaging
///
/// Реализация:
/// - mDNS для локального обнаружения устройств
/// - WebRTC для прямого соединения
/// - Gossipsub protocol для чатов
/// - Kademlia DHT для маршрутизации
///
/// Интеграция с Rust libp2p через FFI
class P2PNetworkService {
  static P2PNetworkService? _instance;
  static P2PNetworkService get instance {
    _instance ??= P2PNetworkService._();
    return _instance!;
  }

  P2PNetworkService._();

  final _uuid = const Uuid();
  final _e2eeService = E2EEService.instance;

  // 🔐 Идентификатор ноды
  String? _nodeId;
  String? _peerId;
  
  // 📡 Состояние сети
  bool _isRunning = false;
  final List<Map<String, dynamic>> _peers = [];
  final List<Map<String, dynamic>> _messages = [];
  
  // 📊 Потоки
  final _peersController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get peersStream => _peersController.stream;
  
  final _messagesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get messagesStream => _messagesController.stream;

  // Getters
  String? get nodeId => _nodeId;
  String? get peerId => _peerId;
  bool get isRunning => _isRunning;
  List<Map<String, dynamic>> get peers => List.unmodifiable(_peers);
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);

  /// 🚀 Запуск P2P ноды
  Future<bool> start({
    required String userId,
    int port = 40000,
  }) async {
    if (_isRunning) {
      debugPrint('⚠️ P2P already running');
      return false;
    }

    try {
      // Генерация ID ноды
      _nodeId = userId;
      _peerId = _uuid.v4();
      
      debugPrint('📡 Starting P2P node: $_peerId');
      debugPrint('🔐 Node ID: $_nodeId');
      debugPrint('🎯 Port: $port');

      // TODO: Интеграция с Rust libp2p
      // - Инициализация TCP транспорта
      // - Noise protocol для шифрования
      // - Yamux для мультиплексирования
      // - mDNS для обнаружения
      // - Kademlia DHT
      // - Gossipsub для чатов

      _isRunning = true;
      
      // Эмуляция обнаружения пиров (для демо)
      _startPeerDiscovery();
      
      debugPrint('✅ P2P node started');
      return true;
    } catch (e) {
      debugPrint('❌ P2P start failed: $e');
      return false;
    }
  }

  /// 🔍 Обнаружение пиров (mDNS)
  void _startPeerDiscovery() {
    // Эмуляция для демо
    Future.delayed(const Duration(seconds: 2), () {
      _peers.add({
        'peerId': 'peer_demo_1',
        'nodeId': 'user_alberto',
        'address': '/ip4/192.168.1.100/tcp/40000',
        'status': 'online',
        'lastSeen': DateTime.now(),
      });
      _peersController.add(_peers);
    });

    Future.delayed(const Duration(seconds: 5), () {
      _peers.add({
        'peerId': 'peer_demo_2',
        'nodeId': 'user_maria',
        'address': '/ip4/192.168.1.101/tcp/40000',
        'status': 'online',
        'lastSeen': DateTime.now(),
      });
      _peersController.add(_peers);
    });
  }

  /// 📨 Отправка сообщения
  Future<bool> sendMessage({
    required String targetPeerId,
    required String chatId,
    required String senderId,
    required String text,
    bool isEncrypted = true,
  }) async {
    if (!_isRunning) {
      debugPrint('❌ P2P not running');
      return false;
    }

    try {
      final messageId = _uuid.v4();
      
      // 🔐 Шифрование
      String? encryptedText;
      if (isEncrypted) {
        encryptedText = _e2eeService.encryptMessage(text);
      }

      final message = {
        'messageId': messageId,
        'chatId': chatId,
        'senderId': senderId,
        'targetPeerId': targetPeerId,
        'text': text,
        'encryptedText': encryptedText,
        'isEncrypted': isEncrypted,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'sent',
        'type': 'chat',
      };

      _messages.add(message);
      _messagesController.add(_messages);

      // TODO: Отправка через libp2p Gossipsub
      // await _rustBridge.sendP2PMessage(message);

      debugPrint('📤 Message sent: $messageId');
      return true;
    } catch (e) {
      debugPrint('❌ Send failed: $e');
      return false;
    }
  }

  /// 📥 Получение сообщения
  void _handleIncomingMessage(Map<String, dynamic> message) {
    _messages.add(message);
    _messagesController.add(_messages);
    debugPrint('📥 Message received: ${message['messageId']}');
  }

  /// 🔗 Подключение к пиру
  Future<bool> connectToPeer(String peerAddress) async {
    try {
      debugPrint('🔗 Connecting to peer: $peerAddress');
      
      // TODO: Интеграция с Rust libp2p
      // - Dial peer через TCP/QUIC
      // - Handshake с Noise
      // - Открытие Yamux stream

      debugPrint('✅ Connected to peer');
      return true;
    } catch (e) {
      debugPrint('❌ Connect failed: $e');
      return false;
    }
  }

  /// ❌ Отключение от пира
  Future<void> disconnectFromPeer(String peerId) async {
    debugPrint('❌ Disconnecting from peer: $peerId');
    // TODO: Интеграция с Rust
  }

  /// 🏁 Остановка ноды
  Future<void> stop() async {
    if (!_isRunning) return;

    debugPrint('🏁 Stopping P2P node...');
    
    // Отключение от всех пиров
    for (final peer in _peers) {
      await disconnectFromPeer(peer['peerId']);
    }

    _peers.clear();
    _isRunning = false;
    
    _peersController.add(_peers);
    debugPrint('✅ P2P node stopped');
  }

  /// 🧹 Очистка
  void wipe() {
    _nodeId = null;
    _peerId = null;
    _peers.clear();
    _messages.clear();
    _isRunning = false;
  }

  /// Закрытие потоков
  void dispose() {
    stop();
    _peersController.close();
    _messagesController.close();
  }
}

// 📊 Extension для отладки
extension DebugPrint on Object {
  void debugPrint(String message) {
    print('[P2P] $message');
  }
}
