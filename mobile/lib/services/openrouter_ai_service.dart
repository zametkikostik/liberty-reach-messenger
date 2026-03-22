import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'production_logger.dart';

/// 🤖 OpenRouter AI Service
///
/// Интеграция с OpenRouter API для доступа к AI моделям:
/// - Qwen 2.5 72B Instruct
/// - GPT-4, Claude, Llama и др.
///
/// API: https://openrouter.ai/api/v1
/// Docs: https://openrouter.ai/docs
class OpenRouterAIService {
  static OpenRouterAIService? _instance;
  static OpenRouterAIService get instance {
    _instance ??= OpenRouterAIService._();
    return _instance!;
  }

  OpenRouterAIService._();

  // Конфигурация из dart-define
  String get _apiKey => const String.fromEnvironment(
        'OPENROUTER_API_KEY',
        defaultValue: 'NOT_SET',
      );

  String get _baseUrl => const String.fromEnvironment(
        'OPENROUTER_URL',
        defaultValue: 'https://openrouter.ai/api/v1',
      );

  String get _model => const String.fromEnvironment(
        'OPENROUTER_MODEL',
        defaultValue: 'qwen/qwen-2.5-72b-instruct:free',
      );

  int get _timeout => const String.fromEnvironment(
        'AI_TIMEOUT_SECS',
        defaultValue: '30',
      );

  // Кэш ответов
  final Map<String, String> _cache = {};

  /// Проверка: настроен ли API
  bool get isConfigured => _apiKey != 'NOT_SET' && _apiKey.isNotEmpty;

  /// 🧠 Запрос к AI (чат)
  Future<String> chat({
    required String message,
    String? systemPrompt,
    List<Map<String, String>>? conversationHistory,
  }) async {
    if (!isConfigured) {
      '❌ OpenRouter API not configured'.secureError(tag: 'AI');
      return 'AI service not configured. Please set OPENROUTER_API_KEY.';
    }

    try {
      '🤖 AI Request: $message'.secureDebug(tag: 'AI');

      // Формируем messages
      final messages = <Map<String, String>>[];

      // System prompt
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': systemPrompt,
        });
      }

      // Conversation history
      if (conversationHistory != null) {
        messages.addAll(conversationHistory);
      }

      // Текущее сообщение
      messages.add({
        'role': 'user',
        'content': message,
      });

      // Запрос к API
      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
              'HTTP-Referer': 'https://github.com/zametkikostik/liberty-reach-messenger',
              'X-Title': 'Liberty Reach Messenger',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'max_tokens': 2048,
              'temperature': 0.7,
            }),
          )
          .timeout(Duration(seconds: _timeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'] as String;

        '✅ AI Response: $aiResponse'.secureDebug(tag: 'AI');

        // Кэшируем
        _cache[message] = aiResponse;

        return aiResponse;
      } else {
        '❌ AI API Error ${response.statusCode}: ${response.body}'.secureError(tag: 'AI');
        return 'AI error: ${response.statusCode}';
      }
    } catch (e) {
      '❌ AI Exception: $e'.secureError(tag: 'AI');
      return 'AI error: $e';
    }
  }

  /// 🌍 Перевод текста
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final systemPrompt = 'You are a professional translator. Translate the text to $targetLanguage. Keep formatting and special characters.';
    
    final sourceLangHint = sourceLanguage != null ? 'from $sourceLanguage ' : '';
    final message = 'Translate this text $sourceLangHintto $targetLanguage:\n\n$text';

    return await chat(
      message: message,
      systemPrompt: systemPrompt,
    );
  }

  /// 📝 Саммаризация (краткое содержание)
  Future<String> summarize({
    required String text,
    int maxSentences = 3,
  }) async {
    final message = '''
Summarize the following text in exactly $maxSentences sentences. 
Keep only the most important information.

Text to summarize:
$text

Summary:''';

    return await chat(
      message: message,
      systemPrompt: 'You are an expert at summarization. Be concise and accurate.',
    );
  }

  /// 💻 Генерация кода
  Future<String> generateCode({
    required String prompt,
    String language = 'dart',
  }) async {
    final message = '''
Write $language code for:
$prompt

Provide only the code, no explanations.
Include necessary imports and comments.''';

    return await chat(
      message: message,
      systemPrompt: 'You are an expert $language programmer. Write clean, efficient code.',
    );
  }

  /// 🎤 Speech-to-Text (транскрипция)
  /// Примечание: OpenRouter не поддерживает аудио напрямую
  /// Используем внешний сервис или локальный Vosk
  Future<String> transcribeAudio({
    required String audioPath,
  }) async {
    // TODO: Интеграция с Whisper API или локальным Vosk
    '⚠️ Audio transcription not yet implemented'.secureDebug(tag: 'AI');
    return 'Transcription not available. Use local Vosk for offline speech-to-text.';
  }

  /// 🔊 Text-to-Speech
  /// Примечание: OpenRouter не поддерживает TTS
  /// Используем внешний сервис или системный TTS
  Future<void> speakText({
    required String text,
    String language = 'en-US',
  }) async {
    // TODO: Интеграция с системным TTS или внешним API
    '⚠️ TTS not yet implemented'.secureDebug(tag: 'AI');
  }

  /// 🎯 Голосовые команды
  Future<Map<String, dynamic>> processVoiceCommand({
    required String command,
  }) async {
    final message = '''
Analyze this voice command and extract the intent and parameters.
Return JSON in this format:
{
  "intent": "the_action_to_take",
  "parameters": {"key": "value"},
  "confidence": 0.9
}

Voice command: $command

JSON:''';

    final response = await chat(
      message: message,
      systemPrompt: 'You are a voice command parser. Return only valid JSON.',
    );

    try {
      return jsonDecode(response) as Map<String, dynamic>;
    } catch (e) {
      '❌ Failed to parse voice command: $e'.secureError(tag: 'AI');
      return {
        'intent': 'unknown',
        'parameters': {},
        'confidence': 0.0,
      };
    }
  }

  /// Очистка кэша
  void clearCache() {
    _cache.clear();
    '🗑️ AI cache cleared'.secureDebug(tag: 'AI');
  }

  /// Получить из кэша
  String? getCached(String key) {
    return _cache[key];
  }
}
