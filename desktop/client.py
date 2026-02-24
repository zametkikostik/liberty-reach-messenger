#!/usr/bin/env python3
"""
Liberty Reach Messenger - Desktop Client
Кроссплатформенный клиент для рабочего стола
"""

import asyncio
import json
import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
from datetime import datetime
import websockets
import threading
import queue

class DesktopClient:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Liberty Reach Messenger")
        self.root.geometry("900x600")
        self.root.minsize(700, 500)
        
        # State
        self.ws = None
        self.current_user = None
        self.users = {}
        self.messages = {}
        self.active_chat = None
        self.message_queue = queue.Queue()
        
        # Configure style
        self.setup_styles()
        
        # Build UI
        self.setup_ui()
        
        # Start WebSocket listener
        self.connect()
        
        # Start message processor
        self.process_messages()
        
    def setup_styles(self):
        """Настройка стилей"""
        style = ttk.Style()
        style.theme_use('clam')
        
        # Colors
        self.bg_dark = '#0f172a'
        self.bg_secondary = '#1e293b'
        self.bg_tertiary = '#334155'
        self.text_primary = '#f1f5f9'
        self.text_secondary = '#94a3b8'
        self.primary = '#4f46e5'
        self.success = '#22c55e'
        
        # Configure colors
        self.root.configure(bg=self.bg_dark)
        style.configure('TFrame', background=self.bg_dark)
        style.configure('TLabel', background=self.bg_dark, foreground=self.text_primary)
        style.configure('Header.TLabel', font=('Segoe UI', 12, 'bold'))
        style.configure('Status.TLabel', font=('Segoe UI', 9), foreground=self.success)
        
    def setup_ui(self):
        """Создание интерфейса"""
        # Login Frame
        self.login_frame = ttk.Frame(self.root, padding=40)
        self.login_frame.pack(fill=tk.BOTH, expand=True)
        
        # Logo
        logo_frame = ttk.Frame(self.login_frame)
        logo_frame.pack(pady=(0, 30))
        
        logo_label = tk.Label(
            logo_frame,
            text="🔐",
            font=('Segoe UI', 48),
            bg=self.bg_dark
        )
        logo_label.pack()
        
        title_label = tk.Label(
            logo_frame,
            text="Liberty Reach",
            font=('Segoe UI', 24, 'bold'),
            bg=self.bg_dark,
            fg=self.text_primary
        )
        title_label.pack()
        
        subtitle_label = tk.Label(
            logo_frame,
            text="Безопасный мессенджер",
            font=('Segoe UI', 10),
            bg=self.bg_dark,
            fg=self.text_secondary
        )
        subtitle_label.pack()
        
        # Username input
        input_frame = ttk.Frame(self.login_frame)
        input_frame.pack(fill=tk.X, pady=20)
        
        tk.Label(
            input_frame,
            text="Имя пользователя:",
            font=('Segoe UI', 10),
            bg=self.bg_dark,
            fg=self.text_secondary
        ).pack(anchor=tk.W, pady=(0, 5))
        
        self.username_entry = tk.Entry(
            input_frame,
            font=('Segoe UI', 12),
            bg=self.bg_tertiary,
            fg=self.text_primary,
            insertbackground=self.text_primary,
            relief=tk.FLAT,
            bd=5
        )
        self.username_entry.pack(fill=tk.X, ipady=5)
        
        # Login button
        self.login_btn = tk.Button(
            self.login_frame,
            text="Войти",
            font=('Segoe UI', 12, 'bold'),
            bg=self.primary,
            fg='white',
            relief=tk.FLAT,
            cursor='hand2',
            command=self.login
        )
        self.login_btn.pack(fill=tk.X, ipady=10, pady=(20, 0))
        
        # Status label
        self.status_label = tk.Label(
            self.login_frame,
            text="",
            font=('Segoe UI', 9),
            bg=self.bg_dark
        )
        self.status_label.pack(pady=(10, 0))
        
        # Chat Interface (hidden initially)
        self.chat_frame = ttk.Frame(self.root)
        
        # Left panel - Users list
        self.users_panel = tk.Frame(self.chat_frame, bg=self.bg_secondary, width=250)
        self.users_panel.pack(side=tk.LEFT, fill=tk.Y)
        self.users_panel.pack_propagate(False)
        
        # Header
        users_header = tk.Frame(self.users_panel, bg=self.bg_secondary, height=60)
        users_header.pack(fill=tk.X)
        users_header.pack_propagate(False)
        
        tk.Label(
            users_header,
            text="💬 Чаты",
            font=('Segoe UI', 14, 'bold'),
            bg=self.bg_secondary,
            fg=self.text_primary
        ).pack(pady=20, padx=15, anchor=tk.W)
        
        # Current user info
        self.user_info_frame = tk.Frame(self.users_panel, bg=self.bg_tertiary)
        self.user_info_frame.pack(fill=tk.X, padx=10, pady=5)
        
        self.user_avatar_label = tk.Label(
            self.user_info_frame,
            text="",
            font=('Segoe UI', 12, 'bold'),
            bg=self.primary,
            fg='white',
            width=3,
            height=2
        )
        self.user_avatar_label.pack(side=tk.LEFT, padx=10, pady=10)
        
        self.user_name_label = tk.Label(
            self.user_info_frame,
            text="",
            font=('Segoe UI', 10, 'bold'),
            bg=self.bg_tertiary,
            fg=self.text_primary
        )
        self.user_name_label.pack(side=tk.LEFT, pady=15)
        
        # Users listbox
        self.users_listbox = tk.Listbox(
            self.users_panel,
            font=('Segoe UI', 10),
            bg=self.bg_secondary,
            fg=self.text_primary,
            selectbackground=self.primary,
            selectforeground='white',
            relief=tk.FLAT,
            highlightthickness=0
        )
        self.users_listbox.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        self.users_listbox.bind('<<ListboxSelect>>', self.on_user_select)
        
        # Right panel - Chat
        self.chat_panel = tk.Frame(self.chat_frame, bg=self.bg_dark)
        self.chat_panel.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        # Chat header
        self.chat_header = tk.Frame(self.chat_panel, bg=self.bg_secondary, height=60)
        self.chat_header.pack(fill=tk.X)
        self.chat_header.pack_propagate(False)
        
        self.chat_avatar_label = tk.Label(
            self.chat_header,
            text="",
            font=('Segoe UI', 12, 'bold'),
            bg=self.primary,
            fg='white',
            width=3,
            height=2
        )
        self.chat_avatar_label.pack(side=tk.LEFT, padx=15, pady=10)
        
        self.chat_name_label = tk.Label(
            self.chat_header,
            text="",
            font=('Segoe UI', 12, 'bold'),
            bg=self.bg_secondary,
            fg=self.text_primary
        )
        self.chat_name_label.pack(side=tk.LEFT, pady=20)
        
        self.chat_status_label = tk.Label(
            self.chat_header,
            text="",
            font=('Segoe UI', 9),
            bg=self.bg_secondary,
            fg=self.success
        )
        self.chat_status_label.pack(side=tk.LEFT, padx=10, pady=25)
        
        # Messages area
        self.messages_text = scrolledtext.ScrolledText(
            self.chat_panel,
            wrap=tk.WORD,
            font=('Segoe UI', 10),
            bg=self.bg_dark,
            fg=self.text_primary,
            relief=tk.FLAT,
            padx=20,
            pady=20
        )
        self.messages_text.pack(fill=tk.BOTH, expand=True)
        
        # Configure tags for messages
        self.messages_text.tag_configure('sent', justify='right')
        self.messages_text.tag_configure('received', justify='left')
        self.messages_text.tag_configure('time', foreground=self.text_secondary, font=('Segoe UI', 8))
        
        # Message input
        input_container = tk.Frame(self.chat_panel, bg=self.bg_secondary, height=60)
        input_container.pack(fill=tk.X, side=tk.BOTTOM)
        input_container.pack_propagate(False)
        
        self.message_entry = tk.Entry(
            input_container,
            font=('Segoe UI', 11),
            bg=self.bg_tertiary,
            fg=self.text_primary,
            insertbackground=self.text_primary,
            relief=tk.FLAT
        )
        self.message_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=15, pady=10, ipady=5)
        self.message_entry.bind('<Return>', self.send_message)
        
        send_btn = tk.Button(
            input_container,
            text="➤",
            font=('Segoe UI', 14),
            bg=self.primary,
            fg='white',
            relief=tk.FLAT,
            cursor='hand2',
            width=3,
            command=self.send_message
        )
        send_btn.pack(side=tk.RIGHT, padx=10, pady=10)
        
    def setup_chat_ui(self):
        """Переключение на чат интерфейс"""
        self.login_frame.pack_forget()
        self.chat_frame.pack(fill=tk.BOTH, expand=True)
        
    def connect(self):
        """Подключение к серверу"""
        threading.Thread(target=self.run_websocket, daemon=True).start()
        
    def run_websocket(self):
        """WebSocket цикл"""
        async def connect_async():
            try:
                uri = "ws://localhost:8765"
                async with websockets.connect(uri) as websocket:
                    self.ws = websocket
                    self.root.after(0, lambda: self.set_status("Подключено", "success"))
                    
                    async for message in websocket:
                        self.message_queue.put(message)
                        
            except Exception as e:
                self.root.after(0, lambda: self.set_status(f"Ошибка: {e}", "error"))
                self.ws = None
                
        asyncio.run(connect_async())
        
    def process_messages(self):
        """Обработка входящих сообщений"""
        try:
            while True:
                message = self.message_queue.get_nowait()
                data = json.loads(message)
                self.handle_message(data)
        except queue.Empty:
            pass
        
        self.root.after(100, self.process_messages)
        
    def handle_message(self, data):
        """Обработка сообщения"""
        msg_type = data.get('type')
        
        if msg_type == 'auth_success':
            self.current_user = data['user']
            self.root.after(0, self.setup_chat_ui)
            self.root.after(0, lambda: self.user_name_label.config(text=self.current_user['username']))
            self.root.after(0, lambda: self.user_avatar_label.config(text=self.current_user['username'][0].upper()))
            self.send_command({'type': 'get_users'})
            
        elif msg_type == 'users_list':
            self.users = {u['id']: u for u in data['users']}
            self.root.after(0, self.update_users_list)
            
        elif msg_type == 'messages_history':
            self.messages = {m['id']: m for m in data['messages']}
            self.root.after(0, self.display_messages)
            
        elif msg_type == 'new_message' or msg_type == 'message_sent':
            msg = data['message']
            self.messages[msg['id']] = msg
            if self.active_chat and (msg['sender_id'] == self.active_chat or msg['recipient_id'] == self.active_chat):
                self.root.after(0, lambda: self.add_message_to_display(msg))
                
        elif msg_type == 'user_status':
            if data['user_id'] in self.users:
                self.users[data['user_id']]['status'] = data['status']
                self.root.after(0, self.update_users_list)
                
        elif msg_type == 'error':
            self.root.after(0, lambda: messagebox.showerror("Ошибка", data['message']))
            
    def login(self):
        """Вход в систему"""
        username = self.username_entry.get().strip()
        if not username:
            messagebox.showwarning("Предупреждение", "Введите имя пользователя")
            return
            
        self.login_btn.config(state='disabled', text='Подключение...')
        
        if self.ws:
            self.send_command({
                'type': 'register',
                'username': username,
                'public_key': f'desktop-key-{datetime.now().timestamp()}'
            })
        else:
            self.set_status("Нет подключения к серверу", "error")
            self.login_btn.config(state='normal', text='Войти')
            
    def send_command(self, data):
        """Отправка команды"""
        if self.ws:
            asyncio.new_event_loop().run_until_complete(self.ws.send(json.dumps(data)))
            
    def send_message(self, event=None):
        """Отправка сообщения"""
        content = self.message_entry.get().strip()
        if not content or not self.active_chat:
            return
            
        self.send_command({
            'type': 'send_message',
            'recipient_id': self.active_chat,
            'content': content
        })
        
        self.message_entry.delete(0, tk.END)
        
    def on_user_select(self, event):
        """Выбор пользователя"""
        selection = self.users_listbox.curselection()
        if not selection:
            return
            
        index = selection[0]
        user_ids = list(self.users.keys())
        
        if index < len(user_ids):
            self.active_chat = user_ids[index]
            user = self.users[self.active_chat]
            
            # Update header
            self.chat_name_label.config(text=user['username'])
            self.chat_avatar_label.config(text=user['username'][0].upper())
            self.chat_status_label.config(text='онлайн' if user['status'] == 'online' else 'офлайн')
            
            # Clear and load messages
            self.messages_text.delete('1.0', tk.END)
            self.send_command({
                'type': 'get_messages',
                'user_id': self.active_chat
            })
            
    def update_users_list(self):
        """Обновление списка пользователей"""
        self.users_listbox.delete(0, tk.END)
        
        for user in self.users.values():
            status_icon = "🟢" if user['status'] == 'online' else "⚫"
            self.users_listbox.insert(tk.END, f"{status_icon} {user['username']}")
            
    def display_messages(self):
        """Отображение сообщений"""
        self.messages_text.delete('1.0', tk.END)
        
        sorted_messages = sorted(self.messages.values(), key=lambda x: x['timestamp'])
        
        for msg in sorted_messages:
            self.add_message_to_display(msg)
            
    def add_message_to_display(self, msg):
        """Добавление сообщения"""
        is_sent = msg['sender_id'] == self.current_user['id']
        time_str = datetime.fromisoformat(msg['timestamp']).strftime('%H:%M')
        
        tag = 'sent' if is_sent else 'received'
        prefix = "Вы: " if is_sent else ""
        
        self.messages_text.insert(tk.END, f"\n{prefix}{msg['content']}\n", tag)
        self.messages_text.insert(tk.END, f"{time_str}\n\n", 'time')
        self.messages_text.see(tk.END)
        
    def set_status(self, text, status_type="info"):
        """Установка статуса"""
        color = self.success if status_type == "success" else "#ef4444"
        self.status_label.config(text=text, fg=color)
        
    def run(self):
        """Запуск приложения"""
        self.root.mainloop()


if __name__ == "__main__":
    client = DesktopClient()
    client.run()
