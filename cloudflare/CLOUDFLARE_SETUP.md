# ☁️ CLOUDFLARE WORKER - НАСТРОЙКА

**Дата:** 22 марта 2026 г.  
**Статус:** ✅ Готово к деплою

---

## 📋 wrangler.toml

Файл конфигурации: `cloudflare/wrangler.toml`

```toml
name = "liberty-reach-messenger"
main = "worker.js"
compatibility_date = "2024-03-22"

[vars]
# Публичные переменные (не секреты!)
GITHUB_URL = "https://github.com/zametkikostik/liberty-reach-messenger"
CODEBERG_URL = "https://codeberg.org/zametkikostik/liberty-reach-messenger"
WORKER_VERSION = "v0.16.1-cloud"
API_TIMEOUT = "10000"
CACHE_TTL = "3600"
```

---

## 🔐 СЕКРЕТЫ (добавляются отдельно)

### Что такое секреты?

Секреты — это чувствительные данные, которые **НЕ** хранятся в `wrangler.toml`:

- ❌ **НЕ** коммитьте в git
- ✅ Шифруются Cloudflare
- ✅ Доступны только вашему Worker

### Какие секреты нужны

| Секрет | Описание | Пример |
|--------|----------|--------|
| `ADMIN_MASTER_KEY` | Мастер-ключ админки | `YourSecretKey2026!` |
| `APP_MASTER_SALT` | Соль для P2P | `RandomSaltValue123` |

---

## 🚀 ДОБАВЛЕНИЕ СЕКРЕТОВ

### Способ 1: Через CLI (рекомендуется)

```bash
cd cloudflare/

# Добавить ADMIN_MASTER_KEY
npx wrangler secret put ADMIN_MASTER_KEY
# Введите значение когда попросит

# Добавить APP_MASTER_SALT
npx wrangler secret put APP_MASTER_SALT
# Введите значение когда попросит
```

### Способ 2: Через панель Cloudflare

1. Откройте: https://dash.cloudflare.com/
2. **Workers & Pages** → **liberty-reach-messenger**
3. **Settings** → **Variables** → **Environment Variables**
4. **Add Variable**
5. Заполните:
   - **Key:** `ADMIN_MASTER_KEY`
   - **Value:** `YourSecretKey2026!`
   - ☑️ **Encrypt** (галочка)
6. **Save**
7. Повторите для `APP_MASTER_SALT`

---

## 📦 ДЕПЛОЙ

### 1. Логин (один раз)

```bash
npx wrangler login
```

Откроется браузер → авторизуйтесь → разрешите доступ

### 2. Деплой

```bash
cd cloudflare/
npx wrangler deploy
```

**Ожидается:**
```
✨ Deployment complete!
https://liberty-reach-messenger.zametkikostik.workers.dev
```

### 3. Проверка

```bash
curl https://liberty-reach-messenger.zametkikostik.workers.dev/api/health
```

**Ожидается:**
```json
{
  "status": "ok",
  "timestamp": "2026-03-22T...",
  "version": "v0.16.1-cloud",
  "mirrors": {
    "github": "...",
    "codeberg": "..."
  }
}
```

---

## 🔍 ПРОСМОТР СЕКРЕТОВ

### Список секретов

```bash
npx wrangler secret list
```

### Удаление секрета

```bash
npx wrangler secret delete ADMIN_MASTER_KEY
```

---

## 🛠️ РАЗРАБОТКА

### Локальный запуск

```bash
cd cloudflare/
npx wrangler dev
```

Откроется: http://localhost:8787

### Логи в реальном времени

```bash
npx wrangler tail
```

---

## 📊 СТРУКТУРА

```
cloudflare/
├── worker.js          # Код Worker (статический сайт)
├── wrangler.toml      # Конфигурация
└── .dev.vars          # Локальные переменные (не коммить!)
```

### .dev.vars (для локальной разработки)

```bash
# Скопируйте .dev.vars.example
cp .dev.vars.example .dev.vars

# Отредактируйте
nano .dev.vars
```

**⚠️ НЕ КОММЬТИТЕ `.dev.vars` В GIT!**

---

## 🆘 ПРОБЛЕМЫ

### Ошибка: "Missing required secret"

**Решение:**
```bash
npx wrangler secret put ADMIN_MASTER_KEY
npx wrangler deploy
```

### Ошибка: "Worker not found"

**Решение:**
```bash
# Проверьте имя в wrangler.toml
# Должно совпадать с именем Worker в Cloudflare
```

### Ошибка: "Authentication failed"

**Решение:**
```bash
# Выйдите и войдите снова
npx wrangler logout
npx wrangler login
```

---

## 📚 ДОКУМЕНТАЦИЯ

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)
- [Secrets Management](https://developers.cloudflare.com/workers/platform/environment-variables/)

---

## ✅ ЧЕК-ЛИСТ

- [ ] `wrangler.toml` настроен
- [ ] `npx wrangler login` выполнен
- [ ] Секреты добавлены (`ADMIN_MASTER_KEY`, `APP_MASTER_SALT`)
- [ ] Деплой успешен
- [ ] Worker доступен по URL
- [ ] `/api/health` возвращает OK

---

**«Cloudflare Workers — быстро, глобально, устойчиво!»** ☁️

*Liberty Reach Security Team*
