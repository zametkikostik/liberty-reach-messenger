import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/perf_tracker_service.dart';
import '../widgets/seven_tap_gesture.dart';
import '../widgets/system_cache_sync.dart';
import 'chat_screen.dart';
import 'auth_screen.dart';

/// 💬 Chat List Screen - Список чатов
///
/// Material 3, ListView.builder, CircleAvatar
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String? _username;
  String? _fullName;
  
  // 🔐 7-tap detector
  final _gestureDetector = SevenTapGesture();

  // Демо-чаты (для примера)
  final List<Map<String, dynamic>> _chats = [
    {'fullName': 'Alberto Rodriguez', 'username': 'alberto_r', 'lastMessage': 'Привет! Как дела?', 'time': DateTime.now(), 'online': true},
    {'fullName': 'Maria Garcia', 'username': 'maria_g', 'lastMessage': 'Скинь фотки с вечеринки', 'time': DateTime.now().subtract(const Duration(hours: 2)), 'online': false},
    {'fullName': 'John Doe', 'username': 'john_doe', 'lastMessage': 'Встреча завтра в 10:00', 'time': DateTime.now().subtract(const Duration(days: 1)), 'online': true},
    {'fullName': 'Alice Smith', 'username': 'alice_s', 'lastMessage': 'Спасибо!', 'time': DateTime.now().subtract(const Duration(days: 2)), 'online': false},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _username = await AuthService.instance.getUsername();
    _fullName = await AuthService.instance.getFullName();
    if (mounted) setState(() {});
  }

  void _handleSecretTap() {
    if (_gestureDetector.handleTap()) {
      SystemCacheSync.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chats',
              style: GoogleFonts.firaCode(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_fullName != null)
              Text(
                _fullName!,
                style: GoogleFonts.firaCode(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () async {
              await AuthService.instance.logout();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _handleSecretTap, // 🔐 7-tap на всём экране
        child: _chats.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No chats yet',
                      style: GoogleFonts.firaCode(color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  return _buildChatTile(chat);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Добавить контакт
        },
        backgroundColor: const Color(0xFFFF0080),
        icon: const Icon(Icons.add),
        label: Text('New Chat', style: GoogleFonts.firaCode(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final fullName = chat['fullName'] as String;
    final lastMessage = chat['lastMessage'] as String;
    final time = chat['time'] as DateTime;
    final online = chat['online'] as bool;

    // Инициалы
    final names = fullName.trim().split(' ');
    final initials = names.length > 1
        ? '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase()
        : names[0].substring(0, 2).toUpperCase();

    // Градиент для аватара
    final gradient = LinearGradient(
      colors: [
        const Color(0xFFFF0080).withOpacity(0.8),
        const Color(0xFFBD00FF).withOpacity(0.8),
      ],
    );

    return ListTile(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(contactName: fullName, contactId: chat['username']),
          ),
        );
      },
      leading: Stack(
        children: [
          // CircleAvatar с градиентом
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.firaCode(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Индикатор онлайн
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        fullName,
        style: GoogleFonts.firaCode(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        lastMessage,
        style: GoogleFonts.firaCode(
          fontSize: 13,
          color: Colors.white.withOpacity(0.6),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(time),
            style: GoogleFonts.firaCode(
              fontSize: 11,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 4),
          if (index == 0)
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFFF0080),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '1',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    
    return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}';
  }
}
