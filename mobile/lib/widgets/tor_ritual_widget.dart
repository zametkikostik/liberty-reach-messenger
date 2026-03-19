import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🧅 Tor Ritual Widget - Минималистичная версия
///
/// Onion-shaped progress indicator с пульсирующей анимацией
/// Без внешних зависимостей (только Flutter SDK)
class TorRitualWidget extends StatefulWidget {
  /// Progress от 0.0 до 1.0
  final double progress;

  /// Режим: 'love' (розовый/фиолетовый) или 'ghost' (зелёный)
  final String mode;

  /// Вызывается когда прогресс достигает 100%
  final VoidCallback? onComplete;

  const TorRitualWidget({
    super.key,
    required this.progress,
    this.mode = 'love',
    this.onComplete,
  });

  @override
  State<TorRitualWidget> createState() => _TorRitualWidgetState();
}

class _TorRitualWidgetState extends State<TorRitualWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initPulseAnimation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _initPulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.repeat(reverse: true);
  }

  /// Получить текст статуса по прогрессу
  String _getStatusText(double progress) {
    if (progress < 0.1) return 'Инициализация...';
    if (progress < 0.2) return 'Генерация ключей...';
    if (progress < 0.3) return 'Поиск входного узла...';
    if (progress < 0.4) return 'Поиск среднего узла...';
    if (progress < 0.5) return 'Поиск выходного узла...';
    if (progress < 0.6) return 'Шифруем туннель...';
    if (progress < 0.7) return 'Устанавливаем цепь...';
    if (progress < 0.8) return 'Проверка соединения...';
    if (progress < 0.9) return 'Почти в безопасности...';
    if (progress < 1.0) return 'Финализация...';
    return '✓ В безопасности';
  }

  /// Получить цвета градиента
  List<Color> _getGradientColors() {
    if (widget.mode == 'ghost') {
      return [
        const Color(0xFF00FF87), // Neon green
        const Color(0xFF00FFD5), // Cyan
        const Color(0xFF7BFF00), // Lime
      ];
    } else {
      return [
        const Color(0xFFFF0080), // Hot pink
        const Color(0xFFBD00FF), // Purple
        const Color(0xFFFF2E63), // Rose
      ];
    }
  }

  /// Получить цвет свечения
  Color _getGlowColor() {
    if (widget.mode == 'ghost') {
      return const Color(0xFF00FF87).withOpacity(0.6);
    } else {
      return const Color(0xFFFF0080).withOpacity(0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getGradientColors();

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.mode == 'ghost'
              ? [
                  const Color(0xFF0A1A0F).withOpacity(0.95),
                  const Color(0xFF1A2E1A).withOpacity(0.95),
                ]
              : [
                  const Color(0xFF1A0A1A).withOpacity(0.95),
                  const Color(0xFF2E1A2E).withOpacity(0.95),
                ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Пульсирующее свечение
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _getGlowColor(),
                            blurRadius: 40 * _pulseAnimation.value,
                            spreadRadius: 10 * _pulseAnimation.value,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Лук (onion painter)
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(140, 140),
                      painter: OnionPainter(
                        progress: widget.progress,
                        gradientColors: colors,
                      ),
                    ),

                    // Процент в центре
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(widget.progress * 100).toInt()}%',
                          style: GoogleFonts.firaCode(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: widget.mode == 'ghost'
                                ? const Color(0xFF00FF87)
                                : const Color(0xFFFF0080),
                            shadows: [
                              Shadow(
                                color: _getGlowColor(),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        if (widget.progress < 1.0)
                          Text(
                            'загрузки',
                            style: GoogleFonts.firaCode(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Текст статуса
              Text(
                _getStatusText(widget.progress),
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),

              // Прогресс бар
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 🧅 CustomPainter для лука
class OnionPainter extends CustomPainter {
  final double progress;
  final List<Color> gradientColors;

  OnionPainter({
    required this.progress,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2 * 0.85;

    // Рисуем слои лука
    for (int i = 4; i >= 0; i--) {
      final layerProgress = math.min(1.0, (progress - i * 0.15) * 3);
      if (layerProgress <= 0) continue;

      final layerRadius = baseRadius * (1 - i * 0.12);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            gradientColors[0].withOpacity(layerProgress * 0.8),
            gradientColors[1].withOpacity(layerProgress * 0.6),
            gradientColors[2].withOpacity(layerProgress * 0.4),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: layerRadius))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      // Рисуем слой лука (сплюснутый круг)
      final path = Path();
      final layerHeight = layerRadius * 1.1;

      path.moveTo(center.dx - layerRadius, center.dy);
      path.quadraticBezierTo(
        center.dx - layerRadius * 0.5,
        center.dy - layerHeight,
        center.dx,
        center.dy - layerHeight * 0.9,
      );
      path.quadraticBezierTo(
        center.dx + layerRadius * 0.5,
        center.dy - layerHeight,
        center.dx + layerRadius,
        center.dy,
      );
      path.quadraticBezierTo(
        center.dx + layerRadius * 0.5,
        center.dy + layerHeight,
        center.dx,
        center.dy + layerHeight * 0.9,
      );
      path.quadraticBezierTo(
        center.dx - layerRadius * 0.5,
        center.dy + layerHeight,
        center.dx - layerRadius,
        center.dy,
      );
      path.close();
      canvas.drawPath(path, paint);
    }

    // Стебель сверху при 80%+
    if (progress > 0.8) {
      final stemPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ).createShader(
            Rect.fromLTWH(center.dx - 3, center.dy - baseRadius - 10, 6, 15))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

      final stemPath = Path();
      stemPath.moveTo(center.dx - 3, center.dy - baseRadius + 5);
      stemPath.quadraticBezierTo(
        center.dx - 5,
        center.dy - baseRadius - 5,
        center.dx,
        center.dy - baseRadius - 10,
      );
      stemPath.quadraticBezierTo(
        center.dx + 5,
        center.dy - baseRadius - 5,
        center.dx + 3,
        center.dy - baseRadius + 5,
      );
      stemPath.close();
      canvas.drawPath(stemPath, stemPaint);
    }
  }

  @override
  bool shouldRepaint(OnionPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
