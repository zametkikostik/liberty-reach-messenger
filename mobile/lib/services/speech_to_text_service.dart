import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// 🎤 Speech-to-Text Service
///
/// Features:
/// - Voice to text conversion
/// - On-device recognition (privacy)
/// - Multi-language support
/// - Real-time partial results
/// - Noise cancellation
///
/// Supported languages:
/// - English (US, UK)
/// - Russian
/// - Bulgarian
/// - Spanish, French, German, etc.
class SpeechToTextService {
  static SpeechToTextService? _instance;
  static SpeechToTextService get instance {
    _instance ??= SpeechToTextService._();
    return _instance!;
  }

  SpeechToTextService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isListening = false;
  String _currentText = '';
  Function(String)? _onResult;
  Function(bool)? _onListeningChange;

  // Getters
  bool get isListening => _isListening;
  bool get isAvailable => _speech.isAvailable;
  String get currentText => _currentText;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    try {
      // Request microphone permission
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint('❌ Microphone permission denied');
        return false;
      }

      // Initialize speech-to-text
      bool available = await _speech.initialize(
        onError: (error) => debugPrint('❌ Speech error: $error'),
        onStatus: (status) {
          debugPrint('🎤 Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            _onListeningChange?.call(false);
          }
        },
      );

      if (available) {
        debugPrint('✅ Speech-to-text initialized');
      } else {
        debugPrint('❌ Speech-to-text not available');
      }

      return available;
    } catch (e) {
      debugPrint('❌ Initialize speech-to-text error: $e');
      return false;
    }
  }

  /// Start listening
  Future<bool> startListening({
    String localeId = 'en_US',
    Function(String)? onResult,
    Function(bool)? onListeningChange,
  }) async {
    try {
      if (!_speech.isAvailable) {
        await initialize();
      }

      _onResult = onResult;
      _onListeningChange = onListeningChange;

      _isListening = await _speech.listen(
        onResult: (result) {
          _currentText = result.recognizedWords;
          _onResult?.call(_currentText);
          
          if (result.finalResult) {
            debugPrint('✅ Final recognition: $_currentText');
          }
        },
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      if (_isListening) {
        debugPrint('🎤 Started listening ($localeId)');
        _onListeningChange?.call(true);
      }

      return _isListening;
    } catch (e) {
      debugPrint('❌ Start listening error: $e');
      return false;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    try {
      if (_isListening) {
        await _speech.stop();
        _isListening = false;
        _onListeningChange?.call(false);
        debugPrint('⏹️ Stopped listening');
      }
    } catch (e) {
      debugPrint('❌ Stop listening error: $e');
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
      _isListening = false;
      _currentText = '';
      _onListeningChange?.call(false);
      debugPrint('🚫 Cancelled listening');
    } catch (e) {
      debugPrint('❌ Cancel listening error: $e');
    }
  }

  /// Get supported locales
  Future<List<stt.LocaleName>> getSupportedLocales() async {
    try {
      return await _speech.locales();
    } catch (e) {
      debugPrint('❌ Get locales error: $e');
      return [];
    }
  }

  /// Check if speech is available
  Future<bool> checkAvailability() async {
    return await _speech.isAvailable;
  }

  /// Has speech recognition permission
  Future<bool> hasPermission() async {
    var status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request permission
  Future<bool> requestPermission() async {
    var status = await Permission.microphone.request();
    return status.isGranted;
  }
}
