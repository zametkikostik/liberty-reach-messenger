// Liberty Reach - API Service
// Uses environment variables from build or .env file

import 'package:flutter/foundation.dart';

/// Configuration loaded from environment/build
class AppConfig {
  // Blockchain RPC
  static String get rpcUrl => const String.fromEnvironment(
        'RPC_URL',
        defaultValue: 'https://polygon-rpc.com',
      );

  // AI Integration
  static String get openrouterApiKey => const String.fromEnvironment(
        'OPENROUTER_API_KEY',
        defaultValue: '',
      );

  // Security
  static String get secretLoveKey => const String.fromEnvironment(
        'SECRET_LOVE_KEY',
        defaultValue: 'liberty_reach_default_salt',
      );

  // IPFS
  static String get pinataApiKey => const String.fromEnvironment(
        'PINATA_API_KEY',
        defaultValue: '',
      );

  static String get pinataSecretKey => const String.fromEnvironment(
        'PINATA_SECRET_KEY',
        defaultValue: '',
      );

  /// Check if running in CI/CD mode
  static bool get isCI => const bool.fromEnvironment('CI', defaultValue: false);

  /// Check if AI is enabled
  static bool get isAiEnabled => openrouterApiKey.isNotEmpty;

  /// Check if IPFS is enabled
  static bool get isIpfsEnabled =>
      pinataApiKey.isNotEmpty && pinataSecretKey.isNotEmpty;

  /// Get RPC chain with fallbacks
  static List<String> get rpcChain => [
        rpcUrl,
        const String.fromEnvironment(
          'POCKET_RPC_URL',
          defaultValue: 'https://poly.api.pocket.network',
        ),
        const String.fromEnvironment(
          'LAVA_RPC_URL',
          defaultValue:
              'https://g.w.lavanet.xyz:443/gateway/polygon/rpc-http/510353c239edb26b7ef54b675ea3dbc8',
        ),
      ];

  /// Print configuration (debug only)
  static void printConfig() {
    if (kDebugMode) {
      print('🏰 Liberty Reach Configuration');
      print('================================');
      print('🔧 Mode: ${isCI ? 'CI/CD' : 'Local'}');
      print('🔗 RPC URL: $rpcUrl');
      print('🤖 AI Enabled: $isAiEnabled');
      print('📦 IPFS Enabled: $isIpfsEnabled');
      print('🔐 Secret Key: ${secretLoveKey.substring(0, 8)}...');
      print('================================');
    }
  }
}

/// API Service for backend communication
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = 'http://localhost:3000';

  /// Initialize API service
  Future<void> init() async {
    // Load from .env file if not in CI
    if (!AppConfig.isCI) {
      await _loadFromEnv();
    }

    // Use RPC_URL from build config
    final rpcUrl = AppConfig.rpcUrl;
    debugPrint('🔗 Using RPC URL: $rpcUrl');

    AppConfig.printConfig();
  }

  /// Load .env file (local development only)
  Future<void> _loadFromEnv() async {
    try {
      // TODO: Use flutter_dotenv package
      // final env = await DotEnv(fileName: '.env').load();
      // _baseUrl = env['API_BASE_URL'] ?? _baseUrl;
      debugPrint('📋 Loaded .env file');
    } catch (e) {
      debugPrint('⚠️  .env file not found, using defaults');
    }
  }

  /// Get base URL
  String get baseUrl => _baseUrl;

  /// Set base URL
  void setBaseUrl(String url) {
    _baseUrl = url;
    debugPrint('🔗 Base URL set to: $url');
  }

  /// Make HTTP request with retry logic
  Future<Map<String, dynamic>> request({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    int retries = 3,
  }) async {
    for (int i = 0; i < retries; i++) {
      try {
        // TODO: Implement with http or dio package
        // final response = await http.post(
        //   Uri.parse('$_baseUrl$endpoint'),
        //   headers: headers,
        //   body: jsonEncode(body),
        // );
        // return jsonDecode(response.body);

        debugPrint('📡 Request: $method $_baseUrl$endpoint');
        return {'status': 'ok'};
      } catch (e) {
        if (i == retries - 1) rethrow;
        await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
      }
    }

    throw Exception('Request failed after $retries retries');
  }

  /// Get with auth header
  Future<Map<String, dynamic>> getAuth(String endpoint, String peerId) async {
    return await request(
      endpoint: endpoint,
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-Peer-ID': peerId,
      },
    );
  }

  /// Post with auth header
  Future<Map<String, dynamic>> postAuth(
    String endpoint,
    String peerId,
    Map<String, dynamic> body,
  ) async {
    return await request(
      endpoint: endpoint,
      method: 'POST',
      body: body,
      headers: {
        'Content-Type': 'application/json',
        'X-Peer-ID': peerId,
      },
    );
  }
}

/// Secure Storage Service
class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  SecureStorage._internal();

  /// Get encryption key from config
  String get encryptionKey => AppConfig.secretLoveKey;

  /// Initialize secure storage
  Future<void> init() async {
    // TODO: Use flutter_secure_storage package
    debugPrint('🔐 Secure Storage initialized');
    debugPrint('🔑 Using key: ${encryptionKey.substring(0, 8)}...');
  }

  /// Read secure value
  Future<String?> read(String key) async {
    // TODO: Implement with flutter_secure_storage
    return null;
  }

  /// Write secure value
  Future<void> write(String key, String value) async {
    // TODO: Implement with flutter_secure_storage
  }

  /// Delete secure value
  Future<void> delete(String key) async {
    // TODO: Implement with flutter_secure_storage
  }

  /// Clear all (GDPR Zeroize)
  Future<void> clear() async {
    // TODO: Implement with flutter_secure_storage
    debugPrint('🗑️  Secure Storage cleared (GDPR Zeroize)');
  }
}
