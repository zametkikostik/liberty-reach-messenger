import 'dart:convert';
import 'package:http/http.dart' as http;

/// IdentityService для взаимодействия с Cloudflare Worker
/// 
/// Backend URL: https://a-love-story.kostik.workers.dev
class IdentityService {
  // Cloudflare Worker URL
  static const String _baseUrl = 'https://a-love-story.kostik.workers.dev';
  
  final http.Client _client = http.Client();
  
  /// Зарегистрировать пользователя на бэкенде
  /// 
  /// [publicKeyBase64] - публичный ключ Ed25519 в Base64
  /// Возвращает User ID (SHA-256 хеш)
  Future<Map<String, dynamic>> registerUser(String publicKeyBase64) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'public_key': publicKeyBase64,
          'username_hash': null,
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Registration failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  /// Верифицировать подпись сообщения
  Future<Map<String, dynamic>> verifySignature({
    required String publicKeyBase64,
    required List<int> payload,
    required String signatureBase64,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'public_key': publicKeyBase64,
          'payload': base64Encode(payload),
          'signature': signatureBase64,
        }),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Verification error: $e');
    }
  }
  
  /// Проверка здоровья бэкенда
  Future<bool> healthCheck() async {
    try {
      final response = await _client.get(Uri.parse('$_baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  void dispose() {
    _client.close();
  }
}
