# 🌐 INFRASTRUCTURE OVERVIEW

**Дата:** 22 марта 2026 г.  
**Статус:** ✅ Настроено

---

## 📊 ПОЛНАЯ КАРТА ИНФРАСТРУКТУРЫ

```
┌─────────────────────────────────────────────────────────────────┐
│                    LIBERTY REACH                                │
│                  Infrastructure                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
        ┌──────────┐   ┌──────────┐   ┌──────────────┐
        │  GitHub  │   │ Codeberg │   │  Cloudflare  │
        │(Primary) │   │ (Backup) │   │   Workers    │
        └──────────┘   └──────────┘   └──────────────┘
              │               │               │
              │               │       ┌───────┴───────┐
              │               │       │               │
              │               │       ▼               ▼
              │               │  ┌─────────┐  ┌─────────────┐
              │               │  │Messenger│  │ Push Notify │
              │               │  │ Worker  │  │   Worker    │
              │               │  └─────────┘  └─────────────┘
              │               │       │               │
              │               │       │               │
              ▼               ▼       ▼               ▼
    zametkikostik/   zametkikostik/  liberty-reach-  liberty-reach-
    liberty-reach-   liberty-reach-  messenger.      push.
    messenger        messenger       zametkikostik.  zametkikostik.
                                      workers.dev   workers.dev
```

---

## 1️⃣ GIT РЕПОЗИТОРИИ

### GitHub (Основной)
- **URL:** https://github.com/zametkikostik/liberty-reach-messenger
- **Статус:** ✅ Активен
- **Назначение:** Основная разработка, Issues, Actions

### Codeberg (Резерв)
- **URL:** https://codeberg.org/zametkikostik/liberty-reach-messenger
- **Статус:** ✅ Настроен как remote
- **Назначение:** Backup mirror

### Команды:
```bash
# Отправка на оба репозитория
git push origin main          # GitHub
git push codeberg main        # Codeberg

# Или автоматически
./backup-to-all-remotes.sh
```

---

## 2️⃣ CLOUDFLARE WORKERS

### Worker 1: liberty-reach-messenger
- **URL:** https://liberty-reach-messenger.zametkikostik.workers.dev
- **Файл:** `cloudflare/worker.js`
- **Config:** `cloudflare/wrangler.toml`
- **Статус:** ✅ Настроен
- **Назначение:** Статический сайт, документация

**Функции:**
- Главная страница
- Документация (/docs/)
- API Health Check (/api/health)
- GitHub/Codeberg редиректы

**Деплой:**
```bash
cd cloudflare/
npx wrangler deploy
```

---

### Worker 2: liberty-reach-push
- **URL:** https://liberty-reach-push.zametkikostik.workers.dev
- **Файл:** `cloudflare/push_worker.js`
- **Config:** `cloudflare/wrangler.push.toml`
- **Статус:** ⚠️ Требует деплоя
- **Назначение:** Push уведомления

**Функции:**
- Регистрация устройств
- Отправка push уведомлений
- Topic подписки
- Firebase Cloud Messaging интеграция

**Деплой:**
```bash
cd cloudflare/
npx wrangler deploy --config wrangler.push.toml

# Добавить секреты:
npx wrangler secret put FCM_SERVER_KEY --config wrangler.push.toml
npx wrangler secret put ADMIN_MASTER_KEY --config wrangler.push.toml
```

---

### Worker 3: a-love-story (старый)
- **URL:** https://a-love-story.zametkikostik.workers.dev
- **Файл:** `backend/wrangler.toml`
- **Статус:** ⚠️ Устарел (Rust)
- **Назначение:** Love Story (legacy)

---

## 3️⃣ СЕКРЕТЫ CLOUDFLARE

### Для liberty-reach-messenger:

| Секрет | Описание | Статус |
|--------|----------|--------|
| `ADMIN_MASTER_KEY` | Ключ админки | ⚠️ Добавить |
| `APP_MASTER_SALT` | Соль P2P | ⚠️ Добавить |

**Добавить:**
```bash
npx wrangler secret put ADMIN_MASTER_KEY
npx wrangler secret put APP_MASTER_SALT
```

### Для liberty-reach-push:

| Секрет | Описание | Статус |
|--------|----------|--------|
| `FCM_SERVER_KEY` | Firebase Cloud Messaging | ⚠️ Добавить |
| `ADMIN_MASTER_KEY` | Ключ админки | ⚠️ Добавить |

**Добавить:**
```bash
npx wrangler secret put FCM_SERVER_KEY --config wrangler.push.toml
npx wrangler secret put ADMIN_MASTER_KEY --config wrangler.push.toml
```

---

## 4️⃣ ПРОВЕРКА РАБОТЫ

### GitHub:
```bash
curl -I https://github.com/zametkikostik/liberty-reach-messenger
# Ожидается: HTTP/2 200
```

### Codeberg:
```bash
curl -I https://codeberg.org/zametkikostik/liberty-reach-messenger
# Ожидается: HTTP/2 200
```

### Messenger Worker:
```bash
curl https://liberty-reach-messenger.zametkikostik.workers.dev/api/health
# Ожидается: {"status": "ok", ...}
```

### Push Worker:
```bash
curl https://liberty-reach-push.zametkikostik.workers.dev/api/health
# Ожидается: {"status": "ok", ...}
```

---

## 5️⃤ ЧЕК-ЛИСТ

### GitHub + Codeberg
- [x] GitHub репозиторий активен
- [x] Codeberg добавлен как remote
- [x] Скрипт зеркалирования работает
- [ ] Codeberg зеркало обновлено

### liberty-reach-messenger Worker
- [x] worker.js создан
- [x] wrangler.toml настроен
- [ ] Деплой выполнен
- [ ] Секреты добавлены
- [ ] Health check работает

### liberty-reach-push Worker
- [x] push_worker.js существует
- [x] wrangler.push.toml создан
- [ ] Деплой выполнен
- [ ] FCM_SERVER_KEY добавлен
- [ ] Health check работает

---

## 6️⃤ БЫСТРЫЙ ДЕПЛОЙ

```bash
cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign/cloudflare

# 1. Messenger Worker
npx wrangler login
npx wrangler deploy

# 2. Push Worker
npx wrangler secret put FCM_SERVER_KEY --config wrangler.push.toml
npx wrangler secret put ADMIN_MASTER_KEY --config wrangler.push.toml
npx wrangler deploy --config wrangler.push.toml

# 3. Проверка
curl https://liberty-reach-messenger.zametkikostik.workers.dev/api/health
curl https://liberty-reach-push.zametkikostik.workers.dev/api/health
```

---

## 📊 ИТОГОВАЯ ТАБЛИЦА

| Компонент | URL | Статус | Готово |
|-----------|-----|--------|--------|
| **GitHub** | https://github.com/.../liberty-reach-messenger | ✅ Active | ✅ |
| **Codeberg** | https://codeberg.org/.../liberty-reach-messenger | ✅ Active | ✅ |
| **Messenger Worker** | liberty-reach-messenger.zametkikostik.workers.dev | ⚠️ Ready | ⏳ Деплой |
| **Push Worker** | liberty-reach-push.zametkikostik.workers.dev | ⚠️ Ready | ⏳ Деплой |

---

**«Инфраструктура готова к деплою!»** 🚀

*Liberty Reach DevOps*  
*22 марта 2026 г.*
