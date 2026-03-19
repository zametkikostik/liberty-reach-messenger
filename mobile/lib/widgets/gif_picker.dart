import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/giphy_service.dart';
import '../services/theme_service.dart';

/// 🎬 GIF Picker Dialog
///
/// Features:
/// - Search bar
/// - Trending GIFs
/// - Search results
/// - Tap to select
class GifPickerSheet extends StatefulWidget {
  final Function(String gifUrl) onGifSelected;

  const GifPickerSheet({
    super.key,
    required this.onGifSelected,
  });

  @override
  State<GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<GifPickerSheet>
    with TickerProviderStateMixin {
  final GiphyService _giphyService = GiphyService.instance;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _gifs = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _giphyService.init();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() {
      _isLoading = true;
      _isSearching = false;
    });

    final gifs = await _giphyService.getTrending(limit: 30);
    
    setState(() {
      _gifs = gifs;
      _isLoading = false;
    });
  }

  Future<void> _searchGifs(String query) async {
    if (query.isEmpty) {
      _loadTrending();
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    final gifs = await _giphyService.search(query: query, limit: 30);
    
    setState(() {
      _gifs = gifs;
      _isLoading = false;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: themeService.isGhostMode
            ? const Color(0xFF1A1A2E)
            : const Color(0xFF2E1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors[0].withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.firaCode(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search GIFs...',
                      hintStyle: GoogleFonts.firaCode(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                _loadTrending();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                    ),
                    onSubmitted: _searchGifs,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _searchGifs(_searchController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors[0],
                    foregroundColor: themeService.isGhostMode
                        ? const Color(0xFF0A0A0F)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            // GIF Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossMaxCount(
                  crossMaxCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _gifs.length,
                itemBuilder: (context, index) {
                  final gif = _gifs[index];
                  return _GifTile(
                    gif: gif,
                    onTap: () {
                      final url = _giphyService.getGifUrl(gif);
                      if (url.isNotEmpty) {
                        widget.onGifSelected(url);
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

/// 🎬 GIF Tile Widget
class _GifTile extends StatelessWidget {
  final Map<String, dynamic> gif;
  final VoidCallback onTap;

  const _GifTile({
    required this.gif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.black.withOpacity(0.2),
          child: CachedNetworkImage(
            imageUrl: gif['previewUrl'] ?? '',
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}

/// 🎬 GIF Button for MessageInput
class GifButton extends StatelessWidget {
  final Function(String gifUrl) onGifSelected;

  const GifButton({
    super.key,
    required this.onGifSelected,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return IconButton(
      icon: const Icon(Icons.gif, size: 28),
      color: colors[0],
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => GifPickerSheet(
            onGifSelected: onGifSelected,
          ),
        );
      },
    );
  }
}
