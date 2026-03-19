import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/biometric_service.dart';
import '../initial_screen.dart';

/// 🛡️ Splash Screen с биометрией
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final BiometricService _biometricService = BiometricService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isAuthenticating = false;
  bool _authComplete = false;
  String _statusText = 'Загрузка...';
  int _failedAttempts = 0;

  static const int maxFailedAttempts = 3;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAuthentication();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.repeat(reverse: true);
  }

  /// Запуск аутентификации
  Future<void> _startAuthentication() async {
    setState(() {
      _isAuthenticating = true;
      _statusText = 'Проверка безопасности...';
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    final biometricEnabled = await _biometricService.isBiometricEnabled();
    final biometricAvailable = await _biometricService.isBiometricAvailable();

    if (biometricEnabled && biometricAvailable) {
      setState(() {
        _statusText = 'Приложите палец или посмотрите на экран';
      });

      await Future.delayed(const Duration(milliseconds: 500));
      await _performBiometricAuth();
    } else {
      // Нет биометрии - идём дальше
      await _authenticationSuccess();
    }
  }

  /// Биометрическая аутентификация
  Future<void> _performBiometricAuth() async {
    final authenticated = await _biometricService.authenticate(
      reason: 'Доступ к Liberty Reach',
    );

    if (authenticated) {
      await _authenticationSuccess();
    } else {
      await _authenticationFailed();
    }
  }

  /// Успех
  Future<void> _authenticationSuccess() async {
    setState(() {
      _authComplete = true;
      _statusText = 'Доступ разрешён ✓';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const InitialScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  /// Ошибка
  Future<void> _authenticationFailed() async {
    _failedAttempts++;

    if (_failedAttempts >= maxFailedAttempts) {
      await _biometricService.wipeAllSecureData();
      if (mounted) {
        _showPanicWipeDialog();
      }
      return;
    }

    setState(() {
      _statusText = '❌ Ошибка ($maxFailedAttempts - $_failedAttempts попытки)';
    });

    await Future.delayed(const Duration(seconds: 2));

    if (mounted && !_authComplete) {
      await _startAuthentication();
    }
  }

  void _showPanicWipeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Безопасность'),
        content: const Text(
          'Превышено количество неудачных попыток.\nВсе данные удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F0A0F),
              Color(0xFF1A0A1A),
              Color(0xFF0A0A0F),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Логотип с пульсацией
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFF0080).withOpacity(0.3),
                              const Color(0xFFBD00FF).withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF0080).withOpacity(0.6),
                              blurRadius: 50 * _pulseAnimation.value,
                              spreadRadius: 20 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 60,
                          color: Color(0xFFFF0080),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 48),

                // Название
                Text(
                  'Liberty Reach',
                  style: GoogleFonts.firaCode(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [
                      const Shadow(
                        color: Color(0xFFFF0080),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'v0.6.0 "Secure & Beautiful"',
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),

                const Spacer(),

                // Статус аутентификации
                if (_isAuthenticating && !_authComplete) ...[
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF0080),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _statusText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.firaCode(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 48),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Zero-Trust Network Architecture',
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
