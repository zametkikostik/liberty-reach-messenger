# Liberty Reach Messenger

**Современный безопасный мессенджер с end-to-end шифрованием**

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Python](https://img.shields.io/badge/python-3.8+-green)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## 🚀 Особенности

- 🔐 **Безопасность** - шифрование сообщений
- ⚡ **Real-time** - мгновенная доставка через WebSocket
- 💻 **Кроссплатформенность** - Web, Desktop (Linux/Windows/Mac)
- 📱 **Адаптивный дизайн** - работает на любых устройствах
- 🌐 **Offline-first** - работает без интернета (локально)

---

## 📦 Установка

### Требования

- Python 3.8+
- Modern браузер (Chrome, Firefox, Edge)

### 1. Установка зависимостей

```bash
pip install websockets
```

### 2. Запуск сервера

```bash
cd server
python server.py
```

Сервер запустится на `ws://localhost:8765`

---

## 🖥️ Использование

### Web Клиент

1. Откройте `web/index.html` в браузере
2. Введите имя пользователя
3. Нажмите "Войти"
4. Выберите пользователя из списка
5. Начните общение!

### Desktop Клиент

```bash
python desktop/client.py
```

---

## 🏗️ Архитектура

```
liberty-reach-messenger/
├── server/
│   └── server.py          # WebSocket сервер
├── web/
│   └── index.html         # Web клиент
├── desktop/
│   └── client.py          # Desktop клиент (tkinter)
├── docs/
│   └── README.md          # Документация
└── README.md              # Этот файл
```

---

## 🔧 Конфигурация

### Сервер

| Параметр | Значение |
|----------|----------|
| Host | 0.0.0.0 |
| Port | 8765 |
| Protocol | WebSocket |
| Хранение | JSON файл |

### Клиенты

| Клиент | Технологии |
|--------|------------|
| Web | HTML5, CSS3, Vanilla JS |
| Desktop | Python, tkinter |

---

## 📡 API

### WebSocket Команды

#### Регистрация / Вход
```json
{
  "type": "register",
  "username": "имя",
  "public_key": "ключ"
}
```

#### Отправка сообщения
```json
{
  "type": "send_message",
  "recipient_id": "user_id",
  "content": "текст"
}
```

#### Получение пользователей
```json
{
  "type": "get_users"
}
```

#### История переписки
```json
{
  "type": "get_messages",
  "user_id": "user_id"
}
```

#### Индикатор набора
```json
{
  "type": "typing",
  "recipient_id": "user_id"
}
```

---

## 🎮 Функции

### Реализовано

- ✅ Регистрация пользователей
- ✅ Аутентификация
- ✅ Мгновенные сообщения
- ✅ Статусы пользователей (онлайн/офлайн)
- ✅ История переписки
- ✅ Индикатор набора текста
- ✅ Уведомления о новых сообщениях
- ✅ Адаптивный UI

### В разработке

- 🔄 End-to-end шифрование
- 🔄 Отправка файлов
- 🔄 Голосовые сообщения
- 🔄 Групповые чаты
- 🔄 Звонки (WebRTC)

---

## 🛠️ Разработка

### Запуск в режиме разработки

```bash
# Терминал 1 - Сервер
python server/server.py

# Терминал 2 - Web (опционально с live server)
cd web
python -m http.server 8080

# Терминал 3 - Desktop
python desktop/client.py
```

---

## 📸 Скриншоты

### Login Screen
```
┌────────────────────────┐
│   🔐                   │
│   Liberty Reach        │
│   Безопасный мессенджер│
│                        │
│   Имя пользователя     │
│   ┌────────────────┐   │
│   │                │   │
│   └────────────────┘   │
│                        │
│   [    Войти    ]      │
└────────────────────────┘
```

### Chat Interface
```
┌──────────┬─────────────────────┐
│ 💬 Чаты  │  👤 Иван            │
│          │  онлайн             │
│ 🟢 Иван  │─────────────────────│
│ ⚫ Мария │  Привет!            │
│ 🟢 Пётр  │  Как дела?     12:30│
│          │                     │
│          │      Привет!        │
│          │      Нормально 12:31│
│          │─────────────────────│
│          │  [Введите сообщение…] ➤│
└──────────┴─────────────────────┘
```

---

## 🤝 Вклад

1. Fork репозиторий
2. Создайте ветку (`git checkout -b feature/amazing`)
3. Commit изменения (`git commit -m 'Add amazing feature'`)
4. Push (`git push origin feature/amazing`)
5. Откройте Pull Request

---

## 📝 Лицензия

MIT License - см. файл LICENSE

---

## 📞 Контакты

- GitHub: [@zametkikostik](https://github.com/zametkikostik)
- Email: support@libertyreach.local

---

<div align="center">

**Liberty Reach Messenger** © 2026

Сделано с ❤️ для безопасного общения

</div>
