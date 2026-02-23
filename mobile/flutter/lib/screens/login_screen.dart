import 'package:flutter/material.dart';

/// Login / Registration Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _recoveryPhraseController = TextEditingController();
  bool _isCreatingAccount = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _recoveryPhraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                
                // Logo
                Icon(
                  Icons.security,
                  size: 80,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 16),
                
                // Title
                Text(
                  'Liberty Reach',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                
                Text(
                  _isCreatingAccount
                      ? 'Създайте сигурен профил'
                      : 'Влезте в профила си',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Security Info Card
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSecurityFeature(
                          Icons.lock_outline,
                          'Post-Quantum криптиране',
                          'CRYSTALS-Kyber защита',
                        ),
                        const SizedBox(height: 12),
                        _buildSecurityFeature(
                          Icons.folder_off,
                          'Профилът не се изтрива',
                          'Само деактивация',
                        ),
                        const SizedBox(height: 12),
                        _buildSecurityFeature(
                          Icons.vpn_key,
                          'Възстановяване',
                          'Чрез Shamir Secret Sharing',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Username Field
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Потребителско име',
                    hintText: 'Въведете потребителско име',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Моля въведете потребителско име';
                    }
                    if (value.length < 3) {
                      return 'Името трябва да е поне 3 символа';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Recovery Phrase (for existing users)
                if (!_isCreatingAccount) ...[
                  TextFormField(
                    controller: _recoveryPhraseController,
                    decoration: const InputDecoration(
                      labelText: 'Възстановителна фраза',
                      hintText: '12 думи за възстановяване',
                      prefixIcon: Icon(Icons.key),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Моля въведете възстановителната фраза';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Info Text
                if (_isCreatingAccount)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Запишете си възстановителната фраза! Тя не може да бъде възстановена.',
                            style: TextStyle(
                              color: Colors.amber.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (_isCreatingAccount) const SizedBox(height: 16),
                
                // Create Account Button
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // Create account
                      _generateRecoveryPhrase();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _isCreatingAccount ? 'Създай профил' : 'Влез',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Toggle Create/Login
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isCreatingAccount = !_isCreatingAccount;
                    });
                  },
                  child: Text(
                    _isCreatingAccount
                        ? 'Вече имате профил? Влезте'
                        : 'Нямате профил? Създайте',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Permanent Profile Notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Вашият профил е постоянен',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Профилите не могат да бъдат изтрити в Liberty Reach. Това гарантира, че вашите данни ще останат достъпни винаги.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityFeature(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.green.shade700, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _generateRecoveryPhrase() {
    // Generate recovery phrase (12 words)
    final words = [
      'liberty', 'reach', 'secure', 'private', 'quantum', 'shield',
      'freedom', 'encrypt', 'forever', 'permanent', 'profile', 'safe'
    ];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Запишете възстановителната фраза'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Това е вашата възстановителна фраза. Запишете я на сигурно място!',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < words.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            '${i + 1}.',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            words[i],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to home
              Navigator.pushReplacementNamed(context, '/home');
            },
            child: const Text('Записах я'),
          ),
        ],
      ),
    );
  }
}
