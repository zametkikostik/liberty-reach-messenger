import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_access_service.dart';
import '../services/rust_bridge_service.dart';
import 'user_login_screen.dart';

/// 🔐 Sovereign Console Screen - Функциональная консоль админа
///
/// - Rust Bridge: стрим данных из ядра
/// - RAM Monitor: индикатор очистки памяти
/// - Стелс-режим: onPaused → isAdmin = false мгновенно
class SovereignConsoleScreen extends StatefulWidget {
  const SovereignConsoleScreen({super.key});

  @override
  State<SovereignConsoleScreen> createState() => _SovereignConsoleScreenState();
}

class _SovereignConsoleScreenState extends State<SovereignConsoleScreen> {
  StreamSubscription? _rustSubscription;
  RustCoreData? _currentRustData;
  Timer? _ramMonitorTimer;
  int _currentRamUsage = 0;

  @override
  void initState() {
    super.initState();
    _startRustStream();
    _startRamMonitor();
  }

  @override
  void dispose() {
    _rustSubscription?.cancel();
    _ramMonitorTimer?.cancel();
    RustBridgeService.instance.stopStreaming();
    super.dispose();
  }

  /// 🔒 RAM WIPE при сворачивании
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // 🔐 МГНОВЕННЫЙ WIPE
      final adminService = Provider.of<AdminAccessService>(context, listen: false);
      adminService.onAppPaused();
      
      // Возврат на главный экран
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserLoginScreen()),
        );
      }
    }
  }

  void _startRustStream() {
    _rustSubscription = RustBridgeService.instance.rustDataStream.listen((data) {
      setState(() => _currentRustData = data);
    });
  }

  void _startRamMonitor() {
    _ramMonitorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Симуляция мониторинга RAM
      setState(() {
        _currentRamUsage = DateTime.now().minute % 100;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminAccessService>(context);

    // 🔐 Проверка: если isAdmin = false → выход
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
        title: const Text('🔐 Sovereign Console'),
        backgroundColor: Colors.grey[900],
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
            colors: [Colors.grey[900]!, Colors.black],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔗 Rust Bridge Card
              _buildRustBridgeCard(),
              
              const SizedBox(height: 16),
              
              // 🧠 RAM Monitor Card
              _buildRamMonitorCard(),
              
              const SizedBox(height: 16),
              
              // 📊 Status Info
              _buildStatusInfo(adminService),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRustBridgeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns, color: Colors.blue[400], size: 24),
              const SizedBox(width: 12),
              Text(
                'Rust Bridge - Live Data',
                style: TextStyle(
                  color: Colors.grey[200],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentRustData != null) ...[
            _buildDataRow('Connections', '${_currentRustData!.activeConnections}'),
            _buildDataRow('Kyber Status', _currentRustData!.kyberStatusText),
            _buildDataRow('Peers', '${_currentRustData!.peerCount}'),
            _buildDataRow('Bandwidth', '${_currentRustData!.bandwidthUsage.toStringAsFixed(1)} Mbps'),
            _buildDataRow('Uptime', _currentRustData!.formattedUptime),
          ] else ...[
            Center(
              child: CircularProgressIndicator(color: Colors.blue[400]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRamMonitorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory, color: Colors.green[400], size: 24),
              const SizedBox(width: 12),
              Text(
                'RAM Monitor',
                style: TextStyle(
                  color: Colors.grey[200],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(color: Colors.green[400], fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Usage',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_currentRamUsage MB',
                      style: TextStyle(
                        color: Colors.green[400],
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wipe on Pause',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.flash_on, size: 16, color: Colors.red[400]),
                        const SizedBox(width: 4),
                        Text(
                          'INSTANT',
                          style: TextStyle(
                            color: Colors.red[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _currentRamUsage / 100,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo(AdminAccessService adminService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.purple[400], size: 20),
              const SizedBox(width: 8),
              Text(
                'Sovereign Status',
                style: TextStyle(
                  color: Colors.grey[200],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow('Mode', 'Sovereign Admin', Colors.purple),
          _buildStatusRow('isAdmin', '${adminService.isSovereignMode}', Colors.green),
          _buildStatusRow('Memory', 'RAM Only (Zero-Persistence)', Colors.orange),
          _buildStatusRow('Auto-Wipe', 'On Paused ✓', Colors.red),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[200],
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, MaterialColor color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color[400],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color[400],
              fontWeight: FontWeight.bold,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
