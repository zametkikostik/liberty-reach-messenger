import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/secure_password_manager.dart';
import '../services/theme_service.dart';
import '../services/zero_knowledge_encryption.dart';
import '../services/secure_storage_service.dart';
import '../initial_screen.dart';

/// 🔐 Master Password Screen - Zero-Persistence Entry Point
///
/// ТАКТИКА "ВСЁ В ГОЛОВЕ":
/// - Запрашивает мастер-пароль при первом входе
/// - Пароль хранится ТОЛЬКО в RAM (SecurePasswordManager)
/// - НИКОГДА не сохраняется на диск
/// - Используется для генерации ключа шифрования
///
/// Мастер-пароль по умолчанию: REDACTED_PASSWORD
/// (Пользователь может изменить при первом входе)
///
/// 🔥 GitHub Autonomous Build:
/// - MASTER_KEY передаётся через --dart-define
/// - По умолчанию: REDACTED_PASSWORD
class MasterPasswordScreen extends StatefulWidget {
  // Мастер-пароль из dart-define или по умолчанию
  static const String defaultMasterKey = 'REDACTED_PASSWORD';
  static String get masterKeyFromBuild => const String.fromEnvironment(
        'MASTER_KEY',
        defaultValue: defaultMasterKey,
      );

  final VoidCallback? onSuccess;

  const MasterPasswordScreen({super.key, this.onSuccess});

  @override
  State<MasterPasswordScreen> createState() => _MasterPasswordScreenState();
}

class _MasterPasswordScreenState extends State<MasterPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _passwordManager = SecurePasswordManager.instance;
  final _encryptionService = ZeroKnowledgeEncryptionService.instance;
  final _secureStorage = SecureStorageService();

  bool _isLoading = false;
  bool _obscureText = true;
  String _statusText = '';
  int _failedAttempts = 0;

  static const int maxFailedAttempts = 3;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: -10, end: 10).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController);
  }

  /// Обработка ввода пароля
  Future<void> _submitPassword() async {
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _statusText = 'Введите пароль';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusText = 'Проверка...';
    });

    try {
      // Получаем userId для соли
      final userId = await _secureStorage.getUserId();

      if (userId == null || userId.isEmpty) {
        // Новый пользователь - просто сохраняем пароль в RAM
        await _passwordManager.setPassword(password);
        await _initializeEncryption(password, userId ?? 'new_user');
        await _success();
      } else {
        // Существующий пользователь - проверяем пароль
        final isValid = await _verifyPassword(password, userId);

        if (isValid) {
          await _passwordManager.setPassword(password);
          await _initializeEncryption(password, userId);
          await _success();
        } else {
          await _handleFailedAttempt();
        }
      }
    } catch (e) {
      setState(() {
        _statusText = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  /// Инициализация шифрования
  Future<void> _initializeEncryption(String password, String userId) async {
    // Генерируем ключ из пароля
    await _encryptionService.deriveKeyFromPassword(password, userId);
  }

  /// Проверка пароля
  Future<bool> _verifyPassword(String password, String userId) async {
    // Получаем сохранённый хеш для проверки
    final storedHash = await _secureStorage.getSetting<String>('password_hash');

    if (storedHash == null) {
      // Нет хеша - принимаем пароль как валидный (первый вход)
      return true;
    }

    // Проверяем пароль
    final isValid = _encryptionService.verifyPassword(password, userId, storedHash);

    if (isValid) {
      return true;
    }

    return false;
  }

  /// Обработка неверного пароля
  Future<void> _handleFailedAttempt() async {
    _failedAttempts++;

    setState(() {
      _statusText = '❌ Неверный пароль ($maxFailedAttempts - $_failedAttempts)';
      _isLoading = false;
    });

    // Анимация тряски
    await _shakeController.forward();
    await _shakeController.reverse();

    if (_failedAttempts >= maxFailedAttempts) {
      // Паническое затирание
      _passwordManager.panicWipe();
      _secureStorage.panicWipe();

      if (mounted) {
        _showPanicDialog();
      }
      return;
    }

    // Очищаем поле
    _passwordController.clear();
  }

  /// Успешный вход
  Future<void> _success() async {
    setState(() {
      _statusText = '✅ Доступ разрешён';
    });

    // Сохраняем хеш пароля для будущей проверки
    final userId = await _secureStorage.getUserId();
    if (userId != null && userId.isNotEmpty) {
      final hash = _encryptionService.hashPassword(
        _passwordController.text,
        userId,
      );
      await _secureStorage.updateSetting('password_hash', hash);
    }

    // Затиранием пароль из поля ввода
    _passwordController.clear();

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      widget.onSuccess?.call();
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

  void _showPanicDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Безопасность'),
        content: const Text(
          'Превышено количество неудачных попыток.\nВсе чувствительные данные удалены.',
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
              mainAxisAlignment: MainAxisAlignment.center,
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
                    Icons.lock_outline,
                    size: 50,
                    color: colors[0],
                  ),
                ),

                const SizedBox(height: 32),

                // Заголовок
                Text(
                  'Master Password',
                  style: GoogleFonts.firaCode(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Введите мастер-пароль для доступа',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),

                const SizedBox(height: 48),

                // Поле ввода пароля
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _statusText.contains('❌')
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
                        prefixIcon: Icon(
                          Icons.lock,
                          color: colors[0],
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      onSubmitted: (_) => _submitPassword(),
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Статус
                if (_statusText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusText.contains('❌')
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusText,
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        color: _statusText.contains('❌')
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ),

                const SizedBox(height: 32),

                // Кнопка входа
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitPassword,
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

                // Подсказка
                Text(
                  '🔐 Пароль хранится только в RAM',
                  style: GoogleFonts.firaCode(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Zero-Persistence Architecture',
                  style: GoogleFonts.firaCode(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.3),
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
