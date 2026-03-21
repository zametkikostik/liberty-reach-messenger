import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/admin_access_service.dart';
import '../services/rust_bridge_service.dart';
import 'sovereign_console_screen.dart';

/// 🔐 Invisible Sovereign Portal - System Verification Dialog
///
/// STEALTH MODE: При неверном пароле показывает "Update Server Busy"
class InvisibleSovereignPortal {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SystemVerificationDialog(),
    );
  }
}

class _SystemVerificationDialog extends StatefulWidget {
  @override
  State<_SystemVerificationDialog> createState() => _SystemVerificationDialogState();
}

class _SystemVerificationDialogState extends State<_SystemVerificationDialog> {
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  String _error = '';
  int _failedAttempts = 0;
  bool _isLoading = false;

  static const int maxFailedAttempts = 3;
  static const String sovereignMasterPassword = 'REDACTED_PASSWORD';

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() => _error = 'Введите пароль');
      return;
    }

    setState(() => _isLoading = true);

    final adminService = Provider.of<AdminAccessService>(context, listen: false);

    try {
      // 🔐 STEALTH MODE: Фейковая ошибка для всех кроме мастер-пароля
      if (password == sovereignMasterPassword) {
        // Успешная активация
        await adminService.activateSovereignMode(password);
        
        // Запуск Rust Bridge
        RustBridgeService.instance.startStreaming();

        if (mounted) {
          Navigator.of(context).pop();
          // Переход в Sovereign Console (не стандартный роутинг)
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SovereignConsoleScreen()),
          );
        }
      } else {
        // 🔐 STEALTH MODE: Фейковая ошибка
        // Никто не поймёт, что там была проверка пароля
        setState(() {
          _error = 'Update Server Busy';
          _isLoading = false;
        });
        
        _failedAttempts++;
        
        // Всё равно считаем попытки для PANIC WIPE
        if (_failedAttempts >= maxFailedAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Update Server Busy';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[700]!, width: 1),
      ),
      title: Row(
        children: [
          Icon(Icons.system_update, color: Colors.grey[400], size: 24),
          const SizedBox(width: 12),
          Text(
            'System Verification',
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
            'Enter credentials to verify system integrity',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscureText,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: Colors.grey[200]),
            decoration: InputDecoration(
              hintText: 'Password',
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
            onSubmitted: (_) => _verifyPassword(),
          ),
          if (_error.isNotEmpty) ...[
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
                      _error,
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                      ),
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
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            foregroundColor: Colors.grey[300],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verify'),
        ),
      ],
    );
  }
}
