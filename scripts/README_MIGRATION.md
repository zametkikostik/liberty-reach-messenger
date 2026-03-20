# 📥 MIGRATION SCRIPTS — Импорт из Telegram и WhatsApp

**Python скрипты для переноса данных из популярных мессенджеров в Liberty Reach**

---

## 🚀 БЫСТРЫЙ СТАРТ

### 1️⃣ Экспорт из Telegram

**Telegram Desktop (ПК):**
1. Открой Telegram Desktop
2. **Настройки** → **Продвинутые** → **Экспорт данных**
3. Выбери: ✅ Личные чаты, ✅ Группы, ✅ Каналы
4. Формат: **JSON**
5. Сохрани в папку (например, `~/Downloads/Telegram Desktop/`)

### 2️⃣ Экспорт из WhatsApp

**Android:**
1. Открой чат
2. **Меню** → **Ещё** → **Экспорт чата**
3. **Без медиа** (быстрее)
4. Отправь себе на email/в облако

**iOS:**
1. Открой чат
2. **Инфо** → **Экспорт чата**
3. Сохрани в Files

---

## 📦 УСТАНОВКА

```bash
# Перейди в папку скриптов
cd liberty-sovereign/scripts

# (Опционально) Создай виртуальное окружение
python3 -m venv venv
source venv/bin/activate  # Linux/Mac
# или
venv\Scripts\activate     # Windows
```

**Зависимости:** Не требуются! (только стандартная библиотека Python 3.7+)

---

## 🔧 ИСПОЛЬЗОВАНИЕ

### Импорт из Telegram

```bash
python telegram_import.py \
  --input ~/Downloads/Telegram\ Desktop/ \
  --user-id YOUR_USER_ID \
  --output liberty_data/
```

**Параметры:**
- `--input` — папка с экспортом Telegram (result.json + chats/)
- `--user-id` — твой User ID в Liberty Reach
- `--output` — папка для базы данных (по умолчанию: `liberty_data`)

### Импорт из WhatsApp

```bash
python whatsapp_import.py \
  --input ~/Downloads/WhatsApp\ Chat.txt \
  --user-id YOUR_USER_ID \
  --output liberty_data/
```

**Параметры:**
- `--input` — файл WhatsApp Chat.txt
- `--user-id` — твой User ID в Liberty Reach
- `--output` — папка для базы данных (по умолчанию: `liberty_data`)

---

## 📊 ПРИМЕР ВЫВОДА

```
============================================================
🔄 TELEGRAM → LIBERTY REACH IMPORTER
============================================================
📥 Импорт из: /home/user/Downloads/Telegram Desktop/
============================================================
📋 Найдено чатов в result.json: 45
📁 Найдено JSON файлов: 45
============================================================

💬 Чат: Иван Иванов (тип: personal, ID: 123456789)
   📝 Сообщений: 1250

💬 Чат: Работа (тип: private_group, ID: 987654321)
   📝 Сообщений: 3456

💬 Чат: Новости IT (тип: private_channel, ID: 555666777)
   📝 Сообщений: 8901

============================================================
✅ ИМПОРТ ЗАВЕРШЁН!
============================================================
📊 СТАТИСТИКА:
   📁 Чатов:        45
   💬 Сообщений:    15678
   👥 Контактов:    123

💾 База данных: liberty_data/messages.db
============================================================
```

---

## 🗄️ СТРУКТУРА БАЗЫ ДАННЫХ

### Таблица: `imported_chats`

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | TEXT | UUID чата |
| `source` | TEXT | Источник: 'telegram' или 'whatsapp' |
| `original_id` | TEXT | ID из исходного мессенджера |
| `user_id` | TEXT | User ID в Liberty Reach |
| `name` | TEXT | Название чата / имя контакта |
| `chat_type` | TEXT | 'personal', 'group', 'channel' |
| `imported_at` | INTEGER | Timestamp импорта |
| `message_count` | INTEGER | Количество сообщений |

### Таблица: `imported_messages`

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | TEXT | UUID сообщения |
| `chat_id` | TEXT | Ссылка на чат |
| `original_id` | TEXT | ID из исходного мессенджера |
| `from_name` | TEXT | Имя отправителя |
| `text` | TEXT | Текст сообщения |
| `timestamp` | INTEGER | Время сообщения |
| `media_cid` | TEXT | IPFS CID для медиа (если есть) |
| `imported_at` | INTEGER | Timestamp импорта |

---

## 🔍 ПРОВЕРКА ДАННЫХ

```bash
# Проверить количество чатов
sqlite3 liberty_data/messages.db "SELECT COUNT(*) FROM imported_chats;"

# Проверить количество сообщений
sqlite3 liberty_data/messages.db "SELECT COUNT(*) FROM imported_messages;"

# Посмотреть последние чаты
sqlite3 liberty_data/messages.db "SELECT name, chat_type, message_count FROM imported_chats ORDER BY imported_at DESC LIMIT 10;"

# Экспорт в CSV
sqlite3 -header -csv liberty_data/messages.db "SELECT * FROM imported_chats;" > chats.csv
```

---

## ⚠️ ОГРАНИЧЕНИЯ

### Telegram:
- ✅ Текст сообщений — 100%
- ✅ Контакты — 100%
- ✅ Группы/Каналы — 100%
- ⚠️ Медиа — только пути к файлам (нужен отдельный upload на IPFS)
- ⚠️ Голосовые — не импортируются

### WhatsApp:
- ✅ Текст сообщений — 100%
- ✅ Контакты — 100%
- ⚠️ Медиа — не импортируются
- ⚠️ Голосовые — не импортируются

---

## 🛠️ ВОЗМОЖНЫЕ ОШИБКИ

### "Файл не найден"
```
FileNotFoundError: Папка не найдена: /path/to/Telegram Desktop
```
**Решение:** Проверь путь к папке экспорта. Используй кавычки для путей с пробелами.

### "Неверный формат даты"
```
ValueError: time data '2024-01-15T10:30:00' does not match format
```
**Решение:** Обновлённая версия Telegram может использовать другой формат. Скрипт автоматически обработает.

### "Permission denied"
```
PermissionError: [Errno 13] Permission denied
```
**Решение:** Запусти от имени администратора или проверь права на папку.

---

## 📝 СЛЕДУЮЩИЕ ШАГИ

После импорта:

1. **Проверь данные:**
   ```bash
   sqlite3 liberty_data/messages.db ".tables"
   ```

2. **Интегрируй с Liberty Reach:**
   - Скопируй `liberty_data/messages.db` в папку приложения
   - Или подключись через D1 API

3. **Загрузи медиа на IPFS (опционально):**
   ```bash
   # Используй Pinata API
   curl -X POST "https://api.pinata.cloud/pinning/pinFileToIPFS" \
     -H "Authorization: Bearer YOUR_JWT" \
     -F "file=@photo.jpg"
   ```

---

## 🙏 ПОДДЕРЖКА

**Вопросы/Проблемы:**
- GitHub Issues: https://github.com/zametkikostik/liberty-reach-messenger/issues
- Email: zametkikostik@gmail.com

---

**Liberty Reach — твоя свобода, твои данные!** 🔐
