import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/theme_service.dart';
import 'services/biometric_service.dart';
// import 'services/call_service.dart';  // TODO: Fix flutter_webrtc build
import 'providers/profile_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeService = ThemeService();
  await themeService.init();

  // Предзагрузка биометрического сервиса
  final biometricService = BiometricService();
  await biometricService.isBiometricAvailable();

  // Инициализация профиля
  final profileProvider = ProfileProvider();
  await profileProvider.init();

  // Инициализация Call Service
  // final callService = CallService();  // TODO: Fix flutter_webrtc build

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        Provider<BiometricService>.value(value: biometricService),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        // ChangeNotifierProvider<CallService>.value(value: callService),  // TODO
      ],
      child: const LibertyReachApp(),
    ),
  );
}

class LibertyReachApp extends StatelessWidget {
  const LibertyReachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Liberty Reach',
          debugShowCheckedModeBanner: false,
          theme: themeService.currentThemeData,
          home: const SplashScreen(),
        );
      },
    );
  }
}
