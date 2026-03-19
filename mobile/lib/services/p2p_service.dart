import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/d1_api_service.dart';

/// 🌐 P2P Network Service — libp2p Integration
///
/// Features:
/// - Peer discovery (mDNS, DHT)
/// - Peer connection management
/// - Message routing
/// - DHT cache
/// - NAT traversal (STUN/TURN)
///
/// Protocols:
/// - /libp2p/noise - Encryption
/// - /libp2p/yamux - Multiplexing
/// - /libp2p/gossipsub - PubSub messaging
/// - /libp2p/kad - Kademlia DHT
///
/// Note: Full libp2p implementation requires native platform code.
/// This service provides the Flutter interface and D1 storage.
/// For production, use flutter-libp2p or platform channels.
class P2PService {
  static P2PService? _instance;
  static P2PService get instance {
    _instance ??= P2PService._();
    return _instance!;
  }

  P2PService._();

  final Dio _dio = Dio();
  final _uuid = const Uuid();
  final D1ApiService _d1Service = D1ApiService();

  // Configuration
  String get _bootstrapNode => dotenv.env['P2P_BOOTSTRAP_NODE'] ?? '';
  int get _listenPort => int.parse(dotenv.env['P2P_LISTEN_PORT'] ?? '4000');

  // Local peer info
  String? _localPeerId;
  String? _localMultiaddr;
  bool _isRunning = false;

  // Getters
  String? get localPeerId => _localPeerId;
  bool get isRunning => _isRunning;

  /// Initialize P2P network
  Future<bool> initialize() async {
    try {
      // In production, initialize libp2p node here
      // For now, generate local peer ID
      _localPeerId = '16Uiu2HAm${_uuid.v4().replaceAll('-', '').toUpperCase()}';
      _localMultiaddr = '/ip4/0.0.0.0/tcp/$_listenPort/p2p/$_localPeerId';

      debugPrint('🌐 P2P initialized: $_localPeerId');
      return true;
    } catch (e) {
      debugPrint('❌ P2P initialize error: $e');
      return false;
    }
  }

  /// Start P2P network
  Future<bool> start() async {
    try {
      if (_isRunning) return true;

      // Initialize if not already done
      if (_localPeerId == null) {
        await initialize();
      }

      // In production:
      // - Start libp2p node
      // - Connect to bootstrap nodes
      // - Start mDNS discovery
      // - Start DHT bootstrap

      _isRunning = true;
      debugPrint('🌐 P2P network started');

      // Start peer discovery
      _startPeerDiscovery();

      return true;
    } catch (e) {
      debugPrint('❌ P2P start error: $e');
      return false;
    }
  }

  /// Stop P2P network
  Future<void> stop() async {
    try {
      if (!_isRunning) return;

      // In production:
      // - Stop libp2p node
      // - Close connections
      // - Clean up resources

      _isRunning = false;
      debugPrint('🌐 P2P network stopped');
    } catch (e) {
      debugPrint('❌ P2P stop error: $e');
    }
  }

  /// Discover peers
  Future<void> _startPeerDiscovery() async {
    try {
      // In production, this would:
      // - Query mDNS for local peers
      // - Query DHT for known peers
      // - Connect to bootstrap nodes

      // Simulate peer discovery for now
      await Future.delayed(const Duration(seconds: 5));
      debugPrint('🔍 Peer discovery started...');
    } catch (e) {
      debugPrint('❌ Peer discovery error: $e');
    }
  }

  /// Add peer to known peers
  Future<bool> addPeer({
    required String peerId,
    required String publicKey,
    String? multiaddr,
    String connectionType = 'tcp',
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _d1Service.execute('''
        INSERT INTO p2p_peers (
          id, peer_id, public_key, multiaddr, last_seen,
          is_online, connection_type, created_at
        ) VALUES (?, ?, ?, ?, ?, 1, ?, ?)
        ON CONFLICT(peer_id) DO UPDATE SET
          last_seen = ?,
          is_online = 1,
          multiaddr = COALESCE(?, multiaddr)
      ''', [
        _uuid.v4(),
        peerId,
        publicKey,
        multiaddr,
        now,
        connectionType,
        now,
        now,
        multiaddr,
      ]);

      debugPrint('✅ Peer added: $peerId');
      return true;
    } catch (e) {
      debugPrint('❌ Add peer error: $e');
      return false;
    }
  }

  /// Get known peers
  Future<List<Map<String, dynamic>>> getPeers({
    bool onlineOnly = false,
    int limit = 50,
  }) async {
    try {
      String query = '''
        SELECT * FROM p2p_peers
        WHERE 1=1
      ''';

      if (onlineOnly) {
        query += ' AND is_online = 1';
      }

      query += ' ORDER BY last_seen DESC LIMIT ?';

      return await _d1Service.query(query, [limit]);
    } catch (e) {
      debugPrint('❌ Get peers error: $e');
      return [];
    }
  }

  /// Send message to peer
  Future<bool> sendMessage({
    required String toPeer,
    required String message,
    String messageType = 'chat',
  }) async {
    try {
      final messageId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Save to routing table
      await _d1Service.execute('''
        INSERT INTO p2p_message_routing (
          id, message_id, from_peer, to_peer, timestamp, status
        ) VALUES (?, ?, ?, ?, ?, 'pending')
      ''', [_uuid.v4(), messageId, _localPeerId, toPeer, now]);

      // In production:
      // - Serialize message
      // - Encrypt with recipient's public key
      // - Send via libp2p stream

      debugPrint('📤 Message sent to $toPeer: $messageId');
      return true;
    } catch (e) {
      debugPrint('❌ Send message error: $e');
      return false;
    }
  }

  /// Store value in DHT
  Future<bool> dhtPut({
    required String key,
    required String value,
    int ttlSeconds = 3600,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiresAt = now + (ttlSeconds * 1000);

      await _d1Service.execute('''
        INSERT INTO dht_cache (
          id, key_hash, value, provider_peer, expires_at, created_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(key_hash) DO UPDATE SET
          value = ?,
          expires_at = ?,
          provider_peer = ?
      ''', [
        _uuid.v4(),
        key,
        value,
        _localPeerId,
        expiresAt,
        now,
        value,
        expiresAt,
        _localPeerId,
      ]);

      debugPrint('💾 DHT put: $key');
      return true;
    } catch (e) {
      debugPrint('❌ DHT put error: $e');
      return false;
    }
  }

  /// Get value from DHT
  Future<String?> dhtGet(String key) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      final results = await _d1Service.query('''
        SELECT value FROM dht_cache
        WHERE key_hash = ? AND expires_at > ?
      ''', [key, now]);

      if (results.isNotEmpty) {
        return results.first['value'] as String?;
      }

      return null;
    } catch (e) {
      debugPrint('❌ DHT get error: $e');
      return null;
    }
  }

  /// Get network stats
  Future<Map<String, dynamic>> getNetworkStats() async {
    try {
      final onlinePeers = await _d1Service.query(
        'SELECT COUNT(*) as count FROM p2p_peers WHERE is_online = 1',
      );

      final totalMessages = await _d1Service.query(
        'SELECT COUNT(*) as count FROM p2p_message_routing',
      );

      final dhtEntries = await _d1Service.query(
        'SELECT COUNT(*) as count FROM dht_cache WHERE expires_at > ?',
        [DateTime.now().millisecondsSinceEpoch],
      );

      return {
        'online_peers': onlinePeers.first['count'] ?? 0,
        'total_messages': totalMessages.first['count'] ?? 0,
        'dht_entries': dhtEntries.first['count'] ?? 0,
        'is_running': _isRunning,
        'local_peer_id': _localPeerId,
      };
    } catch (e) {
      debugPrint('❌ Get stats error: $e');
      return {};
    }
  }

  /// Log discovery event
  Future<void> logDiscovery({
    required String peerId,
    required String method,
    bool success = true,
    String? errorMessage,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _d1Service.execute('''
        INSERT INTO p2p_discovery_log (
          id, peer_id, discovery_method, timestamp, success, error_message
        ) VALUES (?, ?, ?, ?, ?, ?)
      ''', [
        _uuid.v4(),
        peerId,
        method,
        now,
        success ? 1 : 0,
        errorMessage,
      ]);
    } catch (e) {
      debugPrint('❌ Log discovery error: $e');
    }
  }
}
