import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home Screen - Main chat list
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ChatListScreen(),
    const CallsScreen(),
    const ContactsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Чатове',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'Обаждания',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Контакти',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                // New chat
              },
              icon: const Icon(Icons.edit),
              label: const Text('Нов чат'),
            )
          : null,
    );
  }
}

/// Chat List Screen
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          floating: true,
          title: const Text('Liberty Reach'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // Search
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // Menu
              },
            ),
          ],
        ),
        
        // Security Status Banner
        const SliverToBoxAdapter(
          child: SecurityStatusBanner(),
        ),
        
        // Chat List
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return const ChatListItem(
                name: 'Test User',
                lastMessage: 'Hello! This is encrypted message.',
                time: '10:30',
                unreadCount: 2,
                isOnline: true,
              );
            },
            childCount: 20, // Placeholder
          ),
        ),
      ],
    );
  }
}

/// Security Status Banner
class SecurityStatusBanner extends StatelessWidget {
  const SecurityStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Всички съобщения са криптирани',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Post-Quantum + End-to-End Encryption',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green.shade700),
        ],
      ),
    );
  }
}

/// Chat List Item
class ChatListItem extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int? unreadCount;
  final bool isOnline;

  const ChatListItem({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.unreadCount,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade300,
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Encryption badge
          Icon(Icons.lock_outline, size: 14, color: Colors.green.shade600),
        ],
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
          if (unreadCount != null && unreadCount! > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.pushNamed(context, '/chat');
      },
    );
  }
}

/// Calls Screen
class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.call_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Няма обаждания',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Обажданията са криптирани край-до-край',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Contacts Screen
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contacts_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Контакти',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.blue,
                  child: const Text(
                    'U',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Name',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '@username',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Settings Sections
        _buildSectionTitle('Настройки'),
        
        Card(
          child: Column(
            children: [
              _buildListTile(
                icon: Icons.person,
                title: 'Профил',
                subtitle: 'Управление на профила',
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.security,
                title: 'Поверителност',
                subtitle: 'Криптиране и сигурност',
                onTap: () {},
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.notifications,
                title: 'Известия',
                subtitle: 'Звуци и известия',
                onTap: () {},
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.chat,
                title: 'Чатове',
                subtitle: 'Теми и съобщения',
                onTap: () {},
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        _buildSectionTitle('Приложение'),
        
        Card(
          child: Column(
            children: [
              _buildListTile(
                icon: Icons.language,
                title: 'Език',
                subtitle: 'Български',
                onTap: () {},
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.palette,
                title: 'Тема',
                subtitle: 'Системна',
                onTap: () {},
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.info,
                title: 'Относно',
                subtitle: 'Версия 0.1.0',
                onTap: () {},
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Security Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.verified_user, color: Colors.green.shade700, size: 32),
              const SizedBox(height: 8),
              Text(
                'Liberty Reach Messenger',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Post-Quantum криптиране\nПрофилът не може да бъде изтрит',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
  
  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
