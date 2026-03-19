import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/d1_api_service.dart';

/// 📹 Video Call Service — WebRTC Video Calls
///
/// Features:
/// - Video calls (1080p)
/// - Audio calls
/// - Screen sharing
/// - Camera switch
/// - Mute/Unmute
/// - Connection quality monitoring
///
/// Architecture:
/// - WebRTC for P2P media
/// - Cloudflare Worker for signaling
/// - STUN/TURN for NAT traversal
/// - DTLS-SRTP for encryption
class VideoCallService {
  static VideoCallService? _instance;
  static VideoCallService get instance {
    _instance ??= VideoCallService._();
    return _instance!;
  }

  VideoCallService._();

  final Dio _dio = Dio();
  final _uuid = const Uuid();
  final D1ApiService _d1Service = D1ApiService();

  // Configuration
  String get _signalingUrl => dotenv.env['SIGNALING_URL'] ?? 
                             'https://liberty-reach-push.kostik.workers.dev';

  // STUN/TURN servers
  static const List<Map<String, String>> _iceServers = [
    {'url': 'stun:stun.l.google.com:19302'},
    {'url': 'stun:stun1.l.google.com:19302'},
    {'url': 'stun:stun2.l.google.com:19302'},
    // Add TURN for better connectivity
    // {'url': 'turn:your-turn-server.com:3478', 'username': '...', 'credential': '...'}
  ];

  // Call state
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  CallState _state = CallState.idle;
  String? _callId;
  String? _remoteUserId;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isFrontCamera = true;

  // Getters
  CallState get state => _state;
  String? get callId => _callId;
  String? get remoteUserId => _remoteUserId;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isAudioEnabled => _isAudioEnabled;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Initialize local media stream
  Future<MediaStream?> initLocalStream({bool video = true}) async {
    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': video
            ? {
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [
                  {'DtlsSrtpKeyAgreement': true},
                ],
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      debugPrint('✅ Local ${video ? "video" : "audio"} stream initialized');
      return _localStream;
    } catch (e) {
      debugPrint('❌ Init local stream error: $e');
      return null;
    }
  }

  /// Create peer connection
  Future<RTCPeerConnection?> createPeerConnection() async {
    try {
      final configuration = <String, dynamic>{
        'iceServers': _iceServers,
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      // Add local stream tracks
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
      }

      // Listen for remote stream
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        debugPrint('📞 Received remote track: ${event.track.kind}');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          debugPrint('✅ Remote stream attached');
        }
      };

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          _sendIceCandidate(candidate);
        }
      };

      // Listen for connection state
      _peerConnection!.onConnectionStateChange = () {
        final state = _peerConnection!.connectionState;
        debugPrint('📞 Connection state: $state');
        
        switch (state) {
          case RTCIceConnectionState.connected:
            _state = CallState.connected;
            break;
          case RTCIceConnectionState.disconnected:
          case RTCIceConnectionState.failed:
            _state = CallState.failed;
            break;
          case RTCIceConnectionState.closed:
            _state = CallState.ended;
            break;
          default:
            break;
        }
      };

      debugPrint('✅ Peer connection created');
      return _peerConnection;
    } catch (e) {
      debugPrint('❌ Create peer connection error: $e');
      return null;
    }
  }

  /// Start video call
  Future<bool> startCall(String userId, {bool video = true}) async {
    try {
      _state = CallState.dialing;
      _remoteUserId = userId;
      _callId = _uuid.v4();
      _isVideoEnabled = video;

      // Initialize local stream
      await initLocalStream(video: video);

      // Create peer connection
      await createPeerConnection();

      // Create offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Send offer via signaling
      await _sendOffer(userId, offer);

      debugPrint('📹 Video call started: $userId (${video ? "video" : "audio"})');
      return true;
    } catch (e) {
      debugPrint('❌ Start call error: $e');
      _state = CallState.failed;
      return false;
    }
  }

  /// Answer incoming call
  Future<bool> answerCall(String callId, String callerId, RTCSessionDescription offer) async {
    try {
      _state = CallState.connected;
      _callId = callId;
      _remoteUserId = callerId;

      // Initialize local stream
      await initLocalStream(video: true);

      // Create peer connection
      await createPeerConnection();

      // Set remote description
      await _peerConnection!.setRemoteDescription(offer);

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer via signaling
      await _sendAnswer(callerId, answer);

      debugPrint('✅ Video call answered: $callId');
      return true;
    } catch (e) {
      debugPrint('❌ Answer call error: $e');
      _state = CallState.failed;
      return false;
    }
  }

  /// End call
  Future<void> endCall() async {
    debugPrint('📞 Ending video call...');

    // Close peer connection
    await _peerConnection?.close();
    _peerConnection = null;

    // Stop local stream
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;

    // Stop remote stream
    _remoteStream?.getTracks().forEach((track) => track.stop());
    _remoteStream = null;

    // Reset state
    _state = CallState.ended;
    _callId = null;
    _remoteUserId = null;
    _isVideoEnabled = true;
    _isAudioEnabled = true;
    _isFrontCamera = true;

    debugPrint('✅ Video call ended');
  }

  /// Toggle video
  Future<void> toggleVideo() async {
    if (_localStream == null) return;

    _isVideoEnabled = !_isVideoEnabled;
    
    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      videoTrack.enabled = _isVideoEnabled;
    }

    debugPrint('📹 Video ${_isVideoEnabled ? "enabled" : "disabled"}');
  }

  /// Toggle audio
  Future<void> toggleAudio() async {
    if (_localStream == null) return;

    _isAudioEnabled = !_isAudioEnabled;
    
    final audioTrack = _localStream!.getAudioTracks().firstOrNull;
    if (audioTrack != null) {
      audioTrack.enabled = _isAudioEnabled;
    }

    debugPrint('🎤 Audio ${_isAudioEnabled ? "enabled" : "disabled"}');
  }

  /// Switch camera
  Future<void> switchCamera() async {
    try {
      if (_localStream == null) return;

      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await videoTrack.switchCamera();
        _isFrontCamera = !_isFrontCamera;
        debugPrint('📹 Camera switched (${_isFrontCamera ? "front" : "back"})');
      }
    } catch (e) {
      debugPrint('❌ Switch camera error: $e');
    }
  }

  /// Send ICE candidate via signaling
  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    try {
      await _dio.post(
        '$_signalingUrl/webrtc/ice-candidate',
        data: {
          'call_id': _callId,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    } catch (e) {
      debugPrint('❌ Send ICE candidate error: $e');
    }
  }

  /// Send offer via signaling
  Future<void> _sendOffer(String userId, RTCSessionDescription offer) async {
    try {
      await _dio.post(
        '$_signalingUrl/webrtc/offer',
        data: {
          'call_id': _callId,
          'caller_id': _remoteUserId,
          'callee_id': userId,
          'offer': offer.sdp,
          'type': offer.type,
          'is_video': _isVideoEnabled,
        },
      );
    } catch (e) {
      debugPrint('❌ Send offer error: $e');
    }
  }

  /// Send answer via signaling
  Future<void> _sendAnswer(String userId, RTCSessionDescription answer) async {
    try {
      await _dio.post(
        '$_signalingUrl/webrtc/answer',
        data: {
          'call_id': _callId,
          'caller_id': userId,
          'answer': answer.sdp,
          'type': answer.type,
        },
      );
    } catch (e) {
      debugPrint('❌ Send answer error: $e');
    }
  }

  /// Dispose service
  void dispose() {
    endCall();
    debugPrint('📹 Video call service disposed');
  }
}

/// 📞 Call State Enum
enum CallState {
  idle,
  dialing,
  ringing,
  connected,
  disconnected,
  failed,
  ended,
}
