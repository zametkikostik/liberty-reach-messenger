import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_call_service.dart';
import '../services/theme_service.dart';

/// 📞 Call Screen — Full Screen Call UI
///
/// Features:
/// - Video preview (PiP)
/// - Remote video stream
/// - Call controls (mute, camera, speaker, end)
/// - Blur background
/// - Ghost/Love adaptive theme
class CallScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isVideoCall;

  const CallScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.isVideoCall = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRtcCallService _callService = WebRtcCallService.instance;

  @override
  void initState() {
    super.initState();
    _startCall();
  }

  Future<void> _startCall() async {
    await _callService.startCall(widget.userId, video: widget.isVideoCall);
  }

  @override
  Widget build(BuildContext context) {
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
          if (widget.isVideoCall && _callService.remoteStream != null)
            Positioned.fill(
              child: RTCVideoView(
                _callService.remoteStream!,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

          // Audio call UI
          if (!widget.isVideoCall)
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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

                  // Call status
                  Consumer<WebRtcCallService>(
                    builder: (context, callService, child) {
                      return Text(
                        _getStatusText(callService.state),
                        style: GoogleFonts.firaCode(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

          // Local video preview (PiP for video calls)
          if (widget.isVideoCall && _callService.localStream != null)
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                width: 120,
                height: 180,
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
                    _callService.localStream!,
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
            child: Consumer<WebRtcCallService>(
              builder: (context, callService, child) {
                return Column(
                  children: [
                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mute button
                        _CallControlButton(
                          icon: callService.isMicOn ? Icons.mic : Icons.mic_off,
                          label: callService.isMicOn ? 'Mute' : 'Unmute',
                          isActive: callService.isMicOn,
                          onTap: () => callService.toggleMic(),
                        ),

                        const SizedBox(width: 20),

                        // Camera button (video calls only)
                        if (widget.isVideoCall)
                          _CallControlButton(
                            icon: callService.isCameraOn
                                ? Icons.videocam
                                : Icons.videocam_off,
                            label: callService.isCameraOn ? 'Camera' : 'Off',
                            isActive: callService.isCameraOn,
                            onTap: () => callService.toggleCamera(),
                          ),

                        if (widget.isVideoCall) const SizedBox(width: 20),

                        // Switch camera (video calls only)
                        if (widget.isVideoCall)
                          _CallControlButton(
                            icon: Icons.cameraswitch,
                            label: 'Switch',
                            isActive: true,
                            onTap: () => callService.switchCamera(),
                          ),

                        if (widget.isVideoCall) const SizedBox(width: 20),

                        // Speaker button
                        _CallControlButton(
                          icon: callService.isSpeakerOn
                              ? Icons.volume_up
                              : Icons.volume_off,
                          label: callService.isSpeakerOn ? 'Speaker' : 'Phone',
                          isActive: callService.isSpeakerOn,
                          onTap: () => callService.toggleSpeaker(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // End call button
                    GestureDetector(
                      onTap: () async {
                        await callService.endCall();
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

                    const SizedBox(height: 16),
                    Text(
                      'End Call',
                      style: GoogleFonts.firaCode(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                );
              },
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
      case CallState.ringing:
        return 'Ringing...';
      case CallState.connected:
        return 'Connected';
      case CallState.disconnected:
        return 'Disconnected';
      case CallState.failed:
        return 'Call failed';
      case CallState.ended:
        return 'Call ended';
      case CallState.idle:
        return 'Idle';
    }
  }
}

/// 🎛️ Call Control Button Widget
class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CallControlButton({
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
            width: 60,
            height: 60,
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
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
