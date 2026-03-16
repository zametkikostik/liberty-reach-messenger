import 'package:flutter/material.dart';
import 'core/crypto_service.dart';
import 'services/identity_service.dart';

/// InitialScreen — первый экран приложения
/// 
/// Генерирует ключи Ed25519 и регистрирует пользователя на бэкенде
class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final CryptoService _cryptoService = CryptoService();
  final IdentityService _identityService = IdentityService();
  
  bool _isLoading = false;
  String _status = 'Press button to start';
  String _userId = '';
  String _shortUserId = '';
  String _publicKey = '';
  
  @override
  void dispose() {
    _identityService.dispose();
    super.dispose();
  }
  
  /// Обработчик кнопки "Start Love Story"
  Future<void> _startLoveStory() async {
    setState(() {
      _isLoading = true;
      _status = 'Generating Ed25519 keys...';
    });
    
    try {
      // 1. Генерируем пару ключей Ed25519
      final publicKeyBase64 = await _cryptoService.getPublicKeyBase64();
      
      setState(() {
        _publicKey = publicKeyBase64;
        _status = 'Keys generated! Registering on backend...';
      });
      
      // 2. Отправляем публичный ключ на Cloudflare Worker
      final response = await _identityService.registerUser(publicKeyBase64);
      
      if (response['success'] == true) {
        setState(() {
          _userId = response['user_id'] ?? '';
          _shortUserId = response['short_user_id'] ?? '';
          _status = '✅ Registration complete!';
        });
        
        // 3. Показываем успешную регистрацию
        _showSuccessDialog(response);
      } else {
        throw Exception('Backend returned success: false');
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
      
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showSuccessDialog(Map<String, dynamic> response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Welcome to Liberty Reach!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your User ID:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(
              _userId,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Short ID: $_shortUserId',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Public Key (Base64):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(
              _publicKey,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to main app screen
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ Registration Error'),
        content: SelectableText(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liberty Reach'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.favorite_outline,
                size: 100,
                color: Colors.red,
              ),
              const SizedBox(height: 32),
              const Text(
                'A Love Story',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _status.contains('❌') ? Colors.red : Colors.grey,
                ),
              ),
              if (_userId.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text('Your User ID:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SelectableText(
                        _userId,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _startLoveStory,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite),
                label: Text(_isLoading ? 'Processing...' : 'Start Love Story'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
