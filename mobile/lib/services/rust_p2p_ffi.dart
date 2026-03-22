import 'dart:ffi';
import 'dart:convert';
import 'package:ffi/ffi.dart';

// FFI Bindings для Rust P2P
typedef CreateIdentityC = Pointer<Utf8> Function();
typedef CreateIdentityDart = Pointer<Utf8> Function();

typedef StartP2PNodeC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef StartP2PNodeDart = Pointer<Utf8> Function(Pointer<Utf8>);

typedef DiscoverPeersC = Pointer<Utf8> Function();
typedef DiscoverPeersDart = Pointer<Utf8> Function();

typedef SendMessageC = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef SendMessageDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef FreeStringC = Void Function(Pointer<Utf8>);
typedef FreeStringDart = void Function(Pointer<Utf8>);

class RustP2P {
  static RustP2P? _instance;
  static RustP2P get instance {
    _instance ??= RustP2P._();
    return _instance!;
  }

  RustP2P._();

  late DynamicLibrary _lib;
  late CreateIdentityDart _createIdentity;
  late StartP2PNodeDart _startP2PNode;
  late DiscoverPeersDart _discoverPeers;
  late SendMessageDart _sendMessage;
  late FreeStringDart _freeString;

  /// Инициализация
  Future<bool> init() async {
    try {
      _lib = DynamicLibrary.open('libliberty_p2p.so');
      
      _createIdentity = _lib
          .lookup<NativeFunction<CreateIdentityC>>('create_identity')
          .asFunction<CreateIdentityDart>();
      
      _startP2PNode = _lib
          .lookup<NativeFunction<StartP2PNodeC>>('start_p2p_node')
          .asFunction<StartP2PNodeDart>();
      
      _discoverPeers = _lib
          .lookup<NativeFunction<DiscoverPeersC>>('discover_peers')
          .asFunction<DiscoverPeersDart>();
      
      _sendMessage = _lib
          .lookup<NativeFunction<SendMessageC>>('send_message')
          .asFunction<SendMessageDart>();
      
      _freeString = _lib
          .lookup<NativeFunction<FreeStringC>>('free_string')
          .asFunction<FreeStringDart>();
      
      print('✅ Rust P2P initialized');
      return true;
    } catch (e) {
      print('❌ Rust P2P init failed: $e');
      return false;
    }
  }

  /// Создать identity
  Future<Map<String, String>?> createIdentity() async {
    try {
      final result = _createIdentity();
      final jsonStr = result.cast<Utf8>().toDartString();
      _freeString(result);
      
      return Map<String, String>.from(jsonDecode(jsonStr));
    } catch (e) {
      print('❌ createIdentity failed: $e');
      return null;
    }
  }

  /// Старт ноды
  Future<Map<String, dynamic>?> startP2PNode(List<String> bootstrapNodes) async {
    try {
      final bootstrap = bootstrapNodes.join(',');
      final cBootstrap = bootstrap.toNativeUtf8();
      
      final result = _startP2PNode(cBootstrap);
      final jsonStr = result.cast<Utf8>().toDartString();
      calloc.free(cBootstrap);
      _freeString(result);
      
      return jsonDecode(jsonStr);
    } catch (e) {
      print('❌ startP2PNode failed: $e');
      return null;
    }
  }

  /// Обнаружение пиров
  Future<List<Map<String, String>>?> discoverPeers() async {
    try {
      final result = _discoverPeers();
      final jsonStr = result.cast<Utf8>().toDartString();
      _freeString(result);
      
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => Map<String, String>.from(e)).toList();
    } catch (e) {
      print('❌ discoverPeers failed: $e');
      return null;
    }
  }

  /// Отправка сообщения
  Future<Map<String, dynamic>?> sendMessage(String receiver, String content) async {
    try {
      final cReceiver = receiver.toNativeUtf8();
      final cContent = content.toNativeUtf8();
      
      final result = _sendMessage(cReceiver, cContent);
      final jsonStr = result.cast<Utf8>().toDartString();
      calloc.free(cReceiver);
      calloc.free(cContent);
      _freeString(result);
      
      return jsonDecode(jsonStr);
    } catch (e) {
      print('❌ sendMessage failed: $e');
      return null;
    }
  }
}
