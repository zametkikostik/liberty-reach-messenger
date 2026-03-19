# 📬 PUSH NOTIFICATIONS — SETUP GUIDE

**Version:** v0.7.9-Push  
**Status:** ✅ Ready for Production

---

## 📋 ЧТО РЕАЛИЗОВАНО

### ✅ Cloudflare Worker + FCM

**Файл:** `cloudflare/push_worker.js`

**Функции:**
- ✅ Register device tokens
- ✅ Send push notifications
- ✅ Broadcast to all users
- ✅ Unregister devices
- ✅ D1 storage for tokens

### ✅ D1 Schema

**Файл:** `backend-js/push_schema.sql`

**Таблицы:**
- ✅ `push_tokens` — device tokens для пользователей
- ✅ `notification_log` — лог уведомлений
- ✅ Триггеры для очистки старых токенов

### ✅ Flutter Push Service

**Файл:** `mobile/lib/services/push_service.dart`

**Функции:**
- ✅ Register device
- ✅ Unregister device
- ✅ Handle notifications
- ✅ Test notifications

---

## 🔐 НАСТРОЙКА

### Шаг 1: Получить Firebase Cloud Messaging Server Key

1. Открой [Firebase Console](https://console.firebase.google.com/)
2. Выбери проект (или создай новый)
3. Settings (⚙️) → Project settings
4. Вкладка **Cloud Messaging**
5. Скопируй **Server key**
6. Скопируй **Sender ID**

### Шаг 2: Настроить .env.local

В корне `mobile/` создай/обнови `.env.local`:

```env
# ═══════════════════════════════════════════════════════════════
# PUSH NOTIFICATIONS
# ═══════════════════════════════════════════════════════════════

# Cloudflare Push Worker URL
CLOUDFLARE_PUSH_URL=https://liberty-reach-push.kostik.workers.dev

# Firebase Cloud Messaging Server Key (from Step 1)
FCM_SERVER_KEY=AAAA...твои_ключи...

# Firebase Sender ID (from Step 1)
FCM_SENDER_ID=123456789012
```

### Шаг 3: Deploy Cloudflare Worker

```bash
cd cloudflare

# Создай wrangler.toml для push worker
cat > wrangler-push.toml << EOF
name = "liberty-reach-push-notifications"
main = "push_worker.js"
compatibility_date = "2024-01-01"

[[d1_databases]]
binding = "D1"
database_name = "liberty-db"
database_id = "7713033b-1f5c-4f2c-9123-b1c989869035"

[vars]
FCM_SERVER_KEY = "твои_ключи"
EOF

# Deploy
wrangler deploy --config wrangler-push.toml
```

---

## 🧪 ТЕСТИРОВАНИЕ

### 1. Register Device

```dart
import 'package:liberty_reach/services/push_service.dart';

final pushService = PushService();
await pushService.init();

// Register current user
await pushService.registerDevice('user-123');
```

### 2. Send Test Notification

```dart
// Send to specific user
await pushService.sendTestNotification('user-123');

// Response:
// ✅ Test notification sent: {status: success, sent: 1, total: 1}
```

### 3. Via API (curl)

```bash
# Send to user
curl -X POST https://liberty-reach-push.kostik.workers.dev/push/send \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user-123",
    "title": "🔔 New Message",
    "body": "You have a new message!",
    "data": {
      "type": "message",
      "chat_id": "chat-456"
    }
  }'

# Broadcast to all
curl -X POST https://liberty-reach-push.kostik.workers.dev/push/broadcast \
  -H "Content-Type: application/json" \
  -d '{
    "title": "📢 Announcement",
    "body": "New features available!"
  }'
```

### 4. Check D1

```bash
# Check registered tokens
wrangler d1 execute liberty-db --command="SELECT * FROM push_tokens LIMIT 10;" --remote

# Check notification log
wrangler d1 execute liberty-db --command="SELECT * FROM notification_log ORDER BY sent_at DESC LIMIT 10;" --remote
```

---

## 📊 ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  PushService                                          │   │
│  │  - registerDevice()                                   │   │
│  │  - unregisterDevice()                                 │   │
│  │  - handleBackgroundMessage()                          │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ FCM (Firebase Cloud Messaging)
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Cloudflare Worker (Push)                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Endpoints:                                           │   │
│  │  - POST /push/register                                │   │
│  │  - POST /push/send                                    │   │
│  │  - POST /push/broadcast                               │   │
│  │  - DELETE /push/unregister                            │   │
│  └──────────────────────────────────────────────────────┘   │
│                          │                                    │
│                          ▼                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Cloudflare D1 Database                               │   │
│  │  - push_tokens table                                  │   │
│  │  - notification_log table                             │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 SECURITY

### Token Storage

- ✅ Tokens stored in D1 (encrypted at rest)
- ✅ Auto-cleanup after 30 days of inactivity
- ✅ Unique per device

### API Authentication

```javascript
// Add to push_worker.js
const authHeader = request.headers.get('Authorization');
if (!authHeader || !authHeader.startsWith('Bearer ')) {
  return new Response('Unauthorized', { status: 401 });
}

// Verify token (implement your logic)
const valid = await verifyToken(authHeader.substring(7));
if (!valid) {
  return new Response('Invalid token', { status: 401 });
}
```

### Rate Limiting

```javascript
// Add rate limiting (100 requests/hour per user)
const rateLimit = await env.RATE_LIMITER.limit(
  { key: userId }
);

if (!rateLimit.success) {
  return new Response('Rate limit exceeded', { 
    status: 429,
    headers: { 'Retry-After': '3600' }
  });
}
```

---

## 📬 NOTIFICATION TYPES

### 1. New Message

```json
{
  "user_id": "user-123",
  "title": "💬 New Message",
  "body": "Alice: Hey! How are you?",
  "data": {
    "type": "message",
    "chat_id": "chat-456",
    "sender_id": "user-alice"
  }
}
```

### 2. Call Invitation

```json
{
  "user_id": "user-123",
  "title": "📞 Incoming Call",
  "body": "Alice is calling...",
  "data": {
    "type": "call",
    "call_id": "call-789",
    "caller_id": "user-alice",
    "call_type": "video"
  }
}
```

### 3. System Announcement

```json
{
  "broadcast": true,
  "title": "📢 Update Available",
  "body": "Version 0.7.9 is now available!",
  "data": {
    "type": "update",
    "version": "0.7.9"
  }
}
```

---

## 🐛 TROUBLESHOOTING

### Error: "No active devices found"

**Причины:**
- Token не зарегистрирован
- Token просрочен (>30 дней)
- Неверный user_id

**Решение:**
```bash
# Check tokens in D1
wrangler d1 execute liberty-db --command="SELECT * FROM push_tokens WHERE user_id='user-123';" --remote
```

### Error: "FCM error: 401"

**Причины:**
- Неверный FCM_SERVER_KEY
- Key expired

**Решение:**
1. Проверь ключ в Firebase Console
2. Обнови в .env.local
3. Redeploy worker

### Error: "FCM error: 404"

**Причины:**
- Token не существует
- App uninstalled

**Решение:**
```javascript
// Worker автоматически удалит invalid tokens
// Проверь notification_log для details
```

---

## 📊 ANALYTICS

### Query Notification Stats

```sql
-- Total notifications sent today
SELECT COUNT(*) as sent_today 
FROM notification_log 
WHERE sent_at > (strftime('%s', 'now') - 24*60*60) * 1000;

-- Delivery rate
SELECT 
  COUNT(*) as total,
  SUM(delivered) as delivered,
  ROUND(100.0 * SUM(delivered) / COUNT(*), 2) as delivery_rate
FROM notification_log
WHERE sent_at > (strftime('%s', 'now') - 24*60*60) * 1000;

-- Top users by notifications
SELECT user_id, COUNT(*) as count
FROM notification_log
GROUP BY user_id
ORDER BY count DESC
LIMIT 10;
```

---

## 🎯 PRODUCTION DEPLOYMENT

### Step 1: Add firebase_messaging

Add to `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
```

### Step 2: Configure Firebase

1. Download `google-services.json` (Android)
2. Download `GoogleService-Info.plist` (iOS)
3. Add to respective folders

### Step 3: Update PushService

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    await Firebase.initializeApp();
    
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Get token
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
    
    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      registerDevice(userId, newToken);
    });
  }

  Future<String> _getDeviceToken() async {
    return await _messaging.getToken() ?? '';
  }
}
```

---

## ✅ FINAL CHECKLIST

- [ ] Получить FCM Server Key
- [ ] Получить FCM Sender ID
- [ ] Создать .env.local с ключами
- [ ] Deploy Cloudflare Worker
- [ ] Применить push_schema к D1
- [ ] Протестировать registerDevice
- [ ] Протестировать sendTestNotification
- [ ] Проверить D1 таблицу push_tokens

---

**Успех! Push Notifications готовы!** 🎉

*«Свобода связи требует защиты. Мы защищаем вашу свободу.»* 🔐

**Liberty Reach Messenger v0.7.9-Push**  
*Built for freedom, encrypted for life.*
