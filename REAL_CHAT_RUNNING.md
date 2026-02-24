# 🦅 Liberty Reach Messenger - Реален Месинджър!

## ✅ РАБОТИ! Реални потребители, реални съобщения!

---

## 🚀 Как да стартирате

### 1. Стартиране на Backend
```bash
cd /home/kostik/liberty-reach-messenger
python3 backend-server.py
```

### 2. Отворете Месинджъра
```
http://localhost:3000/web/realtime-chat.html
```

Или от главната страница:
```
http://localhost:3000
```

---

## 📊 Статус на Компонентите

| Компонент | Статус | URL/Команда |
|-----------|--------|-------------|
| **Backend Server** | 🟢 | http://localhost:8787 |
| **HTTP Server** | 🟢 | http://localhost:3000 |
| **Real-time Chat** | 🟢 | /web/realtime-chat.html |
| **SQLite Database** | ✅ | liberty_reach.db |

---

## 💬 Възможности

### ✅ Реална Регистрация
- Всеки потребител се регистрира с уникално име
- Автоматично генериране на ID
- Запазване в SQLite база данни
- Статус онлайн/офлайн

### ✅ Съобщения в Реално Време
- Изпращане на съобщения между потребители
- Запазване на историята
- Маркиране като прочетени
- Polling на всеки 3 секунди

### ✅ Списък с Потребители
- Всички регистрирани потребители
- Индикатор за онлайн статус
- Последно съобщение в чата
- Брой непрочетени

### ✅ Чат Интерфейс
- Съобщения в стил балончета
- Време на изпращане
- Индикатори за прочетено (✓✓)
- Автоматично скролване

---

## 🎯 Как да Използвате

### Стъпка 1: Регистрация
1. Отворете http://localhost:3000
2. Кликнете на "Реален Месинджър"
3. Въведете име (мин. 3 знака)
4. Натиснете "Вход"

### Стъпка 2: Изберете Чат
1. Вижте списъка с потребители вляво
2. Кликнете на потребител
3. Започнете разговор

### Стъпка 3: Изпратете Съобщение
1. Напишете в полето долу
2. Натиснете Enter или ➤
3. Съобщението се запазва в базата
4. Получателят ще го види при следващо обновяване

---

## 🔧 API Endpoints

### Регистрация
```bash
POST http://localhost:8787/api/v1/register
Content-Type: application/json

{
  "username": "Иван",
  "public_key": "pq_key_..."
}
```

### Вземане на Потребители
```bash
GET http://localhost:8787/api/v1/users
```

### Изпращане на Съобщение
```bash
POST http://localhost:8787/api/v1/messages
Content-Type: application/json

{
  "from_user": "user_123",
  "to_user": "user_456",
  "content": "Здравей!",
  "encrypted": false
}
```

### Вземане на Съобщения
```bash
GET http://localhost:8787/api/v1/messages/{user_id}
```

### Онлайн Статус
```bash
POST http://localhost:8787/api/v1/users/{user_id}/online
POST http://localhost:8787/api/v1/users/{user_id}/offline
```

---

## 📁 База Данни

### Таблица: users
```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    public_key TEXT,
    created_at INTEGER,
    last_seen INTEGER,
    status TEXT CHECK(status IN ('online', 'offline'))
);
```

### Таблица: messages
```sql
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    from_user TEXT NOT NULL,
    to_user TEXT NOT NULL,
    content TEXT NOT NULL,
    encrypted INTEGER DEFAULT 1,
    created_at INTEGER,
    read INTEGER DEFAULT 0
);
```

---

## 🧪 Тестване с curl

### Регистрация на нов потребител
```bash
curl -X POST http://localhost:8787/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{"username":"Тест","public_key":"test_key"}'
```

### Вземане на всички потребители
```bash
curl http://localhost:8787/api/v1/users
```

### Изпращане на съобщение
```bash
curl -X POST http://localhost:8787/api/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"from_user":"user_pavel","to_user":"user_elon","content":"Здравей!","encrypted":false}'
```

### Вземане на съобщения
```bash
curl http://localhost:8787/api/v1/messages/user_pavel
```

---

## 🎨 Скриншот

```
┌─────────────────────────────────────────────────────────────┐
│  🦅 Liberty Reach          👤 [ТвоятПрофил] [Изход]        │
├──────────────────┬──────────────────────────────────────────┤
│                  │  👤 Павел                  ⋮            │
│  👤● Павел       │  ────────────────────────────────────── │
│  Здравей!        │                                          │
│  14:30           │  💬 Здравей! Как си?                    │
│                  │     14:30   ✓✓                          │
│  👤● Илон       │                                          │
│  На Марс...      │  💬 Добре, благодаря!                   │
│  14:25           │     14:31   ✓✓                          │
│                  │                                          │
│  📰● Liberty... │  ┌─────────────────────────────────┐   │
│  Обновление...   │  │ [Напишете съобщение...]   [➤] │   │
│  14:00           │  └─────────────────────────────────┘   │
└──────────────────┴──────────────────────────────────────────┘
```

---

## 📊 Демонстрационни Потребители

При първи старт се създават:

| ID | Име | Статус |
|----|-----|--------|
| user_pavel | Павел | 🟢 Онлайн |
| user_elon | Илон | 🟢 Онлайн |
| user_news | LibertyNews | 🟢 Онлайн |

---

## 🔐 Сигурност

### В момента:
- ✅ Уникални ID за всеки потребител
- ✅ SQLite база данни за съхранение
- ✅ CORS headers за уеб достъп
- ✅ Статус онлайн/офлайн

### В производство (Cloudflare):
- 🔲 Post-Quantum криптиране (Kyber768)
- 🔲 E2E шифроване
- 🔲 D1 база данни
- 🔲 WebSocket за реално време

---

## 🛠️ Разширяване

### Добавяне на нови функции:

1. **Групови чатове**
   - Нова таблица `chats`
   - Таблица `chat_participants`
   - Промяна в messages за групови

2. **Файлове**
   - R2 bucket за съхранение
   - Endpoint за качване
   - Криптиране на файлове

3. **Гласови обаждания**
   - WebRTC интеграция
   - TURN сървър
   - Сигнализиране през WebSocket

---

## 📝 Файлове

```
liberty-reach-messenger/
├── backend-server.py        # Python backend сървър
├── web/
│   ├── realtime-chat.html   # Реален месинджър
│   └── messenger.html       # Демо версия
├── index.html               # Главна страница
├── liberty_reach.db         # SQLite база данни (генерира се)
└── REAL_CHAT_RUNNING.md     # Този файл
```

---

## 🎯 Следващи Стъпки

### ✅ Направено
- [x] Backend сървър (Python)
- [x] SQLite база данни
- [x] Регистрация на потребители
- [x] Изпращане на съобщения
- [x] Онлайн статус
- [x] Уеб интерфейс

### 🔄 Следващо
- [ ] WebSocket за реално време
- [ ] Групи и канали
- [ ] Качване на файлове
- [ ] Гласови обаждания
- [ ] Mobile приложение

---

## 🐛 Troubleshooting

### Порт 8787 зает
```bash
pkill -f backend-server.py
python3 backend-server.py
```

### Порт 3000 зает
```bash
pkill -f "python.*3000"
python3 -m http.server 3000 &
```

### Грешка в базата
```bash
rm liberty_reach.db
python3 backend-server.py
```

---

## 📞 Контакти

- **GitHub**: https://github.com/zametkikostik/liberty-reach-messenger
- **Local URL**: http://localhost:3000
- **Backend**: http://localhost:8787

---

<div align="center">

**Made with ❤️ by Liberty Reach Team**

[🔝 Back to Top](#-liberty-reach-messenger---реален-месинджър)

**🦅 Liberty Reach - Свобода без компромисси!**

</div>
