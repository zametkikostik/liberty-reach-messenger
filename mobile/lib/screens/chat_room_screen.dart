import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../services/theme_service.dart';
import '../services/storage_service.dart';
import '../services/d1_api_service.dart';
import '../services/self_destruct_service.dart';
import '../services/pinned_messages_service.dart';
import '../services/saved_messages_service.dart';
import '../services/group_chats_service.dart';
import '../services/voice_messages_service.dart';
import '../services/emoji_reactions_service.dart';
import '../services/native_audio_call_service.dart';
import '../providers/profile_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/gif_picker.dart';
import '../widgets/self_destruct_timer.dart';
import '../screens/audio_call_screen.dart';

/// 💬 Chat Room Screen - 1-on-1 Messages
///
/// Features:
/// - Message list with bubbles
/// - Text input with emoji picker
/// - Image attachments (Pinata IPFS)
/// - Ghost/Love adaptive theme
class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String userId;
  final String userName;
  final bool isGroup; // NEW: Group chat flag

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.userId,
    required this.userName,
    this.isGroup = false, // Default to 1-on-1
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final D1ApiService _d1Service = D1ApiService();
  final _uuid = const Uuid();
  final VoiceMessagesService _voiceService = VoiceMessagesService.instance;

  final GroupChatsService _groupChatsService = GroupChatsService.instance;

  bool _showEmojiPicker = false;
  bool _isUploading = false;
  bool _isLoading = true;
  bool _isRecording = false; // Voice recording state
  String? _currentUserId;
  String? _selfDestructTimer; // '1m', '5m', '1h', '1d', '1w'

  // Messages from D1
  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _pinnedMessages = [];

  @override
  void initState() {
    super.initState();
    _initD1();
  }

  Future<void> _initD1() async {
    await _d1Service.init();
    await _loadMessages();
    await _loadPinnedMessages();
    setState(() => _isLoading = false);
  }

  Future<void> _loadPinnedMessages() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final userId = profileProvider.initials ?? 'me';
    
    final pinned = await PinnedMessagesService.instance.getPinnedMessages(
      userId1: userId,
      userId2: widget.userId,
    );
    
    setState(() => _pinnedMessages = pinned);
  }

  Future<void> _loadMessages() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    _currentUserId = profileProvider.initials; // TODO: Get real user ID

    List<Map<String, dynamic>> messages;
    
    if (widget.isGroup) {
      // Load group messages
      messages = await _groupChatsService.getGroupMessages(
        groupId: widget.chatId,
        limit: 50,
      );
    } else {
      // Load 1-on-1 messages
      messages = await _d1Service.getMessages(
        userId1: _currentUserId ?? 'me',
        userId2: widget.userId,
        limit: 50,
      );
    }

    setState(() {
      _messages.clear();
      _messages.addAll(messages.map((msg) => {
        'id': msg['id'],
        'sender_id': msg['sender_id'],
        'text': msg['text'],
        'type': msg['type'] ?? 'text',
        'timestamp': DateTime.fromMillisecondsSinceEpoch(
          (msg['created_at'] as int?) ?? 0,
        ),
        'is_love_immutable': msg['is_love_immutable'] ?? 0,
        'nonce': msg['nonce'],
      }));
    });

    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: colors),
              ),
              child: Center(
                child: Text(
                  _getInitials(widget.userName),
                  style: GoogleFonts.firaCode(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: GoogleFonts.firaCode(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Online',
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Voice call
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // TODO: Start voice call
            },
          ),
          // Video call
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // TODO: Start video call
            },
          ),
          // More options
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 12),
                    Text('Search'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'media',
                child: Row(
                  children: [
                    Icon(Icons.photo_library),
                    SizedBox(width: 12),
                    Text('Media'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 12),
                    Text('Chat Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Pinned messages banner
          if (_pinnedMessages.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _pinnedMessages.length,
                itemBuilder: (context, index) {
                  final message = _pinnedMessages[index];
                  return SizedBox(
                    width: 300,
                    child: PinnedMessageBanner(
                      message: message,
                      onUnpin: () {
                        _unpinMessage(message['id']);
                        _loadPinnedMessages();
                      },
                      onTap: () {
                        // Scroll to message
                        debugPrint('Tap on pinned: ${message['id']}');
                      },
                    ),
                  );
                },
              ),
            ),

          // Message list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState(colors)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return MessageBubble(
                            text: message['text'],
                            isMe: message['sender_id'] == _currentUserId,
                            timestamp: message['timestamp'],
                            isLoveMessage: message['is_love_immutable'] == true,
                            messageType: message['type'],
                            nonce: message['nonce'],
                          );
                        },
                      ),
          ),

          // Upload indicator
          if (_isUploading) _buildUploadIndicator(colors),

          // Message input
          _buildMessageInput(colors),
        ],
      ),
    );
  }

  Widget _buildEmptyState(List<Color> colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: colors),
              boxShadow: [
                BoxShadow(
                  color: colors[0].withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No messages yet',
            style: GoogleFonts.firaCode(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Say hello! 👋',
            style: GoogleFonts.firaCode(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadIndicator(List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Encrypting & uploading to IPFS...',
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(List<Color> colors) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: themeService.isGhostMode
            ? const Color(0xFF1A1A2E)
            : const Color(0xFF2E1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji picker (custom simple version)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildSimpleEmojiPicker(),
            crossFadeState: _showEmojiPicker
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),

          // Input row
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Attachment button
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: colors[0],
                  onPressed: _isUploading ? null : _showAttachmentOptions,
                  iconSize: 28,
                ),

                // Timer button
                TimerButton(
                  currentTimer: _selfDestructTimer,
                  onTimerSelected: (key) {
                    setState(() {
                      _selfDestructTimer = key == 'cancel' ? null : key;
                    });
                  },
                ),

                // Text input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors[0].withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: GoogleFonts.firaCode(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              hintStyle: GoogleFonts.firaCode(
                                color: Colors.white.withOpacity(0.3),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: 4,
                            minLines: 1,
                          ),
                        ),
                        // GIF button
                        GifButton(
                          onGifSelected: (gifUrl) {
                            // Send GIF as message
                            _sendGifMessage(gifUrl);
                          },
                        ),
                        // Emoji button
                        IconButton(
                          icon: Icon(
                            _showEmojiPicker
                                ? Icons.keyboard
                                : Icons.emoji_emotions,
                          ),
                          color: colors[0],
                          onPressed: () {
                            setState(() {
                              _showEmojiPicker = !_showEmojiPicker;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors[0].withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onLongPress: _isRecording ? null : _startVoiceRecording,
                    onLongPressUp: _isRecording ? _stopVoiceRecording : null,
                    onTapUp: (_) {
                      if (_isRecording) {
                        _cancelVoiceRecording();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors[0].withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording
                            ? Icons.stop  // Stop recording
                            : (_messageController.text.isEmpty
                                ? Icons.mic  // Start recording
                                : Icons.send),  // Send message
                        color: themeService.isGhostMode
                            ? const Color(0xFF0A0A0F)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Send text message to D1
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final senderId = profileProvider.initials ?? 'me'; // TODO: Get real user ID

    // Check if message contains "love" keyword
    final isLove = isLoveMessage(text);

    // Generate message ID
    final messageId = _uuid.v4();
    final timestamp = DateTime.now();

    // Add to local list immediately (optimistic UI)
    setState(() {
      _messages.add({
        'id': messageId,
        'sender_id': senderId,
        'text': text,
        'type': 'text',
        'timestamp': timestamp,
        'is_love_immutable': isLove,
        'nonce': '',
      });
      _messageController.clear();
      _showEmojiPicker = false;
    });

    // Scroll to bottom
    _scrollToBottom();

    // Send to D1
    try {
      final result = await _d1Service.sendMessage(
        messageId: messageId,
        senderId: senderId,
        recipientId: widget.userId,
        encryptedText: text, // TODO: Encrypt with E2EE
        nonce: '', // TODO: Generate nonce
        isLoveToken: isLove,
      );
      
      // Set self-destruct timer if enabled
      if (_selfDestructTimer != null && result != null) {
        await SelfDestructService.instance.setTimer(
          messageId: messageId,
          durationKey: _selfDestructTimer!,
        );
      }
      
      debugPrint('✅ Message sent to D1');
    } catch (e) {
      debugPrint('❌ Send message error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send GIF message
  void _sendGifMessage(String gifUrl) {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final senderId = profileProvider.initials ?? 'me';
    final messageId = _uuid.v4();

    setState(() {
      _messages.add({
        'id': messageId,
        'sender_id': senderId,
        'text': gifUrl,
        'type': 'gif',
        'timestamp': DateTime.now(),
        'is_love_immutable': false,
        'nonce': '',
      });
    });

    _scrollToBottom();

    // Send to D1 (GIF URL as is, or encrypt if needed)
    _d1Service.sendMessage(
      messageId: messageId,
      senderId: senderId,
      recipientId: widget.userId,
      encryptedText: gifUrl,
      nonce: '',
      isLoveToken: false,
    );
  }

  /// Start voice recording
  Future<void> _startVoiceRecording() async {
    try {
      final path = await _voiceService.startRecording();
      if (path != null) {
        setState(() => _isRecording = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mic, color: Colors.red),
                const SizedBox(width: 12),
                Text('Recording...'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Start recording error: $e');
    }
  }

  /// Stop voice recording and send
  Future<void> _stopVoiceRecording() async {
    try {
      setState(() => _isRecording = false);

      final file = await _voiceService.stopRecording();
      if (file == null) return;

      // Upload to IPFS
      final result = await _voiceService.uploadVoiceMessage(file);
      if (result == null) return;

      final cid = result['cid'];
      final nonce = result['nonce'];

      // Send as voice message
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final senderId = profileProvider.initials ?? 'me';
      final messageId = _uuid.v4();

      setState(() {
        _messages.add({
          'id': messageId,
          'sender_id': senderId,
          'text': cid,
          'type': 'voice',
          'nonce': nonce,
          'timestamp': DateTime.now(),
          'is_love_immutable': false,
        });
      });

      _scrollToBottom();

      // Send to D1
      if (widget.isGroup) {
        await _groupChatsService.sendGroupMessage(
          groupId: widget.chatId,
          senderId: senderId,
          encryptedText: cid,
          nonce: nonce,
          messageType: 'voice',
        );
      } else {
        await _d1Service.sendMessage(
          messageId: messageId,
          senderId: senderId,
          recipientId: widget.userId,
          encryptedText: cid,
          nonce: nonce,
          isLoveToken: false,
        );
      }

      debugPrint('✅ Voice message sent');
    } catch (e) {
      debugPrint('❌ Send voice message error: $e');
    }
  }

  /// Cancel voice recording
  Future<void> _cancelVoiceRecording() async {
    try {
      await _voiceService.cancelRecording();
      setState(() => _isRecording = false);
      debugPrint('🗑️ Voice recording cancelled');
    } catch (e) {
      debugPrint('❌ Cancel recording error: $e');
    }
  }

  /// Show message context menu
  void _showMessageContextMenu({
    required BuildContext context,
    required Map<String, dynamic> message,
    required Offset tapPosition,
  }) {
    final isMe = message['sender_id'] == _currentUserId;
    final isPinned = message['is_pinned'] == 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: themeService.isGhostMode
              ? const Color(0xFF1A1A2E)
              : const Color(0xFF2E1A2E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.more_vert, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Message Options',
                    style: GoogleFonts.firaCode(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Pin/Unpin option
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                color: Colors.amber,
              ),
              title: Text(
                isPinned ? 'Unpin Message' : 'Pin Message',
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                isPinned ? 'Remove from top of chat' : 'Show at top of chat',
                style: GoogleFonts.firaCode(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (isPinned) {
                  _unpinMessage(message['id']);
                } else {
                  _pinMessage(message['id']);
                }
              },
            ),

            // Save/Remove from Saved option
            ListTile(
              leading: Icon(
                Icons.bookmark_border,
                color: Colors.blue,
              ),
              title: Text(
                'Save Message',
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                'Add to favorites',
                style: GoogleFonts.firaCode(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _saveMessage(message);
              },
            ),

            // Reply option
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.blue),
              title: Text(
                'Reply',
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _replyToMessage(message);
              },
            ),

            // Copy option (for text messages)
            if (message['type'] == 'text' || message['type'] == null)
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.green),
                title: Text(
                  'Copy Text',
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _copyMessageText(message['text']);
                },
              ),

            // Delete option (only for own messages)
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Delete',
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMessage(message['id']);
                },
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Pin message
  Future<void> _pinMessage(String messageId) async {
    final success = await PinnedMessagesService.instance.pinMessage(
      messageId: messageId,
      chatId: widget.chatId,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.push_pin, color: Colors.amber),
              SizedBox(width: 12),
              Text('Message pinned'),
            ],
          ),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  /// Unpin message
  Future<void> _unpinMessage(String messageId) async {
    final success = await PinnedMessagesService.instance.unpinMessage(messageId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message unpinned'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Reply to message
  void _replyToMessage(Map<String, dynamic> message) {
    // TODO: Implement reply functionality
    debugPrint('Reply to: ${message['text']}');
  }

  /// Copy message text
  void _copyMessageText(String text) {
    // TODO: Implement clipboard copy
    debugPrint('Copy: $text');
  }

  /// Confirm delete message
  void _confirmDeleteMessage(String messageId) {
    // TODO: Implement delete confirmation
    debugPrint('Delete: $messageId');
  }

  /// Save message to favorites
  Future<void> _saveMessage(Map<String, dynamic> message) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final userId = profileProvider.initials ?? 'me';
    
    final success = await SavedMessagesService.instance.saveMessage(
      messageId: message['id'],
      userId: userId,
      tags: null, // User can add tags later
    );
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.bookmark, color: Colors.blue),
              SizedBox(width: 12),
              Text('Message saved'),
            ],
          ),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  /// Show attachment options (Photo, Camera, File)
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Pick file
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Pick and upload image to IPFS + D1
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      // Upload to IPFS with E2EE encryption
      final result = await _storageService.uploadEncryptedFile(File(image.path));
      final cid = result['cid'];
      final nonce = result['nonce'];

      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final senderId = profileProvider.initials ?? 'me';
      final messageId = _uuid.v4();

      // Add message with image CID to local list
      setState(() {
        _messages.add({
          'id': messageId,
          'sender_id': senderId,
          'text': cid,
          'type': 'image',
          'nonce': nonce,
          'timestamp': DateTime.now(),
          'is_love_immutable': false,
        });
        _isUploading = false;
      });

      _scrollToBottom();

      // Send to D1
      try {
        await _d1Service.sendMessage(
          messageId: messageId,
          senderId: senderId,
          recipientId: widget.userId,
          encryptedText: cid, // Store CID
          nonce: nonce, // Store nonce for decryption
          isLoveToken: false,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Image uploaded to IPFS & sent'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ D1 send error: $e');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getInitials(String name) {
    final names = name.split(' ');
    if (names.length == 1) return names[0].substring(0, 1).toUpperCase();
    return '${names[0].substring(0, 1)}${names[names.length - 1].substring(0, 1)}'.toUpperCase();
  }

  /// Simple emoji picker with popular emojis
  Widget _buildSimpleEmojiPicker() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final colors = themeService.gradientColors;
    
    final List<String> emojis = [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
      '🙂', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗',
      '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭',
      '🤫', '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏',
      '😒', '🙄', '😬', '🤥', '😌', '😔', '😪', '🤤',
      '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧', '🥵',
      '❤️', '💛', '💚', '💙', '💜', '🖤', '💔', '❣️',
      '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟',
      '👍', '👎', '👊', '✊', '🤛', '🤜', '🤞', '✌️',
      '🤟', '🤘', '👌', '🤌', '🤏', '👈', '👉', '👆',
      '👇', '☝️', '✋', '🤚', '🖐', '🖖', '👋', '🤙',
      '🙌', '🎉', '✨', '🔥', '🌈', '❤️', '😂', '👍',
    ];

    return Container(
      height: 200,
      color: themeService.isGhostMode
          ? const Color(0xFF0A0A0F)
          : const Color(0xFF0F0A0F),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossMaxCount(
          crossMaxCount: 8,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _messageController.text += emojis[index];
              });
            },
            child: Center(
              child: Text(
                emojis[index],
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }
}
