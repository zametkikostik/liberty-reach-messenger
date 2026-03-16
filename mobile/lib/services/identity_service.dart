import 'dart:convert';
import 'package:http/http.dart' as http;

/// IdentityService для взаимодействия с Cloudflare Worker
///
/// Backend URL: https://a-love-story-js.zametkikostik.workers.dev (v0.6.0)
/// Features: Immutable Love Protocol, Encrypted Messages, D1 Storage
class IdentityService {
  // Cloudflare Worker URL - JavaScript Worker with D1
  static const String _baseUrl = 'https://a-love-story-js.zametkikostik.workers.dev';
  
  final http.Client _client = http.Client();
  
  /// Зарегистрировать пользователя на бэкенде
  ///
  /// POST /register
  /// Request: {"public_key": "<Base64-encoded 32 bytes>"}
  /// Response: {"user_id": "...", "short_user_id": "...", "success": true/false}
  Future<Map<String, dynamic>> registerUser(String publicKeyBase64) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'public_key': publicKeyBase64,
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
