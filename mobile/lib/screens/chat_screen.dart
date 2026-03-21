import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

/// 💬 Chat Screen - Экран чата
///
/// Material 3, сообщения привязаны к P2P через MethodChannel
class ChatScreen extends StatefulWidget {
  final String contactName;
  final String contactId;

  const ChatScreen({
    super.key,
    required this.contactName,
    required this.contactId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<Message> _messages = [];
  bool _isSending = false;
  
  // 🔗 MethodChannel для P2P
  static const platform = MethodChannel('liberty_reach/p2p');

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupP2PListener();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Загрузка сообщений (демо)
  void _loadMessages() {
    setState(() {
      _messages = [
        Message(
          id: '1',
          chatId: widget.contactId,
          senderId: widget.contactId,
          text: 'Привет! Как дела?',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        Message(
          id: '2',
          chatId: widget.contactId,
          senderId: 'me',
          text: 'Всё отлично! Работаю над новым мессенджером 🚀',
          timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
        Message(
          id: '3',
          chatId: widget.contactId,
          senderId: widget.contactId,
          text: 'Круто! Когда релиз?',
          timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ];
    });
  }

  /// Слушатель P2P сообщений
  void _setupP2PListener() {
    // В production: platform.setMethodCallHandler(...)
  }

  /// Отправка сообщения через P2P
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      // 🔗 Отправка через MethodChannel в Rust-ядро
      final result = await platform.invokeMethod('sendMessage', {
        'chatId': widget.contactId,
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Добавляем сообщение в список
      setState(() {
        _messages.add(Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId: widget.contactId,
          senderId: 'me',
          text: text,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ));
        _messageController.clear();
      });

      // Прокрутка вниз
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } on PlatformException catch (e) {
      // Ошибка P2P - сохраняем локально
      setState(() {
        _messages.add(Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId: widget.contactId,
          senderId: 'me',
          text: text,
          timestamp: DateTime.now(),
          status: MessageStatus.failed,
        ));
        _messageController.clear();
      });
    }

    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    // Инициалы
    final names = widget.contactName.trim().split(' ');
    final initials = names.length > 1
        ? '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase()
        : names[0].substring(0, 2).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // CircleAvatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF0080).withOpacity(0.8),
                    const Color(0xFFBD00FF).withOpacity(0.8),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Имя
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contactName,
                  style: GoogleFonts.firaCode(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'online',
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    color: Colors.green.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white70),
            onPressed: () {
              // TODO: Audio call
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white70),
            onPressed: () {
              // TODO: Video call
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Сообщения
          Expanded(
            child: _messages.isEmpty
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
                          'No messages yet',
                          style: GoogleFonts.firaCode(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say hello! 👋',
                          style: GoogleFonts.firaCode(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == 'me';
                      return _buildMessageBubble(message, isMe);
                    },
                  ),
          ),

          // Поле ввода
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: GoogleFonts.firaCode(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: GoogleFonts.firaCode(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: 5,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: const Color(0xFFFF0080),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFFFF0080).withOpacity(0.8)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.status == MessageStatus.read
                            ? Icons.done_all
                            : Icons.done,
                        size: 14,
                        color: message.status == MessageStatus.read
                            ? Colors.blue
                            : Colors.white.withOpacity(0.6),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
