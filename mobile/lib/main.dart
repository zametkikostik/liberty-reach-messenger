import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'services/theme_service.dart';
import 'services/biometric_service.dart';
import 'services/secure_password_manager.dart';
import 'services/production_logger.dart';
import 'screens/error_screen.dart';
// import 'services/call_service.dart';  // TODO: Fix flutter_webrtc build
import 'providers/profile_provider.dart';
import 'screens/master_password_screen.dart';

/// 🚫 NO LOGS POLICY
/// Все print() заменены на ProductionLogger:
/// - В debug: логи работают
/// - В release: полная тишина (никаких следов!)

/// 🔒 Global Error Handler - Задача 4: Error Handling
void _initGlobalErrorHandler() {
  // Перехватываем все ошибки Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    // В debug режиме выводим ошибку
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
    
    // В release режиме - показываем экран с замком
    if (kReleaseMode) {
      '🔒 [ERROR HANDLER] UI Error caught: ${details.exception}'.secureDebug(tag: 'ERROR');
      
      // Запускаем безопасный UI
      runZonedGuarded(() {
        runApp(
          MaterialApp(
            home: Scaffold(
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0F0A0F),
                      const Color(0xFF1A0A1A),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.1),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 60,
                          color: Colors.red.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '🔒 Безопасный режим',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ошибка интерфейса\nПерезапустите приложение',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }, (error, stack) {
        '🔒 [ZONED ERROR] $error'.secureDebug(tag: 'ERROR');
      });
    }
  };
}

void main() async {
  // Инициализация глобального обработчика ошибок (Задача 4)
  _initGlobalErrorHandler();
  
  'START_DEBUG: ${DateTime.now()}'.secureDebug(tag: 'APP');
  
  WidgetsFlutterBinding.ensureInitialized();

  // Secure Entry: try-catch вокруг инициализации (Задача 4.1)
  try {
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
  } catch (e, stack) {
    // Критическая ошибка инициализации
    '❌ [FATAL] Init failed: $e'.secureError(tag: 'APP');
    
    // Запускаем экран ошибки
    runApp(
      MaterialApp(
        home: ErrorScreen(
          errorMessage: 'Ошибка инициализации: ${e.toString()}',
          isFatal: true,
        ),
      ),
    );
  }
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
