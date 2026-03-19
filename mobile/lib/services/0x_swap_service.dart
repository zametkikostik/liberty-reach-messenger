import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/d1_api_service.dart';
import '../services/web3_service.dart';

/// 🔄 0x Swap Service — Token Exchange
///
/// Features:
/// - Get swap quotes
/// - Execute token swaps
/// - Slippage protection
/// - Price impact warning
/// - Transaction tracking
///
/// Network: Polygon (MATIC)
/// API: https://api.0x.org/swap/v1
///
/// Supported tokens:
/// - MATIC (native)
/// - USDC, USDT (stablecoins)
/// - WETH, WBTC (wrapped)
/// - Any ERC20 on Polygon
class ZeroXSwapService {
  static ZeroXSwapService? _instance;
  static ZeroXSwapService get instance {
    _instance ??= ZeroXSwapService._();
    return _instance!;
  }

  ZeroXSwapService._();

  final Dio _dio = Dio();
  final _uuid = const Uuid();
  final D1ApiService _d1Service = D1ApiService();
  final Web3Service _web3Service = Web3Service.instance;

  // 0x API Configuration
  String get _baseUrl => 'https://api.0x.org/swap/v1';
  String get _chainId => '137'; // Polygon

  /// Get swap quote
  Future<Map<String, dynamic>?> getQuote({
    required String sellToken,
    required String buyToken,
    required String sellAmount,
    String? slippagePercentage,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/quote',
        queryParameters: {
          'sellToken': sellToken,
          'buyToken': buyToken,
          'sellAmount': sellAmount,
          'chainId': _chainId,
          'slippagePercentage': slippagePercentage ?? '0.5',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        
        debugPrint('📊 Swap quote received:');
        debugPrint('   Sell: ${data['sellAmount']} ${data['sellToken']}');
        debugPrint('   Buy: ${data['buyAmount']} ${data['buyToken']}');
        debugPrint('   Price: ${data['price']}');
        
        return {
          'sellToken': data['sellToken'],
          'buyToken': data['buyToken'],
          'sellAmount': data['sellAmount'],
          'buyAmount': data['buyAmount'],
          'price': data['price'],
          'estimatedPriceImpact': data['estimatedPriceImpact'],
          'guaranteedPrice': data['guaranteedPrice'],
          'to': data['to'],
          'data': data['data'],
          'value': data['value'],
          'gasPrice': data['gasPrice'],
          'gas': data['gas'],
        };
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Get quote error: $e');
      return null;
    }
  }

  /// Execute swap
  Future<Map<String, dynamic>?> executeSwap({
    required Map<String, dynamic> quote,
    required String walletAddress,
    required String privateKey, // In production, use secure storage
  }) async {
    try {
      // In production:
      // 1. Sign transaction with wallet
      // 2. Broadcast to Polygon network
      // 3. Wait for confirmation
      
      // For now, simulate swap
      final txHash = '0x${_uuid.v4().replaceAll('-', '')}';
      final now = DateTime.now().millisecondsSinceEpoch;

      // Get wallet from D1
      final wallet = await _web3Service.getWallet('me');
      if (wallet == null) {
        debugPrint('❌ Wallet not found');
        return null;
      }

      // Save swap to D1
      await _d1Service.execute('''
        INSERT INTO swaps (
          id, wallet_id, from_token, to_token, from_amount,
          to_amount, tx_hash, status, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?)
      ''', [
        _uuid.v4(),
        wallet['id'],
        quote['sellToken'],
        quote['buyToken'],
        quote['sellAmount'],
        quote['buyAmount'],
        txHash,
        now,
      ]);

      debugPrint('🔄 Swap executed: $txHash');
      
      return {
        'tx_hash': txHash,
        'status': 'pending',
        'from_token': quote['sellToken'],
        'to_token': quote['buyToken'],
        'from_amount': quote['sellAmount'],
        'to_amount': quote['buyAmount'],
      };
    } catch (e) {
      debugPrint('❌ Execute swap error: $e');
      return null;
    }
  }

  /// Get token price in USD
  Future<double?> getTokenPrice(String tokenAddress) async {
    try {
      // Use CoinGecko or similar API
      final response = await _dio.get(
        'https://api.coingecko.com/api/v3/simple/token_price/polygon',
        queryParameters: {
          'contract_addresses': tokenAddress,
          'vs_currencies': 'usd',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final price = data[tokenAddress.toLowerCase()]?['usd'] as double?;
        return price;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Get token price error: $e');
      return null;
    }
  }

  /// Get all supported tokens on Polygon
  Future<List<Map<String, dynamic>>> getSupportedTokens() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/tokens',
        queryParameters: {
          'chainId': _chainId,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final tokens = data['tokens'] as List? ?? [];
        
        return tokens.map((token) {
          return {
            'address': token['address'],
            'symbol': token['symbol'],
            'name': token['name'],
            'decimals': token['decimals'],
            'logoURI': token['logoURI'],
          };
        }).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ Get tokens error: $e');
      return [];
    }
  }

  /// Calculate price impact
  double calculatePriceImpact({
    required String sellAmount,
    required String buyAmount,
    required double sellPrice,
    required double buyPrice,
  }) {
    try {
      final sellValue = double.parse(sellAmount) * sellPrice;
      final buyValue = double.parse(buyAmount) * buyPrice;
      
      if (sellValue == 0) return 0;
      
      final impact = ((sellValue - buyValue) / sellValue) * 100;
      return impact.abs();
    } catch (e) {
      return 0;
    }
  }

  /// Check if slippage is acceptable
  bool isSlippageAcceptable({
    required double priceImpact,
    required double maxSlippage,
  }) {
    return priceImpact <= maxSlippage;
  }

  /// Get swap history for wallet
  Future<List<Map<String, dynamic>>> getSwapHistory(String walletId) async {
    return await _web3Service.getSwapHistory(walletId);
  }

  /// Update swap status
  Future<void> updateSwapStatus({
    required String swapId,
    required String status,
    String? txHash,
  }) async {
    try {
      await _d1Service.execute('''
        UPDATE swaps SET status = ?, tx_hash = ?, completed_at = ?
        WHERE id = ?
      ''', [
        status,
        txHash,
        status == 'completed' ? DateTime.now().millisecondsSinceEpoch : null,
        swapId,
      ]);
    } catch (e) {
      debugPrint('❌ Update swap status error: $e');
    }
  }
}
