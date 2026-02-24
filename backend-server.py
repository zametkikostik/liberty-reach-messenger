#!/usr/bin/env python3
"""
Liberty Reach Messenger - Real-time Backend
Python симулатор на Cloudflare Worker с D1 база данни
"""

import http.server
import socketserver
import json
import uuid
import time
import sqlite3
import hashlib
import threading
from urllib.parse import urlparse, parse_qs
from datetime import datetime

# Database setup
def init_db():
    conn = sqlite3.connect('liberty_reach.db')
    c = conn.cursor()
    
    c.execute('''CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        public_key TEXT,
        created_at INTEGER NOT NULL,
        last_seen INTEGER NOT NULL,
        status TEXT DEFAULT 'offline'
    )''')
    
    c.execute('''CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT NOT NULL,
        from_user TEXT NOT NULL,
        to_user TEXT NOT NULL,
        content TEXT NOT NULL,
        encrypted INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        read INTEGER DEFAULT 0
    )''')
    
    # Insert demo users
    demo_users = [
        ('user_pavel', 'Павел', 'pq_key_pavel', int(time.time()*1000), int(time.time()*1000), 'online'),
        ('user_elon', 'Илон', 'pq_key_elon', int(time.time()*1000), int(time.time()*1000), 'online'),
        ('user_news', 'LibertyNews', 'pq_key_news', int(time.time()*1000), int(time.time()*1000), 'online'),
    ]
    
    c.executemany('INSERT OR IGNORE INTO users VALUES (?,?,?,?,?,?)', demo_users)
    
    # Insert demo messages
    demo_messages = [
        ('msg_1', 'user_pavel_user_elon', 'user_pavel', 'user_elon', 'Добро пожаловать в Liberty Reach! 🦅', 1, int(time.time()*1000)-600000, 1),
        ('msg_2', 'user_pavel_user_elon', 'user_elon', 'user_pavel', 'Спасибо! Отличный мессенджер!', 1, int(time.time()*1000)-300000, 1),
    ]
    
    c.executemany('INSERT OR IGNORE INTO messages VALUES (?,?,?,?,?,?,?,?)', demo_messages)
    
    conn.commit()
    conn.close()
    print("[✓] Database initialized")

# HTTP Handler
class LibertyReachHandler(http.server.SimpleHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        if path == '/' or path == '/health':
            self.send_json({
                'status': 'ok',
                'service': 'Liberty Reach Messenger',
                'version': '0.2.0',
                'edge': 'localhost',
                'timestamp': int(time.time()*1000)
            })
        
        elif path == '/api/v1/users':
            conn = sqlite3.connect('liberty_reach.db')
            c = conn.cursor()
            c.execute('SELECT id, username, public_key, created_at, last_seen, status FROM users ORDER BY last_seen DESC')
            users = [{'id': r[0], 'username': r[1], 'public_key': r[2], 'created_at': r[3], 'last_seen': r[4], 'status': r[5]} for r in c.fetchall()]
            conn.close()
            self.send_json({'users': users, 'total': len(users)})
        
        elif path.startswith('/api/v1/users/') and not path.startswith('/api/v1/users/online') and not path.startswith('/api/v1/users/offline'):
            user_id = path.split('/')[-1]
            conn = sqlite3.connect('liberty_reach.db')
            c = conn.cursor()
            c.execute('SELECT id, username, public_key, created_at, last_seen, status FROM users WHERE id = ?', (user_id,))
            row = c.fetchone()
            conn.close()
            if row:
                self.send_json({'user': {'id': row[0], 'username': row[1], 'public_key': row[2], 'created_at': row[3], 'last_seen': row[4], 'status': row[5]}})
            else:
                self.send_error_json(404, 'User not found')
        
        elif path.startswith('/api/v1/messages/'):
            user_id = path.split('/')[-1]
            conn = sqlite3.connect('liberty_reach.db')
            c = conn.cursor()
            c.execute('''SELECT m.id, m.chat_id, m.from_user, m.to_user, m.content, m.encrypted, m.created_at, m.read, u.username
                        FROM messages m LEFT JOIN users u ON m.from_user = u.id
                        WHERE m.to_user = ? OR m.from_user = ? ORDER BY m.created_at DESC LIMIT 100''', (user_id, user_id))
            messages = [{'id': r[0], 'chat_id': r[1], 'from_user': r[2], 'to_user': r[3], 'content': r[4], 'encrypted': bool(r[5]), 'created_at': r[6], 'read': bool(r[7]), 'from_username': r[8]} for r in c.fetchall()]
            c.execute('UPDATE messages SET read = 1 WHERE to_user = ? AND read = 0', (user_id,))
            conn.commit()
            conn.close()
            self.send_json({'messages': messages, 'total': len(messages)})
        
        elif path.startswith('/api/v1/chats/'):
            user_id = path.split('/')[-1]
            conn = sqlite3.connect('liberty_reach.db')
            c = conn.cursor()
            c.execute('''SELECT DISTINCT CASE WHEN m.from_user = ? THEN m.to_user ELSE m.from_user END as chat_user_id,
                        u.username as chat_user_name, u.status as chat_user_status,
                        (SELECT content FROM messages WHERE (from_user = ? AND to_user = chat_user_id) OR (from_user = chat_user_id AND to_user = ?) ORDER BY created_at DESC LIMIT 1) as last_message,
                        (SELECT created_at FROM messages WHERE (from_user = ? AND to_user = chat_user_id) OR (from_user = chat_user_id AND to_user = ?) ORDER BY created_at DESC LIMIT 1) as last_message_time,
                        (SELECT COUNT(*) FROM messages WHERE to_user = ? AND from_user = chat_user_id AND read = 0) as unread_count
                        FROM messages m LEFT JOIN users u ON u.id = chat_user_id
                        WHERE m.from_user = ? OR m.to_user = ? ORDER BY last_message_time DESC''',
                      (user_id, user_id, user_id, user_id, user_id, user_id, user_id, user_id, user_id))
            chats = [{'chat_user_id': r[0], 'chat_user_name': r[1], 'chat_user_status': r[2], 'last_message': r[3], 'last_message_time': r[4], 'unread_count': r[5]} for r in c.fetchall()]
            conn.close()
            self.send_json({'chats': chats, 'total': len(chats)})
        
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'Liberty Reach Messenger API')
    
    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else '{}'
        
        try:
            data = json.loads(body) if body else {}
        except:
            data = {}
        
        if path == '/api/v1/register':
            username = data.get('username', '').strip()
            public_key = data.get('public_key', '')
            
            if not username or len(username) < 3:
                self.send_error_json(400, 'Username must be at least 3 characters')
                return
            
            conn = sqlite3.connect('liberty_reach.db')
            c = conn.cursor()
            c.execute('SELECT id FROM users WHERE username = ?', (username,))
            if c.fetchone():
                conn.close()
                self.send_error_json(409, 'Username taken')
                return
            
            user_id = 'user_' + str(uuid.uuid4()).replace('-', '')[:16]
            now = int(time.time()*1000)
            c.execute('INSERT INTO users VALUES (?,?,?,?,?,?)', (user_id, username, public_key, now, now, 'online'))
            conn.commit()
            conn.close()
            
            self.send_json({
                'success': True,
                'user': {'id': user_id, 'username': username, 'public_key': public_key, 'created_at': now, 'status': 'online'}
            }, 201)
        
        elif path == '/api/v1/messages':
            from_user = data.get('from_user')
            to_user = data.get('to_user')
            content = data.get('content')
            encrypted = data.get('encrypted', True)
            
            if not from_user or not to_user or not content:
                self.send_error_json(400, 'Missing required fields')
                return
            
            message_id = 'msg_' + str(uuid.uuid4()).replace('-', '')
            chat_id = '_'.join(sorted([from_user, to_user]))
            now = int(time.time()*1000)
            
            conn = sqlite3.connect('liberty_reach.db')
            c = conn.cursor()
            c.execute('INSERT INTO messages VALUES (?,?,?,?,?,?,?,?)',
                     (message_id, chat_id, from_user, to_user, content, 1 if encrypted else 0, now, 0))
            conn.commit()
            conn.close()
            
            self.send_json({
                'success': True,
                'message': {'id': message_id, 'chat_id': chat_id, 'from_user': from_user, 'to_user': to_user,
                           'content': content, 'encrypted': encrypted, 'created_at': now, 'read': False}
            }, 201)
        
        elif path.startswith('/api/v1/users/') and path.endswith('/online'):
            user_id = path.split('/')[-2]
            conn = sqlite3.connect('liberty_reach.db')
            c = conn.cursor()
            c.execute('UPDATE users SET status = ?, last_seen = ? WHERE id = ?', ('online', int(time.time()*1000), user_id))
            conn.commit()
            conn.close()
            self.send_json({'success': True, 'status': 'online'})
        
        elif path.startswith('/api/v1/users/') and path.endswith('/offline'):
            user_id = path.split('/')[-2]
            conn = sqlite3.connect('liberty_reach.db')
            c = conn.cursor()
            c.execute('UPDATE users SET status = ?, last_seen = ? WHERE id = ?', ('offline', int(time.time()*1000), user_id))
            conn.commit()
            conn.close()
            self.send_json({'success': True, 'status': 'offline'})
        
        else:
            self.send_error_json(404, 'Not found')
    
    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))
    
    def send_error_json(self, status, message):
        self.send_response(status)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps({'error': message}).encode('utf-8'))
    
    def log_message(self, format, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {args[0]}")

def run_server(port=8787):
    init_db()
    
    with socketserver.TCPServer(("", port), LibertyReachHandler) as httpd:
        print(f"╔═══════════════════════════════════════════════════════════╗")
        print(f"║     🦅 Liberty Reach Backend Server                       ║")
        print(f"║     Порт: {port:<44}                    ║")
        print(f"║     URL: http://localhost:{port:<34} ║")
        print(f"╚═══════════════════════════════════════════════════════════╝")
        httpd.serve_forever()

if __name__ == '__main__':
    run_server()
