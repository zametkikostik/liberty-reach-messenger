import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/native_audio_call_service.dart';
import '../services/theme_service.dart';

/// 📞 Audio Call Screen
///
/// Simple audio call interface with:
/// - Caller info
/// - Call duration
/// - Mute/Speaker/End controls
/// - Blur background
class AudioCallScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userAvatar;

  const AudioCallScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar = '',
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  final NativeAudioCallService _callService = NativeAudioCallService.instance;
  
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  @override
  void initState() {
    super.initState();
    _startCall();
  }

  Future<void> _startCall() async {
    await _callService.startCall(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: themeService.isGhostMode
                ? [
                    const Color(0xFF0A0A0F),
                    const Color(0xFF1A1A2E),
                  ]
                : [
                    const Color(0xFF0F0A0F),
                    const Color(0xFF2E1A2E),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              // Caller info
              Column(
                children: [
                  // Avatar
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: colors),
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 15,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.userName.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.firaCode(
                          fontSize: 60,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Name
                  Text(
                    widget.userName,
                    style: GoogleFonts.firaCode(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Call status and duration
                  Consumer<NativeAudioCallService>(
                    builder: (context, callService, child) {
                      return Column(
                        children: [
                          Text(
                            _getStatusText(callService.state),
                            style: GoogleFonts.firaCode(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          if (callService.state == CallState.connected)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                NativeAudioCallService.formatDuration(
                                  callService.callDuration,
                                ),
                                style: GoogleFonts.firaCode(
                                  fontSize: 18,
                                  color: colors[0],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),

              const Spacer(),

              // Call controls
              Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mute button
                        _CallButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          label: _isMuted ? 'Unmute' : 'Mute',
                          isActive: !_isMuted,
                          onTap: () {
                            setState(() => _isMuted = !_isMuted);
                          },
                        ),

                        const SizedBox(width: 32),

                        // Speaker button
                        _CallButton(
                          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                          label: _isSpeakerOn ? 'Speaker' : 'Phone',
                          isActive: _isSpeakerOn,
                          onTap: () {
                            setState(() => _isSpeakerOn = !_isSpeakerOn);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // End call button
                    GestureDetector(
                      onTap: () async {
                        await _callService.endCall();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(CallState state) {
    switch (state) {
      case CallState.dialing:
        return 'Calling...';
      case CallState.ringing:
        return 'Ringing...';
      case CallState.connected:
        return 'Connected';
      case CallState.ended:
        return 'Call ended';
      case CallState.failed:
        return 'Call failed';
      default:
        return '';
    }
  }
}

/// 🎛️ Call Button Widget
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              border: Border.all(
                color: isActive ? Colors.white : Colors.white54,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.white54,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: isActive ? Colors.white : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
