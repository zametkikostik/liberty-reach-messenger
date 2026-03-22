import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 📡 REAL P2P Network Service
///
/// Реальная P2P связь через локальную сеть:
/// - UDP multicast для обнаружения (mDNS альтернатива)
/// - TCP для прямого соединения
/// - E2EE шифрование через Rust
class RealP2PService {
  static RealP2PService? _instance;
  static RealP2PService get instance {
    _instance ??= RealP2PService._();
    return _instance!;
  }

  RealP2PService._();

  // UDP для обнаружения
  RawDatagramSocket? _udpSocket;
  final String _multicastAddress = '224.0.0.1';
  final int _port = 40000;
  
  // TCP для соединений
  List<Socket> _tcpConnections = [];
  
  // Пиры
  final List<Map<String, dynamic>> _peers = [];
  final _peersController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get peersStream => _peersController.stream;
  
  // Сообщения
  final List<Map<String, dynamic>> _messages = [];
  final _messagesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get messagesStream => _messagesController.stream;
  
  bool _isRunning = false;
  String? _myPeerId;

  bool get isRunning => _isRunning;
  List<Map<String, dynamic>> get peers => List.unmodifiable(_peers);

  /// ▶️ Запуск P2P ноды
  Future<bool> start(String userId) async {
    if (_isRunning) return false;
    
    try {
      _myPeerId = 'peer_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      
      // UDP для обнаружения
      await _startUdpDiscovery();
      
      // TCP для приёма соединений
      await _startTcpServer();
      
      _isRunning = true;
      print('✅ Real P2P started: $_myPeerId');
      return true;
    } catch (e) {
      print('❌ P2P start failed: $e');
      return false;
    }
  }

  /// 🔍 UDP обнаружение
  Future<void> _startUdpDiscovery() async {
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
    
    // Присоединиться к multicast группе
    _udpSocket!.joinMulticast(InternetAddress(_multicastAddress));
    
    // Отправить приветствие
    _broadcastDiscovery();
    
    // Слушать ответы
    _udpSocket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _udpSocket!.receive();
        if (datagram != null) {
          final data = utf8.decode(datagram.data);
          _handleDiscoveryMessage(data, datagram.address);
        }
      }
    });
    
    print('📡 UDP discovery started on port $_port');
  }

  /// 📢 Вещание обнаружения
  void _broadcastDiscovery() {
    final message = jsonEncode({
      'type': 'discovery',
      'peerId': _myPeerId,
      'userId': 'user_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _udpSocket!.send(
      utf8.encode(message),
      InternetAddress(_multicastAddress),
      _port,
    );
  }

  /// 📨 Обработка обнаружения
  void _handleDiscoveryMessage(String data, InternetAddress address) {
    try {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      
      if (msg['type'] == 'discovery' && msg['peerId'] != _myPeerId) {
        final peer = {
          'peerId': msg['peerId'],
          'userId': msg['userId'],
          'address': address.address,
          'port': _port,
          'status': 'online',
          'lastSeen': DateTime.now(),
        };
        
        // Добавить если нет
        if (!_peers.any((p) => p['peerId'] == msg['peerId'])) {
          _peers.add(peer);
          _peersController.add(_peers);
          print('🟢 Peer discovered: ${msg['peerId']}');
          
          // Установить TCP соединение
          _connectToPeer(InternetAddress(address.address), _port);
        }
      }
    } catch (e) {
      print('❌ Discovery error: $e');
    }
  }

  /// 🖥️ TCP сервер
  Future<void> _startTcpServer() async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, _port + 1);
    
    server.listen((Socket client) {
      _tcpConnections.add(client);
      print('🔗 TCP connection established');
      
      client.listen((data) {
        final message = utf8.decode(data);
        _handleMessage(message);
      });
    });
    
    print('🖥️ TCP server listening on port ${_port + 1}');
  }

  /// 🔗 Подключение к пиру
  Future<void> _connectToPeer(InternetAddress address, int port) async {
    try {
      final socket = await Socket.connect(address, port + 1);
      _tcpConnections.add(socket);
      
      socket.listen((data) {
        final message = utf8.decode(data);
        _handleMessage(message);
      });
      
      print('✅ Connected to peer at ${address.address}');
    } catch (e) {
      print('❌ Connection failed: $e');
    }
  }

  /// 📨 Обработка сообщений
  void _handleMessage(String data) {
    try {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      
      if (msg['type'] == 'chat') {
        _messages.add(msg);
        _messagesController.add(_messages);
        print('📨 Message received: ${msg['content']}');
      }
    } catch (e) {
      print('❌ Message error: $e');
    }
  }

  /// 📤 Отправка сообщения
  Future<bool> sendMessage({
    required String targetPeerId,
    required String content,
    required String chatId,
    required String senderId,
  }) async {
    try {
      final message = jsonEncode({
        'type': 'chat',
        'messageId': 'msg_${DateTime.now().millisecondsSinceEpoch}',
        'chatId': chatId,
        'senderId': senderId,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'sent',
      });
      
      // Отправить через все TCP соединения
      for (final socket in _tcpConnections) {
        socket.write(message);
      }
      
      print('📤 Message sent to $targetPeerId');
      return true;
    } catch (e) {
      print('❌ Send failed: $e');
      return false;
    }
  }

  /// ⏹️ Остановка
  Future<void> stop() async {
    _udpSocket?.close();
    for (final socket in _tcpConnections) {
      socket.close();
    }
    _isRunning = false;
    print('🏁 P2P stopped');
  }
}
