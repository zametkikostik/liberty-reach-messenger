import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/stories_service.dart';
import '../services/theme_service.dart';
import '../services/storage_service.dart';

/// 📸 Story Viewer — Full Screen Story Viewer
///
/// Features:
/// - Swipe to navigate between stories
/// - Tap to skip
/// - Long press to pause
/// - Progress indicators
/// - Reply to story
/// - View who viewed (for owner)
class StoryViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;
  final String currentUserId;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    required this.currentUserId,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  
  final StoriesService _storiesService = StoriesService();
  final StorageService _storageService = StorageService();
  
  bool _isPaused = false;
  bool _isLoading = true;
  Uint8List? _decryptedImage;
  
  late List<AnimationController> _progressControllers;
  late List<Animation<double>> _progressAnimations;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initProgressAnimations();
    _loadCurrentStory();
  }

  void _initProgressAnimations() {
    final storyCount = widget.stories.length;
    progressControllers = List.generate(
      storyCount,
      (index) => AnimationController(
        duration: const Duration(seconds: 5),
        vsync: this,
      ),
    );
    
    progressAnimations = progressControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.linear),
      );
    }).toList();
  }

  Future<void> _loadCurrentStory() async {
    setState(() => _isLoading = true);
    
    final story = widget.stories[_currentIndex];
    
    // Mark as viewed
    await _storiesService.viewStory(story['id'], widget.currentUserId);
    
    // Decrypt image
    if (story['media_nonce'] != null) {
      try {
        final decrypted = await _storageService.downloadAndDecryptFile(
          cid: story['media_cid'],
          nonce: story['media_nonce'],
        );
        setState(() {
          _decryptedImage = decrypted;
          _isLoading = false;
        });
      } catch (e) {
        debugPrint('❌ Decrypt error: $e');
        setState(() => _isLoading = false);
      }
    }
    
    // Start progress
    if (!_isPaused) {
      progressControllers[_currentIndex].forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Story content
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stories.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              progressControllers[_currentIndex].forward(from: 0.0);
              _loadCurrentStory();
            },
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              return _buildStory(story, colors);
            },
          ),

          // Progress indicators
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              children: List.generate(
                widget.stories.length,
                (index) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _buildProgressIndicator(index),
                  ),
                ),
              ),
            ),
          ),

          // User info and close button
          Positioned(
            top: 40,
            left: 10,
            right: 10,
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: colors),
                  ),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 10),
                // Name and time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stories[_currentIndex]['user_name'] ?? 'User',
                        style: GoogleFonts.firaCode(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _getTimeAgo(widget.stories[_currentIndex]['created_at']),
                        style: GoogleFonts.firaCode(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Reply input
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildReplyInput(),
          ),
        ],
      ),
    );
  }

  Widget _buildStory(Map<String, dynamic> story, List<Color> colors) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPaused = true);
        progressControllers[_currentIndex].stop();
      },
      onTapUp: (_) {
        setState(() => _isPaused = false);
        progressControllers[_currentIndex].forward();
      },
      onTapCancel: () {
        setState(() => _isPaused = false);
        progressControllers[_currentIndex].forward();
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 100) {
          // Swipe left - previous
          if (_currentIndex > 0) {
            progressControllers[_currentIndex].reset();
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        } else if (details.primaryVelocity! < -100) {
          // Swipe right - next
          if (_currentIndex < widget.stories.length - 1) {
            progressControllers[_currentIndex].reset();
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      },
      child: Container(
        color: Colors.black,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _decryptedImage != null
                ? Image.memory(
                    _decryptedImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : CachedNetworkImage(
                    imageUrl: 'https://gateway.pinata.cloud/ipfs/${story['media_cid']}',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  ),
      ),
    );
  }

  Widget _buildProgressIndicator(int index) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: progressAnimations[index],
              builder: (context, child) {
                return FractionallySizedBox(
                  widthFactor: progressAnimations[index].value,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: GoogleFonts.firaCode(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Send a message...',
                hintStyle: GoogleFonts.firaCode(
                  color: Colors.white.withOpacity(0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (text) {
                if (text.isNotEmpty) {
                  _sendReply(text);
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: () {
              // TODO: Send reply
            },
          ),
        ],
      ),
    );
  }

  void _sendReply(String text) {
    final story = widget.stories[_currentIndex];
    _storiesService.replyToStory(
      storyId: story['id'],
      userId: widget.currentUserId,
      replyText: text,
    );
    // Clear input and show confirmation
  }

  String _getTimeAgo(int? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp;
    
    final minutes = (diff / 60000).floor();
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return '$minutes min ago';
    
    final hours = (minutes / 60).floor();
    if (hours < 24) return '$hours hour${hours > 1 ? 's' : ''} ago';
    
    return '${(hours / 24).floor()} day${hours > 48 ? 's' : ''} ago';
  }

  @override
  void dispose() {
    for (final controller in progressControllers) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }
}
