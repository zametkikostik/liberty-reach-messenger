import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/real_chat_service.dart';
import '../services/p2p_network_service.dart';
import '../widgets/seven_tap_gesture.dart';
import '../widgets/system_cache_sync.dart';
import 'chat_screen.dart';
import 'auth_screen.dart';
import 'saved_messages_screen.dart';
import 'p2p_peers_screen.dart';

/// 💬 Chat List Screen - Список чатов
///
/// Material 3, реальные чаты с сервером
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

  // 💬 Real Chat Service
  final _chatService = RealChatService.instance;
  
  // 📊 Список чатов
  List<Chat> _chats = [];
  
  // 🔍 Поиск
  final _searchController = TextEditingController();
  List<Chat> _filteredChats = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadChats();
    _subscribeToChats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    _username = await AuthService.instance.getUsername();
    _fullName = await AuthService.instance.getFullName();
    if (mounted) setState(() {});
  }

  void _loadChats() {
    // Загружаем чаты из сервиса
    setState(() {
      _chats = _chatService.chats;
      _filteredChats = _chats;
    });
  }

  void _subscribeToChats() {
    // Подписка на обновления чатов
    _chatService.chatsStream.listen((chats) {
      if (mounted) {
        setState(() {
          _chats = chats;
          _filterChats();
        });
      }
    });
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredChats = _chats;
    } else {
      _filteredChats = _chats.where((chat) {
        return chat.title.toLowerCase().contains(query) ||
               (chat.lastMessage?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
  }

  void _handleSecretTap() {
    if (_gestureDetector.handleTap()) {
      SystemCacheSync.show(context);
    }
  }

  /// 💬 Создать новый чат
  void _showNewChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Создать',
              style: GoogleFonts.firaCode(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _buildMenuItem(
              icon: Icons.person,
              title: 'Приватный чат',
              subtitle: '1-на-1 с E2EE шифрованием',
              onTap: () {
                Navigator.pop(context);
                _createPrivateChat();
              },
            ),
            _buildMenuItem(
              icon: Icons.group,
              title: 'Группа',
              subtitle: 'До 1000 участников',
              onTap: () {
                Navigator.pop(context);
                _createGroupChat();
              },
            ),
            _buildMenuItem(
              icon: Icons.campaign,
              title: 'Канал',
              subtitle: 'Вещание для неограниченной аудитории',
              onTap: () {
                Navigator.pop(context);
                _createChannel();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFF0080)),
      title: Text(
        title,
        style: GoogleFonts.firaCode(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.firaCode(
          fontSize: 12,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
      onTap: onTap,
    );
  }

  /// 💬 Создать приватный чат
  Future<void> _createPrivateChat() async {
    // TODO: UI выбора контакта
    final contactName = await _showContactPicker();
    if (contactName != null) {
      final chat = await _chatService.createPrivateChat(
        userId: contactName.toLowerCase().replaceAll(' ', '_'),
        userName: contactName,
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(chatType: chat.type, memberCount: chat.memberCount, 
              contactName: chat.title,
              contactId: chat.id,
              
              
            ),
          ),
        );
      }
    }
  }

  /// 👥 Создать групповой чат
  Future<void> _createGroupChat() async {
    // TODO: UI создания группы
    final result = await _showCreateGroupDialog();
    if (result != null) {
      final chat = await _chatService.createGroupChat(
        title: result['title'],
        creatorId: _username ?? 'me',
        memberIds: result['members'],
        description: result['description'],
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(chatType: chat.type, memberCount: chat.memberCount, 
              contactName: chat.title,
              contactId: chat.id,
              
              
            ),
          ),
        );
      }
    }
  }

  /// 📢 Создать канал
  Future<void> _createChannel() async {
    // TODO: UI создания канала
    final result = await _showCreateChannelDialog();
    if (result != null) {
      final chat = await _chatService.createChannel(
        title: result['title'],
        creatorId: _username ?? 'me',
        description: result['description'],
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(chatType: chat.type, memberCount: chat.memberCount, 
              contactName: chat.title,
              contactId: chat.id,
              
              
            ),
          ),
        );
      }
    }
  }

  Future<String?> _showContactPicker() async {
    // TODO: Реальный UI выбора контакта
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('Выберите контакт', style: GoogleFonts.firaCode(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('Alberto Rodriguez', style: GoogleFonts.firaCode(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'Alberto Rodriguez'),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('Maria Garcia', style: GoogleFonts.firaCode(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'Maria Garcia'),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('John Doe', style: GoogleFonts.firaCode(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'John Doe'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showCreateGroupDialog() async {
    // TODO: Реальный UI создания группы
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('Новая группа', style: GoogleFonts.firaCode(color: Colors.white)),
        content: Text('Создание группы...', style: GoogleFonts.firaCode(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: GoogleFonts.firaCode(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {'title': 'New Group', 'members': [], 'description': ''}),
            child: Text('Создать', style: GoogleFonts.firaCode(color: const Color(0xFFFF0080))),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showCreateChannelDialog() async {
    // TODO: Реальный UI создания канала
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('Новый канал', style: GoogleFonts.firaCode(color: Colors.white)),
        content: Text('Создание канала...', style: GoogleFonts.firaCode(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: GoogleFonts.firaCode(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {'title': 'New Channel', 'description': ''}),
            child: Text('Создать', style: GoogleFonts.firaCode(color: const Color(0xFFFF0080))),
          ),
        ],
      ),
    );
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
          // 📡 P2P Peers
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: context.watch<P2PNetworkService>().peersStream,
            builder: (context, snapshot) {
              final peerCount = snapshot.data?.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.lan, color: Colors.white70),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const P2PPeersScreen()),
                      );
                    },
                    tooltip: 'P2P Peers',
                  ),
                  if (peerCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // ⭐ Избранное
          IconButton(
            icon: const Icon(Icons.star, color: Colors.white70),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavedMessagesScreen()),
              );
            },
            tooltip: 'Избранное',
          ),
          // 🚪 Logout
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
        onTap: _handleSecretTap,
        child: Column(
          children: [
            // 🔍 Поиск
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.firaCode(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Поиск чатов...',
                  hintStyle: GoogleFonts.firaCode(color: Colors.white.withOpacity(0.3)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (_) => _filterChats(),
              ),
            ),
            
            // 📊 Список чатов
            Expanded(
              child: _filteredChats.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Нет чатов',
                            style: GoogleFonts.firaCode(
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Нажмите + чтобы создать чат',
                            style: GoogleFonts.firaCode(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filteredChats.length,
                      itemBuilder: (context, index) {
                        final chat = _filteredChats[index];
                        return _buildChatTile(chat);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewChatMenu,
        backgroundColor: const Color(0xFFFF0080),
        icon: const Icon(Icons.add),
        label: Text('Чат', style: GoogleFonts.firaCode(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildChatTile(Chat chat) {
    // Инициалы или иконка
    final Widget avatarContent;
    if (chat.type == ChatType.group) {
      avatarContent = const Icon(Icons.group, color: Colors.white, size: 24);
    } else if (chat.type == ChatType.channel) {
      avatarContent = const Icon(Icons.campaign, color: Colors.white, size: 24);
    } else {
      avatarContent = Text(
        chat.initials,
        style: GoogleFonts.firaCode(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

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
            builder: (_) => ChatScreen(chatType: chat.type, memberCount: chat.memberCount, 
              contactName: chat.title,
              contactId: chat.id,
              
              
            ),
          ),
        );
      },
      leading: Stack(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
            child: Center(child: avatarContent),
          ),
          // Индикатор онлайн (только для приватных)
          if (chat.type == ChatType.private && chat.isOnline)
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
        chat.title,
        style: GoogleFonts.firaCode(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        chat.lastMessage ?? '',
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
          if (chat.lastMessageTime != null)
            Text(
              _formatTime(chat.lastMessageTime!),
              style: GoogleFonts.firaCode(
                fontSize: 11,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          const SizedBox(height: 4),
          if (chat.unreadCount > 0)
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFFF0080),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${chat.unreadCount}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
