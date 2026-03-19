import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/d1_api_service.dart';
import '../services/stories_service.dart';
import '../providers/profile_provider.dart';
import '../widgets/stories_tray.dart';
import 'chat_room_screen.dart';

/// 💬 Chat List Screen
///
/// Displays all active conversations with:
/// - Contact avatar and name
/// - Last message preview
/// - Timestamp
/// - Unread count
/// - Ghost/Love adaptive theme
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final D1ApiService _d1Service = D1ApiService();
  
  // Chats from D1
  final List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initD1();
  }

  Future<void> _initD1() async {
    await _d1Service.init();
    await _loadChats();
  }

  Future<void> _loadChats() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final userId = profileProvider.initials ?? 'me'; // TODO: Get real user ID
    
    final chats = await _d1Service.getChatList(userId);
    
    setState(() {
      _chats.clear();
      _chats.addAll(chats.map((chat) => {
        'id': 'chat-${chat['user_id']}',
        'user_id': chat['user_id'],
        'name': chat['name'] ?? 'Unknown',
        'avatar_cid': chat['avatar_cid'],
        'last_message': chat['last_message'],
        'timestamp': DateTime.fromMillisecondsSinceEpoch(
          (chat['timestamp'] as int?) ?? 0,
        ),
        'unread': chat['unread'] as int? ?? 0,
        'is_online': false, // TODO: Track online status
      }));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chats',
              style: GoogleFonts.firaCode(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_chats.length} active',
              style: GoogleFonts.firaCode(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          // New chat button
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: () {
              // TODO: Implement new chat
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadChats,
              child: Column(
                children: [
                  // Stories Tray
                  StoriesTray(currentUserId: userId),
                  
                  // Chat List
                  Expanded(
                    child: _chats.isEmpty
                        ? _buildEmptyState(colors)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _chats.length,
                            itemBuilder: (context, index) {
                              final chat = _chats[index];
                              return _ChatListItem(
                                chat: chat,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatRoomScreen(
                                        chatId: chat['id'],
                                        userId: chat['user_id'],
                                        userName: chat['name'],
                                      ),
                                    ),
                                  );
                                },
                                onLongPress: () {
                                  _showChatOptions(context, chat);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Start new chat
        },
        icon: const Icon(Icons.message),
        label: const Text('New Chat'),
        backgroundColor: colors[0],
      ),
    );
  }

  Widget _buildEmptyState(List<Color> colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: colors),
              boxShadow: [
                BoxShadow(
                  color: colors[0].withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No chats yet',
            style: GoogleFonts.firaCode(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation!',
            style: GoogleFonts.firaCode(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions(BuildContext context, Map<String, dynamic> chat) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off),
              title: const Text('Mute Notifications'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Mute chat
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, chat);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: Text('Delete conversation with ${chat['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _chats.removeWhere((c) => c['id'] == chat['id']);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat deleted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// 💬 Chat List Item Widget
class _ChatListItem extends StatelessWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatListItem({
    required this.chat,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: colors),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(chat['name']),
                        style: GoogleFonts.firaCode(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Online indicator
                  if (chat['is_online'] == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeService.isGhostMode
                                ? const Color(0xFF0A0A0F)
                                : const Color(0xFF0F0A0F),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 16),

              // Chat info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and time
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat['name'],
                            style: GoogleFonts.firaCode(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(chat['timestamp']),
                          style: GoogleFonts.firaCode(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Last message
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat['last_message'],
                            style: GoogleFonts.firaCode(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Unread badge
                        if (chat['unread'] > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: colors),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${chat['unread']}',
                              style: GoogleFonts.firaCode(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final names = name.split(' ');
    if (names.length == 1) return names[0].substring(0, 1).toUpperCase();
    return '${names[0].substring(0, 1)}${names[names.length - 1].substring(0, 1)}'.toUpperCase();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    return '${time.day}/${time.month}';
  }
}
