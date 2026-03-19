import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/channels_service.dart';
import '../services/theme_service.dart';
import 'create_channel_screen.dart';

/// 📢 Channels List Screen
///
/// Display all user's channels with:
/// - Channel avatar and name
/// - Subscriber count
/// - Last post preview
/// - Unread count
class ChannelsListScreen extends StatefulWidget {
  const ChannelsListScreen({super.key});

  @override
  State<ChannelsListScreen> createState() => _ChannelsListScreenState();
}

class _ChannelsListScreenState extends State<ChannelsListScreen> {
  final ChannelsService _channelService = ChannelsService.instance;
  
  List<Map<String, dynamic>> _channels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() => _isLoading = true);
    
    // TODO: Get real user ID
    final userId = 'me';
    
    final channels = await _channelService.getUserChannels(userId);
    
    setState(() {
      _channels = channels;
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
          'Channels',
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
                  builder: (context) => const CreateChannelScreen(),
                ),
              );
              
              if (result != null) {
                _loadChannels();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _channels.isEmpty
              ? _buildEmptyState(colors)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _channels.length,
                  itemBuilder: (context, index) {
                    final channel = _channels[index];
                    return _ChannelListItem(
                      channel: channel,
                      onTap: () {
                        // TODO: Navigate to channel posts
                        debugPrint('Tap on channel: ${channel['name']}');
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
              Icons.campaign,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No channels yet',
            style: GoogleFonts.firaCode(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first channel!',
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
                  builder: (context) => const CreateChannelScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Channel'),
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

/// 📢 Channel List Item Widget
class _ChannelListItem extends StatelessWidget {
  final Map<String, dynamic> channel;
  final VoidCallback onTap;

  const _ChannelListItem({
    required this.channel,
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
              // Channel avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colors),
                ),
                child: Center(
                  child: Text(
                    _getChannelInitials(channel['name']),
                    style: GoogleFonts.firaCode(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Channel info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and verified badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            channel['name'],
                            style: GoogleFonts.firaCode(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Verified badge
                        if ((channel['is_verified'] as int? ?? 0) == 1)
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 20,
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Subscriber count
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${channel['subscriber_count'] ?? 0} subscribers',
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

  String _getChannelInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    
    final names = name.split(' ');
    if (names.length == 1) return names[0].substring(0, 1).toUpperCase();
    return '${names[0].substring(0, 1)}${names[names.length - 1].substring(0, 1)}'.toUpperCase();
  }
}
