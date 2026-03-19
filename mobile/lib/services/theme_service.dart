import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🎨 Theme Service - Без provider
///
/// Управление темами: Ghost Mode и Love Story
/// Использует ChangeNotifier для реактивности
class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';

  static const String ghostMode = 'ghost';
  static const String loveStory = 'love';

  String _currentTheme = loveStory;

  String get currentTheme => _currentTheme;
  bool get isGhostMode => _currentTheme == ghostMode;
  bool get isLoveStory => _currentTheme == loveStory;

  /// Инициализация темы
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentTheme = prefs.getString(_themeKey) ?? loveStory;
      notifyListeners();
    } catch (e) {
      debugPrint('Theme init error: $e');
    }
  }

  /// Переключить тему
  Future<void> toggleTheme() async {
    _currentTheme = _currentTheme == loveStory ? ghostMode : loveStory;
    await _saveTheme();
    notifyListeners();
  }

  /// Установить тему
  Future<void> setTheme(String theme) async {
    if (theme != ghostMode && theme != loveStory) return;
    _currentTheme = theme;
    await _saveTheme();
    notifyListeners();
  }

  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, _currentTheme);
    } catch (e) {
      debugPrint('Theme save error: $e');
    }
  }

  /// Получить ThemeData для текущей темы
  ThemeData get currentThemeData {
    return _currentTheme == ghostMode ? _ghostTheme : _loveTheme;
  }

  /// Ghost Mode - неоновый зелёный
  ThemeData get _ghostTheme {
    return ThemeData.dark().copyWith(
      primaryColor: const Color(0xFF00FF87),
      scaffoldBackgroundColor: const Color(0xFF0A0A0F),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00FF87),
        secondary: Color(0xFF00FFD5),
        tertiary: Color(0xFF7BFF00),
        surface: Color(0xFF1A1A2E),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A2E),
        foregroundColor: Color(0xFF00FF87),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF1A1A2E).withOpacity(0.8),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF87),
          foregroundColor: const Color(0xFF0A0A0F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Love Story - розовый/фиолетовый
  ThemeData get _loveTheme {
    return ThemeData.dark().copyWith(
      primaryColor: const Color(0xFFFF0080),
      scaffoldBackgroundColor: const Color(0xFF0F0A0F),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF0080),
        secondary: Color(0xFFBD00FF),
        tertiary: Color(0xFFFF2E63),
        surface: Color(0xFF2E1A2E),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2E1A2E),
        foregroundColor: Color(0xFFFF0080),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF2E1A2E).withOpacity(0.8),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF0080),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  List<Color> get gradientColors => _currentTheme == ghostMode
      ? [
          const Color(0xFF00FF87),
          const Color(0xFF00FFD5),
          const Color(0xFF7BFF00),
        ]
      : [
          const Color(0xFFFF0080),
          const Color(0xFFBD00FF),
          const Color(0xFFFF2E63),
        ];

  Color get glowColor => _currentTheme == ghostMode
      ? const Color(0xFF00FF87).withOpacity(0.6)
      : const Color(0xFFFF0080).withOpacity(0.6);

  /// Получить иконку для текущей темы
  IconData get themeIcon => _currentTheme == ghostMode
      ? Icons.security
      : Icons.favorite;
}
