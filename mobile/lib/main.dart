import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/theme_service.dart';
import 'services/biometric_service.dart';
import 'services/secure_password_manager.dart';
import 'services/production_logger.dart';
// import 'services/call_service.dart';  // TODO: Fix flutter_webrtc build
import 'providers/profile_provider.dart';
import 'screens/master_password_screen.dart';

/// 🚫 NO LOGS POLICY
/// Все print() заменены на ProductionLogger:
/// - В debug: логи работают
/// - В release: полная тишина (никаких следов!)

void main() async {
  'START_DEBUG: ${DateTime.now()}'.secureDebug(tag: 'APP');
  
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация сервисов
  final themeService = ThemeService();
  await themeService.init();

  // Предзагрузка биометрического сервиса
  final biometricService = BiometricService();
  await biometricService.isBiometricAvailable();

  // Инициализация профиля
  final profileProvider = ProfileProvider();
  await profileProvider.init();

  // Инициализация менеджера паролей (RAM-only)
  final passwordManager = SecurePasswordManager.instance;

  // Инициализация Call Service
  // final callService = CallService();  // TODO: Fix flutter_webrtc build

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        Provider<BiometricService>.value(value: biometricService),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        ChangeNotifierProvider<SecurePasswordManager>.value(value: passwordManager),
        // ChangeNotifierProvider<CallService>.value(value: callService),  // TODO
      ],
      child: const LibertyReachApp(),
    ),
  );
}

class LibertyReachApp extends StatefulWidget {
  const LibertyReachApp({super.key});

  @override
  State<LibertyReachApp> createState() => _LibertyReachAppState();
}

class _LibertyReachAppState extends State<LibertyReachApp> with WidgetsBindingObserver {
  final SecurePasswordManager _passwordManager = SecurePasswordManager.instance;

  @override
  void initState() {
    super.initState();
    // Наблюдаем за жизненным циклом приложения для Memory Wipe
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Удаляем наблюдателя
    WidgetsBinding.instance.removeObserver(this);
    // Затиранием пароль при уничтожении
    _passwordManager.wipePassword();
    super.dispose();
  }

  /// 🔥 MEMORY WIPE при изменении состояния приложения
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        // Приложение свёрнуто - затираем пароль!
        'AppLifecycleState.paused - WIPE PASSWORD'.secureDebug(tag: 'SECURITY');
        _passwordManager.wipePassword();
        break;

      case AppLifecycleState.detached:
        // Приложение уничтожается - затираем пароль!
        'AppLifecycleState.detached - WIPE PASSWORD'.secureDebug(tag: 'SECURITY');
        _passwordManager.wipePassword();
        break;

      case AppLifecycleState.resumed:
        // Приложение возвращено - пароль нужно будет ввести заново
        'AppLifecycleState.resumed - password cleared'.secureDebug(tag: 'SECURITY');
        break;

      case AppLifecycleState.inactive:
        // Приложение неактивно (например, во время звонка)
        break;

      case AppLifecycleState.hidden:
        // Приложение скрыто
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Liberty Reach',
          debugShowCheckedModeBanner: false,
          theme: themeService.currentThemeData,
          home: const MasterPasswordScreen(),
        );
      },
    );
  }
}
