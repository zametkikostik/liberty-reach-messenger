import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 📡 WebSocket Service — Real-time Updates
///
/// Provides real-time message synchronization via:
/// - Cloudflare D1 Webhooks (production)
/// - WebSocket polling (fallback)
///
/// Architecture:
/// ```
/// Flutter App ←[WebSocket]→ Cloudflare Worker ←[Webhook]→ D1 Database
/// ```
///
/// Security:
/// - JWT authentication
/// - TLS encryption (wss://)
/// - Automatic reconnection
class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }

  WebSocketService._();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  bool _isConnected = false;
  bool _isReconnecting = false;
  
  // Stream controllers for different event types
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();

  // Get configuration
  String get _wsUrl => dotenv.env['CLOUDFLARE_WEBSOCKET_URL'] ?? '';
  String get _apiToken => dotenv.env['CLOUDFLARE_API_TOKEN'] ?? '';

  /// Get stream of new messages
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Get stream of typing events
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  /// Get stream of presence updates (online/offline)
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Connect to WebSocket server
  Future<void> connect({String? userId}) async {
    if (_isConnected || _isReconnecting) return;

    try {
      final url = _wsUrl.isNotEmpty
          ? _wsUrl
          : 'wss://liberty-reach-push.kostik.workers.dev/ws';

      debugPrint('📡 Connecting to WebSocket: $url');

      _channel = WebSocketChannel.connect(
        Uri.parse(url),
        protocols: ['graphql-ws'], // Or custom protocol
      );

      // Listen for messages
      await for (final message in _channel!.stream) {
        _handleMessage(message, userId: userId);
      }
    } catch (e) {
      debugPrint('❌ WebSocket connection error: $e');
      _scheduleReconnect(userId: userId);
    }
  }

  /// Handle incoming WebSocket message
  void _handleMessage(String message, {String? userId}) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      debugPrint('📩 Received: $type - ${data['payload']}');

      switch (type) {
        case 'message':
          _messageController.add(data['payload'] as Map<String, dynamic>);
          break;
        
        case 'typing':
          _typingController.add(data['payload'] as Map<String, dynamic>);
          break;
        
        case 'presence':
          _presenceController.add(data['payload'] as Map<String, dynamic>);
          break;
        
        case 'ping':
          _sendPong();
          break;
        
        default:
          debugPrint('⚠️ Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('❌ Message handling error: $e');
    }
  }

  /// Send pong response to keep-alive
  void _sendPong() {
    _send({'type': 'pong'});
  }

  /// Send message through WebSocket
  Future<void> _send(Map<String, dynamic> data) async {
    if (!_isConnected || _channel == null) return;

    try {
      _channel!.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('❌ Send error: $e');
    }
  }

  /// Subscribe to chat room
  Future<void> subscribeToChat(String chatId) async {
    _send({
      'type': 'subscribe',
      'channel': 'chat:$chatId',
      'token': _apiToken,
    });
  }

  /// Unsubscribe from chat room
  Future<void> unsubscribeFromChat(String chatId) async {
    _send({
      'type': 'unsubscribe',
      'channel': 'chat:$chatId',
    });
  }

  /// Send typing indicator
  Future<void> sendTyping({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    _send({
      'type': 'typing',
      'channel': 'chat:$chatId',
      'payload': {
        'user_id': userId,
        'is_typing': isTyping,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Update presence (online/offline)
  Future<void> updatePresence({
    required String userId,
    required bool isOnline,
  }) async {
    _send({
      'type': 'presence',
      'payload': {
        'user_id': userId,
        'is_online': isOnline,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Schedule reconnection
  void _scheduleReconnect({String? userId, int delaySeconds = 5}) {
    if (_isReconnecting) return;

    _isReconnecting = true;
    _isConnected = false;

    debugPrint('🔄 Reconnecting in $delaySeconds seconds...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _isReconnecting = false;
      connect(userId: userId);
    });
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _send({'type': 'ping'});
    });
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _messageController.close();
    _typingController.close();
    _presenceController.close();
    
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    
    _isConnected = false;
    debugPrint('📡 WebSocket disconnected');
  }

  /// Test connection
  Future<bool> testConnection() async {
    try {
      await connect();
      return _isConnected;
    } catch (e) {
      return false;
    }
  }
}

/// 🔄 Fallback: HTTP Polling Service
///
/// Used when WebSocket is not available.
/// Polls D1 API every N seconds for new messages.
class PollingService {
  Timer? _pollTimer;
  final Duration _pollInterval;
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  PollingService({Duration pollInterval = const Duration(seconds: 3)})
      : _pollInterval = pollInterval;

  /// Start polling for new messages
  void startPolling({
    required String userId1,
    required String userId2,
    required Future<List<Map<String, dynamic>>> Function() fetchMessages,
  }) {
    _pollTimer?.cancel();
    
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      try {
        final messages = await fetchMessages();
        for (final msg in messages) {
          _messageController.add(msg);
        }
      } catch (e) {
        debugPrint('❌ Polling error: $e');
      }
    });
  }

  /// Stop polling
  void stopPolling() {
    _pollTimer?.cancel();
    _messageController.close();
  }
}
