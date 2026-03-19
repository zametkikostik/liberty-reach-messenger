import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/stories_service.dart';
import '../services/theme_service.dart';
import 'story_viewer_screen.dart';

/// 📸 Stories Tray — Horizontal Story List
///
/// Shows at the top of chat list screen.
/// Similar to Telegram/Instagram stories.
class StoriesTray extends StatefulWidget {
  final String currentUserId;

  const StoriesTray({
    super.key,
    required this.currentUserId,
  });

  @override
  State<StoriesTray> createState() => _StoriesTrayState();
}

class _StoriesTrayState extends State<StoriesTray> {
  final StoriesService _storiesService = StoriesService();
  
  List<Map<String, dynamic>> _contactStories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    setState(() => _isLoading = true);
    
    final stories = await _storiesService.getContactStories(widget.currentUserId);
    
    setState(() {
      _contactStories = stories;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_contactStories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _contactStories.length,
        itemBuilder: (context, index) {
          final userStory = _contactStories[index];
          return _StoryItem(
            userName: userStory['user_name'] ?? 'User',
            userAvatar: userStory['user_avatar'],
            hasUnviewed: userStory['has_unviewed'] == true,
            storyCount: (userStory['stories'] as List).length,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoryViewerScreen(
                    stories: userStory['stories'] as List<Map<String, dynamic>>,
                    currentUserId: widget.currentUserId,
                  ),
                ),
              ).then((_) => _loadStories()); // Refresh on return
            },
          );
        },
      ),
    );
  }
}

/// 📸 Story Item Widget
class _StoryItem extends StatelessWidget {
  final String userName;
  final String? userAvatar;
  final bool hasUnviewed;
  final int storyCount;
  final VoidCallback onTap;

  const _StoryItem({
    required this.userName,
    this.userAvatar,
    required this.hasUnviewed,
    required this.storyCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            // Avatar with gradient border
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnviewed
                    ? LinearGradient(colors: colors)
                    : null,
                border: hasUnviewed
                    ? null
                    : Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                child: userAvatar != null
                    ? CachedNetworkImage(
                        imageUrl: 'https://gateway.pinata.cloud/ipfs/$userAvatar',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.person,
                          color: Colors.white54,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white54,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            // Username (truncated)
            SizedBox(
              width: 72,
              child: Text(
                userName.length > 10
                    ? '${userName.substring(0, 10)}...'
                    : userName,
                style: GoogleFonts.firaCode(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 📸 My Story Button — Add Story
class MyStoryButton extends StatelessWidget {
  final String userId;
  final bool hasActiveStory;
  final VoidCallback onTap;

  const MyStoryButton({
    super.key,
    required this.userId,
    required this.hasActiveStory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasActiveStory
                    ? LinearGradient(colors: colors)
                    : null,
                border: !hasActiveStory
                    ? Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                        style: BorderStyle.solid,
                      )
                    : null,
              ),
              child: hasActiveStory
                  ? Stack(
                      children: [
                        ClipOval(
                          child: Container(
                            color: Colors.black,
                            child: const Icon(
                              Icons.person,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: colors[0],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo,
                          color: Colors.white54,
                          size: 28,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: colors[0],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.black,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              hasActiveStory ? 'My Story' : 'Add Story',
              style: GoogleFonts.firaCode(
                fontSize: 11,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
