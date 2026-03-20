import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/d1_api_service.dart';

/// 🤖 AI Service — Qwen 3.5 Integration
///
/// Features:
/// - Chat assistant
/// - Text summarization
/// - Code generation
/// - Translation cache
/// - Context-aware responses
/// - Text-to-Speech (Qwen TTS)
/// - Speech-to-Text integration
///
/// Models:
/// - qwen-2.5-coder-32b (default)
/// - qwen-2.5-72b (complex tasks)
/// - qwen-tts (text-to-speech)
/// - llama-3-70b (alternative)
class AIService {
  static AIService? _instance;
  static AIService get instance {
    _instance ??= AIService._();
    return _instance!;
  }

  AIService._();

  final Dio _dio = Dio();
  final _uuid = const Uuid();
  final D1ApiService _d1Service = D1ApiService();
  final FlutterTts _flutterTts = FlutterTts();

  // TTS configuration
  bool _isTtsInitialized = false;
  bool _isSpeaking = false;
  StreamSubscription? _ttsCompletionSubscription;

  // Configuration
  String get _apiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  String get _baseUrl => 'https://openrouter.ai/api/v1';
  String get _defaultModel => dotenv.env['AI_MODEL'] ?? 'qwen-2.5-coder-32b';

  /// Chat with AI assistant
  Future<String?> chat({
    required String message,
    String? systemPrompt,
    String? conversationContext,
  }) async {
    try {
      final messages = <Map<String, String>>[];

      // Add system prompt
      if (systemPrompt != null) {
        messages.add({
          'role': 'system',
          'content': systemPrompt,
        });
      }

      // Add context
      if (conversationContext != null) {
        messages.add({
          'role': 'system',
          'content': 'Context: $conversationContext',
        });
      }

      // Add user message
      messages.add({
        'role': 'user',
        'content': message,
      });

      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://liberty-reach.app',
            'X-Title': 'Liberty Reach Messenger',
          },
        ),
        data: jsonEncode({
          'model': _defaultModel,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final content = data['choices']?[0]?['message']?['content'] as String?;
        
        // Save to history
        if (content != null) {
          await _saveChatHistory(message, content);
        }
        
        return content;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ AI chat error: $e');
      return null;
    }
  }

  /// Summarize chat conversation
  Future<String?> summarizeChat({
    required List<String> messages,
    int maxWords = 100,
  }) async {
    try {
      // Check cache first
      final cacheKey = messages.join('|||');
      final cached = await _getSummaryFromCache(cacheKey);
      if (cached != null) return cached;

      final prompt = '''
Summarize the following chat conversation in $maxWords words or less.
Include key points, decisions, and action items.

Conversation:
${messages.join('\n')}

Summary:
''';

      final summary = await chat(
        message: prompt,
        systemPrompt: 'You are a helpful assistant that summarizes conversations concisely.',
      );

      if (summary != null) {
        // Save to cache
        await _saveSummaryToCache(cacheKey, summary);
      }

      return summary;
    } catch (e) {
      debugPrint('❌ Summarize error: $e');
      return null;
    }
  }

  /// Generate code
  Future<String?> generateCode({
    required String description,
    String language = 'dart',
  }) async {
    try {
      final prompt = '''
Generate $language code for: $description

Provide only the code, no explanations.
''';

      return await chat(
        message: prompt,
        systemPrompt: 'You are an expert $language programmer. Write clean, efficient code.',
      );
    } catch (e) {
      debugPrint('❌ Generate code error: $e');
      return null;
    }
  }

  /// Translate text (with caching)
  Future<String?> translate({
    required String text,
    required String fromLang,
    required String toLang,
  }) async {
    try {
      // Check cache
      final cached = await _getTranslationFromCache(
        text,
        fromLang,
        toLang,
      );
      if (cached != null) return cached;

      final prompt = '''
Translate the following text from $fromLang to $toLang.
Only output the translation, nothing else.

Text: $text

Translation:
''';

      final translation = await chat(message: prompt);

      if (translation != null) {
        // Save to cache
        await _saveTranslationToCache(
          text,
          translation,
          fromLang,
          toLang,
        );
      }

      return translation;
    } catch (e) {
      debugPrint('❌ Translate error: $e');
      return null;
    }
  }

  /// Answer question with context
  Future<String?> answerQuestion({
    required String question,
    required String context,
  }) async {
    try {
      return await chat(
        message: question,
        systemPrompt: '''
You are a helpful assistant. Use the following context to answer the question.
If the answer is not in the context, say "I don't have enough information."

Context:
$context
''',
      );
    } catch (e) {
      debugPrint('❌ Answer question error: $e');
      return null;
    }
  }

  /// Save chat history to D1
  Future<void> _saveChatHistory(String message, String response) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _d1Service.execute('''
        INSERT INTO ai_chat_history (
          id, user_id, message, response, model, created_at
        ) VALUES (?, 'me', ?, ?, ?, ?)
      ''', [_uuid.v4(), message, response, _defaultModel, now]);
    } catch (e) {
      debugPrint('❌ Save chat history error: $e');
    }
  }

  /// Get summary from cache
  Future<String?> _getSummaryFromCache(String key) async {
    try {
      // TODO: Implement summary caching
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save summary to cache
  Future<void> _saveSummaryToCache(String key, String summary) async {
    // TODO: Implement summary caching
  }

  /// Get translation from cache
  Future<String?> _getTranslationFromCache(
    String text,
    String fromLang,
    String toLang,
  ) async {
    try {
      final results = await _d1Service.query('''
        SELECT translated_text FROM ai_translations_cache
        WHERE original_text = ? AND source_lang = ? AND target_lang = ?
      ''', [text, fromLang, toLang]);

      if (results.isNotEmpty) {
        // Update usage count
        await _d1Service.execute('''
          UPDATE ai_translations_cache
          SET usage_count = usage_count + 1
          WHERE original_text = ? AND source_lang = ? AND target_lang = ?
        ''', [text, fromLang, toLang]);

        return results.first['translated_text'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save translation to cache
  Future<void> _saveTranslationToCache(
    String text,
    String translation,
    String fromLang,
    String toLang,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _d1Service.execute('''
        INSERT INTO ai_translations_cache (
          id, original_text, translated_text, source_lang,
          target_lang, created_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(original_text, source_lang, target_lang) DO UPDATE SET
          usage_count = usage_count + 1
      ''', [_uuid.v4(), text, translation, fromLang, toLang, now]);
    } catch (e) {
      debugPrint('❌ Save translation error: $e');
    }
  }

  /// Get chat history
  Future<List<Map<String, dynamic>>> getChatHistory({
    String? userId,
    int limit = 50,
  }) async {
    try {
      return await _d1Service.query('''
        SELECT * FROM ai_chat_history
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT ?
      ''', [userId ?? 'me', limit]);
    } catch (e) {
      debugPrint('❌ Get chat history error: $e');
      return [];
    }
  }

  /// Clear chat history
  Future<void> clearChatHistory(String userId) async {
    try {
      await _d1Service.execute(
        'DELETE FROM ai_chat_history WHERE user_id = ?',
        [userId],
      );
    } catch (e) {
      debugPrint('❌ Clear chat history error: $e');
    }
  }

  // ==================== 🗣️ TEXT-TO-SPEECH ====================

  /// Initialize TTS engine
  Future<void> initTTS() async {
    if (_isTtsInitialized) return;

    try {
      // Set TTS parameters
      await _flutterTts.setLanguage("ru-RU");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Listen for completion
      _flutterTts.setCompletionHandler(() {
        debugPrint('✅ TTS completed');
        _isSpeaking = false;
      });

      _flutterTts.setErrorHandler((error) {
        debugPrint('❌ TTS error: $error');
        _isSpeaking = false;
      });

      _isTtsInitialized = true;
      debugPrint('✅ TTS initialized');
    } catch (e) {
      debugPrint('❌ Init TTS error: $e');
    }
  }

  /// Speak text (Text-to-Speech)
  Future<void> speak(String text, {String? language}) async {
    try {
      await initTTS();

      if (language != null) {
        await _flutterTts.setLanguage(language);
      }

      _isSpeaking = true;
      await _flutterTts.speak(text);
      debugPrint('🔊 Speaking: ${text.substring(0, text.length.clamp(0, 50))}...');
    } catch (e) {
      debugPrint('❌ Speak error: $e');
    }
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      debugPrint('⏹️ TTS stopped');
    } catch (e) {
      debugPrint('❌ Stop speaking error: $e');
    }
  }

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Set TTS language
  Future<void> setTtsLanguage(String languageCode) async {
    try {
      await _flutterTts.setLanguage(languageCode);
      debugPrint('🌐 TTS language set to: $languageCode');
    } catch (e) {
      debugPrint('❌ Set TTS language error: $e');
    }
  }

  /// Set TTS speech rate (0.0 - 1.0)
  Future<void> setTtsSpeechRate(double rate) async {
    try {
      await _flutterTts.setSpeechRate(rate);
      debugPrint('📊 TTS speech rate set to: $rate');
    } catch (e) {
      debugPrint('❌ Set TTS speech rate error: $e');
    }
  }

  /// Set TTS pitch (0.5 - 2.0)
  Future<void> setTtsPitch(double pitch) async {
    try {
      await _flutterTts.setPitch(pitch);
      debugPrint('🎵 TTS pitch set to: $pitch');
    } catch (e) {
      debugPrint('❌ Set TTS pitch error: $e');
    }
  }

  /// Get available TTS languages
  Future<List<String>> getAvailableLanguages() async {
    try {
      return await _flutterTts.getLanguages ?? [];
    } catch (e) {
      debugPrint('❌ Get available languages error: $e');
      return [];
    }
  }

  /// Speak AI response (convenience method)
  Future<String?> speakAIResponse({
    required String message,
    String? systemPrompt,
    bool speakResponse = true,
  }) async {
    try {
      final response = await chat(
        message: message,
        systemPrompt: systemPrompt,
      );

      if (response != null && speakResponse) {
        await speak(response);
      }

      return response;
    } catch (e) {
      debugPrint('❌ Speak AI response error: $e');
      return null;
    }
  }

  /// Read message aloud (for accessibility)
  Future<void> readMessage(String messageText) async {
    await speak(messageText);
  }

  /// Dispose TTS resources
  void dispose() {
    stopSpeaking();
    _ttsCompletionSubscription?.cancel();
  }
}
