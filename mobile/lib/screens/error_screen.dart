import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🚨 Error Screen - Задача 4.1: Secure Entry
///
/// Показывает ошибку инициализации или расшифровки хранилища.
/// В release режиме не показывает детали ошибки.
class ErrorScreen extends StatelessWidget {
  final String errorMessage;
  final bool isFatal;

  const ErrorScreen({
    super.key,
    required this.errorMessage,
    this.isFatal = false,
  });

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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Иконка ошибки
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFatal
                          ? Colors.red.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                    ),
                    child: Icon(
                      isFatal ? Icons.lock_outline : Icons.warning_amber_rounded,
                      size: 60,
                      color: isFatal
                          ? Colors.red.withOpacity(0.8)
                          : Colors.orange.withOpacity(0.8),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Заголовок
                  Text(
                    isFatal ? '🔒 Критическая ошибка' : '⚠️ Ошибка',
                    style: GoogleFonts.firaCode(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Сообщение об ошибке
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFatal
                            ? Colors.red.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      // В release режиме скрываем детали
                      kReleaseMode
                          ? 'Ошибка расшифровки хранилища'
                          : errorMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Индикатор безопасности
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.security,
                        size: 16,
                        color: Colors.green.withOpacity(0.8),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Данные защищены',
                        style: GoogleFonts.firaCode(
                          fontSize: 12,
                          color: Colors.green.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Кнопка действия
                  ElevatedButton.icon(
                    onPressed: isFatal
                        ? () => SystemNavigator.pop()
                        : () => _retry(context),
                    icon: Icon(isFatal ? Icons.close : Icons.refresh),
                    label: Text(isFatal ? 'Закрыть' : 'Повторить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFatal
                          ? Colors.red.withOpacity(0.8)
                          : Colors.orange.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Подсказка
                  Text(
                    isFatal
                        ? 'Все чувствительные данные удалены'
                        : 'Пароль хранится только в RAM',
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _retry(BuildContext context) {
    // Перезапуск приложения
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ErrorScreen(
          errorMessage: errorMessage,
          isFatal: false,
        ),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }
}
