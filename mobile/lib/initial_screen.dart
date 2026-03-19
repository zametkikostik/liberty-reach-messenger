import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/crypto_service.dart';
import 'services/identity_service.dart';
import 'services/tor_service.dart';
import 'services/theme_service.dart';
import 'widgets/tor_ritual_widget.dart';

/// InitialScreen с TorRitualWidget
class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with SingleTickerProviderStateMixin {
  final CryptoService _cryptoService = CryptoService();
  final IdentityService _identityService = IdentityService();
  final ThemeService _themeService = ThemeService();

  bool _isLoading = false;
  bool _torEnabled = false;
  String _status = 'Нажми кнопку для начала';
  String _userId = '';
  String _shortUserId = '';
  String _publicKey = '';
  double _torProgress = 0.0;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showChatList = false;

  StreamSubscription<int>? _torSubscription;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _listenToTorStatus();
  }

  @override
  void dispose() {
    _identityService.dispose();
    _torSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
    );
  }

  void _listenToTorStatus() {
    _torSubscription = TorService.bootstrapStream.listen((progress) {
      setState(() {
        _torProgress = progress / 100.0;
      });

      if (progress >= 100 && !_isLoading && _userId.isEmpty) {
        _startLoveStory();
      }
    });
  }

  Future<void> _toggleTor() async {
    setState(() => _isLoading = true);

    try {
      if (_torEnabled) {
        await TorService.stop();
        setState(() {
          _torEnabled = false;
          _torProgress = 0.0;
        });
      } else {
        await TorService.initialize();
        await TorService.start();
        setState(() => _torEnabled = true);
      }
    } catch (e) {
      setState(() => _status = '❌ Tor error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startLoveStory() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _status = 'Генерация ключей...';
    });

    try {
      final publicKeyBase64 = await _cryptoService.getPublicKeyBase64();

      setState(() {
        _publicKey = publicKeyBase64;
        _status = 'Ключи созданы! Регистрация...';
      });

      final response = await _identityService.registerUser(publicKeyBase64);

      if (response['success'] == true) {
        setState(() {
          _userId = response['user_id'] ?? '';
          _shortUserId = response['short_user_id'] ?? '';
          _status = '✅ Готово!';
        });

        _performStaggeredTransition();
      } else {
        throw Exception('Backend returned success: false');
      }
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performStaggeredTransition() async {
    await _fadeController.forward();

    setState(() => _showChatList = true);

    _fadeController.reset();
    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Добро пожаловать!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your User ID:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(_userId, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            Text('Short ID: $_shortUserId',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_torEnabled)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _themeService.gradientColors[0].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _themeService.gradientColors[0].withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security,
                        color: _themeService.gradientColors[0], size: 20),
                    const SizedBox(width: 12),
                    Text('Tor: connected (${(_torProgress * 100).toInt()}%)',
                        style:
                            TextStyle(color: _themeService.gradientColors[0])),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
        title: const Text('❌ Error'),
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
      body: Stack(
        children: [
          // Main content
          FadeTransition(
            opacity: _fadeAnimation,
            child: IgnorePointer(
              ignoring: _showChatList,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _themeService.isGhostMode
                        ? [
                            const Color(0xFF0A0A0F),
                            const Color(0xFF1A1A2E),
                          ]
                        : [
                            const Color(0xFF0F0A0F),
                            const Color(0xFF2E1A2E),
                          ],
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),

                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Liberty Reach',
                              style: GoogleFonts.firaCode(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _themeService.gradientColors[0],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _torEnabled ? Icons.security : Icons.cloud_off,
                                color: _torEnabled
                                    ? _themeService.gradientColors[0]
                                    : Colors.grey,
                              ),
                              onPressed: _isLoading ? null : _toggleTor,
                            ),
                          ],
                        ),

                        const SizedBox(height: 48),

                        // Tor Ritual Widget
                        if (_torEnabled && _torProgress > 0) ...[
                          TorRitualWidget(
                            progress: _torProgress,
                            mode: _themeService.currentTheme,
                            onComplete: () {
                              if (!_isLoading && _userId.isEmpty) {
                                _startLoveStory();
                              }
                            },
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Status
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _themeService.isGhostMode
                                ? const Color(0xFF00FF87).withOpacity(0.1)
                                : const Color(0xFFFF0080).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _themeService.gradientColors[0]
                                  .withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _status,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.firaCode(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Start button
                        if (!_torEnabled || _torProgress < 100)
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _startLoveStory,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.favorite),
                            label: Text(_isLoading
                                ? 'Processing...'
                                : 'Start Love Story'),
                          ),

                        if (!_torEnabled) ...[
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _isLoading ? null : _toggleTor,
                            icon: const Icon(Icons.cloud_off, size: 18),
                            label: const Text('Enable Tor for anonymity'),
                          ),
                        ],

                        // Theme switcher
                        const SizedBox(height: 32),
                        _buildThemeSwitcher(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Chat list placeholder
          if (_showChatList)
            Container(
              color: _themeService.isGhostMode
                  ? const Color(0xFF0A0A0F)
                  : const Color(0xFF0F0A0F),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat, size: 80, color: Colors.white24),
                    const SizedBox(height: 24),
                    Text('Chat List',
                        style: GoogleFonts.firaCode(
                            fontSize: 24, color: Colors.white54)),
                    const SizedBox(height: 8),
                    Text('TODO: Main chat screen',
                        style: GoogleFonts.firaCode(
                            fontSize: 14, color: Colors.white38)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThemeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Appearance',
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildThemeOption(
                icon: Icons.security,
                label: 'Ghost',
                isActive: _themeService.isGhostMode,
                colors: const [Color(0xFF00FF87), Color(0xFF00FFD5)],
                onTap: () => _themeService.setTheme(ThemeService.ghostMode),
              ),
              const SizedBox(width: 32),
              _buildThemeOption(
                icon: Icons.favorite,
                label: 'Love',
                isActive: _themeService.isLoveStory,
                colors: const [Color(0xFFFF0080), Color(0xFFBD00FF)],
                onTap: () => _themeService.setTheme(ThemeService.loveStory),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required bool isActive,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive ? LinearGradient(colors: colors) : null,
          color: isActive ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? colors[0] : Colors.white.withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: isActive ? Colors.white : Colors.white.withOpacity(0.6)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.firaCode(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
