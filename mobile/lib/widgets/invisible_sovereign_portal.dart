import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/admin_access_service.dart';
import 'sovereign_dashboard_screen.dart';

/// 🔐 Invisible Sovereign Portal - System Verification Dialog
///
/// Вызывается 7-кратным тапом на версию приложения в Settings
/// Показывает системное окно для ввода мастер-пароля
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
      // Проверка с 3-attempt rule
      final isValid = adminService.checkPasswordAttempt(password);

      if (isValid) {
        // Успешная активация Sovereign Mode
        await adminService.activateSovereignMode(password);

        if (mounted) {
          // Закрыть диалог
          Navigator.of(context).pop();

          // Переход в Sovereign Dashboard
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SovereignDashboardScreen()),
          );
        }
      }
    } on SecurityException catch (e) {
      // PANIC WIPE активирован
      setState(() {
        _error = '🚨 $e';
        _isLoading = false;
      });

      // Haptic feedback
      HapticFeedback.heavyImpact();

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = '❌ Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.purple.withOpacity(0.3),
          width: 1,
        ),
      ),
      title: Row(
        children: [
          Icon(
            Icons.security,
            color: Colors.purple.withOpacity(0.8),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'System Verification',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Описание
          Text(
            'Enter sovereign credentials to access system controls',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Поле ввода пароля
          TextField(
            controller: _passwordController,
            obscureText: _obscureText,
            autofocus: true,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'Master Password',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.lock_outline,
                color: Colors.purple.withOpacity(0.6),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[600],
                ),
                onPressed: () {
                  setState(() => _obscureText = !_obscureText);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _error.isNotEmpty ? Colors.red : Colors.grey[300]!,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _error.isNotEmpty ? Colors.red : Colors.grey[300]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _error.isNotEmpty ? Colors.red : Colors.purple.withOpacity(0.6),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onSubmitted: (_) => _verifyPassword(),
            textInputAction: TextInputAction.done,
          ),

          // Сообщение об ошибке
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _error.contains('🚨')
                    ? Colors.red.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error,
                style: TextStyle(
                  color: _error.contains('🚨') ? Colors.red : Colors.orange,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],

          // Предупреждение о попытках
          if (_failedAttempts > 0 && _failedAttempts < maxFailedAttempts) ...[
            const SizedBox(height: 8),
            Text(
              '⚠️ ${maxFailedAttempts - _failedAttempts} attempt(s) remaining',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
      actions: [
        // Кнопка отмены
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ),

        // Кнопка подтверждения
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Verify',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        ),
      ],
    );
  }
}
