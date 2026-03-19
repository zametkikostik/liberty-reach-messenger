import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/storage_service.dart';

/// 🎤 Voice Messages Service
///
/// Features:
/// - Record audio messages
/// - Play back recordings
/// - Upload to IPFS with encryption
/// - Visual audio waveform (future)
///
/// Audio format:
/// - Codec: AAC or OPUS
/// - Sample rate: 44.1kHz
/// - Bit rate: 128kbps
class VoiceMessagesService {
  static VoiceMessagesService? _instance;
  static VoiceMessagesService get instance {
    _instance ??= VoiceMessagesService._();
    return _instance!;
  }

  VoiceMessagesService._();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final StorageService _storageService = StorageService();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentRecordingPath;
  StreamSubscription? _playerSubscription;

  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  /// Start recording voice message
  Future<String?> startRecording() async {
    try {
      // Check permissions
      if (!await _recorder.hasPermission()) {
        debugPrint('❌ Microphone permission denied');
        return null;
      }

      // Get temp directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/voice_$timestamp.m4a';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _currentRecordingPath = path;
      _isRecording = true;

      debugPrint('🎤 Recording started: $path');
      return path;
    } catch (e) {
      debugPrint('❌ Start recording error: $e');
      return null;
    }
  }

  /// Stop recording and return file
  Future<File?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _recorder.stop();
      _isRecording = false;

      debugPrint('✅ Recording stopped: $path');

      if (path != null) {
        return File(path);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Stop recording error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording (delete file)
  Future<void> cancelRecording() async {
    try {
      if (!_isRecording) return;

      await _recorder.stop();
      _isRecording = false;

      // Delete temp file
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
        _currentRecordingPath = null;
      }

      debugPrint('🗑️ Recording cancelled');
    } catch (e) {
      debugPrint('❌ Cancel recording error: $e');
    }
  }

  /// Get recording duration
  Future<Duration> getRecordingDuration() async {
    try {
      return await _recorder.recordDuration();
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Play voice message
  Future<void> playVoiceMessage(String filePath) async {
    try {
      if (_isPlaying) {
        await stopPlaying();
      }

      _playerSubscription = _player.onPlayerComplete.listen((event) {
        _isPlaying = false;
        debugPrint('⏹️ Playback completed');
      });

      await _player.play(DeviceFileSource(filePath));
      _isPlaying = true;

      debugPrint('▶️ Playing: $filePath');
    } catch (e) {
      debugPrint('❌ Play error: $e');
    }
  }

  /// Stop playing
  Future<void> stopPlaying() async {
    try {
      await _player.stop();
      _playerSubscription?.cancel();
      _isPlaying = false;
      debugPrint('⏹️ Playback stopped');
    } catch (e) {
      debugPrint('❌ Stop playing error: $e');
    }
  }

  /// Pause playing
  Future<void> pausePlaying() async {
    try {
      await _player.pause();
      _isPlaying = false;
      debugPrint('⏸️ Playback paused');
    } catch (e) {
      debugPrint('❌ Pause playing error: $e');
    }
  }

  /// Resume playing
  Future<void> resumePlaying() async {
    try {
      await _player.resume();
      _isPlaying = true;
      debugPrint('▶️ Playback resumed');
    } catch (e) {
      debugPrint('❌ Resume playing error: $e');
    }
  }

  /// Upload voice message to IPFS
  Future<Map<String, String>?> uploadVoiceMessage(File file) async {
    try {
      debugPrint('📦 Uploading voice message to IPFS...');

      // Upload with encryption
      final result = await _storageService.uploadEncryptedFile(file);

      debugPrint('✅ Voice message uploaded: ${result['cid']}');

      return result;
    } catch (e) {
      debugPrint('❌ Upload voice message error: $e');
      return null;
    }
  }

  /// Download and play voice message from IPFS
  Future<void> downloadAndPlayVoiceMessage({
    required String cid,
    required String nonce,
  }) async {
    try {
      debugPrint('📥 Downloading voice message from IPFS...');

      // Download and decrypt
      final audioData = await _storageService.downloadAndDecryptFile(
        cid: cid,
        nonce: nonce,
      );

      // Save to temp file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/voice_$timestamp.m4a';
      final file = File(path);
      await file.writeAsBytes(audioData);

      // Play
      await playVoiceMessage(path);

      debugPrint('✅ Voice message downloaded and playing');
    } catch (e) {
      debugPrint('❌ Download and play error: $e');
    }
  }

  /// Clean up old recordings
  Future<void> cleanupOldRecordings({Duration maxAge = const Duration(days: 1)}) async {
    try {
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();
      final now = DateTime.now();

      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.m4a')) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          if (age > maxAge) {
            await entity.delete();
            debugPrint('🗑️ Deleted old recording: ${entity.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Cleanup error: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _playerSubscription?.cancel();
    debugPrint('🎤 Voice messages service disposed');
  }
}

/// 🎤 Voice Message Widget
///
/// Displays voice message with play/pause controls
class VoiceMessageWidget extends StatefulWidget {
  final String cid;
  final String nonce;
  final int duration; // in seconds
  final bool isMe;

  const VoiceMessageWidget({
    super.key,
    required this.cid,
    required this.nonce,
    required this.duration,
    this.isMe = false,
  });

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  final VoiceMessagesService _service = VoiceMessagesService.instance;
  
  bool _isPlaying = false;
  double _progress = 0.0;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Theme.of(context).primaryColor.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isMe
                  ? Theme.of(context).primaryColor
                  : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isPlaying = !_isPlaying;
              });
              // TODO: Implement play logic
            },
          ),

          // Waveform placeholder
          Expanded(
            child: Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: CustomPaint(
                painter: _WaveformPainter(
                  progress: _progress,
                  color: widget.isMe
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                ),
              ),
            ),
          ),

          // Duration
          Text(
            _formatDuration(widget.duration),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// 🎵 Waveform Painter
class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveformPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final playedWidth = size.width * progress;

    // Played portion
    canvas.drawRect(
      Rect.fromLTWH(0, 0, playedWidth, size.height),
      paint,
    );

    // Unplayed portion
    paint.color = color.withOpacity(0.2);
    canvas.drawRect(
      Rect.fromLTWH(playedWidth, 0, size.width - playedWidth, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
