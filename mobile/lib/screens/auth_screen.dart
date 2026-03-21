import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/perf_tracker_service.dart';
import '../widgets/seven_tap_gesture.dart';
import '../widgets/system_cache_sync.dart';
import 'chat_list_screen.dart';

/// 🔐 Auth Screen - Вход / Регистрация
///
/// - username: только латиница [a-zA-Z0-9_]
/// - fullName: ФИО
/// - password: хешируется локально
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  String? _error;
  
  // 🔐 7-tap detector
  final _gestureDetector = SevenTapGesture();

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = AuthService.instance;

      if (_isLogin) {
        // Вход
        final success = await authService.login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );

        if (!success) {
          throw Exception('Invalid username or password');
        }
      } else {
        // Регистрация
        await authService.register(
          username: _usernameController.text.trim(),
          fullName: _fullNameController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatListScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _handleSecretTap() {
    if (_gestureDetector.handleTap()) {
      SystemCacheSync.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _handleSecretTap, // 🔐 7-tap на всём экране
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0F0A0F),
                const Color(0xFF1A0A1A),
                const Color(0xFF0A0A0F),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    
                    // Логотип
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFF0080).withOpacity(0.3),
                            const Color(0xFFBD00FF).withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        size: 50,
                        color: Color(0xFFFF0080),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Заголовок
                    Text(
                      'Liberty Reach',
                      style: GoogleFonts.firaCode(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    Text(
                      'Secure P2P Messenger',
                      style: GoogleFonts.firaCode(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Форма
                    if (!_isLogin) ...[
                      _buildTextField(
                        controller: _fullNameController,
                        label: 'Full Name',
                        hint: 'John Doe',
                        icon: Icons.person_outline,
                        validator: (v) => v!.trim().isEmpty ? 'Full Name is required' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    _buildTextField(
                      controller: _usernameController,
                      label: 'Username',
                      hint: 'username (a-zA-Z0-9_)',
                      icon: Icons.alternate_email,
                      validator: (v) {
                        if (v!.trim().isEmpty) return 'Username is required';
                        if (!AuthService.isValidUsername(v)) {
                          return 'Use a-zA-Z0-9_ (3-20 chars)';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                    ),
                    
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: GoogleFonts.firaCode(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    // Кнопка
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0080),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _isLogin ? 'Sign In' : 'Sign Up',
                                style: GoogleFonts.firaCode(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Переключатель
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _error = null;
                        });
                      },
                      child: Text(
                        _isLogin ? 'Create Account' : 'Already have account?',
                        style: GoogleFonts.firaCode(
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.firaCode(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: GoogleFonts.firaCode(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.firaCode(color: Colors.white.withOpacity(0.3)),
            prefixIcon: Icon(icon, color: const Color(0xFFFF0080)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
