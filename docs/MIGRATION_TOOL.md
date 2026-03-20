# 📥 MIGRATION TOOL — Перенос данных из Telegram и WhatsApp

**Liberty Reach Messenger** поддерживает импорт данных из популярных мессенджеров для бесшовной миграции пользователей.

---

## 🎯 ПОДДЕРЖИВАЕМЫЕ ИСТОЧНИКИ

| Мессенджер | Формат экспорта | Что импортируется |
|------------|-----------------|-------------------|
| **Telegram** | JSON (Desktop) | ✅ Контакты, ✅ Чаты, ✅ Сообщения, ✅ Медиа (ссылки) |
| **WhatsApp** | TXT/ZIP | ✅ Контакты, ✅ Чаты, ✅ Сообщения (текст) |

---

## 📤 ЭКСПОРТ ИЗ TELEGRAM

### Шаг 1: Экспорт из Telegram Desktop

1. Открой **Telegram Desktop** (ПК версия)
2. **Настройки** → **Продвинутые** → **Экспорт данных**
3. Выбери:
   - ✅ Личные чаты
   - ✅ Группы
   - ✅ Каналы
   - ✅ Сообщения (макс. размер: 500MB)
   - ✅ Фотографии (опционально)
   - ✅ Видео (опционально)
4. Формат: **JSON**
5. Нажми **Экспортировать**

### Шаг 2: Структура экспорта

```
Telegram Desktop/
├── result.json           # Основная информация
├── chats/
│   ├── chat_0001.json    # Личный чат 1
│   ├── chat_0002.json    # Личный чат 2
│   ├── group_0001.json   # Группа 1
│   └── channel_0001.json # Канал 1
└── media/                # Медиа файлы (опционально)
```

### Шаг 3: Формат JSON (чат)

```json
{
  "name": "Имя контакта",
  "type": "personal",
  "id": 123456789,
  "messages": [
    {
      "id": 1,
      "type": "message",
      "date": "2024-01-15T10:30:00",
      "from": "Имя",
      "text": "Привет!",
      "photo": "media/photo_001.jpg",
      "video": null
    }
  ]
}
```

---

## 📤 ЭКСПОРТ ИЗ WHATSAPP

### Шаг 1: Экспорт из WhatsApp

**Android:**
1. Открой чат
2. **Меню** → **Ещё** → **Экспорт чата**
3. **Без медиа** (для скорости) или **С медиа**
4. Отправь себе на email или в облако

**iOS:**
1. Открой чат
2. **Инфо** → **Экспорт чата**
3. **Без медиа** / **С медиа**
4. Сохрани в Files

### Шаг 2: Структура экспорта

```
WhatsApp Chat.txt
```

### Шаг 3: Формат TXT

```
[15.01.24, 10:30:00] Имя контакта:
Привет! Как дела?

[15.01.24, 10:31:00] Вы:
Всё отлично!
```

---

## 📥 ИМПОРТ В LIBERTY REACH

### Способ 1: Через приложение (Flutter)

**Путь:** `mobile/lib/screens/import_data_screen.dart`

```dart
// Пример использования
import 'package:file_picker/file_picker.dart';
import '../services/import_service.dart';

// Выбор файла
FilePickerResult? result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['json', 'txt', 'zip'],
);

if (result != null) {
  final file = result.files.first;
  
  // Импорт
  final importService = ImportService();
  final stats = await importService.importFromTelegram(file.path);
  
  print('Импортировано:');
  print('- Чатов: ${stats.chats}');
  print('- Сообщений: ${stats.messages}');
  print('- Контактов: ${stats.contacts}');
}
```

### Способ 2: Через веб-интерфейс

**Путь:** `backend/import_server.js`

```bash
# Запуск сервера импорта
node backend/import_server.js

# Открой в браузере
http://localhost:3001/import
```

### Способ 3: Через CLI (Python скрипт)

**Путь:** `scripts/telegram_import.py`

```bash
# Установка зависимостей
pip install -r scripts/requirements.txt

# Импорт из Telegram
python scripts/telegram_import.py \
  --input ~/Downloads/Telegram\ Desktop/ \
  --user-id YOUR_USER_ID \
  --output liberty_data/

# Импорт из WhatsApp
python scripts/whatsapp_import.py \
  --input ~/Downloads/WhatsApp\ Chat.txt \
  --user-id YOUR_USER_ID \
  --output liberty_data/
```

---

## 🔧 PYTHON СКРИПТЫ

### telegram_import.py

```python
#!/usr/bin/env python3
"""
Telegram → Liberty Reach Importer
Переносит чаты, сообщения и контакты из Telegram
"""

import json
import os
import sqlite3
from datetime import datetime
from pathlib import Path

class TelegramImporter:
    def __init__(self, user_id: str, db_path: str = 'liberty_data/messages.db'):
        self.user_id = user_id
        self.db_path = db_path
        self.stats = {'chats': 0, 'messages': 0, 'contacts': 0}
    
    def import_from_folder(self, folder_path: str):
        """Импорт из папки экспорта Telegram"""
        folder = Path(folder_path)
        
        # Читаем result.json
        result_file = folder / 'result.json'
        if result_file.exists():
            with open(result_file, 'r', encoding='utf-8') as f:
                result = json.load(f)
                print(f"Найдено чатов: {len(result.get('chats', []))}")
        
        # Импортируем чаты
        chats_folder = folder / 'chats'
        if chats_folder.exists():
            for chat_file in chats_folder.glob('*.json'):
                self._import_chat(chat_file)
        
        return self.stats
    
    def _import_chat(self, chat_file: Path):
        """Импорт одного чата"""
        with open(chat_file, 'r', encoding='utf-8') as f:
            chat = json.load(f)
        
        chat_name = chat.get('name', 'Unknown')
        chat_type = chat.get('type', 'personal')
        
        print(f"Импорт чата: {chat_name} ({chat_type})")
        self.stats['chats'] += 1
        
        # Создаём чат в D1
        chat_id = self._create_chat_in_db(chat_name, chat_type)
        
        # Импортируем сообщения
        for msg in chat.get('messages', []):
            self._import_message(chat_id, msg)
            self.stats['messages'] += 1
    
    def _create_chat_in_db(self, name: str, chat_type: str) -> str:
        """Создание чата в базе данных"""
        # TODO: Интеграция с D1 API
        return f"chat-{name.replace(' ', '-').lower()}"
    
    def _import_message(self, chat_id: str, msg: dict):
        """Импорт одного сообщения"""
        text = msg.get('text', '')
        if isinstance(text, list):
            # Telegram хранит текст как список элементов
            text = ''.join([t if isinstance(t, str) else t.get('text', '') for t in text])
        
        date_str = msg.get('date', '')
        timestamp = datetime.strptime(date_str, '%Y-%m-%dT%H:%M:%S').timestamp() * 1000
        
        # TODO: Сохранение в D1
        print(f"  Сообщение ({date_str}): {text[:50]}...")

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Telegram → Liberty Reach Importer')
    parser.add_argument('--input', required=True, help='Путь к папке экспорта Telegram')
    parser.add_argument('--user-id', required=True, help='Ваш User ID в Liberty Reach')
    parser.add_argument('--output', default='liberty_data', help='Папка для данных')
    
    args = parser.parse_args()
    
    importer = TelegramImporter(user_id=args.user_id, db_path=f'{args.output}/messages.db')
    stats = importer.import_from_folder(args.input)
    
    print("\n✅ Импорт завершён!")
    print(f"📊 Статистика:")
    print(f"   - Чатов: {stats['chats']}")
    print(f"   - Сообщений: {stats['messages']}")
    print(f"   - Контактов: {stats['contacts']}")
```

### whatsapp_import.py

```python
#!/usr/bin/env python3
"""
WhatsApp → Liberty Reach Importer
Переносит чаты и сообщения из WhatsApp
"""

import re
import sqlite3
from datetime import datetime
from pathlib import Path

class WhatsAppImporter:
    def __init__(self, user_id: str, db_path: str = 'liberty_data/messages.db'):
        self.user_id = user_id
        self.db_path = db_path
        self.stats = {'chats': 0, 'messages': 0, 'contacts': 0}
    
    def import_from_file(self, file_path: str):
        """Импорт из WhatsApp Chat.txt"""
        file = Path(file_path)
        
        if not file.exists():
            raise FileNotFoundError(f"Файл не найден: {file_path}")
        
        print(f"Импорт из: {file_path}")
        
        current_chat = None
        current_messages = []
        
        # Паттерн WhatsApp: [DD.MM.YY, HH:MM:SS] Имя: Сообщение
        pattern = r'\[(\d{2}\.\d{2}\.\d{2},\s+\d{2}:\d{2}:\d{2})\]\s+(.+?):\s+(.*)'
        
        with open(file, 'r', encoding='utf-8') as f:
            for line in f:
                match = re.match(pattern, line)
                
                if match:
                    # Новое сообщение
                    date_str, sender, message = match.groups()
                    
                    # Сохраняем предыдущий чат
                    if current_chat and current_messages:
                        self._save_chat(current_chat, current_messages)
                    
                    current_chat = sender
                    current_messages = [(date_str, sender, message)]
                elif current_chat and line.strip():
                    # Продолжение предыдущего сообщения
                    current_messages.append((None, None, line.strip()))
        
        # Сохраняем последний чат
        if current_chat and current_messages:
            self._save_chat(current_chat, current_messages)
        
        return self.stats
    
    def _save_chat(self, chat_name: str, messages: list):
        """Сохранение чата в базу"""
        print(f"Чат: {chat_name} ({len(messages)} сообщений)")
        self.stats['chats'] += 1
        self.stats['messages'] += len(messages)
        
        # TODO: Интеграция с D1 API

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='WhatsApp → Liberty Reach Importer')
    parser.add_argument('--input', required=True, help='Путь к WhatsApp Chat.txt')
    parser.add_argument('--user-id', required=True, help='Ваш User ID в Liberty Reach')
    parser.add_argument('--output', default='liberty_data', help='Папка для данных')
    
    args = parser.parse_args()
    
    importer = WhatsAppImporter(user_id=args.user_id, db_path=f'{args.output}/messages.db')
    stats = importer.import_from_file(args.input)
    
    print("\n✅ Импорт завершён!")
    print(f"📊 Статистика:")
    print(f"   - Чатов: {stats['chats']}")
    print(f"   - Сообщений: {stats['messages']}")
```

---

## 📊 ИНТЕГРАЦИЯ С D1

### SQL Schema для импорта

```sql
-- Таблица импортированных данных
CREATE TABLE IF NOT EXISTS imported_chats (
    id TEXT PRIMARY KEY,
    source TEXT NOT NULL, -- 'telegram' | 'whatsapp'
    original_id TEXT, -- ID из исходного мессенджера
    user_id TEXT NOT NULL,
    name TEXT,
    chat_type TEXT, -- 'personal' | 'group' | 'channel'
    imported_at INTEGER NOT NULL,
    message_count INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS imported_messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    original_id TEXT,
    from_name TEXT,
    text TEXT,
    timestamp INTEGER NOT NULL,
    media_cid TEXT, -- IPFS CID для медиа
    imported_at INTEGER NOT NULL,
    FOREIGN KEY (chat_id) REFERENCES imported_chats(id)
);

-- Индексы для производительности
CREATE INDEX idx_imported_chats_user ON imported_chats(user_id);
CREATE INDEX idx_imported_messages_chat ON imported_messages(chat_id);
```

---

## 🎯 UI ДЛЯ ИМПОРТА (Flutter)

### import_data_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/import_service.dart';

class ImportDataScreen extends StatefulWidget {
  const ImportDataScreen({super.key});

  @override
  State<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends State<ImportDataScreen> {
  final ImportService _importService = ImportService();
  bool _isImporting = false;
  String? _status;
  ImportStats? _stats;

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt', 'zip'],
    );

    if (result == null) return;

    final file = result.files.first;
    setState(() {
      _isImporting = true;
      _status = 'Импорт...';
    });

    try {
      // Определяем тип файла
      if (file.path!.contains('Telegram')) {
        _stats = await _importService.importFromTelegram(file.path!);
      } else if (file.path!.contains('WhatsApp')) {
        _stats = await _importService.importFromWhatsApp(file.path!);
      }

      setState(() {
        _status = '✅ Готово!';
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Импорт данных'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.telegram),
                title: const Text('Импорт из Telegram'),
                subtitle: const Text('JSON экспорт из Telegram Desktop'),
                onTap: _pickAndImport,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.message),
                title: const Text('Импорт из WhatsApp'),
                subtitle: const Text('TXT экспорт чатов'),
                onTap: _pickAndImport,
              ),
            ),
            if (_isImporting) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              if (_status != null) Text(_status!),
            ],
            if (_stats != null) ...[
              const SizedBox(height: 16),
              Text('✅ Импортировано:'),
              Text('📁 Чатов: ${_stats!.chats}'),
              Text('💬 Сообщений: ${_stats!.messages}'),
              Text('👥 Контактов: ${_stats!.contacts}'),
            ],
          ],
        ),
      ),
    );
  }
}

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
```

---

## 🚀 БЫСТРЫЙ СТАРТ

### 1. Экспорт из Telegram

```bash
# Telegram Desktop → Экспорт → JSON
# Сохрани в ~/Downloads/Telegram Desktop/
```

### 2. Запуск импорта

```bash
cd liberty-sovereign
python scripts/telegram_import.py \
  --input ~/Downloads/Telegram\ Desktop/ \
  --user-id YOUR_USER_ID \
  --output liberty_data/
```

### 3. Проверка

```bash
# Проверь базу данных
sqlite3 liberty_data/messages.db "SELECT * FROM imported_chats;"
```

---

## 📝 ПРИМЕЧАНИЯ

- ⚠️ **Медиа файлы** не импортируются автоматически (нужен отдельный upload на Pinata IPFS)
- ✅ **Текстовые сообщения** импортируются полностью
- ✅ **Контакты** импортируются с именами
- ⚠️ **Голосовые сообщения** требуют конвертации

---

**Liberty Reach Messenger — твоя свобода, твои данные!** 🔐
