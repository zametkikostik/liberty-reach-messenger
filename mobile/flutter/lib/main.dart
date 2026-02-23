import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize secure storage
  // await SecureStorage.init();
  
  // Initialize local database
  // await Database.init();
  
  runApp(
    const ProviderScope(
      child: LibertyReachApp(),
    ),
  );
}

class LibertyReachApp extends ConsumerWidget {
  const LibertyReachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Liberty Reach',
      debugShowCheckedModeBanner: false,
      
      // Theme
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      
      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('bg'), // Bulgarian (priority)
        Locale('ru'), // Russian
        Locale('de'), // German
        Locale('fr'), // French
        Locale('es'), // Spanish
        Locale('it'), // Italian
        Locale('tr'), // Turkish
        Locale('zh'), // Chinese
        Locale('ar'), // Arabic
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        // Prioritize Bulgarian
        if (locale?.languageCode == 'bg') {
          return const Locale('bg');
        }
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return const Locale('en');
      },
      
      // Routes
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/chat': (context) => const ChatScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
