import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/0x_swap_service.dart';
import '../services/web3_service.dart';
import '../services/theme_service.dart';

/// 🔄 Swap Screen — Token Exchange UI
///
/// Features:
/// - Select tokens (sell/buy)
/// - Enter amount
/// - Get real-time quote
/// - Price impact warning
/// - Slippage settings
/// - Execute swap
class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final ZeroXSwapService _swapService = ZeroXSwapService.instance;
  final Web3Service _web3Service = Web3Service.instance;
  
  // Token selection
  Map<String, dynamic>? _sellToken;
  Map<String, dynamic>? _buyToken;
  
  // Amounts
  final _sellAmountController = TextEditingController();
  String _buyAmount = '0';
  
  // Quote
  Map<String, dynamic>? _quote;
  bool _isLoadingQuote = false;
  
  // Settings
  double _slippage = 0.5;
  
  // State
  bool _isSwapping = false;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    final tokens = await _swapService.getSupportedTokens();
    
    // Set defaults: MATIC -> USDC
    setState(() {
      _sellToken = tokens.firstWhere(
        (t) => t['symbol'] == 'MATIC',
        orElse: () => tokens.first,
      );
      _buyToken = tokens.firstWhere(
        (t) => t['symbol'] == 'USDC',
        orElse: () => tokens.length > 1 ? tokens[1] : tokens.first,
      );
    });
    
    _getQuote();
  }

  Future<void> _getQuote() async {
    if (_sellToken == null || _buyToken == null) return;
    if (_sellAmountController.text.isEmpty) return;

    setState(() => _isLoadingQuote = true);

    final quote = await _swapService.getQuote(
      sellToken: _sellToken!['address'],
      buyToken: _buyToken!['address'],
      sellAmount: _sellAmountController.text,
      slippagePercentage: _slippage.toString(),
    );

    if (quote != null && mounted) {
      setState(() {
        _quote = quote;
        _buyAmount = quote['buyAmount'];
      });
    }

    setState(() => _isLoadingQuote = false);
  }

  Future<void> _executeSwap() async {
    if (_quote == null) return;

    setState(() => _isSwapping = true);

    // Get wallet
    final wallet = await _web3Service.getWallet('me');
    if (wallet == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet not found')),
        );
      }
      setState(() => _isSwapping = false);
      return;
    }

    // Execute swap
    final result = await _swapService.executeSwap(
      quote: _quote!,
      walletAddress: wallet['address'],
      privateKey: '', // TODO: Get from secure storage
    );

    if (mounted) {
      setState(() => _isSwapping = false);
      
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Swap executed: ${result['tx_hash']}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reset form
        _sellAmountController.clear();
        setState(() {
          _quote = null;
          _buyAmount = '0';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Swap failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Swap Tokens',
          style: GoogleFonts.firaCode(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSlippageSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sell token card
            _buildTokenCard(
              label: 'Sell',
              token: _sellToken,
              amountController: _sellAmountController,
              onAmountChanged: (_) => _getQuote(),
              onTokenSelected: (token) {
                setState(() => _sellToken = token);
                _getQuote();
              },
            ),

            const SizedBox(height: 16),

            // Swap direction button
            Center(
              child: IconButton(
                icon: const Icon(Icons.swap_vert),
                onPressed: () {
                  setState(() {
                    final temp = _sellToken;
                    _sellToken = _buyToken;
                    _buyToken = temp;
                  });
                  _getQuote();
                },
                style: IconButton.styleFrom(
                  backgroundColor: colors[0],
                  foregroundColor: themeService.isGhostMode
                      ? const Color(0xFF0A0A0F)
                      : Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Buy token card
            _buildTokenCard(
              label: 'Buy',
              token: _buyToken,
              amount: _buyAmount,
              isReadOnly: true,
            ),

            const SizedBox(height: 24),

            // Quote details
            if (_quote != null) ...[
              _buildQuoteDetails(colors),
              const SizedBox(height: 24),
            ],

            // Swap button
            ElevatedButton(
              onPressed: (_quote != null && !_isSwapping)
                  ? _executeSwap
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors[0],
                foregroundColor: themeService.isGhostMode
                    ? const Color(0xFF0A0A0F)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSwapping
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Swap ${_sellToken?['symbol']} → ${_buyToken?['symbol']}',
                      style: GoogleFonts.firaCode(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenCard({
    required String label,
    Map<String, dynamic>? token,
    TextEditingController? amountController,
    String? amount,
    bool isReadOnly = false,
    Function(Map<String, dynamic>)? onTokenSelected,
    Function(String)? onAmountChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            label,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),

          const SizedBox(height: 12),

          // Token selector and amount
          Row(
            children: [
              // Token selector
              Expanded(
                child: InkWell(
                  onTap: onTokenSelected != null
                      ? () => _showTokenSelector(onTokenSelected)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        if (token != null) ...[
                          CircleAvatar(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              token['symbol'][0],
                              style: GoogleFonts.firaCode(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            token?['symbol'] ?? 'Select',
                            style: GoogleFonts.firaCode(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Amount input
              Expanded(
                child: TextField(
                  controller: amountController,
                  readOnly: isReadOnly,
                  style: GoogleFonts.firaCode(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: amount ?? '0.0',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: onAmountChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteDetails(List<Color> colors) {
    if (_quote == null) return const SizedBox.shrink();

    final priceImpact = double.tryParse(_quote['estimatedPriceImpact'] ?? '0') ?? 0;
    final isHighImpact = priceImpact > 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighImpact
            ? Colors.red.withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighImpact ? Colors.red : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quote Details',
            style: GoogleFonts.firaCode(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          _buildQuoteRow('Price', '1 ${_sellToken?['symbol']} = ${_quote!['price']} ${_buyToken?['symbol']}'),
          _buildQuoteRow('Price Impact', '${(priceImpact * 100).toStringAsFixed(2)}%',
              valueColor: isHighImpact ? Colors.red : Colors.green),
          _buildQuoteRow('Slippage', '$_slippage%'),
          _buildQuoteRow('Network Fee', '~\$${_quote!['gasPrice']}'),
        ],
      ),
    );
  }

  Widget _buildQuoteRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showTokenSelector(Function(Map<String, dynamic>) onTokenSelected) async {
    final tokens = await _swapService.getSupportedTokens();
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: BoxDecoration(
          color: themeService.isGhostMode
              ? const Color(0xFF1A1A2E)
              : const Color(0xFF2E1A2E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Text(
                'Select Token',
                style: GoogleFonts.firaCode(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // Token list
            Expanded(
              child: ListView.builder(
                itemCount: tokens.length,
                itemBuilder: (context, index) {
                  final token = tokens[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      child: Text(
                        token['symbol'][0],
                        style: GoogleFonts.firaCode(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      token['symbol'],
                      style: GoogleFonts.firaCode(color: Colors.white),
                    ),
                    subtitle: Text(
                      token['name'],
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    onTap: () {
                      onTokenSelected(token);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSlippageSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Slippage Tolerance', style: GoogleFonts.firaCode()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSlippageOption(0.1),
            _buildSlippageOption(0.5),
            _buildSlippageOption(1.0),
          ],
        ),
      ),
    );
  }

  Widget _buildSlippageOption(double value) {
    final isSelected = _slippage == value;
    return ListTile(
      title: Text('$value%', style: GoogleFonts.firaCode()),
      selected: isSelected,
      onTap: () {
        setState(() => _slippage = value);
        Navigator.pop(context);
        _getQuote();
      },
    );
  }

  @override
  void dispose() {
    _sellAmountController.dispose();
    super.dispose();
  }
}
