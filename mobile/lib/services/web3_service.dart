import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/d1_api_service.dart';

/// 💰 Web3 Service — Polygon Crypto Wallet
///
/// Features:
/// - Create wallet
/// - Get balance (MATIC, USDC, USDT)
/// - Send tokens
/// - Swap tokens (0x Protocol)
/// - Transaction history
///
/// Network: Polygon (MATIC)
/// RPC: https://polygon-rpc.com
/// Explorer: https://polygonscan.com
class Web3Service {
  static Web3Service? _instance;
  static Web3Service get instance {
    _instance ??= Web3Service._();
    return _instance!;
  }

  Web3Service._();

  final Dio _dio = Dio();
  final _uuid = const Uuid();
  final D1ApiService _d1Service = D1ApiService();

  // Configuration
  String get _rpcUrl => dotenv.env['WEB3_RPC_URL'] ?? 'https://polygon-rpc.com';
  
  // Token addresses on Polygon
  static const String MATIC_TOKEN = '0x0000000000000000000000000000000000001010'; // Native
  static const String USDC_TOKEN = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
  static const String USDT_TOKEN = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';

  /// Create wallet for user
  Future<Map<String, dynamic>?> createWallet(String userId) async {
    try {
      // In production, generate wallet using eth_wallet or similar package
      // For now, simulate wallet creation
      final address = '0x${_uuid.v4().replaceAll('-', '').substring(0, 40)}';
      final now = DateTime.now().millisecondsSinceEpoch;

      // Save to D1
      await _d1Service.execute('''
        INSERT INTO crypto_wallets (id, user_id, address, created_at)
        VALUES (?, ?, ?, ?)
      ''', [_uuid.v4(), userId, address, now]);

      debugPrint('💰 Wallet created: $address');

      return {
        'id': _uuid.v4(),
        'user_id': userId,
        'address': address,
        'created_at': now,
      };
    } catch (e) {
      debugPrint('❌ Create wallet error: $e');
      return null;
    }
  }

  /// Get wallet for user
  Future<Map<String, dynamic>?> getWallet(String userId) async {
    try {
      final wallets = await _d1Service.query(
        'SELECT * FROM crypto_wallets WHERE user_id = ? AND is_active = 1',
        [userId],
      );
      return wallets.isNotEmpty ? wallets.first : null;
    } catch (e) {
      debugPrint('❌ Get wallet error: $e');
      return null;
    }
  }

  /// Get token balance
  Future<String> getBalance({
    required String walletAddress,
    String? tokenAddress,
  }) async {
    try {
      // In production, call RPC endpoint
      // For now, return simulated balance
      return '0.0';
    } catch (e) {
      debugPrint('❌ Get balance error: $e');
      return '0.0';
    }
  }

  /// Get all token balances for wallet
  Future<List<Map<String, dynamic>>> getAllBalances(String walletId) async {
    try {
      final balances = await _d1Service.query(
        'SELECT * FROM token_balances WHERE wallet_id = ?',
        [walletId],
      );
      return balances;
    } catch (e) {
      debugPrint('❌ Get all balances error: $e');
      return [];
    }
  }

  /// Send tokens
  Future<Map<String, dynamic>?> sendTokens({
    required String walletId,
    required String toAddress,
    required String amount,
    required String tokenSymbol,
    String? tokenAddress,
  }) async {
    try {
      // In production, create and sign transaction
      // For now, simulate transaction
      final txHash = '0x${_uuid.v4().replaceAll('-', '')}';
      final now = DateTime.now().millisecondsSinceEpoch;

      // Save transaction to D1
      await _d1Service.execute('''
        INSERT INTO transactions (
          id, wallet_id, tx_hash, type, amount, token_symbol,
          from_address, to_address, status, timestamp
        ) VALUES (?, ?, ?, 'send', ?, ?, ?, ?, 'pending', ?)
      ''', [
        _uuid.v4(),
        walletId,
        txHash,
        amount,
        tokenSymbol,
        '0x...', // from address
        toAddress,
        now,
      ]);

      debugPrint('💸 Tokens sent: $amount $tokenSymbol to $toAddress');

      return {
        'tx_hash': txHash,
        'status': 'pending',
        'amount': amount,
        'token': tokenSymbol,
      };
    } catch (e) {
      debugPrint('❌ Send tokens error: $e');
      return null;
    }
  }

  /// Swap tokens via 0x Protocol
  Future<Map<String, dynamic>?> swapTokens({
    required String walletId,
    required String fromToken,
    required String toToken,
    required String fromAmount,
  }) async {
    try {
      // In production, call 0x API
      // POST https://api.0x.org/swap/v1/quote
      // For now, simulate swap
      final swapId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Save swap to D1
      await _d1Service.execute('''
        INSERT INTO swaps (
          id, wallet_id, from_token, to_token, from_amount,
          to_amount, status, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)
      ''', [
        swapId,
        walletId,
        fromToken,
        toToken,
        fromAmount,
        '0.0', // to_amount (will be updated)
        now,
      ]);

      debugPrint('🔄 Swap initiated: $fromToken -> $toToken');

      return {
        'swap_id': swapId,
        'status': 'pending',
        'from_token': fromToken,
        'to_token': toToken,
        'from_amount': fromAmount,
      };
    } catch (e) {
      debugPrint('❌ Swap tokens error: $e');
      return null;
    }
  }

  /// Get transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory({
    required String walletId,
    int limit = 50,
  }) async {
    try {
      return await _d1Service.query('''
        SELECT * FROM transactions
        WHERE wallet_id = ?
        ORDER BY timestamp DESC
        LIMIT ?
      ''', [walletId, limit]);
    } catch (e) {
      debugPrint('❌ Get transaction history error: $e');
      return [];
    }
  }

  /// Get swap history
  Future<List<Map<String, dynamic>>> getSwapHistory(String walletId) async {
    try {
      return await _d1Service.query('''
        SELECT * FROM swaps
        WHERE wallet_id = ?
        ORDER BY created_at DESC
      ''', [walletId]);
    } catch (e) {
      debugPrint('❌ Get swap history error: $e');
      return [];
    }
  }

  /// Update token balance
  Future<void> updateBalance({
    required String walletId,
    required String tokenAddress,
    required String tokenSymbol,
    required String balance,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _d1Service.execute('''
        INSERT INTO token_balances (
          id, wallet_id, token_address, token_symbol, balance, last_updated
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(wallet_id, token_address) DO UPDATE SET
          balance = ?,
          last_updated = ?
      ''', [
        _uuid.v4(),
        walletId,
        tokenAddress,
        tokenSymbol,
        balance,
        now,
        balance,
        now,
      ]);
    } catch (e) {
      debugPrint('❌ Update balance error: $e');
    }
  }

  /// Get current token prices (from CoinGecko or similar)
  Future<Map<String, double>> getTokenPrices() async {
    try {
      // In production, call CoinGecko API
      // https://api.coingecko.com/api/v3/simple/price
      return {
        'MATIC': 0.85,
        'USDC': 1.00,
        'USDT': 1.00,
      };
    } catch (e) {
      debugPrint('❌ Get token prices error: $e');
      return {};
    }
  }
}
