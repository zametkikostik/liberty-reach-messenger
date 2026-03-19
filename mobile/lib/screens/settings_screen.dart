import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/biometric_service.dart';
import '../widgets/theme_switcher_widget.dart';

/// ⚙️ Settings Screen
///
/// App settings including:
/// - Theme switching (Ghost Mode / Love Story)
/// - Biometric authentication toggle
/// - Security settings
/// - About app info
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  BiometricService? _biometricService;

  bool _biometricEnabled = false;
  bool _isLoading = true;

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
    final enabled = await _biometricService!.isBiometricEnabled();
    setState(() {
      _biometricEnabled = enabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleBiometric() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_biometricEnabled) {
        // Disable biometrics
        await _biometricService!.disableBiometrics();
        setState(() {
          _biometricEnabled = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication disabled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Enable biometrics - require authentication first
        final authenticated = await _biometricService!.authenticate(
          reason: 'Enable biometric authentication',
        );

        if (authenticated) {
          await _biometricService!.enableBiometrics();
          setState(() {
            _biometricEnabled = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Biometric authentication enabled ✓'),
                backgroundColor:
                    Provider.of<ThemeService>(context, listen: false)
                        .gradientColors[0],
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication cancelled'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.firaCode(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            _buildSectionTitle('Appearance'),
            const SizedBox(height: 12),
            const ThemeSwitcherWidget(showLabel: false),

            const SizedBox(height: 32),

            // Security Section
            _buildSectionTitle('Security'),
            const SizedBox(height: 12),
            _buildSecurityCard(themeService),

            const SizedBox(height: 32),

            // About Section
            _buildSectionTitle('About'),
            const SizedBox(height: 12),
            _buildAboutCard(),

            const SizedBox(height: 32),

            // Danger Zone
            _buildSectionTitle('Danger Zone', color: Colors.red),
            const SizedBox(height: 12),
            _buildDangerCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Color? color}) {
    return Text(
      title,
      style: GoogleFonts.firaCode(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: color ?? Colors.white.withOpacity(0.7),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSecurityCard(ThemeService themeService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeService.gradientColors[0].withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.fingerprint,
                color: themeService.gradientColors[0],
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biometric Authentication',
                      style: GoogleFonts.firaCode(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _biometricEnabled
                          ? 'Enabled - Use fingerprint/face to unlock'
                          : 'Disabled - Tap to enable',
                      style: GoogleFonts.firaCode(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      themeService.gradientColors[0],
                    ),
                  ),
                )
              else
                Switch(
                  value: _biometricEnabled,
                  onChanged: (_) => _toggleBiometric(),
                  activeColor: themeService.gradientColors[0],
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Security info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeService.isGhostMode
                  ? const Color(0xFF00FF87).withOpacity(0.1)
                  : const Color(0xFFFF0080).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  size: 20,
                  color: themeService.gradientColors[0],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your data is encrypted and stored securely',
                    style: GoogleFonts.firaCode(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
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
                  gradient: LinearGradient(
                    colors: Provider.of<ThemeService>(context).gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 28,
                ),
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
                    Text(
                      'v0.6.0 "Secure & Beautiful"',
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

          const SizedBox(height: 16),

          // Features list
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureChip('E2EE'),
              _buildFeatureChip('Tor'),
              _buildFeatureChip('P2P'),
              _buildFeatureChip('Open Source'),
            ],
          ),

          const SizedBox(height: 16),

          // GitHub link
          TextButton.icon(
            onPressed: () {
              // TODO: Open GitHub repo
            },
            icon: const Icon(Icons.code, size: 18),
            label: const Text('View on GitHub'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: GoogleFonts.firaCode(
          fontSize: 11,
          color: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildDangerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning,
                color: Colors.red,
                size: 28,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panic Wipe',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Delete all secure data immediately',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPanicWipeDialog(),
              icon: const Icon(Icons.delete_forever),
              label: const Text('WIPE ALL DATA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPanicWipeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('🚨 PANIC WIPE'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDeleteItem('All encryption keys'),
            _buildDeleteItem('User credentials'),
            _buildDeleteItem('Cached messages'),
            _buildDeleteItem('Tor configuration'),
            const SizedBox(height: 16),
            const Text(
              'This action CANNOT be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Provider.of<BiometricService>(context, listen: false)
                  .wipeAllSecureData();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data wiped successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('WIPE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
