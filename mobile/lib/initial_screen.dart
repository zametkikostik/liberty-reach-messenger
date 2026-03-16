import 'dart:async';
import 'package:flutter/material.dart';
import 'core/crypto_service.dart';
import 'services/identity_service.dart';
import 'services/tor_service.dart';

/// InitialScreen — Liberty Reach Messenger v0.6.0
///
/// First screen of the application:
/// - Generates Ed25519 key pair
/// - Registers user on Cloudflare Worker (JS backend)
/// - Shows Tor connection progress (0-100%)
/// - Displays user ID and short ID
///
/// Backend: JavaScript Worker v0.6.0
/// URL: https://a-love-story-js.zametkikostik.workers.dev
/// Features: Immutable Love Protocol, D1 Storage, E2EE
class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final CryptoService _cryptoService = CryptoService();
  final IdentityService _identityService = IdentityService();

  // State variables
  bool _isLoading = false;
  bool _torEnabled = false;
  String _status = 'Press button to start';
  String _userId = '';
  String _shortUserId = '';
  String _publicKey = '';
  int _torProgress = 0;
  String _torStatus = 'disconnected';

  // Tor subscription
  StreamSubscription<int>? _torSubscription;

  @override
  void initState() {
    super.initState();
    _listenToTorStatus();
  }

  @override
  void dispose() {
    _identityService.dispose();
    _torSubscription?.cancel();
    super.dispose();
  }

  /// Listen to Tor bootstrap progress
  void _listenToTorStatus() {
    _torSubscription = TorService.bootstrapStream.listen((progress) {
      setState(() {
        _torProgress = progress;
        _torStatus = progress >= 100 ? 'connected' : 'connecting';
      });
    });
  }

  /// Toggle Tor on/off
  Future<void> _toggleTor() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_torEnabled) {
        await TorService.stop();
        setState(() {
          _torEnabled = false;
          _torProgress = 0;
          _torStatus = 'disconnected';
        });
      } else {
        await TorService.initialize();
        await TorService.start();
        setState(() {
          _torEnabled = true;
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Tor error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Handle "Start Love Story" button
  Future<void> _startLoveStory() async {
    setState(() {
      _isLoading = true;
      _status = 'Generating Ed25519 keys...';
    });

    try {
      // 1. Generate Ed25519 key pair
      final publicKeyBase64 = await _cryptoService.getPublicKeyBase64();

      setState(() {
        _publicKey = publicKeyBase64;
        _status = 'Keys generated! Registering on backend...';
      });

      // 2. Register on Cloudflare Worker
      final response = await _identityService.registerUser(publicKeyBase64);

      if (response['success'] == true) {
        setState(() {
          _userId = response['user_id'] ?? '';
          _shortUserId = response['short_user_id'] ?? '';
          _status = '✅ Registration complete!';
        });

        // 3. Show success dialog
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

  /// Show success dialog
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
              _publicKey.length > 44 
                ? '${_publicKey.substring(0, 44)}...' 
                : _publicKey,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
            ),
            if (_torEnabled) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tor: $_torStatus ($_torProgress%)',
                      style: TextStyle(color: Colors.green[900]),
                    ),
                  ],
                ),
              ),
            ],
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

  /// Show error dialog
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
        title: const Text('Liberty Reach v0.6.0'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Tor toggle button
          IconButton(
            icon: Icon(
              _torEnabled ? Icons.security : Icons.cloud_off,
              color: _torEnabled ? Colors.green : Colors.grey,
            ),
            onPressed: _isLoading ? null : _toggleTor,
            tooltip: _torEnabled ? 'Tor Active' : 'Enable Tor',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon
              const Icon(
                Icons.favorite_outline,
                size: 100,
                color: Colors.red,
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'A Love Story',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'v0.6.0 "Immortal Love"',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),

              const SizedBox(height: 32),

              // Status text
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _status.contains('❌') ? Colors.red : Colors.grey[700],
                ),
              ),

              // User ID display (if registered)
              if (_userId.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '✅ Registration Successful!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Your User ID:', style: TextStyle(fontSize: 12)),
                      SelectableText(
                        _userId,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Short ID: $_shortUserId',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Tor progress (if enabled)
              if (_torEnabled && _torProgress > 0 && _torProgress < 100) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi_tethering, color: Colors.orange[700]),
                          const SizedBox(width: 12),
                          Text(
                            'Tor Bootstrap Progress',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _torProgress / 100,
                        minHeight: 8,
                        backgroundColor: Colors.orange[100],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[700]!),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_torProgress%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _torProgress < 30
                            ? 'Connecting to Tor network...'
                            : _torProgress < 60
                                ? 'Establishing circuit...'
                                : _torProgress < 90
                                    ? 'Finalizing connection...'
                                    : 'Ready!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Start button
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
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 16),

              // Tor info
              if (!_torEnabled) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _isLoading ? null : _toggleTor,
                  icon: const Icon(Icons.cloud_off, size: 18),
                  label: const Text('Enable Tor for anonymity'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
              ],

              // Battery warning
              if (_torEnabled) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.battery_alert, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tor increases battery usage by ~5-10% per hour',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
