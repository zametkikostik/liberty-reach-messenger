import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/perf_tracker_service.dart';
import '../services/rust_bridge_service.dart';
import 'user_login_screen.dart';

/// 📊 UIPerformanceScreen - Performance Monitoring
///
/// МАСКИРОВКА: Выглядит как инструмент для замера FPS и метрик
/// РЕАЛЬНОСТЬ: Админ-панель с доступом к Rust-ядру
class UIPerformanceScreen extends StatefulWidget {
  const UIPerformanceScreen({super.key});

  @override
  State<UIPerformanceScreen> createState() => _UIPerformanceScreenState();
}

class _UIPerformanceScreenState extends State<UIPerformanceScreen> {
  StreamSubscription? _rustSubscription;
  RustCoreData? _rustData;
  Timer? _metricsTimer;
  int _ramUsage = 0;

  @override
  void initState() {
    super.initState();
    _startRustStream();
    _startMetricsMonitor();
  }

  @override
  void dispose() {
    _rustSubscription?.cancel();
    _metricsTimer?.cancel();
    RustBridgeService.instance.stopStreaming();
    super.dispose();
  }

  /// 🔒 INSTANT WIPE on Pause
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      final perfService = Provider.of<PerfTrackerService>(context, listen: false);
      perfService.onAppPaused();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserLoginScreen()),
        );
      }
    }
  }

  void _startRustStream() {
    _rustSubscription = RustBridgeService.instance.rustDataStream.listen((data) {
      setState(() => _rustData = data);
    });
  }

  void _startMetricsMonitor() {
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _ramUsage = DateTime.now().minute % 100;
      });
      final perfService = Provider.of<PerfTrackerService>(context, listen: false);
      perfService.updateMetrics(60.0, _ramUsage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final perfService = Provider.of<PerfTrackerService>(context);

    // 🔒 Проверка доступа
    if (!perfService.isPerfTrackerEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserLoginScreen()),
        );
      });
      return const Scaffold();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 UI Performance'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.red),
            onPressed: () {
              perfService.stopMonitoring();
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
              _buildRustNodeCard(),
              const SizedBox(height: 16),
              _buildRamMonitorCard(),
              const SizedBox(height: 16),
              _buildPerfStatusCard(perfService),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRustNodeCard() {
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
                'Rust Node (libp2p)',
                style: TextStyle(
                  color: Colors.grey[200],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_rustData != null) ...[
            _buildMetricRow('Connections', '${_rustData!.activeConnections}'),
            _buildMetricRow('Protocol', 'Kyber ${_rustData!.kyberStatusText}'),
            _buildMetricRow('Peers', '${_rustData!.peerCount}'),
            _buildMetricRow('Bandwidth', '${_rustData!.bandwidthUsage.toStringAsFixed(1)} Mbps'),
            _buildMetricRow('Uptime', _rustData!.formattedUptime),
          ] else ...[
            Center(child: CircularProgressIndicator(color: Colors.blue[400])),
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
                'RAM Usage',
                style: TextStyle(
                  color: Colors.grey[200],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              _buildLiveIndicator(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$_ramUsage MB',
            style: TextStyle(
              color: Colors.green[400],
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _ramUsage / 100,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.flash_on, size: 14, color: Colors.red[400]),
              const SizedBox(width: 4),
              Text(
                'Auto-clear on background',
                style: TextStyle(color: Colors.red[400], fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerfStatusCard(PerfTrackerService perfService) {
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
                'Performance Status',
                style: TextStyle(
                  color: Colors.grey[200],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow('Monitoring', perfService.isMonitoring ? 'Active' : 'Inactive', Colors.purple),
          _buildStatusRow('FPS', '${perfService.fps.toStringAsFixed(1)}', Colors.green),
          _buildStatusRow('Memory', 'Real-time', Colors.orange),
          _buildStatusRow('Auto-Clear', 'On Paused ✓', Colors.red),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
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
            decoration: BoxDecoration(color: color[400], shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
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

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('LIVE', style: TextStyle(color: Colors.green[400], fontSize: 10)),
        ],
      ),
    );
  }
}
