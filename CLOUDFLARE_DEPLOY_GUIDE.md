# 🚀 Liberty Reach - Деплой в Cloudflare

## 📋 ПОШАГОВАЯ ИНСТРУКЦИЯ

---

## ⚠️ ВАЖНОЕ ПРЕДУПРЕЖДЕНИЕ

Текущий код в `worker.ts` имеет **TypeScript ошибки**. Нужно их исправить перед деплоем.

---

## 🔧 ШАГ 1: Исправление TypeScript Ошибок

### 1.1 Проверь ошибки
```bash
cd /home/kostik/liberty-reach-messenger/cloudflare
npm run build
```

### 1.2 Исправь worker.ts

**Проблемы:**
- Дубликат функции `handleSendMessage` (строка 893)
- Неиспользуемые типы `User`, `ChatMessage`
- Неправильные типы для `body`

**Решение:**

Открой `src/worker.ts` и:

1. **Удали дубликат функции** (одну из `handleSendMessage`)
2. **Исправь типы:**
```typescript
// Вместо:
const body = await request.json();

// Используй:
const body = await request.json() as any;
const username = body.username as string;
```

3. **Исправь WebSocket:**
```typescript
// Вместо:
const [client, server] = new WebSocketPair();

// Используй:
const webSocketPair = new WebSocketPair();
const client = webSocketPair[0];
const server = webSocketPair[1];
```

---

## 🔑 ШАГ 2: Аутентификация в Cloudflare

### 2.1 Войди в Cloudflare
```bash
cd /home/kostik/liberty-reach-messenger/cloudflare
npx wrangler login
```

Откроется браузер. Войди через:
- Email
- Google
- GitHub

### 2.2 Проверь аккаунт
```bash
npx wrangler whoami
```

Должно показать:
```
✅ Successfully logged in!
Account: твой-аккаунт
```

---

## 🗄️ ШАГ 3: Создание D1 Базы Данных

### 3.1 Создай базу
```bash
npx wrangler d1 create liberty-reach-db
```

Запомни `database_id` из вывода!

### 3.2 Обнови wrangler.toml

Замени `database_id` на свой:
```toml
[[d1_databases]]
binding = "DATABASE"
database_name = "liberty-reach-db"
database_id = "ТВОЙ_ID_ИЗ_ШАГА_3.1"
migrations_dir = "migrations"
```

### 3.3 Создай миграции

Создай файл `migrations/0001_init.sql`:
```sql
-- Users table
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    public_key TEXT,
    created_at INTEGER NOT NULL,
    last_seen INTEGER NOT NULL,
    status TEXT DEFAULT 'offline' CHECK(status IN ('online', 'offline'))
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    from_user TEXT NOT NULL,
    to_user TEXT NOT NULL,
    content TEXT NOT NULL,
    encrypted INTEGER DEFAULT 1,
    created_at INTEGER NOT NULL,
    read INTEGER DEFAULT 0
);

-- Insert demo users
INSERT INTO users (id, username, public_key, created_at, last_seen, status) VALUES 
    ('user_pavel', 'Павел', 'pq_key_pavel', 1708700000000, 1708700000000, 'online'),
    ('user_elon', 'Илон', 'pq_key_elon', 1708700000000, 1708700000000, 'online'),
    ('user_news', 'LibertyNews', 'pq_key_news', 1708700000000, 1708700000000, 'online');
```

### 3.4 Примени миграции
```bash
npx wrangler d1 migrations apply liberty-reach-db
```

---

## 🗃️ ШАГ 4: Создание R2 Хранилищ

### 4.1 Создай бакеты
```bash
npx wrangler r2 bucket create liberty-reach-encrypted-storage
npx wrangler r2 bucket create liberty-reach-profile-backup
```

### 4.2 Обнови wrangler.toml

Убедись что названия совпадают:
```toml
[[r2_buckets]]
bucket_name = "liberty-reach-encrypted-storage"
binding = "ENCRYPTED_STORAGE"

[[r2_buckets]]
bucket_name = "liberty-reach-profile-backup"
binding = "PROFILE_BACKUP"
```

---

## 📬 ШАГ 5: Создание Queues

### 5.1 Создай очередь
```bash
npx wrangler queues create liberty-reach-messages
```

### 5.2 Проверь wrangler.toml

Должно быть:
```toml
[[queues.producers]]
queue = "liberty-reach-messages"
binding = "MESSAGE_QUEUE"

[[queues.consumers]]
queue = "liberty-reach-messages"
max_batch_size = 100
max_batch_timeout = 30
```

---

## 🔐 ШАГ 6: Настройка Переменных Окружения

### 6.1 Создай .dev.vars и .production.vars

**Файл `.dev.vars`:**
```
TURN_SECRET=твоя_секретная_строка
MAX_MESSAGE_SIZE=4194304
BULGARIA_EDGE=sofia.libertyreach.internal
LOG_LEVEL=debug
```

**Файл `.production.vars`:**
```
TURN_SECRET=твоя_секретная_строка
MAX_MESSAGE_SIZE=4194304
BULGARIA_EDGE=sofia.libertyreach.internal
LOG_LEVEL=warn
```

### 6.2 Или используй secrets
```bash
npx wrangler secret put TURN_SECRET
# Введи секретное значение
```

---

## 🚀 ШАГ 7: Деплой

### 7.1 Тестовый деплой (dev)
```bash
cd /home/kostik/liberty-reach-messenger/cloudflare
npm run deploy
```

Или:
```bash
npx wrangler deploy
```

### 7.2 Production деплой
```bash
npx wrangler deploy --env production
```

### 7.3 Проверь статус
```bash
npx wrangler status
```

---

## 🌐 ШАГ 8: Проверка Работы

### 8.1 Открой в браузере

Cloudflare даст тебе URL:
```
https://liberty-reach-messenger.<твой-subdomain>.workers.dev
```

### 8.2 Проверь endpoints

```bash
# Health check
curl https://liberty-reach-messenger.<subdomain>.workers.dev/

# Получить пользователей
curl https://liberty-reach-messenger.<subdomain>.workers.dev/api/v1/users

# Регистрация
curl -X POST https://liberty-reach-messenger.<subdomain>.workers.dev/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{"username":"Тест","public_key":"test"}'
```

### 8.3 Логи
```bash
npx wrangler tail
```

Или с фильтрацией:
```bash
npx wrangler tail --status error
```

---

## 🎯 ШАГ 9: Кастомный Домен (Опционально)

### 9.1 Добавь домен в Cloudflare

1. Зайди в [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Workers & Pages → liberty-reach-messenger
3. Settings → Triggers → Custom Domains
4. Add Custom Domain

### 9.2 Введи свой домен
```
messenger.libertyreach.internal
```

### 9.3 Обнови wrangler.toml

Добавь:
```toml
[site]
bucket = "./public"

[[routes]]
pattern = "messenger.libertyreach.internal"
zone_name = "libertyreach.internal"
```

---

## 📊 ШАГ 10: Мониторинг

### 10.1 Analytics Dashboard

Cloudflare Dashboard → Workers → liberty-reach-messenger → Analytics

Смотри:
- Requests
- Errors
- Duration
- CPU Time

### 10.2 Логи в реальном времени
```bash
npx wrangler tail --format json
```

### 10.3 Alerts

Настрой алерты:
1. Workers → Alerts
2. Create Alert
3. Выбери:
   - Error rate > 5%
   - CPU time > 50ms
   - Requests > 1000/min

---

## 🔄 CI/CD (Автоматический Деплой)

### GitHub Actions

Создай `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Cloudflare

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
      
      - name: Install dependencies
        run: npm install
        working-directory: ./cloudflare
      
      - name: Deploy to Cloudflare
        run: npx wrangler deploy
        working-directory: ./cloudflare
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CF_API_TOKEN }}
```

### Секреты GitHub

Добавь в GitHub Secrets:
```
CF_API_TOKEN=твой_token_из_Cloudflare
```

---

## 🛠️ Troubleshooting

### Ошибка: "Database not found"
```bash
# Проверь database_id в wrangler.toml
npx wrangler d1 info liberty-reach-db
```

### Ошибка: "Bucket not found"
```bash
# Пересоздай бакеты
npx wrangler r2 bucket delete liberty-reach-encrypted-storage
npx wrangler r2 bucket create liberty-reach-encrypted-storage
```

### Ошибка: "TypeScript compilation failed"
```bash
# Исправь ошибки в worker.ts
cd cloudflare
npm run build
```

### Ошибка: "Authentication failed"
```bash
# Перелогинься
npx wrangler logout
npx wrangler login
```

---

## 💰 Стоимость

### Cloudflare Workers (Бесплатно):
- 100,000 запросов/день
- 10ms CPU time
- D1: 5GB storage, 5M reads/day
- R2: 10GB storage, 10M operations/month
- Queues: 1M operations/month

### Premium ($5/месяц):
- 100M запросов/месяц
- Более 10ms CPU time
- Приоритетная поддержка

---

## 📁 Чеклист Перед Деплоем

- [ ] Исправлены все TypeScript ошибки
- [ ] `npm run build` проходит без ошибок
- [ ] D1 база создана и миграции применены
- [ ] R2 бакеты созданы
- [ ] Queues создана
- [ ] Секреты настроены
- [ ] wrangler.toml обновлен с правильными ID
- [ ] Тестовый деплой прошел успешно
- [ ] Health check работает
- [ ] Логи пишутся

---

## 🎯 Быстрый Старт (Копировать/Вставить)

```bash
# 1. Войти
cd /home/kostik/liberty-reach-messenger/cloudflare
npx wrangler login

# 2. Создать базу
npx wrangler d1 create liberty-reach-db
# Запомни database_id!

# 3. Применить миграции
npx wrangler d1 migrations apply liberty-reach-db

# 4. Создать бакеты
npx wrangler r2 bucket create liberty-reach-encrypted-storage
npx wrangler r2 bucket create liberty-reach-profile-backup

# 5. Создать очередь
npx wrangler queues create liberty-reach-messages

# 6. Задеплоить
npx wrangler deploy

# 7. Проверить
curl https://liberty-reach-messenger.<subdomain>.workers.dev/

# 8. Логи
npx wrangler tail
```

---

## 📞 Контакты

- **Cloudflare Dashboard**: https://dash.cloudflare.com
- **Workers Docs**: https://developers.cloudflare.com/workers/
- **Discord**: https://discord.gg/cloudflaredev

---

<div align="center">

**🚀 Liberty Reach - Деплой в Cloudflare Успешен!**

[🔝 Back to Top](#-liberty-reach---деплой-в-cloudflare)

</div>
