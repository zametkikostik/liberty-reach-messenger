# 🗄️ D1 INTEGRATION — SETUP GUIDE

**Version:** v0.7.7-D1  
**Status:** ✅ Ready for Production

---

## 📋 ЧТО РЕАЛИЗОВАНО

### ✅ D1 API Service

**Файл:** `mobile/lib/services/d1_api_service.dart`

**Функции:**
- ✅ Прямой доступ к Cloudflare D1 через REST API
- ✅ Параметризованные SQL запросы (защита от SQL injection)
- ✅ CRUD операции для users и messages
- ✅ Chat list с unread count
- ✅ Отправка сообщений с `is_love_token`

### ✅ Chat List Screen (обновлён)

**Файл:** `mobile/lib/screens/chat_list_screen.dart`

**Функции:**
- ✅ Загрузка чатов из D1
- ✅ Pull-to-refresh
- ✅ Real unread count
- ✅ Loading indicator

### ✅ Chat Room Screen (обновлён)

**Файл:** `mobile/lib/screens/chat_room_screen.dart`

**Функции:**
- ✅ Загрузка сообщений из D1
- ✅ Отправка текстовых сообщений в D1
- ✅ Загрузка изображений (IPFS + D1)
- ✅ Love token detection
- ✅ Optimistic UI updates

---

## 🔐 НАСТРОЙКА CLOUDFLARE D1 API

### Шаг 1: Получить Cloudflare API Token

1. Открой https://dash.cloudflare.com/profile/api-tokens
2. Click **"Create Token"**
3. Выбери **"Create Custom Token"**
4. Permissions:
   - **Account** → **D1** → **Edit**
   - **Account** → **Cloudflare Workers** → **Read** (optional)
5. Click **"Continue to summary"**
6. Click **"Create Token"**
7. **Скопируй токен** (показывается только один раз!)

### Шаг 2: Получить Account ID

1. Открой https://dash.cloudflare.com/
2. Справа в sidebar будет **"Account ID"**
3. Скопируй его

### Шаг 3: Получить D1 Database ID

1. Открой https://dash.cloudflare.com/?to=/:account/d1
2. Click на свою базу данных (`liberty-db`)
3. В URL будет ID: `.../d1/database/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`
4. Скопируй ID

### Шаг 4: Создать .env.local

В корне `mobile/` создай файл `.env.local`:

```env
# ═══════════════════════════════════════════════════════════════
# CLOUDFLARE D1 API ACCESS
# ═══════════════════════════════════════════════════════════════

# API Token from Step 1
CLOUDFLARE_API_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Account ID from Step 2
CLOUDFLARE_ACCOUNT_ID=9d3f70325c3f26a70c09c2d13b981f3c

# D1 Database ID from Step 3
CLOUDFLARE_D1_DATABASE_ID=7713033b-1f5c-4f2c-9123-b1c989869035

# ═══════════════════════════════════════════════════════════════
# PINATA IPFS (для изображений)
# ═══════════════════════════════════════════════════════════════

PINATA_JWT=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

⚠️ **ВАЖНО:** `.env.local` уже добавлен в `.gitignore` — не коммить в Git!

---

## 🧪 ТЕСТИРОВАНИЕ

### 1. Проверка подключения

```dart
// В любом месте app:
import 'package:liberty_reach/services/d1_api_service.dart';

final d1 = D1ApiService();
await d1.init();

// Test connection
final success = await d1.testConnection();
print('D1 connected: $success');
```

### 2. Получить пользователя

```dart
final user = await d1.getUser('user-alice');
print('User: ${user?['full_name']}');
```

### 3. Отправить сообщение

```dart
await d1.sendMessage(
  messageId: 'msg-123',
  senderId: 'me',
  recipientId: 'user-alice',
  encryptedText: 'Hello!',
  nonce: 'random-nonce',
  isLoveToken: false,
);
```

### 4. Получить чаты

```dart
final chats = await d1.getChatList('me');
for (final chat in chats) {
  print('${chat['name']}: ${chat['last_message']}');
}
```

### 5. Получить сообщения

```dart
final messages = await d1.getMessages(
  userId1: 'me',
  userId2: 'user-alice',
  limit: 50,
);

for (final msg in messages) {
  print('${msg['sender_id']}: ${msg['text']}');
}
```

---

## 📊 D1 SCHEMA

### Таблица: users

```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    public_key TEXT NOT NULL,
    full_name TEXT,
    avatar_cid TEXT,
    bio TEXT DEFAULT '',
    phone_hash TEXT,
    email_hash TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen INTEGER
);
```

### Таблица: messages

```sql
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    sender_id TEXT NOT NULL,
    recipient_id TEXT NOT NULL,
    encrypted_text TEXT NOT NULL,
    nonce TEXT NOT NULL,
    signature TEXT,
    is_love_immutable INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at INTEGER,
    deleted_at DATETIME DEFAULT NULL,
    FOREIGN KEY (sender_id) REFERENCES users(id),
    FOREIGN KEY (recipient_id) REFERENCES users(id)
);
```

### Триггеры (Vault Protection)

```sql
-- 9 triggers for protection
- prevent_love_delete
- prevent_love_update
- prevent_love_soft_delete
- prevent_user_delete_with_messages
- prevent_user_delete_with_calls
- audit_user_update
- cleanup_expired_ice_candidates
- prevent_ice_candidate_modify
- prevent_schema_downgrade
```

---

## 🔐 БЕЗОПАСНОСТЬ

### Что зашифровано:

| Данные | Шифрование | Ключ |
|--------|------------|------|
| **encrypted_text** | ✅ AES-256-GCM | Сессионный (X25519) |
| **nonce** | ❌ Не шифруется | Нужен для расшифровки |
| **signature** | ✅ Ed25519 | Приватный ключ |

### Что НЕ зашифровано (метаданные):

| Данные | Видят | Причина |
|--------|-------|---------|
| `sender_id` | ✅ Cloudflare | Маршрутизация |
| `recipient_id` | ✅ Cloudflare | Маршрутизация |
| `created_at` | ✅ Cloudflare | Сортировка |
| `is_love_immutable` | ✅ Cloudflare | Vault protection |

### Защита от атак:

| Атака | Защита |
|-------|--------|
| **SQL Injection** | ✅ Параметризованные запросы |
| **XSS** | ✅ Нет JavaScript в БД |
| **CSRF** | ✅ API Token в заголовке |
| **MITM** | ✅ HTTPS + TLS 1.3 |
| **Direct DB Access** | ✅ API Token permissions |

---

## 🚀 PRODUCTION DEPLOYMENT

### Option A: Direct D1 API (Current)

**Pros:**
- ✅ Быстро (прямой доступ)
- ✅ Просто (один сервис)
- ✅ Дёшево (нет Worker costs)

**Cons:**
- ❌ API token на клиенте (риск)
- ❌ Нет business logic на сервере
- ❌ Rate limiting Cloudflare (1000 req/day free)

**Best for:** Development, MVP, internal apps

---

### Option B: Cloudflare Worker Proxy (Recommended)

**Architecture:**
```
Flutter App → Cloudflare Worker → D1 Database
     ↓              ↓
  JWT Auth     Business Logic
```

**Pros:**
- ✅ API token скрыт в Worker
- ✅ Business logic на сервере
- ✅ Rate limiting, auth, validation
- ✅ Бесплатно (100k requests/day)

**Cons:**
- ❌ Сложнее (доп. сервис)
- ❌ Extra latency (~50ms)

**How to migrate:**
1. Create Worker with `/api/messages` endpoint
2. Move D1 queries to Worker
3. Update app to call Worker instead of D1 API
4. Add JWT authentication

---

## 🐛 TROUBLESHOOTING

### Error: "Invalid API token"

**Причины:**
- Token скопирован с пробелами
- Token expired (30 days)
- Wrong permissions

**Решение:**
1. Проверь токен в .env.local (без пробелов)
2. Создай новый токен
3. Проверь permissions: Account → D1 → Edit

---

### Error: "Database not found"

**Причины:**
- Wrong database ID
- Database deleted

**Решение:**
1. Проверь `CLOUDFLARE_D1_DATABASE_ID`
2. Убедись что БД существует в Cloudflare Dashboard

---

### Error: "SQLITE_CONSTRAINT"

**Причины:**
- FOREIGN KEY violation
- UNIQUE constraint violation

**Решение:**
1. Проверь что `sender_id` и `recipient_id` существуют в `users`
2. Проверь что `message_id` уникален

---

### Error: "🔒 VAULT PROTECTED"

**Причины:**
- Попытка удалить сообщение с `is_love_immutable=1`

**Решение:**
- Это нормальное поведение! Вечные сообщения нельзя удалить.

---

## 📊 API REFERENCE

### D1ApiService Methods

```dart
// Initialize
await d1.init();

// Test connection
await d1.testConnection();

// Users
await d1.getUser(userId);
await d1.upsertUser(userId: '...', publicKey: '...');

// Messages
await d1.getMessages(userId1: '...', userId2: '...');
await d1.sendMessage(...);
await d1.deleteMessage(messageId);

// Chat List
await d1.getChatList(userId);

// Raw SQL
await d1.query('SELECT * FROM users');
await d1.execute('DELETE FROM ...');
```

---

## 🎯 NEXT STEPS

### 1. Image Decryption (TODO)

```dart
// In MessageBubble:
if (widget.messageType == 'image') {
  final decrypted = await StorageService.downloadAndDecryptFile(
    cid: widget.text,
    nonce: widget.nonce,
  );
  // Display with Image.memory(decrypted)
}
```

### 2. Real-time WebSocket (TODO)

```dart
// Use Cloudflare D1 Webhooks or Workers
// to push new messages to clients
```

### 3. Worker Proxy (TODO)

```javascript
// worker.js
export default {
  async fetch(request, env) {
    const { message } = await request.json();
    await env.DB.prepare('INSERT INTO messages...').run();
    return Response.json({ success: true });
  }
}
```

---

## ✅ FINAL CHECKLIST

- [ ] Создать Cloudflare API Token
- [ ] Скопировать Account ID
- [ ] Скопировать D1 Database ID
- [ ] Создать `.env.local` с ключами
- [ ] Запустить app
- [ ] Проверить Chat List
- [ ] Отправить сообщение
- [ ] Проверить D1 Dashboard

---

**Успех! D1 Integration готова!** 🎉

*«Свобода связи требует защиты. Мы защищаем вашу свободу.»* 🔐

**Liberty Reach Messenger v0.7.7-D1**  
*Built for freedom, encrypted for life.*
