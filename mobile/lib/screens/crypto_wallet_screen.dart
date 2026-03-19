import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import '../services/theme_service.dart';
import 'swap_screen.dart';

/// 💰 Crypto Wallet Screen
///
/// Features:
/// - View balance (MATIC, USDC, USDT)
/// - Send tokens
/// - Swap tokens
/// - Transaction history
/// - Wallet address display
class CryptoWalletScreen extends StatefulWidget {
  const CryptoWalletScreen({super.key});

  @override
  State<CryptoWalletScreen> createState() => _CryptoWalletScreenState();
}

class _CryptoWalletScreenState extends State<CryptoWalletScreen> {
  final Web3Service _web3Service = Web3Service.instance;
  
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _balances = [];
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    
    // TODO: Get real user ID
    final userId = 'me';
    
    // Get or create wallet
    var wallet = await _web3Service.getWallet(userId);
    if (wallet == null) {
      wallet = await _web3Service.createWallet(userId);
    }
    
    if (wallet != null) {
      setState(() {
        _wallet = wallet;
        _isLoading = false;
      });
      
      // Load balances and transactions
      // TODO: Implement
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_wallet == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, size: 64, color: Colors.white54),
              const SizedBox(height: 24),
              Text(
                'No wallet found',
                style: GoogleFonts.firaCode(
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors[0],
                ),
                child: const Text('Create Wallet'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Wallet',
          style: GoogleFonts.firaCode(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWallet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet card
            _buildWalletCard(colors),
            
            const SizedBox(height: 24),
            
            // Actions
            _buildActionsRow(),
            
            const SizedBox(height: 24),
            
            // Balances
            Text(
              'Balances',
              style: GoogleFonts.firaCode(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Balance list
            ..._buildBalanceList(),
            
            const SizedBox(height: 24),
            
            // Transactions
            Text(
              'Recent Transactions',
              style: GoogleFonts.firaCode(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Transaction list
            ..._buildTransactionList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: GoogleFonts.firaCode(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$0.00',
            style: GoogleFonts.firaCode(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          // Wallet address
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white54, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _truncateAddress(_wallet!['address']),
                    style: GoogleFonts.firaCode(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
                  onPressed: () {
                    // TODO: Copy to clipboard
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied')),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: Icons.send,
          label: 'Send',
          onTap: () {
            // TODO: Implement send
          },
        ),
        _ActionButton(
          icon: Icons.swap_horiz,
          label: 'Swap',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SwapScreen(),
              ),
            );
          },
        ),
        _ActionButton(
          icon: Icons.download,
          label: 'Receive',
          onTap: () {
            // TODO: Implement receive
          },
        ),
      ],
    );
  }

  List<Widget> _buildBalanceList() {
    if (_balances.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'No tokens yet',
            style: GoogleFonts.firaCode(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ];
    }
    
    return _balances.map((balance) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  balance['token_symbol'][0],
                  style: GoogleFonts.firaCode(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    balance['token_symbol'],
                    style: GoogleFonts.firaCode(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${balance['balance']} ${balance['token_symbol']}',
                    style: GoogleFonts.firaCode(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '\$0.00',
              style: GoogleFonts.firaCode(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildTransactionList() {
    if (_transactions.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'No transactions yet',
            style: GoogleFonts.firaCode(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ];
    }
    
    return _transactions.map((tx) {
      return ListTile(
        leading: Icon(
          tx['type'] == 'send' ? Icons.arrow_upward : Icons.arrow_downward,
          color: tx['type'] == 'send' ? Colors.red : Colors.green,
        ),
        title: Text(
          tx['token_symbol'],
          style: GoogleFonts.firaCode(color: Colors.white),
        ),
        subtitle: Text(
          _truncateAddress(tx['to_address']),
          style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white54),
        ),
        trailing: Text(
          '${tx['type'] == 'send' ? '-' : '+'}${tx['amount']}',
          style: GoogleFonts.firaCode(
            color: tx['type'] == 'send' ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }).toList();
  }

  String _truncateAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}

/// 💰 Action Button Widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
