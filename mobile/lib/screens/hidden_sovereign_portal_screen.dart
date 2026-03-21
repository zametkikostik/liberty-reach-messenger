import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/admin_access_service.dart';
import '../services/theme_service.dart';
import 'sovereign_dashboard_screen.dart';

/// 🔐 Hidden Sovereign Portal - Скрытый портал для входа в Sovereign Mode
///
/// Активируется 7-кратным тапом на версию приложения в настройках
/// Мастер-пароль: REDACTED_PASSWORD
/// 3 попытки → PANIC WIPE
class HiddenSovereignPortalScreen extends StatefulWidget {
  const HiddenSovereignPortalScreen({super.key});

  @override
  State<HiddenSovereignPortalScreen> createState() => _HiddenSovereignPortalScreenState();
}

class _HiddenSovereignPortalScreenState extends State<HiddenSovereignPortalScreen> {
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  String _error = '';
  int _failedAttempts = 0;

  static const int maxFailedAttempts = 3;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() => _error = 'Введите пароль');
      return;
    }

    final adminService = Provider.of<AdminAccessService>(context, listen: false);

    try {
      // Проверка с 3-attempt rule
      final isValid = adminService.checkPasswordAttempt(password);

      if (isValid) {
        // Успешная активация Sovereign Mode
        await adminService.activateSovereignMode(password);

        if (mounted) {
          // Переход в Sovereign Dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SovereignDashboardScreen()),
          );
        }
      }
    } on SecurityException catch (e) {
      // PANIC WIPE активирован
      setState(() {
        _error = '🚨 $e';
      });

      // Haptic feedback
      HapticFeedback.heavyImpact();

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = '❌ Ошибка: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F0A0F),
              const Color(0xFF1A0A1A),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),

                // 🔐 Иконка портала
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.purple.withOpacity(0.3),
                        Colors.blue.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.6),
                        blurRadius: 50,
                        spreadRadius: 15,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.door_front_door,
                    size: 60,
                    color: Colors.purple,
                  ),
                ),

                const SizedBox(height: 32),

                // Заголовок
                Text(
                  '🔐 Hidden Sovereign Portal',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.firaCode(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  'Скрытый вход в Sovereign Mode',
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),

                const SizedBox(height: 48),

                // Поле ввода мастер-пароля
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _error.isNotEmpty
                          ? Colors.red.withOpacity(0.5)
                          : colors[0].withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    style: GoogleFonts.firaCode(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Мастер-пароль',
                      hintStyle: GoogleFonts.firaCode(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      prefixIcon: const Icon(Icons.lock, color: Colors.purple),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        onPressed: () {
                          setState(() => _obscureText = !_obscureText);
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onSubmitted: (_) => _submitPassword(),
                    textInputAction: TextInputAction.done,
                  ),
                ),

                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _error.contains('🚨')
                          ? Colors.red.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error,
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        color: _error.contains('🚨')
                            ? Colors.red
                            : Colors.orange,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Кнопка активации
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Активировать Sovereign Mode',
                      style: GoogleFonts.firaCode(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Кнопка отмены
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Отмена',
                    style: GoogleFonts.firaCode(
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // ⚠️ SECURITY WARNING
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.withOpacity(0.8),
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '⚠️ SOVEREIGN SECURITY PROTOCOL',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.firaCode(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Мастер-пароль НИКОГДА не сохраняется\n'
                        '3 неудачные попытки → PANIC WIPE\n'
                        'Сворачивание → FULL MEMORY WIPE',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.firaCode(
                          fontSize: 9,
                          color: Colors.red.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ℹ️ INFO
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.withOpacity(0.8),
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sovereign Mode предоставляет:\n'
                        '• Полный доступ к Memory Wipe\n'
                        '• Логи Rust-ядра (libp2p)\n'
                        '• Управление лимитами сети\n'
                        '• Контроль над нодой',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.firaCode(
                          fontSize: 9,
                          color: Colors.blue.withOpacity(0.8),
                        ),
                      ),
                    ],
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
