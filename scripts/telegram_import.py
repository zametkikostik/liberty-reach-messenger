#!/usr/bin/env python3
"""
Telegram → Liberty Reach Importer
Переносит чаты, сообщения и контакты из Telegram Desktop
"""

import json
import os
import sqlite3
from datetime import datetime
from pathlib import Path
import argparse

class TelegramImporter:
    def __init__(self, user_id: str, db_path: str = 'liberty_data/messages.db'):
        self.user_id = user_id
        self.db_path = db_path
        self.stats = {'chats': 0, 'messages': 0, 'contacts': 0}
        self._init_db()
    
    def _init_db(self):
        """Инициализация базы данных"""
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Таблица импортированных чатов
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS imported_chats (
                id TEXT PRIMARY KEY,
                source TEXT NOT NULL,
                original_id TEXT,
                user_id TEXT NOT NULL,
                name TEXT,
                chat_type TEXT,
                imported_at INTEGER NOT NULL,
                message_count INTEGER DEFAULT 0
            )
        ''')
        
        # Таблица импортированных сообщений
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS imported_messages (
                id TEXT PRIMARY KEY,
                chat_id TEXT NOT NULL,
                original_id TEXT,
                from_name TEXT,
                text TEXT,
                timestamp INTEGER NOT NULL,
                media_cid TEXT,
                imported_at INTEGER NOT NULL
            )
        ''')
        
        # Индексы
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_imported_chats_user ON imported_chats(user_id)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_imported_messages_chat ON imported_messages(chat_id)')
        
        conn.commit()
        conn.close()
    
    def import_from_folder(self, folder_path: str):
        """Импорт из папки экспорта Telegram"""
        folder = Path(folder_path)
        
        if not folder.exists():
            raise FileNotFoundError(f"Папка не найдена: {folder_path}")
        
        print(f"📥 Импорт из: {folder_path}")
        print("=" * 60)
        
        # Читаем result.json
        result_file = folder / 'result.json'
        if result_file.exists():
            with open(result_file, 'r', encoding='utf-8') as f:
                result = json.load(f)
                chats_list = result.get('chats', [])
                print(f"📋 Найдено чатов в result.json: {len(chats_list)}")
        
        # Импортируем чаты
        chats_folder = folder / 'chats'
        if chats_folder.exists():
            json_files = list(chats_folder.glob('*.json'))
            print(f"📁 Найдено JSON файлов: {len(json_files)}")
            print("=" * 60)
            
            for chat_file in json_files:
                self._import_chat(chat_file)
        
        return self.stats
    
    def _import_chat(self, chat_file: Path):
        """Импорт одного чата"""
        try:
            with open(chat_file, 'r', encoding='utf-8') as f:
                chat = json.load(f)
            
            chat_name = chat.get('name', 'Unknown')
            chat_type = chat.get('type', 'personal')
            chat_id = chat.get('id', 'unknown')
            
            print(f"\n💬 Чат: {chat_name} (тип: {chat_type}, ID: {chat_id})")
            self.stats['chats'] += 1
            
            # Создаём чат в БД
            db_chat_id = self._create_chat_in_db(chat_name, chat_type, chat_id)
            
            # Импортируем сообщения
            messages = chat.get('messages', [])
            print(f"   📝 Сообщений: {len(messages)}")
            
            for msg in messages:
                self._import_message(db_chat_id, msg)
                self.stats['messages'] += 1
            
            # Обновляем счётчик
            self._update_chat_count(db_chat_id, len(messages))
            
        except Exception as e:
            print(f"   ❌ Ошибка импорта чата {chat_file}: {e}")
    
    def _create_chat_in_db(self, name: str, chat_type: str, original_id: str) -> str:
        """Создание чата в базе данных"""
        import uuid
        
        db_id = str(uuid.uuid4())
        timestamp = int(datetime.now().timestamp() * 1000)
        
        # Маппинг типов Telegram → Liberty Reach
        type_map = {
            'personal': 'personal',
            'private_group': 'group',
            'private_supergroup': 'group',
            'private_channel': 'channel',
        }
        
        liberty_type = type_map.get(chat_type, 'personal')
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO imported_chats (id, source, original_id, user_id, name, chat_type, imported_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (db_id, 'telegram', original_id, self.user_id, name, liberty_type, timestamp))
        
        conn.commit()
        conn.close()
        
        return db_id
    
    def _import_message(self, chat_id: str, msg: dict):
        """Импорт одного сообщения"""
        import uuid
        
        # Извлекаем текст (Telegram хранит как список или строку)
        text = msg.get('text', '')
        if isinstance(text, list):
            text = ''.join([t if isinstance(t, str) else t.get('text', '') for t in text])
        
        # Парсим дату
        date_str = msg.get('date', '')
        try:
            timestamp = datetime.strptime(date_str, '%Y-%m-%dT%H:%M:%S').timestamp() * 1000
        except:
            timestamp = int(datetime.now().timestamp() * 1000)
        
        # Получаем отправителя
        from_name = msg.get('from', '')
        if not from_name:
            from_name = msg.get('from_id', 'Unknown')
        
        # Медиа (пока только сохраняем путь)
        media_cid = None
        if 'photo' in msg:
            media_cid = str(msg['photo'])
        elif 'video' in msg:
            media_cid = str(msg['video'])
        
        # Сохраняем в БД
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO imported_messages (id, chat_id, original_id, from_name, text, timestamp, media_cid, imported_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            str(uuid.uuid4()),
            chat_id,
            msg.get('id'),
            from_name,
            text,
            int(timestamp),
            media_cid,
            int(datetime.now().timestamp() * 1000)
        ))
        
        conn.commit()
        conn.close()
    
    def _update_chat_count(self, chat_id: str, count: int):
        """Обновление счётчика сообщений"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            UPDATE imported_chats SET message_count = ? WHERE id = ?
        ''', (count, chat_id))
        
        conn.commit()
        conn.close()

def main():
    parser = argparse.ArgumentParser(
        description='Telegram → Liberty Reach Importer',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Пример использования:
  python telegram_import.py --input ~/Downloads/Telegram\ Desktop/ --user-id YOUR_USER_ID
        '''
    )
    parser.add_argument('--input', required=True, help='Путь к папке экспорта Telegram')
    parser.add_argument('--user-id', required=True, help='Ваш User ID в Liberty Reach')
    parser.add_argument('--output', default='liberty_data', help='Папка для данных (по умолчанию: liberty_data)')
    
    args = parser.parse_args()
    
    db_path = f'{args.output}/messages.db'
    
    print("=" * 60)
    print("🔄 TELEGRAM → LIBERTY REACH IMPORTER")
    print("=" * 60)
    
    importer = TelegramImporter(user_id=args.user_id, db_path=db_path)
    stats = importer.import_from_folder(args.input)
    
    print("\n" + "=" * 60)
    print("✅ ИМПОРТ ЗАВЕРШЁН!")
    print("=" * 60)
    print(f"📊 СТАТИСТИКА:")
    print(f"   📁 Чатов:        {stats['chats']}")
    print(f"   💬 Сообщений:    {stats['messages']}")
    print(f"   👥 Контактов:    {stats['contacts']}")
    print(f"\n💾 База данных: {db_path}")
    print("=" * 60)

if __name__ == '__main__':
    main()
