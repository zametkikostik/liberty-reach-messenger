import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/theme_service.dart';
import 'services/biometric_service.dart';
import 'services/secure_password_manager.dart';
import 'services/production_logger.dart';
import 'services/perf_tracker_service.dart';
import 'services/cloud_config_service.dart';
import 'services/p2p_network_service.dart';
import 'services/real_chat_service.dart';
import 'services/webrtc_call_service.dart';
import 'services/web3_wallet_service.dart';
import 'screens/auth_screen.dart';

/// 🚫 NO LOGS POLICY
void main() async {
  'START_DEBUG: ${DateTime.now()}'.secureDebug(tag: 'APP');

  WidgetsFlutterBinding.ensureInitialized();

  // 🔐 Инициализация мастер-ключей из облака
  final cloudConfig = CloudConfigService.instance;
  await cloudConfig.initialize(
    adminKey: const String.fromEnvironment('ADMIN_MASTER_KEY', defaultValue: 'NOT_SET'),
    salt: const String.fromEnvironment('APP_MASTER_SALT', defaultValue: 'NOT_SET'),
  );

  // 📡 Запуск P2P ноды
  final p2pService = P2PNetworkService.instance;
  final userId = 'user_' + DateTime.now().millisecondsSinceEpoch.toString();
  await p2pService.start(userId: userId);
  
  // 💬 Инициализация Real Chat Service с P2P
  final chatService = RealChatService.instance;
  await chatService.initializeP2P(userId);

  // 📞 WebRTC готов
  final callService = WebRTCCallService.instance;
  
  // 💰 Web3 готов
  final walletService = Web3WalletService.instance;

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
        Provider<CloudConfigService>.value(value: cloudConfig),
        Provider<P2PNetworkService>.value(value: p2pService),
        Provider<RealChatService>.value(value: chatService),
        Provider<WebRTCCallService>.value(value: callService),
        Provider<Web3WalletService>.value(value: walletService),
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
