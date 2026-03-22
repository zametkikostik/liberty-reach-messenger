import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// 📞 WebRTC Call Service
///
/// Аудио/Видео звонки с HD качеством
class WebRTCCallService {
  static WebRTCCallService? _instance;
  static WebRTCCallService get instance {
    _instance ??= WebRTCCallService._();
    return _instance!;
  }

  WebRTCCallService._();

  final RTCPeerConnection? _peerConnection;
  final MediaStream? _localStream;
  final MediaStream? _remoteStream;
  
  bool _isInCall = false;
  bool _isVideoEnabled = false;
  bool _isAudioEnabled = true;

  bool get isInCall => _isInCall;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isAudioEnabled => _isAudioEnabled;

  /// 📞 Начать звонок
  Future<bool> startCall(String peerId, bool video) async {
    try {
      // Создание peer connection
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ]
      };

      final peerConnection = await createPeerConnection(configuration);
      
      // Получение локального медиа потока
      final mediaStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': video ? {'width': {'ideal': 1920}, 'height': {'ideal': 1080}} : false,
      });

      // Добавление треков
      mediaStream.getTracks().forEach((track) {
        peerConnection.addTrack(track, mediaStream);
      });

      _isInCall = true;
      _isVideoEnabled = video;
      
      print('📞 Call started with peer: $peerId');
      return true;
    } catch (e) {
      print('❌ Call start failed: $e');
      return false;
    }
  }

  /// 📥 Принять звонок
  Future<bool> acceptCall(String peerId) async {
    try {
      // Аналогично startCall, но для входящего
      _isInCall = true;
      print('📞 Call accepted from: $peerId');
      return true;
    } catch (e) {
      print('❌ Call accept failed: $e');
      return false;
    }
  }

  /// ❌ Завершить звонок
  Future<void> endCall() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _peerConnection?.close();
    _isInCall = false;
    _isVideoEnabled = false;
    print('📞 Call ended');
  }

  /// 🔇 Включить/выключить микрофон
  void toggleAudio() {
    _isAudioEnabled = !_isAudioEnabled;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = _isAudioEnabled;
    });
  }

  /// 📹 Включить/выключить камеру
  void toggleVideo() {
    _isVideoEnabled = !_isVideoEnabled;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _isVideoEnabled;
    });
  }

  /// 🔄 Переключить камеру (фронтальная/задняя)
  Future<void> switchCamera() async {
    // TODO: Реализация переключения камеры
  }

  /// 📤 Отправить DTMF тон
  Future<void> sendDTMF(String tone) async {
    // TODO: DTMF tones
  }
}
