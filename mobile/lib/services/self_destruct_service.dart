import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/d1_api_service.dart';

/// ⏱️ Self-Destruct Timer Service
///
/// Features:
/// - Set timer for message auto-deletion
/// - Timer options: 1 min, 5 min, 1 hour, 1 day, 1 week
/// - Auto-delete expired messages
/// - Visual countdown indicator
///
/// Use cases:
/// - Sensitive information
/// - Temporary credentials
/// - Private conversations
/// - Compliance requirements
class SelfDestructService {
  static SelfDestructService? _instance;
  static SelfDestructService get instance {
    _instance ??= SelfDestructService._();
    return _instance!;
  }

  SelfDestructService._();

  final D1ApiService _d1Service = D1ApiService();
  final Dio _dio = Dio();
  
  String get _baseUrl => dotenv.env['CLOUDFLARE_WORKER_URL'] ?? 
                        'https://liberty-reach-push.kostik.workers.dev';

  // Timer presets
  static const Map<String, Duration> timerPresets = {
    '1m': Duration(minutes: 1),
    '5m': Duration(minutes: 5),
    '1h': Duration(hours: 1),
    '1d': Duration(days: 1),
    '1w': Duration(days: 7),
  };

  /// Set self-destruct timer for a message
  Future<bool> setTimer({
    required String messageId,
    required String durationKey, // '1m', '5m', '1h', '1d', '1w'
  }) async {
    try {
      final duration = timerPresets[durationKey];
      if (duration == null) {
        debugPrint('❌ Invalid duration key: $durationKey');
        return false;
      }

      final expiresAt = DateTime.now().add(duration).millisecondsSinceEpoch;

      // Update message in D1
      await _d1Service.execute('''
        UPDATE messages 
        SET expires_at = ?
        WHERE id = ?
      ''', [expiresAt, messageId]);

      debugPrint('⏱️ Timer set: $messageId will self-destruct in $durationKey');
      return true;
    } catch (e) {
      debugPrint('❌ Set timer error: $e');
      return false;
    }
  }

  /// Cancel self-destruct timer
  Future<bool> cancelTimer(String messageId) async {
    try {
      await _d1Service.execute('''
        UPDATE messages 
        SET expires_at = NULL
        WHERE id = ?
      ''', [messageId]);

      debugPrint('⏱️ Timer cancelled: $messageId');
      return true;
    } catch (e) {
      debugPrint('❌ Cancel timer error: $e');
      return false;
    }
  }

  /// Get time remaining for message
  Future<Duration?> getTimeRemaining(String messageId) async {
    try {
      final messages = await _d1Service.query('''
        SELECT expires_at FROM messages WHERE id = ?
      ''', [messageId]);

      if (messages.isEmpty || messages.first['expires_at'] == null) {
        return null;
      }

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        messages.first['expires_at'] as int,
      );
      final now = DateTime.now();
      
      if (expiresAt.isBefore(now)) {
        return Duration.zero; // Already expired
      }

      return expiresAt.difference(now);
    } catch (e) {
      debugPrint('❌ Get time remaining error: $e');
      return null;
    }
  }

  /// Delete expired messages (cleanup job)
  Future<int> cleanupExpiredMessages() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final result = await _d1Service.execute('''
        DELETE FROM messages 
        WHERE expires_at IS NOT NULL 
          AND expires_at < ?
          AND is_love_immutable = 0
      ''', [now]);

      debugPrint('🗑️ Cleaned up $result expired messages');
      return result;
    } catch (e) {
      debugPrint('❌ Cleanup error: $e');
      return 0;
    }
  }

  /// Start background cleanup timer
  Timer? _cleanupTimer;
  
  void startBackgroundCleanup({Duration interval = const Duration(minutes: 5)}) {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(interval, (_) {
      cleanupExpiredMessages();
    });
    debugPrint('⏱️ Background cleanup started (every ${interval.inMinutes} min)');
  }

  void stopBackgroundCleanup() {
    _cleanupTimer?.cancel();
    debugPrint('⏱️ Background cleanup stopped');
  }

  /// Format duration for display
  static String formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    }
  }

  /// Get timer preset label
  static String getPresetLabel(String key) {
    switch (key) {
      case '1m': return '1 minute';
      case '5m': return '5 minutes';
      case '1h': return '1 hour';
      case '1d': return '1 day';
      case '1w': return '1 week';
      default: return key;
    }
  }
}

/// ⏱️ Self-Destruct Timer Widget
///
/// Shows countdown timer for message
class SelfDestructTimerWidget extends StatefulWidget {
  final String messageId;
  final VoidCallback? onExpired;

  const SelfDestructTimerWidget({
    super.key,
    required this.messageId,
    this.onExpired,
  });

  @override
  State<SelfDestructTimerWidget> createState() => _SelfDestructTimerWidgetState();
}

class _SelfDestructTimerWidgetState extends State<SelfDestructTimerWidget> {
  final SelfDestructService _service = SelfDestructService.instance;
  
  Duration? _timeRemaining;
  Timer? _timer;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() async {
    // Update every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final remaining = await _service.getTimeRemaining(widget.messageId);
      
      if (remaining == null) {
        setState(() => _timeRemaining = null);
        _timer?.cancel();
      } else if (remaining == Duration.zero) {
        setState(() {
          _timeRemaining = Duration.zero;
          _isExpired = true;
        });
        _timer?.cancel();
        widget.onExpired?.call();
      } else {
        setState(() => _timeRemaining = remaining);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isExpired) {
      return const Text(
        '💥 Self-destructed',
        style: TextStyle(fontSize: 10, color: Colors.red),
      );
    }

    if (_timeRemaining == null) {
      return const SizedBox.shrink();
    }

    final color = _getColorForTime(_timeRemaining!);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          SelfDestructService.formatDuration(_timeRemaining!),
          style: TextStyle(
            fontSize: 10,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getColorForTime(Duration duration) {
    if (duration.inSeconds < 10) {
      return Colors.red;
    } else if (duration.inSeconds < 60) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
}
