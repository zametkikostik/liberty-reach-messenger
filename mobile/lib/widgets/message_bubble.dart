import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/storage_service.dart';
import '../services/self_destruct_service.dart';
import '../services/emoji_reactions_service.dart';
import '../widgets/emoji_reactions.dart';

/// 💬 Message Bubble Widget
///
/// Features:
/// - Text messages with E2EE decryption
/// - Image messages from IPFS CID
/// - Love particle effect for special messages
/// - Adaptive theme (Ghost/Love)
class MessageBubble extends StatefulWidget {
  final String text;
  final bool isMe;
  final String? imageCid;
  final String? messageType; // 'text' or 'image'
  final String? nonce; // For decryption
  final DateTime timestamp;
  final bool isLoveMessage;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    this.imageCid,
    this.messageType,
    this.nonce,
    required this.timestamp,
    this.isLoveMessage = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with TickerProviderStateMixin {
  late AnimationController _loveController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  final StorageService _storageService = StorageService();
  final EmojiReactionsService _reactionsService = EmojiReactionsService.instance;
  Uint8List? _decryptedImageBytes;
  bool _isDecrypting = false;
  Map<String, Map<String, dynamic>> _reactions = {};
  bool _showReactionPicker = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _decryptImageIfNeeded();
    _loadReactions();
  }

  Future<void> _loadReactions() async {
    final reactions = await _reactionsService.getMessageReactions(
      'msg-${widget.timestamp.millisecondsSinceEpoch}',
    );
    
    final grouped = <String, Map<String, dynamic>>{};
    for (final reaction in reactions) {
      final type = reaction['reaction_type'] as String;
      if (!grouped.containsKey(type)) {
        grouped[type] = {'count': 0, 'users': []};
      }
      grouped[type]!['count'] = (grouped[type]!['count'] as int) + 1;
      (grouped[type]!['users'] as List).add(reaction['user_id']);
    }
    
    setState(() => _reactions = grouped);
  }

  void _initAnimations() {
    _loveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loveController,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loveController,
        curve: Curves.easeOut,
      ),
    );

    if (widget.isLoveMessage) {
      _loveController.forward();
    }
  }

  Future<void> _decryptImageIfNeeded() async {
    if (widget.messageType != 'image' || widget.nonce == null) return;
    
    setState(() => _isDecrypting = true);
    
    try {
      final decrypted = await _storageService.downloadAndDecryptFile(
        cid: widget.imageCid ?? widget.text,
        nonce: widget.nonce!,
      );
      
      setState(() {
        _decryptedImageBytes = decrypted;
        _isDecrypting = false;
      });
    } catch (e) {
      debugPrint('❌ Image decryption error: $e');
      setState(() => _isDecrypting = false);
    }
  }

  @override
  void dispose() {
    _loveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!widget.isMe) ...[
            // Avatar placeholder
            CircleAvatar(
              radius: 16,
              backgroundColor: colors[0].withOpacity(0.3),
              child: Text(
                '?',
                style: GoogleFonts.firaCode(
                  fontSize: 12,
                  color: colors[0],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          // Long-press for context menu and reactions
          GestureDetector(
            onLongPress: () {
              setState(() => _showReactionPicker = !_showReactionPicker);
            },
            child: Flexible(
              child: Column(
              crossAxisAlignment: widget.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Message bubble
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: widget.isMe
                        ? LinearGradient(colors: colors)
                        : LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isMe
                            ? colors[0].withOpacity(0.3)
                            : Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Voice message
                      if (widget.messageType == 'voice')
                        _VoiceMessagePlayer(
                          cid: widget.text,
                          nonce: widget.nonce,
                          isMe: widget.isMe,
                        ),
                      
                      if (widget.messageType == 'voice')
                        const SizedBox(height: 8),
                      
                      // GIF message
                      if (widget.messageType == 'gif')
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: widget.text,
                            placeholder: (context, url) => Container(
                              height: 200,
                              color: Colors.white.withOpacity(0.1),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              color: Colors.white.withOpacity(0.1),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                              ),
                            ),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 200,
                          ),
                        ),
                      
                      if (widget.messageType == 'gif')
                        const SizedBox(height: 8),
                      
                      // Image message
                      if (widget.messageType == 'image' || _isImageCid(widget.text))
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _isDecrypting
                              ? Container(
                                  height: 200,
                                  color: Colors.white.withOpacity(0.1),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _decryptedImageBytes != null
                                  ? Image.memory(
                                      _decryptedImageBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 200,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl:
                                          'https://gateway.pinata.cloud/ipfs/${widget.imageCid ?? widget.text}',
                                      placeholder: (context, url) => Container(
                                        height: 200,
                                        color: Colors.white.withOpacity(0.1),
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        height: 200,
                                        color: Colors.white.withOpacity(0.1),
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.white54,
                                        ),
                                      ),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 200,
                                    ),
                        ),
                      
                      if ((widget.messageType == 'image' || _isImageCid(widget.text)) && widget.messageType != 'gif')
                        const SizedBox(height: 8),
                      
                      // Text message
                      if (widget.messageType == 'text' || widget.messageType == null)
                        Text(
                          widget.text,
                          style: GoogleFonts.firaCode(
                            fontSize: 14,
                            color: widget.isMe
                                ? (themeService.isGhostMode
                                    ? const Color(0xFF0A0A0F)
                                    : Colors.white)
                                : Colors.white,
                          ),
                        ),
                      
                      // Timestamp
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(widget.timestamp),
                            style: GoogleFonts.firaCode(
                              fontSize: 10,
                              color: (widget.isMe
                                      ? (themeService.isGhostMode
                                          ? Colors.black54
                                          : Colors.white70)
                                      : Colors.white54)),
                            ),
                          // Self-destruct timer
                          if (widget.messageType == 'text' || widget.messageType == null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: SelfDestructTimerWidget(
                                messageId: 'msg-${widget.timestamp.millisecondsSinceEpoch}',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Love particle effect overlay
                if (widget.isLoveMessage)
                  SizedBox(
                    height: 100,
                    child: Stack(
                      children: [
                        FadeTransition(
                          opacity: _opacityAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: CustomPaint(
                              size: const Size(200, 100),
                              painter: LoveParticlePainter(
                                colors: colors,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          if (widget.isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Check if text looks like an IPFS CID
  bool _isImageCid(String text) {
    // IPFS CIDs typically start with Qm or are base64/base58 encoded
    return text.startsWith('Qm') || text.startsWith('bafy');
  }
}

/// 💖 Love Particle Painter
///
/// Draws golden particle effect for love messages
class LoveParticlePainter extends CustomPainter {
  final List<Color> colors;
  final math.Random _random = math.Random();

  LoveParticlePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Draw golden particles
    for (int i = 0; i < 30; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height * 0.5;
      final radius = _random.nextDouble() * 3 + 1;
      final opacity = _random.nextDouble() * 0.5 + 0.3;

      paint.color = Colors.amber.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Draw heart shape in center
    final heartPath = _createHeartPath(size);
    paint.shader = RadialGradient(
      colors: [
        colors[0].withOpacity(0.8),
        colors[1].withOpacity(0.6),
        Colors.transparent,
      ],
    ).createShader(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: size.height,
      ),
    );
    
    canvas.drawPath(heartPath, paint);
  }

  Path _createHeartPath(Size size) {
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2 + 10;
    final scale = size.width / 4;

    path.moveTo(centerX, centerY - scale * 0.5);
    
    // Left lobe
    path.cubicTo(
      centerX - scale * 0.5,
      centerY - scale,
      centerX - scale,
      centerY - scale * 0.5,
      centerX,
      centerY + scale * 0.5,
    );
    
    // Right lobe
    path.cubicTo(
      centerX + scale,
      centerY - scale * 0.5,
      centerX + scale * 0.5,
      centerY - scale,
      centerX,
      centerY - scale * 0.5,
    );
    
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(LoveParticlePainter oldDelegate) => false;
}

/// 🎤 Voice Message Player Widget
class _VoiceMessagePlayer extends StatefulWidget {
  final String cid;
  final String? nonce;
  final bool isMe;

  const _VoiceMessagePlayer({
    required this.cid,
    this.nonce,
    required this.isMe,
  });

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMe
            ? colors[0].withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isMe
                  ? colors[0]
                  : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isPlaying = !_isPlaying;
              });
              // TODO: Implement play logic with voice_messages_service
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),

          // Waveform visualization
          Expanded(
            child: Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: CustomPaint(
                painter: _WaveformPainter(
                  progress: _duration.inSeconds > 0
                      ? _position.inSeconds / _duration.inSeconds
                      : 0.0,
                  color: widget.isMe ? colors[0] : Colors.white,
                ),
              ),
            ),
          ),

          // Duration
          Text(
            _formatDuration(_duration),
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// 🎵 Waveform Painter
class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveformPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final playedWidth = size.width * progress;

    // Played portion
    canvas.drawRect(
      Rect.fromLTWH(0, 0, playedWidth, size.height),
      paint,
    );

    // Unplayed portion
    paint.color = color.withOpacity(0.2);
    canvas.drawRect(
      Rect.fromLTWH(playedWidth, 0, size.width - playedWidth, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// ✨ Check if message contains "love" keyword
bool isLoveMessage(String text) {
  final loveKeywords = [
    'love',
    'люблю',
    'любим',
    'amour',
    'liebe',
    'amor',
    'amore',
    '愛',
    '사랑',
  ];
  
  final lowerText = text.toLowerCase();
  return loveKeywords.any((keyword) => lowerText.contains(keyword));
}
