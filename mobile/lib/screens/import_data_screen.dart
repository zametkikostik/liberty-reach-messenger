import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/d1_api_service.dart';
import '../providers/profile_provider.dart';

/// 📥 Import Data Screen — Перенос из Telegram и WhatsApp
///
/// Features:
/// - Импорт из Telegram Desktop (JSON)
/// - Импорт из WhatsApp (TXT)
/// - Прогресс импорта
/// - Статистика
class ImportDataScreen extends StatefulWidget {
  const ImportDataScreen({super.key});

  @override
  State<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends State<ImportDataScreen> {
  final D1ApiService _d1Service = D1ApiService();
  bool _isImporting = false;
  String? _status;
  ImportStats? _stats;

  @override
  void initState() {
    super.initState();
    _initD1();
  }

  Future<void> _initD1() async {
    await _d1Service.init();
  }

  Future<void> _pickAndImport(String source) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: source == 'telegram' ? ['json'] : ['txt'],
    );

    if (result == null) return;

    final file = result.files.first;
    setState(() {
      _isImporting = true;
      _status = 'Чтение файла...';
    });

    try {
      // Чтение файла
      final bytes = await file.xFile.readAsBytes();
      final content = String.fromCharCodes(bytes);

      // Парсинг и импорт
      if (source == 'telegram') {
        await _importFromTelegram(content);
      } else {
        await _importFromWhatsApp(content);
      }

      setState(() {
        _status = '✅ Готово!';
      });

      // Показываем результат
      _showStatsDialog();
    } catch (e) {
      setState(() {
        _status = '❌ Ошибка: $e';
      });
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  Future<void> _importFromTelegram(String jsonContent) async {
    // TODO: Парсинг JSON Telegram
    // Для покажем заглушку
    await Future.delayed(const Duration(seconds: 2));
    
    _stats = ImportStats(
      chats: 0,
      messages: 0,
      contacts: 0,
    );
  }

  Future<void> _importFromWhatsApp(String txtContent) async {
    // TODO: Парсинг TXT WhatsApp
    // Для покажем заглушку
    await Future.delayed(const Duration(seconds: 2));
    
    _stats = ImportStats(
      chats: 0,
      messages: 0,
      contacts: 0,
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Импорт завершён'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📁 Чатов: ${_stats?.chats ?? 0}'),
            Text('💬 Сообщений: ${_stats?.messages ?? 0}'),
            Text('👥 Контактов: ${_stats?.contacts ?? 0}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Импорт данных'),
        backgroundColor: colors[0],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.telegram, color: Colors.blue),
                title: const Text('Импорт из Telegram'),
                subtitle: const Text('JSON экспорт из Telegram Desktop'),
                onTap: _isImporting ? null : () => _pickAndImport('telegram'),
                enabled: !_isImporting,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.message, color: Colors.green),
                title: const Text('Импорт из WhatsApp'),
                subtitle: const Text('TXT экспорт чатов'),
                onTap: _isImporting ? null : () => _pickAndImport('whatsapp'),
                enabled: !_isImporting,
              ),
            ),
            if (_isImporting) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              if (_status != null) ...[
                const SizedBox(height: 16),
                Text(
                  _status!,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ],
            const SizedBox(height: 24),
            Card(
              color: colors[0].withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📖 Как экспортировать из Telegram:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Открой Telegram Desktop'),
                    const Text('2. Настройки → Продвинутые → Экспорт данных'),
                    const Text('3. Выбери JSON формат'),
                    const Text('4. Сохрани папку'),
                    const SizedBox(height: 16),
                    const Text(
                      '📖 Как экспортировать из WhatsApp:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Открой чат'),
                    const Text('2. Меню → Ещё → Экспорт чата'),
                    const Text('3. Без медиа (быстрее)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Статистика импорта
class ImportStats {
  final int chats;
  final int messages;
  final int contacts;

  ImportStats({
    required this.chats,
    required this.messages,
    required this.contacts,
  });
}
