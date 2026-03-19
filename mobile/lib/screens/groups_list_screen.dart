import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/group_chats_service.dart';
import '../services/theme_service.dart';
import 'create_group_screen.dart';
import 'chat_room_screen.dart';

/// 👥 Groups List Screen
///
/// Display all user's groups with:
/// - Group avatar and name
/// - Member count
/// - Last message preview
/// - Unread count
class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  final GroupChatsService _groupService = GroupChatsService.instance;
  
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    
    // TODO: Get real user ID
    final userId = 'me';
    
    final groups = await _groupService.getUserGroups(userId);
    
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Groups',
          style: GoogleFonts.firaCode(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateGroupScreen(),
                ),
              );
              
              if (result != null) {
                _loadGroups();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? _buildEmptyState(colors)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return _GroupListItem(
                      group: group,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatRoomScreen(
                              chatId: group['id'],
                              userId: group['id'],
                              userName: group['name'],
                              isGroup: true,
                            ),
                          ),
                        );
                      },
                    );
                  },
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
              Icons.group_add,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No groups yet',
            style: GoogleFonts.firaCode(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first group!',
            style: GoogleFonts.firaCode(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateGroupScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors[0],
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 👥 Group List Item Widget
class _GroupListItem extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTap;

  const _GroupListItem({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              // Group avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colors),
                ),
                child: Center(
                  child: Text(
                    _getGroupInitials(group['name']),
                    style: GoogleFonts.firaCode(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Group info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and member count
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group['name'],
                            style: GoogleFonts.firaCode(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Public badge
                        if ((group['is_public'] as int? ?? 0) == 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.public,
                              size: 14,
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Member count and description
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${group['member_count'] ?? 1} members',
                          style: GoogleFonts.firaCode(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6),
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

  String _getGroupInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    
    final names = name.split(' ');
    if (names.length == 1) return names[0].substring(0, 1).toUpperCase();
    return '${names[0].substring(0, 1)}${names[names.length - 1].substring(0, 1)}'.toUpperCase();
  }
}
