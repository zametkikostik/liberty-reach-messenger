import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/admin_access_service.dart';
import '../services/theme_service.dart';
import '../services/p2p_service.dart';
import 'user_login_screen.dart';

/// 🔐 Admin Dashboard - Sovereign Admin Panel
///
/// Доступно ТОЛЬКО при isAdmin = true:
/// - Логи Rust-ядра (libp2p) в реальном времени
/// - Управление нодой (старт/стоп/рестарт)
/// - P2P статистика (пиры, DHT, соединения)
/// - Системные настройки
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _logTimer;
  bool _isNodeRunning = false;

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

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final adminService = Provider.of<AdminAccessService>(context);
    final colors = themeService.gradientColors;

    // Проверка доступа
    if (!adminService.isAdmin) {
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
          '🔐 Sovereign Admin',
          style: GoogleFonts.firaCode(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colors[0].withOpacity(0.2),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
        child: Column(
          children: [
            // Статус ноды
            _buildNodeStatusCard(colors),

            // Логи Rust-ядра
            Expanded(
              child: _buildRustLogs(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeStatusCard(List<Color> colors) {
    return Container(
      margin: const EdgeInsets.all(16),
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

  Widget _buildRustLogs(List<Color> colors) {
    return Container(
      margin: const EdgeInsets.all(16),
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
          Expanded(
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
                      fontSize: 11,
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
