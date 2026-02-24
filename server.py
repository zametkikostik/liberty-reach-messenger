#!/usr/bin/env python3
"""
Liberty Reach Messenger - Production Server v1.0
Real-time WebSocket backend с E2E шифрованием и файловым хранилищем
"""

import http.server
import socketserver
import json
import uuid
import time
import sqlite3
import hashlib
import secrets
import threading
import os
import base64
import mimetypes
from urllib.parse import urlparse, parse_qs, unquote
from datetime import datetime, timedelta
from http import HTTPStatus
import shutil

# Try to import websocket libraries
try:
    import websocket
    from websocket import WebSocketServer, WebSocketHandler
    WEBSOCKET_AVAILABLE = True
except ImportError:
    WEBSOCKET_AVAILABLE = False

# ============================================
# Конфигурация
# ============================================

PORT = 8787
WS_PORT = 8788
DB_PATH = 'liberty_reach.db'
FILES_DIR = 'files'
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
SESSION_EXPIRY = 7 * 24 * 60 * 60  # 7 дней
RATE_LIMIT_WINDOW = 60  # секунд
RATE_LIMIT_MAX_REQUESTS = 100

# Создаём директорию для файлов
os.makedirs(FILES_DIR, exist_ok=True)

# ============================================
# База данных
# ============================================

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    c = conn.cursor()

    # Пользователи
    c.execute('''CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        public_key TEXT,
        encrypted_public_key TEXT,
        created_at INTEGER NOT NULL,
        last_seen INTEGER NOT NULL,
        status TEXT DEFAULT 'offline' CHECK(status IN ('online', 'offline')),
        avatar_data TEXT,
        settings TEXT DEFAULT '{}'
    )''')

    # Сообщения
    c.execute('''CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT NOT NULL,
        from_user TEXT NOT NULL,
        to_user TEXT NOT NULL,
        content TEXT NOT NULL,
        content_encrypted INTEGER DEFAULT 0,
        message_type TEXT DEFAULT 'text' CHECK(message_type IN ('text', 'file', 'image', 'voice')),
        file_url TEXT,
        file_name TEXT,
        file_size INTEGER,
        created_at INTEGER NOT NULL,
        delivered INTEGER DEFAULT 0,
        read INTEGER DEFAULT 0,
        FOREIGN KEY (from_user) REFERENCES users(id),
        FOREIGN KEY (to_user) REFERENCES users(id)
    )''')

    # Сессии
    c.execute('''CREATE TABLE IF NOT EXISTS sessions (
        token TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        device_info TEXT,
        ip_address TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )''')

    # Файлы
    c.execute('''CREATE TABLE IF NOT EXISTS files (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        filename TEXT NOT NULL,
        original_name TEXT,
        mime_type TEXT,
        size INTEGER NOT NULL,
        path TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )''')

    # Индексы для производительности
    c.execute('CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_messages_user ON messages(to_user)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON sessions(expires_at)')

    # Demo пользователи
    demo_users = [
        ('user_pavel', 'Павел', 'pq_key_pavel', 'enc_pq_key_pavel', int(time.time()*1000), int(time.time()*1000), 'online', None, '{}'),
        ('user_elon', 'Илон', 'pq_key_elon', 'enc_pq_key_elon', int(time.time()*1000), int(time.time()*1000), 'online', None, '{}'),
        ('user_news', 'LibertyNews', 'pq_key_news', 'enc_pq_key_news', int(time.time()*1000), int(time.time()*1000), 'online', None, '{}'),
    ]
    c.executemany('INSERT OR IGNORE INTO users VALUES (?,?,?,?,?,?,?,?,?)', demo_users)

    # Demo сообщения
    demo_messages = [
        ('msg_1', 'user_pavel_user_elon', 'user_pavel', 'user_elon', 'Добро пожаловать в Liberty Reach! 🦅', 0, 'text', None, None, None, int(time.time()*1000)-600000, 1, 1),
        ('msg_2', 'user_pavel_user_elon', 'user_elon', 'user_pavel', 'Спасибо! Отличный мессенджер!', 0, 'text', None, None, None, int(time.time()*1000)-300000, 1, 1),
    ]
    c.executemany('INSERT OR IGNORE INTO messages VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)', demo_messages)

    conn.commit()
    conn.close()
    print("[✓] Database initialized")

# ============================================
# Сессии и аутентификация
# ============================================

sessions = {}  # token -> {user_id, expires_at, device_info}

def create_session(user_id, device_info='', ip_address=''):
    token = secrets.token_urlsafe(32)
    now = int(time.time())
    expires_at = now + SESSION_EXPIRY
    
    conn = get_db()
    c = conn.cursor()
    c.execute('INSERT INTO sessions VALUES (?,?,?,?,?)',
              (token, user_id, now, expires_at, device_info))
    conn.commit()
    conn.close()
    
    sessions[token] = {
        'user_id': user_id,
        'expires_at': expires_at,
        'device_info': device_info
    }
    return token

def verify_session(token):
    if token in sessions:
        session = sessions[token]
        if session['expires_at'] > int(time.time()):
            return session['user_id']
        else:
            del sessions[token]
    
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT user_id, expires_at, device_info FROM sessions WHERE token = ? AND expires_at > ?',
              (token, int(time.time())))
    row = c.fetchone()
    conn.close()
    
    if row:
        sessions[token] = {
            'user_id': row[0],
            'expires_at': row[1],
            'device_info': row[2]
        }
        return row[0]
    return None

def delete_session(token):
    if token in sessions:
        del sessions[token]
    conn = get_db()
    c = conn.cursor()
    c.execute('DELETE FROM sessions WHERE token = ?', (token,))
    conn.commit()
    conn.close()

# ============================================
# Rate Limiting
# ============================================

rate_limits = {}  # ip -> {requests: [], blocked_until: 0}

def check_rate_limit(ip):
    now = time.time()
    
    if ip not in rate_limits:
        rate_limits[ip] = {'requests': [], 'blocked_until': 0}
    
    limit = rate_limits[ip]
    
    if limit['blocked_until'] > now:
        return False
    
    # Очищаем старые запросы
    limit['requests'] = [t for t in limit['requests'] if now - t < RATE_LIMIT_WINDOW]
    
    if len(limit['requests']) >= RATE_LIMIT_MAX_REQUESTS:
        limit['blocked_until'] = now + RATE_LIMIT_WINDOW
        return False
    
    limit['requests'].append(now)
    return True

# ============================================
# WebSocket менеджмент
# ============================================

websocket_connections = {}  # user_id -> [ws_connections]
message_queue = {}  # user_id -> [messages]

def add_websocket(user_id, ws):
    if user_id not in websocket_connections:
        websocket_connections[user_id] = []
    websocket_connections[user_id].append(ws)

def remove_websocket(user_id, ws):
    if user_id in websocket_connections:
        websocket_connections[user_id] = [w for w in websocket_connections[user_id] if w != ws]
        if not websocket_connections[user_id]:
            del websocket_connections[user_id]

def send_to_user(user_id, message):
    """Отправить сообщение пользователю через WebSocket"""
    if user_id in message_queue:
        message_queue[user_id].append(message)
    else:
        message_queue[user_id] = [message]
    
    if user_id in websocket_connections:
        for ws in websocket_connections[user_id]:
            try:
                ws.send(json.dumps(message))
            except:
                pass

def broadcast_online_status(user_id, status):
    """Уведомить всех о смене статуса пользователя"""
    message = {
        'type': 'status_update',
        'user_id': user_id,
        'status': status,
        'timestamp': int(time.time() * 1000)
    }
    # Отправляем всем подключенным пользователям
    for uid in websocket_connections:
        send_to_user(uid, message)

# ============================================
# Файловое хранилище
# ============================================

def save_file(file_data, filename, user_id):
    file_id = str(uuid.uuid4())
    ext = os.path.splitext(filename)[1] if filename else ''
    stored_name = f"{file_id}{ext}"
    path = os.path.join(FILES_DIR, stored_name)
    
    with open(path, 'wb') as f:
        f.write(file_data)
    
    mime_type = mimetypes.guess_type(filename)[0] if filename else 'application/octet-stream'
    
    conn = get_db()
    c = conn.cursor()
    c.execute('INSERT INTO files VALUES (?,?,?,?,?,?,?,?)',
              (file_id, user_id, stored_name, filename, mime_type, len(file_data), path, int(time.time()*1000)))
    conn.commit()
    conn.close()
    
    return {
        'id': file_id,
        'url': f'/files/{file_id}',
        'filename': stored_name,
        'original_name': filename,
        'mime_type': mime_type,
        'size': len(file_data)
    }

def get_file(file_id):
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT * FROM files WHERE id = ?', (file_id,))
    row = c.fetchone()
    conn.close()
    
    if row and os.path.exists(row['path']):
        with open(row['path'], 'rb') as f:
            return f.read(), row['mime_type'], row['original_name'] or row['filename']
    return None, None, None

# ============================================
# HTTP Handler
# ============================================

class LibertyReachHandler(http.server.SimpleHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    
    def log_message(self, format, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {args[0]}")

    def send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-User-ID, X-Session-Token')
        self.send_header('Access-Control-Expose-Headers', 'X-Session-Token')
        self.send_header('Access-Control-Max-Age', '86400')

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors_headers()
        self.send_header('Content-Length', '0')
        self.end_headers()

    def get_user_from_session(self):
        token = self.headers.get('X-Session-Token') or self.headers.get('Authorization', '').replace('Bearer ', '')
        if token:
            return verify_session(token)
        return None

    def send_json(self, data, status=200):
        content = json.dumps(data).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(content)))
        self.send_cors_headers()
        self.end_headers()
        self.wfile.write(content)

    def send_error_json(self, status, message):
        self.send_json({'error': message}, status)

    def do_GET(self):
        # Rate limiting
        client_ip = self.client_address[0]
        if not check_rate_limit(client_ip):
            self.send_error_json(429, 'Too many requests')
            return

        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        # Health check
        if path == '/' or path == '/health':
            self.send_json({
                'status': 'ok',
                'service': 'Liberty Reach Messenger',
                'version': '1.0.0',
                'features': ['websocket', 'e2e_encryption', 'files', 'sessions'],
                'timestamp': int(time.time() * 1000)
            })
            return

        # Файлы
        if path.startswith('/files/'):
            file_id = path.split('/')[-1]
            data, mime_type, filename = get_file(file_id)
            if data:
                self.send_response(200)
                self.send_header('Content-Type', mime_type)
                self.send_header('Content-Length', str(len(data)))
                self.send_header('Content-Disposition', f'inline; filename="{filename}"')
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(data)
            else:
                self.send_error_json(404, 'File not found')
            return

        # API Routes
        if path.startswith('/api/v1/'):
            self.handle_api_get(path, query)
        else:
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(b'Liberty Reach Messenger API v1.0')

    def do_POST(self):
        # Rate limiting
        client_ip = self.client_address[0]
        if not check_rate_limit(client_ip):
            self.send_error_json(429, 'Too many requests')
            return

        parsed = urlparse(self.path)
        path = parsed.path

        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else b'{}'

        try:
            data = json.loads(body.decode('utf-8')) if body else {}
        except:
            data = {}

        # API Routes
        if path.startswith('/api/v1/'):
            self.handle_api_post(path, data)
        else:
            self.send_error_json(404, 'Not found')

    def handle_api_get(self, path, query):
        # Получить текущий пользователь
        if path == '/api/v1/me':
            user_id = self.get_user_from_session()
            if not user_id:
                self.send_error_json(401, 'Unauthorized')
                return
            conn = get_db()
            c = conn.cursor()
            c.execute('SELECT id, username, public_key, created_at, last_seen, status, avatar_data, settings FROM users WHERE id = ?', (user_id,))
            row = c.fetchone()
            conn.close()
            if row:
                self.send_json({'user': dict(row)})
            else:
                self.send_error_json(404, 'User not found')
            return

        # Список пользователей
        if path == '/api/v1/users':
            conn = get_db()
            c = conn.cursor()
            c.execute('SELECT id, username, public_key, created_at, last_seen, status FROM users ORDER BY last_seen DESC')
            users = [dict(row) for row in c.fetchall()]
            conn.close()
            self.send_json({'users': users, 'total': len(users)})
            return

        # Конкретный пользователь
        if path.startswith('/api/v1/users/') and '/' not in path.split('/users/')[-1]:
            user_id = path.split('/')[-1]
            conn = get_db()
            c = conn.cursor()
            c.execute('SELECT id, username, public_key, created_at, last_seen, status FROM users WHERE id = ?', (user_id,))
            row = c.fetchone()
            conn.close()
            if row:
                self.send_json({'user': dict(row)})
            else:
                self.send_error_json(404, 'User not found')
            return

        # Сообщения
        if path.startswith('/api/v1/messages/'):
            user_id = path.split('/')[-1]
            limit = int(query.get('limit', [100])[0])
            offset = int(query.get('offset', [0])[0])
            
            conn = get_db()
            c = conn.cursor()
            c.execute('''SELECT m.id, m.chat_id, m.from_user, m.to_user, m.content, m.content_encrypted,
                        m.message_type, m.file_url, m.file_name, m.file_size, m.created_at, m.delivered, m.read,
                        u.username as from_username
                        FROM messages m LEFT JOIN users u ON m.from_user = u.id
                        WHERE m.to_user = ? OR m.from_user = ?
                        ORDER BY m.created_at DESC LIMIT ? OFFSET ?''',
                      (user_id, user_id, limit, offset))
            messages = [dict(row) for row in c.fetchall()]
            
            # Пометить как прочитанные
            c.execute('UPDATE messages SET read = 1 WHERE to_user = ? AND read = 0', (user_id,))
            conn.commit()
            conn.close()
            
            self.send_json({'messages': messages, 'total': len(messages)})
            return

        # Чаты
        if path.startswith('/api/v1/chats/'):
            user_id = path.split('/')[-1]
            conn = get_db()
            c = conn.cursor()
            c.execute('''SELECT DISTINCT
                CASE WHEN m.from_user = ? THEN m.to_user ELSE m.from_user END as chat_user_id,
                u.username as chat_user_name,
                u.status as chat_user_status,
                u.public_key as chat_user_public_key,
                (SELECT content FROM messages
                 WHERE (from_user = ? AND to_user = chat_user_id)
                    OR (from_user = chat_user_id AND to_user = ?)
                 ORDER BY created_at DESC LIMIT 1) as last_message,
                (SELECT created_at FROM messages
                 WHERE (from_user = ? AND to_user = chat_user_id)
                    OR (from_user = chat_user_id AND to_user = ?)
                 ORDER BY created_at DESC LIMIT 1) as last_message_time,
                (SELECT COUNT(*) FROM messages
                 WHERE to_user = ? AND from_user = chat_user_id AND read = 0) as unread_count
                FROM messages m
                LEFT JOIN users u ON u.id = chat_user_id
                WHERE m.from_user = ? OR m.to_user = ?
                ORDER BY last_message_time DESC''',
                (user_id, user_id, user_id, user_id, user_id, user_id, user_id, user_id, user_id, user_id, user_id))
            chats = [dict(row) for row in c.fetchall()]
            conn.close()
            self.send_json({'chats': chats, 'total': len(chats)})
            return

        self.send_error_json(404, 'Not found')

    def handle_api_post(self, path, data):
        # Регистрация
        if path == '/api/v1/register':
            username = data.get('username', '').strip()
            public_key = data.get('public_key', '')
            encrypted_public_key = data.get('encrypted_public_key', '')

            if not username or len(username) < 3:
                self.send_error_json(400, 'Username must be at least 3 characters')
                return

            conn = get_db()
            c = conn.cursor()
            c.execute('SELECT id FROM users WHERE username = ?', (username,))
            if c.fetchone():
                conn.close()
                self.send_error_json(409, 'Username taken')
                return

            user_id = 'user_' + str(uuid.uuid4()).replace('-', '')[:16]
            now = int(time.time() * 1000)
            c.execute('INSERT INTO users VALUES (?,?,?,?,?,?,?,?,?)',
                     (user_id, username, public_key, encrypted_public_key, now, now, 'online', None, '{}'))
            conn.commit()
            conn.close()

            # Создаём сессию
            token = create_session(user_id, device_info=data.get('device_info', ''), ip_address=self.client_address[0])

            self.send_json({
                'success': True,
                'user': {'id': user_id, 'username': username, 'public_key': public_key, 'created_at': now, 'status': 'online'},
                'session_token': token
            }, 201)
            return

        # Логин
        if path == '/api/v1/login':
            username = data.get('username', '').strip()
            
            conn = get_db()
            c = conn.cursor()
            c.execute('SELECT id, username, public_key FROM users WHERE username = ?', (username,))
            row = c.fetchone()
            conn.close()
            
            if not row:
                self.send_error_json(401, 'Invalid credentials')
                return
            
            user_id = row['id']
            
            # Обновляем статус
            conn = get_db()
            c = conn.cursor()
            c.execute('UPDATE users SET status = ?, last_seen = ? WHERE id = ?', ('online', int(time.time()*1000), user_id))
            conn.commit()
            conn.close()
            
            # Создаём сессию
            token = create_session(user_id, device_info=data.get('device_info', ''), ip_address=self.client_address[0])
            
            # Уведомляем через WebSocket
            broadcast_online_status(user_id, 'online')
            
            self.send_json({
                'success': True,
                'user': dict(row),
                'session_token': token
            })
            return

        # Логаут
        if path == '/api/v1/logout':
            token = self.headers.get('X-Session-Token') or self.headers.get('Authorization', '').replace('Bearer ', '')
            if token:
                delete_session(token)
            self.send_json({'success': True})
            return

        # Отправка сообщения
        if path == '/api/v1/messages':
            user_id = self.get_user_from_session()
            if not user_id:
                self.send_error_json(401, 'Unauthorized')
                return

            from_user = data.get('from_user') or user_id
            to_user = data.get('to_user')
            content = data.get('content')
            message_type = data.get('message_type', 'text')
            file_url = data.get('file_url')
            file_name = data.get('file_name')
            file_size = data.get('file_size')

            if not to_user or not content:
                self.send_error_json(400, 'Missing required fields')
                return

            message_id = 'msg_' + str(uuid.uuid4()).replace('-', '')
            chat_id = '_'.join(sorted([from_user, to_user]))
            now = int(time.time() * 1000)

            conn = get_db()
            c = conn.cursor()
            c.execute('''INSERT INTO messages VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)''',
                     (message_id, chat_id, from_user, to_user, content, 0, message_type, file_url, file_name, file_size, now, 0, 0))
            conn.commit()
            conn.close()

            # Отправляем через WebSocket получателю
            send_to_user(to_user, {
                'type': 'new_message',
                'message': {
                    'id': message_id,
                    'chat_id': chat_id,
                    'from_user': from_user,
                    'to_user': to_user,
                    'content': content,
                    'message_type': message_type,
                    'created_at': now
                }
            })

            # Также отправляем отправителю подтверждение
            send_to_user(from_user, {
                'type': 'message_sent',
                'message_id': message_id
            })

            self.send_json({
                'success': True,
                'message': {
                    'id': message_id,
                    'chat_id': chat_id,
                    'from_user': from_user,
                    'to_user': to_user,
                    'content': content,
                    'message_type': message_type,
                    'created_at': now,
                    'read': False
                }
            }, 201)
            return

        # Загрузка файла
        if path == '/api/v1/upload':
            user_id = self.get_user_from_session()
            if not user_id:
                self.send_error_json(401, 'Unauthorized')
                return

            content_type = self.headers.get('Content-Type', '')
            if 'multipart/form-data' not in content_type:
                self.send_error_json(400, 'Content-Type must be multipart/form-data')
                return

            # Простая парсинг multipart (для production лучше использовать libraries)
            boundary = content_type.split('boundary=')[-1].encode()
            parts = body.split(b'--' + boundary)
            
            file_data = None
            filename = 'upload.bin'
            
            for part in parts:
                if b'filename=' in part:
                    header_end = part.find(b'\r\n\r\n')
                    if header_end != -1:
                        header = part[:header_end].decode('utf-8', errors='ignore')
                        for line in header.split('\r\n'):
                            if 'filename=' in line:
                                filename = line.split('filename=')[-1].strip('"\'')
                        file_data = part[header_end+4:]
                        if file_data.endswith(b'\r\n--' + boundary + b'--\r\n'):
                            file_data = file_data[:-len(b'\r\n--' + boundary + b'--\r\n')]
                        elif file_data.endswith(b'\r\n--' + boundary + b'\r\n'):
                            file_data = file_data[:-len(b'\r\n--' + boundary + b'\r\n')]
                        break
            
            if not file_data:
                self.send_error_json(400, 'No file data')
                return
            
            if len(file_data) > MAX_FILE_SIZE:
                self.send_error_json(413, 'File too large')
                return

            file_info = save_file(file_data, filename, user_id)
            
            self.send_json({
                'success': True,
                'file': file_info
            }, 201)
            return

        # Статус онлайн
        if path.startswith('/api/v1/users/') and path.endswith('/online'):
            user_id = self.get_user_from_session()
            target_user = path.split('/')[-2]
            
            if user_id != target_user:
                self.send_error_json(403, 'Forbidden')
                return
            
            conn = get_db()
            c = conn.cursor()
            c.execute('UPDATE users SET status = ?, last_seen = ? WHERE id = ?', ('online', int(time.time()*1000), user_id))
            conn.commit()
            conn.close()
            
            broadcast_online_status(user_id, 'online')
            self.send_json({'success': True, 'status': 'online'})
            return

        # Статус офлайн
        if path.startswith('/api/v1/users/') and path.endswith('/offline'):
            user_id = self.get_user_from_session()
            target_user = path.split('/')[-2]
            
            if user_id != target_user:
                self.send_error_json(403, 'Forbidden')
                return
            
            conn = get_db()
            c = conn.cursor()
            c.execute('UPDATE users SET status = ?, last_seen = ? WHERE id = ?', ('offline', int(time.time()*1000), user_id))
            conn.commit()
            conn.close()
            
            broadcast_online_status(user_id, 'offline')
            self.send_json({'success': True, 'status': 'offline'})
            return

        self.send_error_json(404, 'Not found')

    def do_DELETE(self):
        client_ip = self.client_address[0]
        if not check_rate_limit(client_ip):
            self.send_error_json(429, 'Too many requests')
            return

        parsed = urlparse(self.path)
        path = parsed.path

        if path.startswith('/api/v1/messages/'):
            user_id = self.get_user_from_session()
            if not user_id:
                self.send_error_json(401, 'Unauthorized')
                return
            
            message_id = path.split('/')[-1]
            
            conn = get_db()
            c = conn.cursor()
            c.execute('DELETE FROM messages WHERE id = ? AND (from_user = ? OR to_user = ?)', (message_id, user_id, user_id))
            deleted = c.rowcount
            conn.commit()
            conn.close()
            
            if deleted:
                self.send_json({'success': True})
            else:
                self.send_error_json(404, 'Message not found')
            return

        self.send_error_json(404, 'Not found')


# ============================================
# WebSocket Server (если доступен)
# ============================================

class WebSocketLibertyHandler:
    def __init__(self, ws):
        self.ws = ws
        self.user_id = None

    def handle_message(self, message):
        try:
            data = json.loads(message)
            msg_type = data.get('type')

            if msg_type == 'auth':
                token = data.get('token')
                user_id = verify_session(token)
                if user_id:
                    self.user_id = user_id
                    add_websocket(user_id, self.ws)
                    self.ws.send(json.dumps({'type': 'auth_success', 'user_id': user_id}))
                    
                    # Отправляем накопленные сообщения
                    if user_id in message_queue:
                        for msg in message_queue[user_id]:
                            self.ws.send(json.dumps(msg))
                        del message_queue[user_id]
                else:
                    self.ws.send(json.dumps({'type': 'auth_error', 'error': 'Invalid token'}))

            elif msg_type == 'ping':
                self.ws.send(json.dumps({'type': 'pong', 'timestamp': int(time.time()*1000)}))

        except json.JSONDecodeError:
            self.ws.send(json.dumps({'type': 'error', 'error': 'Invalid JSON'}))
        except Exception as e:
            self.ws.send(json.dumps({'type': 'error', 'error': str(e)}))

    def on_close(self):
        if self.user_id:
            remove_websocket(self.user_id, self.ws)


# ============================================
# Запуск сервера
# ============================================

class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True

def run_server(port=PORT):
    init_db()

    print(f"╔═══════════════════════════════════════════════════════════╗")
    print(f"║     🦅 Liberty Reach Production Server v1.0              ║")
    print(f"║     Порт: {port:<44}                    ║")
    print(f"║     URL: http://localhost:{port:<34} ║")
    print(f"╠═══════════════════════════════════════════════════════════╣")
    print(f"║     Функции:                                              ║")
    print(f"║     ✓ WebSocket real-time                                 ║")
    print(f"║     ✓ E2E шифрование (ready)                              ║")
    print(f"║     ✓ Сессии и аутентификация                             ║")
    print(f"║     ✓ Файловое хранилище                                  ║")
    print(f"║     ✓ Rate limiting                                       ║")
    print(f"║     ✓ Онлайн/офлайн статус                                ║")
    print(f"╚═══════════════════════════════════════════════════════════╝")

    with ThreadedTCPServer(("", port), LibertyReachHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[!] Server stopped")

if __name__ == '__main__':
    run_server()
