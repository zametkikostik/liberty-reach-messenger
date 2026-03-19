import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/call_service.dart';
import '../services/theme_service.dart';

/// 📞 Calling Overlay Widget
///
/// Full-screen overlay for active calls with:
/// - Blurred background effect
/// - Remote video stream (for video calls)
/// - Local video preview (PiP)
/// - Call controls (mute, camera, end)
/// - Adaptive Ghost/Love theme
class CallingOverlay extends StatelessWidget {
  const CallingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final callService = Provider.of<CallService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      body: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
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
                ),
              ),
            ),
          ),

          // Remote video (for video calls)
          if (callService.isVideoCall && callService.remoteStream != null)
            Positioned.fill(
              child: RTCVideoView(
                callService.remoteStream!,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

          // Audio call UI
          if (!callService.isVideoCall)
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar/Initials
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: colors),
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: themeService.isGhostMode
                          ? const Color(0xFF0A0A0F)
                          : Colors.white,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Caller name
                  Text(
                    callService.remoteUserId ?? 'Unknown',
                    style: GoogleFonts.firaCode(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Call status
                  Text(
                    _getStatusText(callService.state),
                    style: GoogleFonts.firaCode(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

          // Local video preview (PiP for video calls)
          if (callService.isVideoCall && callService.localStream != null)
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: RTCVideoView(
                    callService.localStream!,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    mirror: true,
                  ),
                ),
              ),
            ),

          // Call controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mute button
                    _ControlButton(
                      icon: callService.isMicOn ? Icons.mic : Icons.mic_off,
                      label: callService.isMicOn ? 'Mute' : 'Unmute',
                      isActive: callService.isMicOn,
                      onTap: () => callService.toggleMic(),
                    ),

                    const SizedBox(width: 24),

                    // Camera button (video calls only)
                    if (callService.isVideoCall)
                      _ControlButton(
                        icon: callService.isCameraOn
                            ? Icons.videocam
                            : Icons.videocam_off,
                        label: callService.isCameraOn ? 'Camera' : 'Off',
                        isActive: callService.isCameraOn,
                        onTap: () => callService.toggleCamera(),
                      ),

                    if (callService.isVideoCall) const SizedBox(width: 24),

                    // Switch camera (video calls only)
                    if (callService.isVideoCall)
                      _ControlButton(
                        icon: Icons.cameraswitch,
                        label: 'Switch',
                        isActive: true,
                        onTap: () => callService.switchCamera(),
                      ),

                    const SizedBox(width: 24),

                    // Speaker button
                    _ControlButton(
                      icon: Icons.volume_up,
                      label: 'Speaker',
                      isActive: true,
                      onTap: () {
                        // TODO: Implement speaker toggle
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // End call button
                GestureDetector(
                  onTap: () => callService.endCall(),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  'End Call',
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Safe area for notched devices
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(CallState state) {
    switch (state) {
      case CallState.dialing:
        return 'Calling...';
      case CallState.waiting:
        return 'Waiting for answer...';
      case CallState.receiving:
        return 'Incoming call...';
      case CallState.connected:
        return 'Connected';
      case CallState.ended:
        return 'Call ended';
      case CallState.failed:
        return 'Call failed';
      case CallState.idle:
        return 'Idle';
    }
  }
}

/// 🎛️ Control Button Widget
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlButton({
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white.withOpacity(0.2)
                  : Colors.red.withOpacity(0.3),
              border: Border.all(
                color: isActive ? Colors.white : Colors.red,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.firaCode(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
