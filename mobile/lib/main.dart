import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/theme_service.dart';
import 'services/biometric_service.dart';
import 'services/secure_password_manager.dart';
import 'services/production_logger.dart';
import 'services/perf_tracker_service.dart';
import 'screens/auth_screen.dart';

/// 🚫 NO LOGS POLICY
void main() async {
  'START_DEBUG: ${DateTime.now()}'.secureDebug(tag: 'APP');
  
  WidgetsFlutterBinding.ensureInitialized();

  final themeService = ThemeService();
  await themeService.init();

  final biometricService = BiometricService();
  await biometricService.isBiometricAvailable();

  final passwordManager = SecurePasswordManager.instance;
  final perfTrackerService = PerfTrackerService.instance;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        Provider<BiometricService>.value(value: biometricService),
        ChangeNotifierProvider<SecurePasswordManager>.value(value: passwordManager),
        ChangeNotifierProvider<PerfTrackerService>.value(value: perfTrackerService),
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
  final PerfTrackerService _perfTrackerService = PerfTrackerService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordManager.wipePassword();
    _perfTrackerService.stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        'AppLifecycleState.paused - WIPE PASSWORD'.secureDebug(tag: 'SECURITY');
        _passwordManager.wipePassword();
        _perfTrackerService.onAppPaused();
        break;

      case AppLifecycleState.detached:
        'AppLifecycleState.detached - WIPE PASSWORD'.secureDebug(tag: 'SECURITY');
        _passwordManager.wipePassword();
        _perfTrackerService.stopMonitoring();
        break;

      case AppLifecycleState.resumed:
        'AppLifecycleState.resumed - password cleared'.secureDebug(tag: 'SECURITY');
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
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
          home: const AuthScreen(),
        );
      },
    );
  }
}
