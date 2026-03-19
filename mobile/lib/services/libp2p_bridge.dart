// 🌐 P2P LibP2P Platform Channel Interface
// Liberty Reach Messenger v1.0.0
// Native platform integration for libp2p

import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 🌐 LibP2P Native Bridge
///
/// Platform channel interface for native libp2p implementation
/// 
/// Android: Kotlin + jvm-libp2p
/// iOS: Swift + swift-libp2p
///
/// Features:
/// - Peer discovery (mDNS, DHT)
/// - Peer connections
/// - GossipSub messaging
/// - Kademlia DHT
/// - Noise encryption
/// - Yamux multiplexing
class LibP2PBridge {
  static const MethodChannel _channel = MethodChannel('liberty_reach/libp2p');

  /// Initialize libp2p node
  static Future<bool> initialize({
    required String peerId,
    required String privateKey,
    int listenPort = 4000,
  }) async {
    try {
      final result = await _channel.invokeMethod('initialize', {
        'peerId': peerId,
        'privateKey': privateKey,
        'listenPort': listenPort,
      });
      
      debugPrint('🌐 LibP2P initialized: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ LibP2P initialize error: $e');
      return false;
    }
  }

  /// Start listening for connections
  static Future<bool> startListening() async {
    try {
      final result = await _channel.invokeMethod('startListening');
      debugPrint('🌐 LibP2P started listening: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ Start listening error: $e');
      return false;
    }
  }

  /// Stop libp2p node
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
      debugPrint('🌐 LibP2P stopped');
    } catch (e) {
      debugPrint('❌ Stop error: $e');
    }
  }

  /// Connect to peer
  static Future<bool> connectToPeer({
    required String peerId,
    required String multiaddr,
  }) async {
    try {
      final result = await _channel.invokeMethod('connectToPeer', {
        'peerId': peerId,
        'multiaddr': multiaddr,
      });
      
      debugPrint('🌐 Connected to peer $peerId: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ Connect to peer error: $e');
      return false;
    }
  }

  /// Disconnect from peer
  static Future<void> disconnectFromPeer(String peerId) async {
    try {
      await _channel.invokeMethod('disconnectFromPeer', {'peerId': peerId});
      debugPrint('🌐 Disconnected from peer $peerId');
    } catch (e) {
      debugPrint('❌ Disconnect error: $e');
    }
  }

  /// Send message to peer
  static Future<bool> sendMessage({
    required String peerId,
    required String protocol,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod('sendMessage', {
        'peerId': peerId,
        'protocol': protocol,
        'message': message,
      });
      
      debugPrint('🌐 Sent message to $peerId: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ Send message error: $e');
      return false;
    }
  }

  /// Subscribe to topic (GossipSub)
  static Future<bool> subscribeToTopic(String topic) async {
    try {
      final result = await _channel.invokeMethod('subscribeToTopic', {
        'topic': topic,
      });
      
      debugPrint('🌐 Subscribed to topic $topic: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ Subscribe error: $e');
      return false;
    }
  }

  /// Publish message to topic
  static Future<bool> publishToTopic({
    required String topic,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod('publishToTopic', {
        'topic': topic,
        'message': message,
      });
      
      debugPrint('🌐 Published to topic $topic: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ Publish error: $e');
      return false;
    }
  }

  /// DHT: Put value
  static Future<bool> dhtPut({
    required String key,
    required String value,
  }) async {
    try {
      final result = await _channel.invokeMethod('dhtPut', {
        'key': key,
        'value': value,
      });
      
      debugPrint('🌐 DHT put $key: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ DHT put error: $e');
      return false;
    }
  }

  /// DHT: Get value
  static Future<String?> dhtGet(String key) async {
    try {
      final result = await _channel.invokeMethod('dhtGet', {'key': key});
      debugPrint('🌐 DHT get $key: $result');
      return result as String?;
    } catch (e) {
      debugPrint('❌ DHT get error: $e');
      return null;
    }
  }

  /// Find peers by content ID
  static Future<List<String>> findProviders(String contentId) async {
    try {
      final result = await _channel.invokeMethod('findProviders', {
        'contentId': contentId,
      });
      
      final providers = (result as List).map((e) => e.toString()).toList();
      debugPrint('🌐 Found ${providers.length} providers for $contentId');
      return providers;
    } catch (e) {
      debugPrint('❌ Find providers error: $e');
      return [];
    }
  }

  /// Provide content to network
  static Future<bool> provideContent({
    required String contentId,
    required String data,
  }) async {
    try {
      final result = await _channel.invokeMethod('provideContent', {
        'contentId': contentId,
        'data': data,
      });
      
      debugPrint('🌐 Provided content $contentId: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ Provide content error: $e');
      return false;
    }
  }

  /// Get connected peers
  static Future<List<String>> getConnectedPeers() async {
    try {
      final result = await _channel.invokeMethod('getConnectedPeers');
      final peers = (result as List).map((e) => e.toString()).toList();
      debugPrint('🌐 Connected peers: ${peers.length}');
      return peers;
    } catch (e) {
      debugPrint('❌ Get connected peers error: $e');
      return [];
    }
  }

  /// Get node status
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _channel.invokeMethod('getStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('❌ Get status error: $e');
      return {};
    }
  }

  /// Set event handler for incoming messages
  static void setOnMessageReceived(Function(String peerId, String protocol, String message) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'messageReceived') {
        final peerId = call.arguments['peerId'] as String;
        final protocol = call.arguments['protocol'] as String;
        final message = call.arguments['message'] as String;
        handler(peerId, protocol, message);
      } else if (call.method == 'peerConnected') {
        final peerId = call.arguments['peerId'] as String;
        debugPrint('🌐 Peer connected: $peerId');
      } else if (call.method == 'peerDisconnected') {
        final peerId = call.arguments['peerId'] as String;
        debugPrint('🌐 Peer disconnected: $peerId');
      }
    });
  }
}
