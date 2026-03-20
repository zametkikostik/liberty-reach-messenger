# 🔐 SECURITY PARANOID MODE — Максимальная защита

**Liberty Reach Messenger** — Zero-Knowledge Architecture с максимальной паранойей безопасности.

---

## 1️⃣ ZERO-KNOWLEDGE ENCRYPTION

### Принцип работы

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENT SIDE (Flutter)                    │
│                                                             │
│  User Password → PBKDF2 → AES-256 Key → Encrypt Message    │
│       ↑                                                      │
│       └── NEVER saved, NEVER transmitted                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    Encrypted Data
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    SERVER SIDE (Cloudflare)                 │
│                                                             │
│  Stores ONLY ciphertext — CANNOT decrypt                    │
│  Zero knowledge of plaintext or password                    │
└─────────────────────────────────────────────────────────────┘
```

### Использование (Flutter)

```dart
import '../services/zero_knowledge_encryption.dart';

// 1. Пользователь вводит пароль (НИКОГДА не сохраняем!)
const password = 'REDACTED_PASSWORD'; // Запросить у пользователя
const userId = 'user-123'; // Уникальная соль

// 2. Генерируем ключ из пароля
final encryption = ZeroKnowledgeEncryption.instance;
await encryption.deriveKeyFromPassword(password, userId);

// 3. Шифруем сообщение
const message = 'Секретное сообщение';
final encrypted = encryption.encryptMessage(message);
// {"ciphertext": "...", "iv": "...", "timestamp": 1234567890}

// 4. Отправляем на сервер (сервер НЕ МОЖЕТ расшифровать!)
await sendMessage(encrypted);

// 5. Получаем и расшифровываем
final decrypted = encryption.decryptMessage(encrypted);

// 6. При выходе — удаляем ключ из памяти
encryption.wipeKey();
```

### Безопасность

| Параметр | Значение |
|----------|----------|
| Алгоритм | AES-256-GCM |
| Ключ | 256 бит (32 байта) |
| PBKDF2 итерации | 100,000 |
| IV | 12 байт (уникальный) |
| Хранение ключа | ТОЛЬКО в RAM |

---

## 2️⃣ GITHUB SECURITY SCAN

### Автоматическая проверка на бэкдоры

При каждом пуше GitHub Actions сканирует код:

**Что проверяется:**
- ✅ Хардкод секретов (API ключи, пароли)
- ✅ Опасные импорты (`dart:ffi`, `child_process`, `eval()`)
- ✅ Подозрительные URL (ngrok, cloudflare tunnel)
- ✅ Крипто-майнинг паттерны
- ✅ Data exfiltration (скрытые POST запросы)

**Файлы:**
- `.github/workflows/security-scan.yml` — GitHub Actions workflow
- `.github/security_scanner.py` — Python сканер бэкдоров

### Запуск локально

```bash
cd .github
python security_scanner.py
```

### Пример вывода

```
============================================================
🔍 GITHUB SECURITY BACKDOOR SCAN
============================================================
Scanning: /path/to/liberty-sovereign
============================================================

✅ NO BACKDOORS FOUND
✅ SECURITY SCAN PASSED
```

---

## 3️⃣ KILL SWITCH — ПАНИЧЕСКОЕ УНИЧТОЖЕНИЕ

### Принцип работы

```
┌──────────────────────────────────────────────────────────────┐
│  ACTIVATION:                                                 │
│  curl -H "X-Panic-Wipe: SECRET_CODE" \                       │
│    https://your-worker.workers.dev/                          │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  Cloudflare Worker проверяет заголовок X-Panic-Wipe          │
│  Если совпадает с KILL_SWITCH_CODE:                          │
│    → DELETE FROM messages                                    │
│    → DELETE FROM users                                       │
│    → DELETE FROM groups                                      │
│    → ... (все таблицы)                                       │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  ✅ PANIC WIPE COMPLETE - ALL DATA DESTROYED                 │
└──────────────────────────────────────────────────────────────┘
```

### Настройка

**1. Установи переменную в Cloudflare Dashboard:**

1. Зайди на https://dash.cloudflare.com/
2. Workers & Pages → твой воркер → Settings
3. Variables → Add Variable
4. Name: `KILL_SWITCH_CODE`
5. Value: `REDACTED_PASSWORD` (или любой другой секрет)
6. ✅ Save

**2. Активация Kill Switch:**

```bash
# Отправь запрос с секретным кодом
curl -H "X-Panic-Wipe: REDACTED_PASSWORD" \
  https://your-worker.workers.dev/
```

**3. Ответ:**

```json
{
  "success": true,
  "message": "PANIC WIPE COMPLETE - ALL DATA DESTROYED",
  "timestamp": 1711065600000,
  "tables_cleared": 22
}
```

### Удаляемые таблицы

- `messages` — все сообщения
- `users` — пользователи
- `groups` — группы
- `group_members` — участники групп
- `channels` — каналы
- `channel_subscribers` — подписчики
- `crypto_wallets` — кошельки
- `token_balances` — балансы
- `transactions` — транзакции
- `swaps` — свопы
- `abcex_orders` — заказы ABCEX
- `bitget_orders` — заказы Bitget
- `p2p_escrows` — эскроу
- `fee_splits` — распределение комиссий
- `ai_chat_history` — история AI чатов
- `ai_translations_cache` — кэш переводов
- `pinned_messages` — закреплённые сообщения
- `saved_messages` — сохранённые сообщения
- `emoji_reactions` — реакции
- `stories` — истории
- `story_views` — просмотры историй
- `user_profiles` — профили
- `love_tokens` — токены любви

---

## 4️⃣ ЗАЩИТА ПАРОЛЯ

### ⚠️ КРИТИЧЕСКИ ВАЖНО

**ПАРОЛЬ `REDACTED_PASSWORD` НИКОГДА не должен быть в коде на GitHub!**

### Правильно:

```dart
// ❌ НЕЛЬЗЯ (хардкод в коде)
const password = 'REDACTED_PASSWORD';

// ✅ МОЖНО (запрос у пользователя)
final password = await showDialog<String>(...);

// ✅ МОЖНО (переменная окружения)
final password = dotenv.env['MASTER_PASSWORD'];
```

### .env.local (в .gitignore!)

```bash
# Никогда не коммить этот файл!
MASTER_PASSWORD=REDACTED_PASSWORD
```

### Flutter Dotenv

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

// В main.dart
await dotenv.load(fileName: ".env.local");

// Использование
final password = dotenv.env['MASTER_PASSWORD'];
```

---

## 5️ SECURITY CHECKLIST

Перед каждым коммитом:

- [ ] Нет хардкода паролей в коде
- [ ] Нет хардкода API ключей
- [ ] `.env` и `.env.local` в `.gitignore`
- [ ] `security_scanner.py` проходит ✅
- [ ] Zero-Knowledge шифрование включено
- [ ] Kill Switch настроен в Cloudflare

---

## 🚀 БЫСТРЫЙ СТАРТ

### 1. Настройка Zero-Knowledge

```dart
// main.dart
import 'services/zero_knowledge_encryption.dart';

// Запрос пароля у пользователя
final password = await showPasswordDialog();

// Генерация ключа
await ZeroKnowledgeEncryption.instance
    .deriveKeyFromPassword(password, userId);
```

### 2. Настройка GitHub Security

```yaml
# .github/workflows/security-scan.yml уже создан
# Автоматически запускается при каждом пуше
```

### 3. Настройка Kill Switch

```bash
# Cloudflare Dashboard → Workers → Settings → Variables
# Добавить: KILL_SWITCH_CODE=REDACTED_PASSWORD

# Активация
curl -H "X-Panic-Wipe: REDACTED_PASSWORD" \
  https://your-worker.workers.dev/
```

---

**Liberty Reach — твоя свобода под максимальной защитой!** 🔐🛡️
