import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/saved_messages_service.dart';
import '../services/theme_service.dart';
import '../providers/profile_provider.dart';

/// 💾 Saved Messages Screen
///
/// View all saved/favorite messages with:
/// - Search by tags
/// - Filter by date
/// - Remove from saved
/// - Tap to view original context
class SavedMessagesScreen extends StatefulWidget {
  const SavedMessagesScreen({super.key});

  @override
  State<SavedMessagesScreen> createState() => _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends State<SavedMessagesScreen> {
  final SavedMessagesService _savedService = SavedMessagesService.instance;
  
  List<Map<String, dynamic>> _savedMessages = [];
  List<String> _allTags = [];
  String? _selectedTag;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedMessages();
  }

  Future<void> _loadSavedMessages() async {
    setState(() => _isLoading = true);
    
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    // TODO: Get real user ID
    final userId = profileProvider.initials ?? 'me';
    
    // Get saved messages
    List<Map<String, dynamic>> messages;
    if (_selectedTag != null) {
      messages = await _savedService.searchByTag(
        userId: userId,
        tag: _selectedTag!,
      );
    } else {
      messages = await _savedService.getSavedMessages(userId: userId);
    }
    
    // Get all tags
    final tags = await _savedService.getAllTags(userId);
    
    setState(() {
      _savedMessages = messages;
      _allTags = tags;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Messages',
              style: GoogleFonts.firaCode(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_savedMessages.length} saved',
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
        ],
      ),
      body: Column(
        children: [
          // Tags filter
          if (_allTags.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _allTags.length + 1, // +1 for "All"
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // "All" tag
                    final isSelected = _selectedTag == null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedTag = null);
                          _loadSavedMessages();
                        },
                        backgroundColor: Colors.white.withOpacity(0.1),
                        selectedColor: colors[0].withOpacity(0.3),
                        labelStyle: GoogleFonts.firaCode(
                          color: isSelected ? colors[0] : Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  
                  final tag = _allTags[index - 1];
                  final isSelected = _selectedTag == tag;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('#$tag'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTag = selected ? tag : null;
                        });
                        _loadSavedMessages();
                      },
                      backgroundColor: Colors.white.withOpacity(0.1),
                      selectedColor: colors[0].withOpacity(0.3),
                      labelStyle: GoogleFonts.firaCode(
                        color: isSelected ? colors[0] : Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Loading indicator
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_savedMessages.isEmpty)
            // Empty state
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: colors),
                      ),
                      child: const Icon(
                        Icons.bookmark_border,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No saved messages',
                      style: GoogleFonts.firaCode(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Long-press on messages to save them',
                      style: GoogleFonts.firaCode(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Messages list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _savedMessages.length,
                itemBuilder: (context, index) {
                  final message = _savedMessages[index];
                  final tags = (message['tags'] as String?)?.split(',') ?? [];
                  
                  return SavedMessageCard(
                    message: message,
                    tags: tags.where((t) => t.isNotEmpty).toList(),
                    onRemove: () async {
                      final profileProvider = Provider.of<ProfileProvider>(
                        context,
                        listen: false,
                      );
                      final userId = profileProvider.initials ?? 'me';
                      
                      final success = await _savedService.removeMessage(
                        messageId: message['message_id'],
                        userId: userId,
                      );
                      
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Removed from saved'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        _loadSavedMessages();
                      }
                    },
                    onTap: () {
                      // TODO: Navigate to original chat context
                      debugPrint('Tap on saved: ${message['message_id']}');
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
