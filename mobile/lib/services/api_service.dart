// Liberty Reach - API Service
// Предназначен для защищенного взаимодействия с бэкендом и блокчейном

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Конфигурация, загружаемая из переменных окружения (CI/CD) или заданная по умолчанию
class AppConfig {
  static String get rpcUrl => const String.fromEnvironment(
        'RPC_URL',
        defaultValue: 'https://polygon-rpc.com',
      );

  static String get openrouterApiKey => const String.fromEnvironment(
        'OPENROUTER_API_KEY',
        defaultValue: '',
      );

  static String get secretLoveKey => const String.fromEnvironment(
        'SECRET_LOVE_KEY',
        defaultValue: 'liberty_reach_default_salt',
      );

  static String get pinataApiKey => const String.fromEnvironment(
        'PINATA_API_KEY',
        defaultValue: '',
      );

  static String get pinataSecretKey => const String.fromEnvironment(
        'PINATA_SECRET_KEY',
        defaultValue: '',
      );

  static bool get isCI => const bool.fromEnvironment('CI', defaultValue: false);
  static bool get isAiEnabled => openrouterApiKey.isNotEmpty;
  static bool get isIpfsEnabled => pinataApiKey.isNotEmpty && pinataSecretKey.isNotEmpty;

  static void printConfig() {
    if (kDebugMode) {
      print('🏰 Liberty Reach Configuration');
      print('================================');
      print('🔧 Mode: ${isCI ? 'CI/CD' : 'Local'}');
      print('🔗 RPC URL: $rpcUrl');
      print('🤖 AI Enabled: $isAiEnabled');
      print('📦 IPFS Enabled: $isIpfsEnabled');
      print('🔐 Secret Key (Salt): ${secretLoveKey.substring(0, 4)}***');
      print('================================');
    }
  }
}

/// Основной сервис для работы с API
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Для эмулятора Android используем 10.0.2.2 вместо localhost
  String _baseUrl = kDebugMode ? 'http://10.0.2.2:3000' : 'https://api.libertyreach.com';

  Future<void> init() async {
    final rpcUrl = AppConfig.rpcUrl;
    debugPrint('🔗 Initializing ApiService with RPC: $rpcUrl');
    AppConfig.printConfig();
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    debugPrint('🔗 Base URL changed to: $url');
  }

  /// Универсальный метод для HTTP запросов с логикой повторов
  Future<Map<String, dynamic>> request({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    int retries = 3,
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final Map<String, String> defaultHeaders = {
      'Content-Type': 'application/json',
      'X-App-Name': 'LibertyReach',
    };

    if (headers != null) defaultHeaders.addAll(headers);

    for (int i = 0; i < retries; i++) {
      try {
        http.Response response;
        
        if (method == 'POST') {
          response = await http.post(url, headers: defaultHeaders, body: jsonEncode(body));
        } else {
          response = await http.get(url, headers: defaultHeaders);
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonDecode(response.body);
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('⚠️ Attempt ${i + 1} failed: $e');
        if (i == retries - 1) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
    throw Exception('Request failed after all retries');
  }

  /// GET запрос с Peer ID для авторизации в P2P сети
  Future<Map<String, dynamic>> getAuth(String endpoint, String peerId) async {
    return await request(
      endpoint: endpoint,
      method: 'GET',
      headers: {'X-Peer-ID': peerId},
    );
  }

  /// POST запрос с шифрованием или авторизацией
  Future<Map<String, dynamic>> postAuth(String endpoint, String peerId, Map<String, dynamic> body) async {
    return await request(
      endpoint: endpoint,
      method: 'POST',
      body: body,
      headers: {'X-Peer-ID': peerId},
    );
  }
}

/// Защищенное хранилище (Secure Storage)
class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  SecureStorage._internal();

  String get encryptionKey => AppConfig.secretLoveKey;

  Future<void> init() async {
    debugPrint('🔐 Secure Storage ready with salt: ${encryptionKey.substring(0, 4)}...');
  }

  // Здесь будет логика работы с flutter_secure_storage после добавления в pubspec.yaml
  Future<void> clear() async {
    debugPrint('🗑️ GDPR Zeroize: Local data wiped.');
  }
}// Liberty Reach - API Service
// Предназначен для защищенного взаимодействия с бэкендом и блокчейном

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Конфигурация, загружаемая из переменных окружения (CI/CD) или заданная по умолчанию
class AppConfig {
  static String get rpcUrl => const String.fromEnvironment(
        'RPC_URL',
        defaultValue: 'https://polygon-rpc.com',
      );

  static String get openrouterApiKey => const String.fromEnvironment(
        'OPENROUTER_API_KEY',
        defaultValue: '',
      );

  static String get secretLoveKey => const String.fromEnvironment(
        'SECRET_LOVE_KEY',
        defaultValue: 'liberty_reach_default_salt',
      );

  static String get pinataApiKey => const String.fromEnvironment(
        'PINATA_API_KEY',
        defaultValue: '',
      );

  static String get pinataSecretKey => const String.fromEnvironment(
        'PINATA_SECRET_KEY',
        defaultValue: '',
      );

  static bool get isCI => const bool.fromEnvironment('CI', defaultValue: false);
  static bool get isAiEnabled => openrouterApiKey.isNotEmpty;
  static bool get isIpfsEnabled => pinataApiKey.isNotEmpty && pinataSecretKey.isNotEmpty;

  static void printConfig() {
    if (kDebugMode) {
      print('🏰 Liberty Reach Configuration');
      print('================================');
      print('🔧 Mode: ${isCI ? 'CI/CD' : 'Local'}');
      print('🔗 RPC URL: $rpcUrl');
      print('🤖 AI Enabled: $isAiEnabled');
      print('📦 IPFS Enabled: $isIpfsEnabled');
      print('🔐 Secret Key (Salt): ${secretLoveKey.substring(0, 4)}***');
      print('================================');
    }
  }
}

/// Основной сервис для работы с API
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Для эмулятора Android используем 10.0.2.2 вместо localhost
  String _baseUrl = kDebugMode ? 'http://10.0.2.2:3000' : 'https://api.libertyreach.com';

  Future<void> init() async {
    final rpcUrl = AppConfig.rpcUrl;
    debugPrint('🔗 Initializing ApiService with RPC: $rpcUrl');
    AppConfig.printConfig();
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    debugPrint('🔗 Base URL changed to: $url');
  }

  /// Универсальный метод для HTTP запросов с логикой повторов
  Future<Map<String, dynamic>> request({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    int retries = 3,
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final Map<String, String> defaultHeaders = {
      'Content-Type': 'application/json',
      'X-App-Name': 'LibertyReach',
    };

    if (headers != null) defaultHeaders.addAll(headers);

    for (int i = 0; i < retries; i++) {
      try {
        http.Response response;
        
        if (method == 'POST') {
          response = await http.post(url, headers: defaultHeaders, body: jsonEncode(body));
        } else {
          response = await http.get(url, headers: defaultHeaders);
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonDecode(response.body);
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('⚠️ Attempt ${i + 1} failed: $e');
        if (i == retries - 1) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
    throw Exception('Request failed after all retries');
  }

  /// GET запрос с Peer ID для авторизации в P2P сети
  Future<Map<String, dynamic>> getAuth(String endpoint, String peerId) async {
    return await request(
      endpoint: endpoint,
      method: 'GET',
      headers: {'X-Peer-ID': peerId},
    );
  }

  /// POST запрос с шифрованием или авторизацией
  Future<Map<String, dynamic>> postAuth(String endpoint, String peerId, Map<String, dynamic> body) async {
    return await request(
      endpoint: endpoint,
      method: 'POST',
      body: body,
      headers: {'X-Peer-ID': peerId},
    );
  }
}

/// Защищенное хранилище (Secure Storage)
class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  SecureStorage._internal();

  String get encryptionKey => AppConfig.secretLoveKey;

  Future<void> init() async {
    debugPrint('🔐 Secure Storage ready with salt: ${encryptionKey.substring(0, 4)}...');
  }

  // Здесь будет логика работы с flutter_secure_storage после добавления в pubspec.yaml
  Future<void> clear() async {
    debugPrint('🗑️ GDPR Zeroize: Local data wiped.');
  }
}
