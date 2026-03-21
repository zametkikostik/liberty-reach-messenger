// Liberty Reach - API Service
// Minimal Zero-Trust Implementation
// © 2026 Liberty Reach Project

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'production_logger.dart';

/// Конфигурация приложения
class AppConfig {
  static String get rpcUrl => const String.fromEnvironment(
        'RPC_URL',
        defaultValue: 'https://polygon-rpc.com',
      );

  static String get secretLoveKey => const String.fromEnvironment(
        'SECRET_LOVE_KEY',
        defaultValue: 'liberty_reach_default_salt',
      );

  static bool get isCI => const bool.fromEnvironment('CI', defaultValue: false);

  static void printConfig() {
    if (kDebugMode) {
      '🏰 Liberty Reach Configuration Ready'.secureDebug(tag: 'CONFIG');
    }
  }
}

/// API Service для HTTP запросов
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = kDebugMode ? 'http://10.0.2.2:3000' : 'https://api.libertyreach.com';

  /// Универсальный HTTP запрос
  Future<Map<String, dynamic>> request({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final response = method == 'POST'
        ? await http.post(
            url,
            body: jsonEncode(body),
            headers: {'Content-Type': 'application/json'},
          )
        : await http.get(url);
    return jsonDecode(response.body);
  }

  /// GET запрос
  Future<Map<String, dynamic>> get(String endpoint) async {
    return await request(endpoint: endpoint, method: 'GET');
  }

  /// POST запрос
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    return await request(endpoint: endpoint, method: 'POST', body: body);
  }
}

/// Защищённое хранилище на базе flutter_secure_storage
class SecureStorage {
  final _storage = const FlutterSecureStorage();

  /// Запись значения
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Чтение значения
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Удаление ключа
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Полная очистка (GDPR Zeroize)
  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
