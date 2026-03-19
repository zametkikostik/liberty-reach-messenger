import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/video_call_service.dart';
import '../services/theme_service.dart';

/// 📹 Video Call Screen — Full Screen Video Call UI
///
/// Features:
/// - Remote video (full screen)
/// - Local video (PiP)
/// - Call controls (video, audio, camera, end)
/// - Connection quality indicator
/// - Timer
class VideoCallScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isIncoming;

  const VideoCallScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.isIncoming = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final VideoCallService _callService = VideoCallService.instance;
  
  int _callDuration = 0;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    
    if (widget.isIncoming) {
      // Show incoming call UI
      _showIncomingCall();
    } else {
      // Start outgoing call
      _startCall();
    }
  }

  Future<void> _startCall() async {
    final success = await _callService.startCall(widget.userId, video: true);
    
    if (success && mounted) {
      _startDurationTimer();
    }
  }

  void _showIncomingCall() {
    // Show answer/decline UI
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Incoming Video Call', style: GoogleFonts.firaCode()),
        content: Text('From: ${widget.userName}', style: GoogleFonts.firaCode()),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Decline
              await _callService.endCall();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Answer
              // TODO: Implement answer call
              _startDurationTimer();
            },
            child: const Text('Answer'),
          ),
        ],
      ),
    );
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      body: Stack(
        children: [
          // Remote video (full screen)
          Positioned.fill(
            child: _callService.remoteStream != null
                ? RTCVideoView(
                    _callService.remoteStream!,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
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
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: colors),
                            ),
                            child: Center(
                              child: Text(
                                widget.userName.substring(0, 1).toUpperCase(),
                                style: GoogleFonts.firaCode(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.userName,
                            style: GoogleFonts.firaCode(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Consumer<VideoCallService>(
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
                  ),
          ),

          // Local video (PiP)
          if (_callService.localStream != null)
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

          // Top bar (user info + timer)
          Positioned(
            top: 50,
            left: 20,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userName,
                      style: GoogleFonts.firaCode(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _formatDuration(_callDuration),
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Consumer<VideoCallService>(
              builder: (context, callService, child) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Video toggle
                        _CallControlButton(
                          icon: callService.isVideoEnabled
                              ? Icons.videocam
                              : Icons.videocam_off,
                          label: callService.isVideoEnabled ? 'Video' : 'Off',
                          isActive: callService.isVideoEnabled,
                          onTap: () => callService.toggleVideo(),
                        ),

                        const SizedBox(width: 20),

                        // Audio toggle
                        _CallControlButton(
                          icon: callService.isAudioEnabled
                              ? Icons.mic
                              : Icons.mic_off,
                          label: callService.isAudioEnabled ? 'Mute' : 'Unmute',
                          isActive: callService.isAudioEnabled,
                          onTap: () => callService.toggleAudio(),
                        ),

                        const SizedBox(width: 20),

                        // Switch camera
                        _CallControlButton(
                          icon: Icons.cameraswitch,
                          label: 'Switch',
                          isActive: true,
                          onTap: () => callService.switchCamera(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // End call button
                    GestureDetector(
                      onTap: () async {
                        _durationTimer?.cancel();
                        await callService.endCall();
                        if (mounted) Navigator.pop(context);
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
                );
              },
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
      case CallState.ended:
        return 'Call ended';
      case CallState.failed:
        return 'Call failed';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callService.dispose();
    super.dispose();
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
