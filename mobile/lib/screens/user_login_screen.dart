import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/admin_access_service.dart';
import '../services/theme_service.dart';
import 'chat_list_screen.dart';
import 'admin_dashboard_screen.dart';

/// 👤 User Login Screen - Обычная регистрация
///
/// - Никнейм + пароль
/// - Локальная аутентификация
/// - Без доступа к системным функциям
class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Введите имя и пароль');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminService = Provider.of<AdminAccessService>(context, listen: false);
    final success = await adminService.userLogin(
      _usernameController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Ошибка входа';
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
            colors: themeService.isGhostMode
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
                const SizedBox(height: 48),

                // Логотип
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors[0].withOpacity(0.3),
                        colors[1].withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors[0].withOpacity(0.6),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 50,
                    color: colors[0],
                  ),
                ),

                const SizedBox(height: 32),

                // Заголовок
                Text(
                  'Вход',
                  style: GoogleFonts.firaCode(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  'Liberty Reach Messenger',
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),

                const SizedBox(height: 48),

                // Поле имени
                _buildInputField(
                  controller: _usernameController,
                  label: 'Никнейм',
                  hint: 'Ваше имя',
                  icon: Icons.person,
                ),

                const SizedBox(height: 24),

                // Поле пароля
                _buildInputField(
                  controller: _passwordController,
                  label: 'Пароль',
                  hint: '••••••••',
                  icon: Icons.lock,
                  obscureText: true,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Кнопка входа
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors[0],
                      foregroundColor: themeService.isGhostMode
                          ? const Color(0xFF0A0A0F)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Войти',
                            style: GoogleFonts.firaCode(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Регистрация
                TextButton(
                  onPressed: () {
                    // TODO: Переход на экран регистрации
                  },
                  child: Text(
                    'Нет аккаунта? Зарегистрироваться',
                    style: GoogleFonts.firaCode(
                      color: Colors.white.withOpacity(0.5),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.firaCode(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: GoogleFonts.firaCode(
              color: Colors.white,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.firaCode(
                color: Colors.white.withOpacity(0.3),
              ),
              prefixIcon: Icon(icon, color: colors[0]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}
