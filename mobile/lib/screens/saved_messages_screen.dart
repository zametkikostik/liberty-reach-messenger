import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/saved_messages_service.dart';

/// ⭐ Saved Messages Screen
class SavedMessagesScreen extends StatefulWidget {
  const SavedMessagesScreen({super.key});

  @override
  State<SavedMessagesScreen> createState() => _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends State<SavedMessagesScreen> {
  final _savedMessagesService = SavedMessagesService.instance;
  List<SavedMessage> _savedMessages = [];

  @override
  void initState() {
    super.initState();
    _loadSavedMessages();
  }

  void _loadSavedMessages() {
    setState(() {
      _savedMessages = _savedMessagesService.getSavedMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Избранное',
          style: GoogleFonts.firaCode(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _savedMessages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_border,
                    size: 64,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет сохранённых сообщений',
                    style: GoogleFonts.firaCode(
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _savedMessages.length,
              itemBuilder: (context, index) {
                final savedMessage = _savedMessages[index];
                return _buildMessageCard(savedMessage);
              },
            ),
    );
  }

  Widget _buildMessageCard(SavedMessage savedMessage) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Chat: ${savedMessage.message.chatId}',
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              savedMessage.message.text,
              style: GoogleFonts.firaCode(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(
                  'Удалить',
                  style: GoogleFonts.firaCode(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.withOpacity(0.8),
                ),
                onPressed: () => _removeMessage(savedMessage.message.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeMessage(String messageId) async {
    _savedMessagesService.removeMessage(messageId);
    _loadSavedMessages();
  }
}
