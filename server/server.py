#!/usr/bin/env python3
"""
Liberty Reach Messenger - Backend Server
WebSocket сервер для обмена сообщениями в реальном времени
"""

import asyncio
import json
import uuid
import hashlib
from datetime import datetime
from typing import Dict, Set, Optional
from dataclasses import dataclass, asdict
from pathlib import Path
import websockets
from websockets.server import WebSocketServerProtocol

# Конфигурация
HOST = "0.0.0.0"
PORT = 8765
DB_FILE = Path("server_data.json")


@dataclass
class User:
    id: str
    username: str
    public_key: str
    status: str = "offline"
    last_seen: str = ""


@dataclass
class Message:
    id: str
    sender_id: str
    recipient_id: str
    content: str
    timestamp: str
    encrypted: bool = True
    delivered: bool = False


class MessageServer:
    def __init__(self):
        self.users: Dict[str, User] = {}
        self.messages: Dict[str, Message] = {}
        self.online_users: Dict[str, WebSocketServerProtocol] = {}
        self.user_connections: Dict[str, Set[str]] = {}  # user_id -> set of connection ids
        self.load_data()

    def load_data(self):
        """Загрузка данных из файла"""
        if DB_FILE.exists():
            try:
                data = json.loads(DB_FILE.read_text(encoding='utf-8'))
                self.users = {k: User(**v) for k, v in data.get('users', {}).items()}
                self.messages = {k: Message(**v) for k, v in data.get('messages', {}).items()}
                print(f"✅ Загружено {len(self.users)} пользователей, {len(self.messages)} сообщений")
            except Exception as e:
                print(f"⚠️ Ошибка загрузки данных: {e}")

    def save_data(self):
        """Сохранение данных в файл"""
        data = {
            'users': {k: asdict(v) for k, v in self.users.items()},
            'messages': {k: asdict(v) for k, v in self.messages.items()}
        }
        DB_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')

    def create_user(self, username: str, public_key: str) -> User:
        """Создание нового пользователя"""
        user_id = f"user_{uuid.uuid4().hex[:8]}"
        user = User(
            id=user_id,
            username=username,
            public_key=public_key,
            last_seen=datetime.now().isoformat()
        )
        self.users[user_id] = user
        self.save_data()
        return user

    def get_user_by_username(self, username: str) -> Optional[User]:
        """Поиск пользователя по имени"""
        for user in self.users.values():
            if user.username.lower() == username.lower():
                return user
        return None

    def store_message(self, sender_id: str, recipient_id: str, content: str) -> Message:
        """Сохранение сообщения"""
        msg = Message(
            id=f"msg_{uuid.uuid4().hex[:12]}",
            sender_id=sender_id,
            recipient_id=recipient_id,
            content=content,
            timestamp=datetime.now().isoformat(),
            delivered=recipient_id in self.online_users
        )
        self.messages[msg.id] = msg
        self.save_data()
        return msg

    def get_messages(self, user1_id: str, user2_id: str) -> list:
        """Получение истории переписки"""
        msgs = []
        for msg in self.messages.values():
            if (msg.sender_id == user1_id and msg.recipient_id == user2_id) or \
               (msg.sender_id == user2_id and msg.recipient_id == user1_id):
                msgs.append(asdict(msg))
        return sorted(msgs, key=lambda x: x['timestamp'])

    async def broadcast_user_status(self, user_id: str, status: str):
        """Рассылка статуса пользователя"""
        if user_id in self.users:
            user = self.users[user_id]
            user.status = status
            user.last_seen = datetime.now().isoformat()
            
            broadcast = {
                'type': 'user_status',
                'user_id': user_id,
                'username': user.username,
                'status': status
            }
            
            # Отправить всем подключенным
            for conn in self.online_users.values():
                try:
                    await conn.send(json.dumps(broadcast))
                except:
                    pass

    async def handle_register(self, ws: WebSocketServerProtocol, data: dict):
        """Регистрация пользователя"""
        username = data.get('username', '').strip()
        public_key = data.get('public_key', '')
        
        if not username:
            await ws.send(json.dumps({'type': 'error', 'message': 'Требуется имя пользователя'}))
            return

        # Проверка существующего пользователя
        existing = self.get_user_by_username(username)
        if existing:
            # Вход существующего пользователя
            self.online_users[existing.id] = ws
            await ws.send(json.dumps({
                'type': 'auth_success',
                'user': asdict(existing)
            }))
            await self.broadcast_user_status(existing.id, 'online')
            print(f"✅ {username} вошёл в систему")
        else:
            # Новый пользователь
            user = self.create_user(username, public_key)
            self.online_users[user.id] = ws
            await ws.send(json.dumps({
                'type': 'auth_success',
                'user': asdict(user)
            }))
            await self.broadcast_user_status(user.id, 'online')
            print(f"✅ {username} зарегистрирован")

    async def handle_send_message(self, ws: WebSocketServerProtocol, data: dict, user_id: str):
        """Отправка сообщения"""
        recipient_id = data.get('recipient_id')
        content = data.get('content', '')
        
        if not recipient_id or not content:
            await ws.send(json.dumps({'type': 'error', 'message': 'Некорректные данные'}))
            return

        msg = self.store_message(user_id, recipient_id, content)
        
        # Отправить получателю если онлайн
        if recipient_id in self.online_users:
            try:
                await self.online_users[recipient_id].send(json.dumps({
                    'type': 'new_message',
                    'message': asdict(msg)
                }))
            except:
                pass

        # Подтверждение отправителю
        await ws.send(json.dumps({
            'type': 'message_sent',
            'message': asdict(msg)
        }))

    async def handle_get_users(self, ws: WebSocketServerProtocol, user_id: str):
        """Список всех пользователей"""
        users_list = [asdict(u) for u in self.users.values() if u.id != user_id]
        await ws.send(json.dumps({
            'type': 'users_list',
            'users': users_list
        }))

    async def handle_get_messages(self, ws: WebSocketServerProtocol, data: dict, user_id: str):
        """История переписки"""
        other_user_id = data.get('user_id')
        if other_user_id:
            messages = self.get_messages(user_id, other_user_id)
            await ws.send(json.dumps({
                'type': 'messages_history',
                'messages': messages
            }))

    async def handler(self, ws: WebSocketServerProtocol, path: str):
        """Обработчик WebSocket подключений"""
        user_id = None
        
        try:
            async for message in ws:
                try:
                    data = json.loads(message)
                    msg_type = data.get('type')

                    if msg_type == 'register':
                        await self.handle_register(ws, data)
                        if user_id is None and 'user' in data:
                            user_id = data['user'].get('id')
                    
                    elif msg_type == 'auth' and user_id:
                        await self.handle_register(ws, data)
                    
                    elif msg_type == 'send_message' and user_id:
                        await self.handle_send_message(ws, data, user_id)
                    
                    elif msg_type == 'get_users' and user_id:
                        await self.handle_get_users(ws, user_id)
                    
                    elif msg_type == 'get_messages' and user_id:
                        await self.handle_get_messages(ws, data, user_id)
                    
                    elif msg_type == 'typing' and user_id:
                        # Индикатор набора текста
                        recipient_id = data.get('recipient_id')
                        if recipient_id in self.online_users:
                            try:
                                await self.online_users[recipient_id].send(json.dumps({
                                    'type': 'typing',
                                    'user_id': user_id
                                }))
                            except:
                                pass

                    else:
                        await ws.send(json.dumps({'type': 'error', 'message': 'Неизвестный тип'}))
                
                except json.JSONDecodeError:
                    await ws.send(json.dumps({'type': 'error', 'message': 'Неверный JSON'}))
                except Exception as e:
                    await ws.send(json.dumps({'type': 'error', 'message': str(e)}))
        
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            # Пользователь офлайн
            if user_id and user_id in self.online_users:
                del self.online_users[user_id]
                await self.broadcast_user_status(user_id, 'offline')
                print(f"❌ Пользователь {user_id} отключился")


async def main():
    server = MessageServer()
    
    print(f"🚀 Liberty Reach Messenger Server")
    print(f"📡 Запуск на {HOST}:{PORT}")
    
    async with websockets.serve(server.handler, HOST, PORT):
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 Сервер остановлен")
