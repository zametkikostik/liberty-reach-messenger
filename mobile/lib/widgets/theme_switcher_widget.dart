import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

/// 🎨 Theme Switcher Widget
///
/// A beautiful toggle for switching between Ghost Mode and Love Story.
/// Can be used in settings screen or anywhere in the app.
///
/// Features:
/// - Animated gradient borders
/// - Icon + label for each theme
/// - Haptic feedback on toggle
/// - Glassmorphism container
class ThemeSwitcherWidget extends StatelessWidget {
  final bool showLabel;
  final VoidCallback? onThemeChanged;

  const ThemeSwitcherWidget({
    super.key,
    this.showLabel = true,
    this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Text(
              'Appearance',
              style: GoogleFonts.firaCode(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Ghost Mode
              _ThemeOption(
                icon: Icons.security,
                label: 'Ghost',
                isActive: themeService.isGhostMode,
                colors: const [
                  Color(0xFF00FF87),
                  Color(0xFF00FFD5),
                ],
                onTap: () {
                  themeService.setTheme(ThemeService.ghostMode);
                  onThemeChanged?.call();
                },
              ),

              // Love Story
              _ThemeOption(
                icon: Icons.favorite,
                label: 'Love',
                isActive: themeService.isLoveStory,
                colors: const [
                  Color(0xFFFF0080),
                  Color(0xFFBD00FF),
                ],
                onTap: () {
                  themeService.setTheme(ThemeService.loveStory);
                  onThemeChanged?.call();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                )
              : null,
          color: isActive ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? colors[0] : Colors.white.withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: colors[0].withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.firaCode(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🎭 Quick Theme Toggle Button
///
/// A floating action button that toggles between themes.
/// Shows current theme icon and changes color based on theme.
class QuickThemeToggle extends StatelessWidget {
  const QuickThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return FloatingActionButton.small(
          heroTag: 'themeToggle',
          backgroundColor: themeService.gradientColors[0],
          foregroundColor:
              themeService.isGhostMode ? const Color(0xFF0A0A0F) : Colors.white,
          elevation: 4,
          onPressed: () {
            themeService.toggleTheme();
            // Optional haptic feedback
            Feedback.forTap(context);
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: Icon(
              themeService.themeIcon,
              key: ValueKey(themeService.currentTheme),
              size: 24,
            ),
          ),
        );
      },
    );
  }
}

/// 🎨 Theme Preview Card
///
/// Shows a preview of both themes with live colors.
class ThemePreviewCard extends StatelessWidget {
  const ThemePreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme Preview',
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Ghost Mode Preview
              Expanded(
                child: _PreviewBox(
                  title: 'Ghost',
                  colors: const [
                    Color(0xFF00FF87),
                    Color(0xFF00FFD5),
                    Color(0xFF7BFF00),
                  ],
                  isActive: themeService.isGhostMode,
                ),
              ),
              const SizedBox(width: 12),
              // Love Story Preview
              Expanded(
                child: _PreviewBox(
                  title: 'Love',
                  colors: const [
                    Color(0xFFFF0080),
                    Color(0xFFBD00FF),
                    Color(0xFFFF2E63),
                  ],
                  isActive: themeService.isLoveStory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  final String title;
  final List<Color> colors;
  final bool isActive;

  const _PreviewBox({
    required this.title,
    required this.colors,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.map((c) => c.withOpacity(0.3)).toList(),
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? colors[0] : Colors.white.withOpacity(0.1),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Color dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: colors
                .map(
                  (color) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.firaCode(
              fontSize: 11,
              color: isActive ? colors[0] : Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
