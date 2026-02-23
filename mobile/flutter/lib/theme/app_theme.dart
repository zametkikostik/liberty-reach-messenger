import 'package:flutter/material.dart';

/// Liberty Reach App Theme
/// 
/// Modern, clean design with focus on readability and security indicators
class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF1976D2); // Blue - Trust
  static const Color secondaryColor = Color(0xFF00C853); // Green - Security
  static const Color accentColor = Color(0xFFFF6D00); // Orange - Liberty
  static const Color errorColor = Color(0xFFD32F2F); // Red - Warning
  
  // Security Status Colors
  static const Color secureColor = Color(0xFF00C853); // Encrypted
  static const Color warningColor = Color(0xFFFFB300); // Caution
  static const Color insecureColor = Color(0xFFD32F2F); // Not secure
  
  // Light Theme
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // Primary Colors
    primaryColor: primaryColor,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      error: errorColor,
      surface: Color(0xFFFAFAFA),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Color(0xFF212121),
    ),
    
    // AppBar
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF212121),
      iconTheme: IconThemeData(color: Color(0xFF212121)),
      titleTextStyle: TextStyle(
        color: Color(0xFF212121),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    
    // Card
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
    ),
    
    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    ),
    
    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    
    // Navigation Bar
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: Colors.white,
      indicatorColor: primaryColor.withOpacity(0.1),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    
    // Divider
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE0E0E0),
      thickness: 1,
    ),
  );
  
  // Dark Theme
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // Primary Colors
    primaryColor: primaryColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      error: errorColor,
      surface: Color(0xFF121212),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Color(0xFFE0E0E0),
    ),
    
    // AppBar
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    
    // Card
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color(0xFF1E1E1E),
    ),
    
    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    ),
    
    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    
    // Navigation Bar
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: const Color(0xFF1E1E1E),
      indicatorColor: primaryColor.withOpacity(0.1),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    
    // Divider
    dividerTheme: const DividerThemeData(
      color: Color(0xFF424242),
      thickness: 1,
    ),
  );
  
  // Security Badge Styles
  static Widget buildSecureBadge({bool small = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: secureColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secureColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: small ? 12 : 16,
            color: secureColor,
          ),
          if (!small) ...[
            const SizedBox(width: 4),
            Text(
              'E2EE',
              style: TextStyle(
                color: secureColor,
                fontSize: small ? 10 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // PQ Encryption Badge
  static Widget buildPQBadge({bool small = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: small ? 12 : 16,
            color: accentColor,
          ),
          if (!small) ...[
            const SizedBox(width: 4),
            Text(
              'PQ',
              style: TextStyle(
                color: accentColor,
                fontSize: small ? 10 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
