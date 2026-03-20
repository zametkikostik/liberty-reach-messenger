#!/usr/bin/env python3
"""
WhatsApp → Liberty Reach Importer
Переносит чаты и сообщения из WhatsApp
"""

import re
import os
import sqlite3
from datetime import datetime
from pathlib import Path
import argparse

class WhatsAppImporter:
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
    
    def import_from_file(self, file_path: str):
        """Импорт из WhatsApp Chat.txt"""
        file = Path(file_path)
        
        if not file.exists():
            raise FileNotFoundError(f"Файл не найден: {file_path}")
        
        print(f"📥 Импорт из: {file_path}")
        print("=" * 60)
        
        current_chat = None
        current_messages = []
        chat_count = 0
        
        # Паттерн WhatsApp: [DD.MM.YY, HH:MM:SS] Имя: Сообщение
        pattern = r'\[(\d{2}\.\d{2}\.\d{2},\s+\d{2}:\d{2}:\d{2})\]\s+(.+?):\s+(.*)'
        
        with open(file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                match = re.match(pattern, line)
                
                if match:
                    # Новое сообщение
                    date_str, sender, message = match.groups()
                    
                    # Сохраняем предыдущий чат
                    if current_chat and current_messages:
                        self._save_chat(current_chat, current_messages)
                        chat_count += 1
                    
                    current_chat = sender
                    current_messages = [(date_str, sender, message)]
                elif current_chat and line.strip():
                    # Продолжение предыдущего сообщения
                    current_messages.append((None, None, line.strip()))
        
        # Сохраняем последний чат
        if current_chat and current_messages:
            self._save_chat(current_chat, current_messages)
            chat_count += 1
        
        self.stats['chats'] = chat_count
        return self.stats
    
    def _save_chat(self, chat_name: str, messages: list):
        """Сохранение чата в базу"""
        import uuid
        
        print(f"\n💬 Чат: {chat_name} ({len(messages)} сообщений)")
        
        db_chat_id = str(uuid.uuid4())
        timestamp = int(datetime.now().timestamp() * 1000)
        
        # Сохраняем чат
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO imported_chats (id, source, original_id, user_id, name, chat_type, imported_at, message_count)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (db_chat_id, 'whatsapp', chat_name, self.user_id, chat_name, 'personal', timestamp, len(messages)))
        
        # Сохраняем сообщения
        for msg_data in messages:
            date_str, sender, message = msg_data
            
            if date_str:
                try:
                    # Формат WhatsApp: DD.MM.YY, HH:MM:SS
                    dt = datetime.strptime(date_str, '%d.%m.%y, %H:%M:%S')
                    timestamp = dt.timestamp() * 1000
                except:
                    timestamp = int(datetime.now().timestamp() * 1000)
            else:
                timestamp = int(datetime.now().timestamp() * 1000)
            
            cursor.execute('''
                INSERT INTO imported_messages (id, chat_id, original_id, from_name, text, timestamp, imported_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                str(uuid.uuid4()),
                db_chat_id,
                None,
                sender or chat_name,
                message,
                int(timestamp),
                int(datetime.now().timestamp() * 1000)
            ))
            
            self.stats['messages'] += 1
        
        conn.commit()
        conn.close()

def main():
    parser = argparse.ArgumentParser(
        description='WhatsApp → Liberty Reach Importer',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Пример использования:
  python whatsapp_import.py --input ~/Downloads/WhatsApp\ Chat.txt --user-id YOUR_USER_ID
        '''
    )
    parser.add_argument('--input', required=True, help='Путь к WhatsApp Chat.txt')
    parser.add_argument('--user-id', required=True, help='Ваш User ID в Liberty Reach')
    parser.add_argument('--output', default='liberty_data', help='Папка для данных (по умолчанию: liberty_data)')
    
    args = parser.parse_args()
    
    db_path = f'{args.output}/messages.db'
    
    print("=" * 60)
    print("🔄 WHATSAPP → LIBERTY REACH IMPORTER")
    print("=" * 60)
    
    importer = WhatsAppImporter(user_id=args.user_id, db_path=db_path)
    stats = importer.import_from_file(args.input)
    
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
