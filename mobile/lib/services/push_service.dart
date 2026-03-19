import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 📬 Push Notification Service
///
/// Handles push notifications via Cloudflare Worker + FCM
///
/// Features:
/// - Register device token
/// - Receive push notifications
/// - Handle notification taps
/// - Unregister on logout
///
/// Architecture:
/// ```
/// Flutter App ←[FCM]← Cloudflare Worker ←[API]← D1 Database
/// ```
class PushService {
  final Dio _dio = Dio();
  
  // Cloudflare Push Worker URL
  String get _pushUrl => dotenv.env['CLOUDFLARE_PUSH_URL'] ?? 
                        dotenv.env['CLOUDFLARE_WORKER_URL'] ?? 
                        'https://liberty-reach-push.kostik.workers.dev';

  // FCM configuration
  String get _fcmSenderId => dotenv.env['FCM_SENDER_ID'] ?? '';
  
  // Local storage
  static const String _tokenKey = 'push_token';
  static const String _subscribedKey = 'push_subscribed';

  /// Initialize push notifications
  Future<void> init() async {
    try {
      debugPrint('📬 Initializing push notifications...');
      
      // For now, we'll use a simplified approach
      // In production, integrate with firebase_messaging package
      
      final prefs = await SharedPreferences.getInstance();
      final isSubscribed = prefs.getBool(_subscribedKey) ?? false;
      
      if (isSubscribed) {
        debugPrint('✅ Push already subscribed');
      } else {
        debugPrint('⏳ Push not subscribed yet');
      }
    } catch (e) {
      debugPrint('❌ Push init error: $e');
    }
  }

  /// Register device for push notifications
  Future<void> registerDevice(String userId) async {
    try {
      // Generate a unique token for this device
      // In production, get token from firebase_messaging
      final deviceToken = await _getDeviceToken();
      
      if (deviceToken.isEmpty) {
        debugPrint('⚠️ No device token available');
        return;
      }

      // Register with Cloudflare Worker
      final response = await _dio.post(
        '$_pushUrl/push/register',
        data: {
          'user_id': userId,
          'device_token': deviceToken,
          'device_type': 'android', // or 'ios', 'web'
        },
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, deviceToken);
        await prefs.setBool(_subscribedKey, true);
        
        debugPrint('✅ Device registered for push notifications');
      }
    } catch (e) {
      debugPrint('❌ Register device error: $e');
    }
  }

  /// Unregister device from push notifications
  Future<void> unregisterDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceToken = prefs.getString(_tokenKey);
      
      if (deviceToken == null) return;

      // Unregister from Cloudflare Worker
      await _dio.delete(
        '$_pushUrl/push/unregister',
        data: {
          'device_token': deviceToken,
        },
      );

      await prefs.remove(_tokenKey);
      await prefs.remove(_subscribedKey);
      
      debugPrint('✅ Device unregistered from push notifications');
    } catch (e) {
      debugPrint('❌ Unregister device error: $e');
    }
  }

  /// Get device token (simulated for now)
  Future<String> _getDeviceToken() async {
    // In production, use firebase_messaging:
    // final FirebaseMessaging messaging = FirebaseMessaging.instance;
    // final String? token = await messaging.getToken();
    // return token ?? '';
    
    // For now, generate a unique ID
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(_tokenKey);
    
    if (token == null) {
      // Generate a fake token for development
      token = 'fake_token_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_tokenKey, token);
    }
    
    return token;
  }

  /// Handle background messages
  static Future<void> handleBackgroundMessage(Map<String, dynamic> message) async {
    debugPrint('📬 Background message received: ${message['notification']}');
    
    // Handle the message (show notification, update badge, etc.)
    final title = message['notification']?['title'];
    final body = message['notification']?['body'];
    
    debugPrint('📬 $title: $body');
  }

  /// Handle notification tap
  Future<void> handleNotificationTap(Map<String, dynamic> data) async {
    debugPrint('📬 Notification tapped: $data');
    
    // Navigate to appropriate screen based on data
    // Example: Open chat room, view profile, etc.
  }

  /// Send test notification (for development)
  Future<void> sendTestNotification(String userId) async {
    try {
      final response = await _dio.post(
        '$_pushUrl/push/send',
        data: {
          'user_id': userId,
          'title': '🔔 Test Notification',
          'body': 'This is a test push notification!',
          'data': {
            'type': 'test',
            'timestamp': DateTime.now().toIso8601String(),
          },
        },
      );

      debugPrint('✅ Test notification sent: ${response.data}');
    } catch (e) {
      debugPrint('❌ Send test notification error: $e');
    }
  }

  /// Check if push is enabled
  Future<bool> isPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_subscribedKey) ?? false;
  }

  /// Get current device token
  Future<String?> getDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}

/// 📬 Push Notification Model
class PushNotification {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;

  PushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
    this.isRead = false,
  });

  factory PushNotification.fromJson(Map<String, dynamic> json) {
    return PushNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] ?? {},
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['sent_at'] ?? 0),
      isRead: json['read'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'sent_at': timestamp.millisecondsSinceEpoch,
      'read': isRead,
    };
  }
}
