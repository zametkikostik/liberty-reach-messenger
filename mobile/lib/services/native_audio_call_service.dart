import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../services/d1_api_service.dart';

/// 📞 Native Audio Call Service
///
/// Uses platform-specific calling APIs:
/// - Android: ConnectionService (VoIP)
/// - iOS: CallKit
///
/// Features:
/// - Audio calls via Internet (VoIP)
/// - Call history
/// - Missed call notifications
/// - Call duration tracking
///
/// Note: This is a simplified implementation.
/// For production, use flutter_callkit_voip or similar.
class NativeAudioCallService {
  static NativeAudioCallService? _instance;
  static NativeAudioCallService get instance {
    _instance ??= NativeAudioCallService._();
    return _instance!;
  }

  NativeAudioCallService._();

  final D1ApiService _d1Service = D1ApiService();
  final _uuid = const Uuid();

  // Call state
  String? _currentCallId;
  String? _remoteUserId;
  CallState _state = CallState.idle;
  DateTime? _callStartTime;
  Timer? _durationTimer;
  int _callDuration = 0;

  // Getters
  CallState get state => _state;
  String? get currentCallId => _currentCallId;
  String? get remoteUserId => _remoteUserId;
  int get callDuration => _callDuration;

  /// Start outgoing call
  Future<bool> startCall(String userId) async {
    try {
      _currentCallId = _uuid.v4();
      _remoteUserId = userId;
      _state = CallState.dialing;

      // Save call to D1
      final now = DateTime.now().millisecondsSinceEpoch;
      await _d1Service.execute('''
        INSERT INTO calls (
          id, caller_id, callee_id, call_type, status, started_at
        ) VALUES (?, ?, ?, 'audio', 'ringing', ?)
      ''', [_currentCallId, 'me', userId, now]);

      debugPrint('📞 Starting call to $userId (ID: $_currentCallId)');

      // TODO: Integrate with native VoIP service
      // For now, simulate call flow
      _simulateCallConnected();

      return true;
    } catch (e) {
      debugPrint('❌ Start call error: $e');
      _state = CallState.failed;
      return false;
    }
  }

  /// Answer incoming call
  Future<bool> answerCall(String callId) async {
    try {
      _currentCallId = callId;
      _state = CallState.connected;
      _callStartTime = DateTime.now();

      // Update call status
      await _d1Service.execute('''
        UPDATE calls SET status = 'connected', started_at = ?
        WHERE id = ?
      ''', [_callStartTime!.millisecondsSinceEpoch, _currentCallId]);

      // Start duration timer
      _startDurationTimer();

      debugPrint('✅ Call answered: $callId');
      return true;
    } catch (e) {
      debugPrint('❌ Answer call error: $e');
      _state = CallState.failed;
      return false;
    }
  }

  /// End call
  Future<void> endCall() async {
    try {
      _state = CallState.ended;
      _durationTimer?.cancel();

      final now = DateTime.now().millisecondsSinceEpoch;
      final duration = _callDuration;

      // Update call record
      if (_currentCallId != null) {
        await _d1Service.execute('''
          UPDATE calls SET status = 'ended', ended_at = ?, duration = ?
          WHERE id = ?
        ''', [now, duration, _currentCallId]);

        // Add call log
        await _d1Service.execute('''
          INSERT INTO call_logs (id, call_id, event_type, timestamp)
          VALUES (?, ?, 'ended', ?)
        ''', [_uuid.v4(), _currentCallId, now]);
      }

      debugPrint('📞 Call ended (duration: ${duration}s)');

      // Reset state
      _currentCallId = null;
      _remoteUserId = null;
      _callDuration = 0;
    } catch (e) {
      debugPrint('❌ End call error: $e');
    }
  }

  /// Reject incoming call
  Future<void> rejectCall(String callId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _d1Service.execute('''
        UPDATE calls SET status = 'rejected', ended_at = ?
        WHERE id = ?
      ''', [now, callId]);

      debugPrint('📞 Call rejected: $callId');
    } catch (e) {
      debugPrint('❌ Reject call error: $e');
    }
  }

  /// Get call history for user
  Future<List<Map<String, dynamic>>> getCallHistory({
    String? userId,
    int limit = 50,
  }) async {
    try {
      if (userId == null) return [];

      return await _d1Service.query('''
        SELECT 
          c.id,
          c.caller_id,
          c.callee_id,
          c.call_type,
          c.status,
          c.started_at,
          c.ended_at,
          c.duration,
          CASE
            WHEN c.caller_id = ? THEN u.full_name
            ELSE ?
          END as remote_user_name,
          u.avatar_cid as remote_user_avatar
        FROM calls c
        LEFT JOIN users u ON 
          (c.caller_id = ? AND u.id = c.callee_id) OR
          (c.callee_id = ? AND u.id = c.caller_id)
        WHERE c.caller_id = ? OR c.callee_id = ?
        ORDER BY c.started_at DESC
        LIMIT ?
      ''', [userId, userId, userId, userId, userId, userId, limit]);
    } catch (e) {
      debugPrint('❌ Get call history error: $e');
      return [];
    }
  }

  /// Get missed calls
  Future<List<Map<String, dynamic>>> getMissedCalls(String userId) async {
    try {
      return await _d1Service.query('''
        SELECT 
          c.id,
          c.caller_id,
          c.started_at,
          u.full_name as caller_name,
          u.avatar_cid as caller_avatar
        FROM calls c
        INNER JOIN users u ON c.caller_id = u.id
        WHERE c.callee_id = ? AND c.status = 'missed'
        ORDER BY c.started_at DESC
        LIMIT 10
      ''', [userId]);
    } catch (e) {
      debugPrint('❌ Get missed calls error: $e');
      return [];
    }
  }

  /// Simulate call connected (for demo)
  void _simulateCallConnected() async {
    await Future.delayed(const Duration(seconds: 2));
    _state = CallState.connected;
    _callStartTime = DateTime.now();
    _startDurationTimer();
    debugPrint('✅ Call connected');
  }

  /// Start call duration timer
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration++;
    });
  }

  /// Format duration for display
  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// 📞 Call State Enum
enum CallState {
  idle,
  dialing,
  ringing,
  connected,
  disconnected,
  failed,
  ended,
}

/// 📞 Call Type Enum
enum CallType {
  audio,
  video,
}
