import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/admin_access_service.dart';
import '../services/theme_service.dart';
import '../services/p2p_service.dart';
import 'user_login_screen.dart';

/// 🔐 Sovereign Dashboard - Панель управления Sovereign Mode
///
/// Доступно ТОЛЬКО при isSovereignMode = true:
/// - Полный Memory Wipe контроль
/// - Логи Rust-ядра (libp2p) в реальном времени
/// - Управление нодой (старт/стоп/конфигурация)
/// - Лимиты сети (bandwidth, connections, peers)
class SovereignDashboardScreen extends StatefulWidget {
  const SovereignDashboardScreen({super.key});

  @override
  State<SovereignDashboardScreen> createState() => _SovereignDashboardScreenState();
}

class _SovereignDashboardScreenState extends State<SovereignDashboardScreen> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _logTimer;
  
  // Node status
  bool _isNodeRunning = false;
  
  // Network limits
  double _bandwidthLimit = 100; // Mbps
  int _maxConnections = 50;
  int _maxPeers = 100;

  @override
  void initState() {
    super.initState();
    _startLogStream();
    _checkNodeStatus();
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startLogStream() {
    // Симуляция потока логов от Rust-ядра
    _logTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final messages = [
        '[libp2p] Peer discovered: 16Uiu2HAm...',
        '[DHT] Routing table updated: 47 peers',
        '[Noise] Handshake completed with peer',
        '[Yamux] New stream opened: stream_12345',
        '[Gossipsub] Message received on topic: /liberty/1.0.0',
        '[Kademlia] Node added to bucket: 8a7f9c...',
        '[Identify] Protocol version: ipfs/0.1.0',
        '[Ping] Latency to peer: 45ms',
        '[Bandwidth] Current: 45 Mbps / ${_bandwidthLimit.toInt()} Mbps',
        '[Connections] Active: ${_maxConnections ~/ 2} / $_maxConnections',
      ];
      
      final randomMsg = messages[DateTime.now().millisecondsSinceEpoch % messages.length];
      final timestamp = DateTime.now().toString().substring(11, 19);
      
      setState(() {
        _logs.add('[$timestamp] $randomMsg');
        if (_logs.length > 100) {
          _logs.removeAt(0);
        }
      });
      
      // Автопрокрутка вниз
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _checkNodeStatus() async {
    final p2p = P2PService.instance;
    setState(() => _isNodeRunning = p2p.isRunning);
  }

  Future<void> _toggleNode() async {
    final p2p = P2PService.instance;
    
    setState(() => _isNodeRunning = !_isNodeRunning);
    
    if (_isNodeRunning) {
      await p2p.start();
    } else {
      await p2p.stop();
    }
  }

  void _triggerMemoryWipe() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔥 Memory Wipe'),
        content: const Text(
          'Вы уверены?\n\nЭто затрёт:\n• Мастер-пароль из RAM\n• Все сессионные ключи\n• Временные данные\n\nПриложение будет перезапущено.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final adminService = Provider.of<AdminAccessService>(context, listen: false);
              adminService.logout(); // Это вызовет _secureWipe()
              
              Navigator.pop(context);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const UserLoginScreen()),
              );
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

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final adminService = Provider.of<AdminAccessService>(context);
    final colors = themeService.gradientColors;

    // Проверка доступа
    if (!adminService.isSovereignMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserLoginScreen()),
        );
      });
      return const Scaffold();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '🔐 Sovereign Mode',
          style: GoogleFonts.firaCode(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.purple.withOpacity(0.2),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              adminService.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const UserLoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F0A0F),
              const Color(0xFF1A0A1A),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Node Status Card
              _buildNodeStatusCard(colors),

              const SizedBox(height: 16),

              // Memory Wipe Button
              _buildMemoryWipeCard(colors),

              const SizedBox(height: 16),

              // Network Limits
              _buildNetworkLimitsCard(colors),

              const SizedBox(height: 16),

              // Rust Logs
              _buildRustLogsCard(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeStatusCard(List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isNodeRunning
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isNodeRunning
              ? Colors.green.withOpacity(0.5)
              : Colors.orange.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isNodeRunning ? Icons.dns : Icons.dns_outlined,
            color: _isNodeRunning ? Colors.green : Colors.orange,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rust libp2p Node',
                  style: GoogleFonts.firaCode(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _isNodeRunning ? 'Running' : 'Stopped',
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: _isNodeRunning ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _toggleNode,
            icon: Icon(_isNodeRunning ? Icons.stop : Icons.play_arrow),
            label: Text(_isNodeRunning ? 'Stop' : 'Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isNodeRunning
                  ? Colors.red.withOpacity(0.8)
                  : Colors.green.withOpacity(0.8),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryWipeCard(List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.delete_forever,
                color: Colors.red.withOpacity(0.8),
                size: 32,
              ),
              const SizedBox(width: 16),
              Text(
                'Memory Wipe Control',
                style: GoogleFonts.firaCode(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Полное затирание чувствительных данных из RAM:\n'
            '• Мастер-пароль\n'
            '• Сессионные ключи\n'
            '• Временные данные',
            style: GoogleFonts.firaCode(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _triggerMemoryWipe,
              icon: const Icon(Icons.warning),
              label: const Text('🔥 TRIGGER MEMORY WIPE'),
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

  Widget _buildNetworkLimitsCard(List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.network_check,
                color: Colors.blue.withOpacity(0.8),
                size: 32,
              ),
              const SizedBox(width: 16),
              Text(
                'Network Limits',
                style: GoogleFonts.firaCode(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Bandwidth
          _buildSlider(
            label: 'Bandwidth Limit (Mbps)',
            value: _bandwidthLimit,
            min: 10,
            max: 1000,
            onChanged: (v) => setState(() => _bandwidthLimit = v),
          ),
          
          const SizedBox(height: 12),
          
          // Max Connections
          _buildSlider(
            label: 'Max Connections',
            value: _maxConnections.toDouble(),
            min: 10,
            max: 200,
            divisions: 19,
            onChanged: (v) => setState(() => _maxConnections = v.toInt()),
          ),
          
          const SizedBox(height: 12),
          
          // Max Peers
          _buildSlider(
            label: 'Max Peers in DHT',
            value: _maxPeers.toDouble(),
            min: 50,
            max: 500,
            divisions: 9,
            onChanged: (v) => setState(() => _maxPeers = v.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.firaCode(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(0),
          onChanged: onChanged,
        ),
        Text(
          value.toStringAsFixed(0),
          style: GoogleFonts.firaCode(
            fontSize: 10,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildRustLogsCard(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors[0].withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors[0].withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal,
                  size: 20,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  'Rust Core Logs (libp2p)',
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Логи
          SizedBox(
            height: 300,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    log,
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      color: _getLogColor(log),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getLogColor(String log) {
    if (log.contains('ERROR')) return Colors.red;
    if (log.contains('WARN')) return Colors.orange;
    if (log.contains('INFO')) return Colors.green;
    if (log.contains('DEBUG')) return Colors.blue;
    return Colors.white70;
  }
}
