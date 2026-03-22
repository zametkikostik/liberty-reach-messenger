import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/openrouter_ai_service.dart';

/// 🤖 AI Assistant Screen
///
/// Интерфейс для работы с AI через OpenRouter:
/// - Чат с AI
/// - Перевод текста
/// - Саммаризация
/// - Генерация кода
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _aiService = OpenRouterAIService.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String _selectedMode = 'chat'; // chat, translate, summarize, code

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkConfiguration() {
    if (!_aiService.isConfigured) {
      setState(() {
        _messages.add({
          'role': 'system',
          'content': '⚠️ OpenRouter API not configured.\n\nPlease set OPENROUTER_API_KEY in your environment variables or rebuild the app with:\n\n--dart-define=OPENROUTER_API_KEY=your_key',
        });
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'content': text,
      });
      _isLoading = true;
    });

    String response;

    switch (_selectedMode) {
      case 'translate':
        response = await _aiService.translate(
          text: text,
          targetLanguage: 'Russian',
        );
        break;
      case 'summarize':
        response = await _aiService.summarize(text: text);
        break;
      case 'code':
        response = await _aiService.generateCode(
          prompt: text,
          language: 'dart',
        );
        break;
      default:
        response = await _aiService.chat(
          message: text,
          conversationHistory: _messages
              .map((m) => {'role': m['role']!, 'content': m['content']!})
              .toList(),
        );
    }

    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': response,
      });
      _isLoading = false;
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '🤖 AI Assistant',
          style: GoogleFonts.firaCode(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, color: Colors.white70),
            onSelected: (value) {
              setState(() => _selectedMode = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'chat',
                child: Text('💬 Чат'),
              ),
              const PopupMenuItem(
                value: 'translate',
                child: Text('🌍 Перевод'),
              ),
              const PopupMenuItem(
                value: 'summarize',
                child: Text('📝 Саммаризация'),
              ),
              const PopupMenuItem(
                value: 'code',
                child: Text('💻 Генерация кода'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Индикатор режима
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFFFF0080).withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeChip('chat', '💬 Чат'),
                const SizedBox(width: 8),
                _buildModeChip('translate', '🌍 Перевод'),
                const SizedBox(width: 8),
                _buildModeChip('summarize', '📝 Краткое'),
                const SizedBox(width: 8),
                _buildModeChip('code', '💻 Код'),
              ],
            ),
          ),

          // Сообщения
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['role'] == 'user';
                      return _buildMessageBubble(message, isUser);
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
                      hintText: _getHint(),
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
                  backgroundColor: _isLoading ? Colors.grey : const Color(0xFFFF0080),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: _isLoading ? null : _sendMessage,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String mode, String label) {
    final isSelected = _selectedMode == mode;
    return Chip(
      label: Text(label, style: GoogleFonts.firaCode(fontSize: 12)),
      backgroundColor: isSelected
          ? const Color(0xFFFF0080)
          : Colors.white.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'AI Assistant',
            style: GoogleFonts.firaCode(
              color: Colors.white.withOpacity(0.5),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a mode and start chatting!',
            style: GoogleFonts.firaCode(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> message, bool isUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0xFFFF0080).withOpacity(0.8)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message['role'] == 'system')
                  Row(
                    children: [
                      Icon(Icons.warning, size: 14, color: Colors.orange.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text(
                        'System',
                        style: GoogleFonts.firaCode(
                          fontSize: 10,
                          color: Colors.orange.withOpacity(0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                Text(
                  message['content']!,
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getHint() {
    switch (_selectedMode) {
      case 'translate':
        return 'Enter text to translate to Russian...';
      case 'summarize':
        return 'Enter text to summarize...';
      case 'code':
        return 'Describe the code you need...';
      default:
        return 'Ask AI anything...';
    }
  }
}
