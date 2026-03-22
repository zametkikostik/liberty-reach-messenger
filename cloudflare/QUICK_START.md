# ☁️ CLOUDFLARE WORKER - БЫСТРЫЙ СТАРТ

**wrangler.toml** уже настроен! ✅

---

## 🚀 ДЕПЛОЙ ЗА 3 МИНУТЫ

### 1. Логин

```bash
cd cloudflare/
npx wrangler login
```

### 2. Добавь секреты

```bash
npx wrangler secret put ADMIN_MASTER_KEY
npx wrangler secret put APP_MASTER_SALT
```

### 3. Деплой

```bash
npx wrangler deploy
```

**Готово!** Worker доступен:
```
https://liberty-reach-messenger.zametkikostik.workers.dev
```

---

## 📋 wrangler.toml

```toml
name = "liberty-reach-messenger"
main = "worker.js"
compatibility_date = "2024-03-22"

[vars]
GITHUB_URL = "https://github.com/..."
CODEBERG_URL = "https://codeberg.org/..."
WORKER_VERSION = "v0.16.1-cloud"
```

---

## 🔐 СЕКРЕТЫ

| Секрет | Как добавить |
|--------|--------------|
| `ADMIN_MASTER_KEY` | `npx wrangler secret put ADMIN_MASTER_KEY` |
| `APP_MASTER_SALT` | `npx wrangler secret put APP_MASTER_SALT` |

---

## 🛠️ КОМАНДЫ

```bash
# Деплой
npx wrangler deploy

# Локальный запуск
npx wrangler dev

# Логи
npx wrangler tail

# Список секретов
npx wrangler secret list
```

---

## 📚 ПОЛНАЯ ДОКУМЕНТАЦИЯ

[cloudflare/CLOUDFLARE_SETUP.md](cloudflare/CLOUDFLARE_SETUP.md)

---

**«Готово к работе!»** ☁️
