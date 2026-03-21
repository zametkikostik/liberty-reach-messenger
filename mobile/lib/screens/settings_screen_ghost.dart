import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/biometric_service.dart';
import '../services/perf_tracker_service.dart';
import '../widgets/theme_switcher_widget.dart';
import '../widgets/seven_tap_gesture.dart';
import '../widgets/system_cache_sync.dart';

/// ⚙️ Settings Screen (Ghost Protocol)
///
/// МАСКИРОВКА: Обычные настройки приложения
/// СКРЫТЫЙ ВХОД: 7 тапов на версию → System Cache Sync
class SettingsScreenGhost extends StatefulWidget {
  const SettingsScreenGhost({super.key});

  @override
  State<SettingsScreenGhost> createState() => _SettingsScreenGhostState();
}

class _SettingsScreenGhostState extends State<SettingsScreenGhost> {
  BiometricService? _biometricService;
  bool _biometricEnabled = false;
  bool _isLoading = true;
  
  // 🔐 7-tap detector (замаскирован)
  final _gestureDetector = SevenTapGesture();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _biometricService = Provider.of<BiometricService>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    final enabled = await _biometricService!.isBiometricAvailable();
    setState(() {
      _biometricEnabled = enabled;
      _isLoading = false;
    });
  }

  /// 🔐 Обработка 7 тапов (вызывает System Cache Sync)
  void _handleSecretTap() {
    if (_gestureDetector.handleTap()) {
      SystemCacheSync.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.firaCode(fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: themeService.isGhostMode
                ? [const Color(0xFF0A0A0F), const Color(0xFF1A1A2E)]
                : [const Color(0xFF0F0A0F), const Color(0xFF2E1A2E)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('Appearance'),
            const ThemeSwitcherWidget(),
            const SizedBox(height: 24),
            _buildSectionTitle('Security'),
            _buildSecuritySettings(),
            const SizedBox(height: 24),
            _buildSectionTitle('About'),
            _buildAboutCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.firaCode(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildSecuritySettings() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.fingerprint, color: Colors.white.withOpacity(0.7)),
            title: Text('Biometric Auth', style: GoogleFonts.firaCode(color: Colors.white)),
            trailing: Switch(
              value: _biometricEnabled,
              onChanged: _isLoading ? null : (v) {},
              activeColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return GestureDetector(
      // 🔐 7-tap detector на версии
      onTap: _handleSecretTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: Provider.of<ThemeService>(context).gradientColors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.info, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liberty Reach',
                        style: GoogleFonts.firaCode(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 🔐 Версия приложения (7 тапов)
                      Text(
                        'v0.9.5 "Ghost Protocol"',
                        style: GoogleFonts.firaCode(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
