import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/admin_access_service.dart';
import '../services/theme_service.dart';
import 'admin_dashboard_screen.dart';

/// 🔐 Secret Admin Login - Скрытый вход для админа
///
/// Вызывается 5-кратным тапом на версию приложения
class SecretAdminLoginScreen extends StatefulWidget {
  const SecretAdminLoginScreen({super.key});

  @override
  State<SecretAdminLoginScreen> createState() => _SecretAdminLoginScreenState();
}

class _SecretAdminLoginScreenState extends State<SecretAdminLoginScreen> {
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
    final success = await adminService.adminLogin(password);

    if (success && mounted) {
      // Успешный вход админа
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } else {
      _failedAttempts++;

      if (_failedAttempts >= maxFailedAttempts) {
        // 3 ошибки → паника
        setState(() {
          _error = '🚨 3 попытки исчерпаны. Доступ заблокирован.';
        });
        
        // Haptic feedback
        HapticFeedback.vibrate();
        
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _error = '❌ Неверно ($maxFailedAttempts - $_failedAttempts)';
        });
        _passwordController.clear();
      }
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

                // Иконка замка
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.red.withOpacity(0.3),
                        Colors.red.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.6),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 50,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(height: 32),

                // Заголовок
                Text(
                  '🔐 Sovereign Access',
                  style: GoogleFonts.firaCode(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  'Скрытый вход администратора',
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),

                const SizedBox(height: 48),

                // Поле ввода пароля
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
                      prefixIcon: const Icon(Icons.lock, color: Colors.red),
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

                // Кнопка входа
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Войти как Admin',
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

                // Предупреждение
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
                        '⚠️ SECURITY WARNING',
                        style: GoogleFonts.firaCode(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '3 неудачные попытки →\nПолное затирание памяти',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.firaCode(
                          fontSize: 10,
                          color: Colors.red.withOpacity(0.8),
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
