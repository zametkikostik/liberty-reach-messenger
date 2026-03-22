# 🚀 БЫСТРЫЙ СТАРТ: ЗЕРКАЛИРОВАНИЕ

**Дата:** 22 марта 2026 г.  
**Цель:** Отправить код на все зеркала

---

## 📋 Что настроено

| Платформа | URL | Статус |
|-----------|-----|--------|
| **GitHub** | https://github.com/zametkikostik/liberty-reach-messenger | ✅ Основной |
| **Codeberg** | https://codeberg.org/zametkikostik/liberty-reach-messenger | ✅ Резерв |
| **Cloudflare** | https://liberty-reach-messenger.zametkikostik.workers.dev | ✅ Статика |

---

## 🎯 Быстрая отправка

### Вариант 1: Автоматически (рекомендуется)

```bash
cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign

# Запустить скрипт зеркалирования
./backup-to-all-remotes.sh
```

### Вариант 2: Вручную

```bash
# GitHub
git push origin main --force
git push origin --tags --force

# Codeberg (нужен токен или логин)
git push codeberg main --force
git push codeberg --tags --force
```

---

## 🔐 Настройка Codeberg токена (для автоматизации)

### 1. Создайте токен

1. Перейдите на https://codeberg.org/settings/applications
2. Создайте **Personal Access Token**
3. Скопируйте токен

### 2. Добавьте в окружение

```bash
# Локально (для сессии)
export CODEBERG_TOKEN=your_token_here

# Или в .env.local (для постоянного использования)
echo "CODEBERG_TOKEN=your_token_here" >> .env.local
```

### 3. Проверка

```bash
./backup-to-all-remotes.sh
```

---

## ☁️ Деплой на Cloudflare Workers

### 1. Установка Wrangler

```bash
npm install -g wrangler
# ИЛИ
npx wrangler --version
```

### 2. Логин (один раз)

```bash
cd cloudflare/
npx wrangler login
```

### 3. Деплой

```bash
npx wrangler deploy
```

### 4. Проверка

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

## 🔄 Автоматическое зеркалирование

### GitHub Actions

Создайте `.github/workflows/mirror.yml`:

```yaml
name: Mirror to Codeberg

on:
  push:
    branches: [main]

jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Mirror to Codeberg
        uses: pixta-dev/repository-mirroring-action@v1
        with:
          target_repo_url:
            https://codeberg.org/zametkikostik/liberty-reach-messenger.git
          ssh_private_key:
            ${{ secrets.CODEBERG_SSH_KEY }}
```

### Локальный cron

```bash
# Отредактируйте crontab
crontab -e

# Добавьте строку (каждые 6 часов)
0 */6 * * * cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign && ./backup-to-all-remotes.sh
```

---

## 📊 Мониторинг

### Проверка всех зеркал

```bash
# GitHub
curl -I https://github.com/zametkikostik/liberty-reach-messenger

# Codeberg
curl -I https://codeberg.org/zametkikostik/liberty-reach-messenger

# Cloudflare
curl https://liberty-reach-messenger.zametkikostik.workers.dev/api/health
```

### Статус

- **200 OK** — всё работает ✅
- **404 Not Found** — репозиторий удалён ❌
- **403 Forbidden** — проблемы с доступом ⚠️

---

## 🆘 Восстановление

### Если GitHub удалён

1. Codeberg имеет полную копию ✅
2. Создайте новый GitHub репозиторий
3. Склонируйте из Codeberg:
   ```bash
   git clone https://codeberg.org/zametkikostik/liberty-reach-messenger.git
   cd liberty-reach-messenger
   git remote add new-origin https://github.com/.../liberty-reach-messenger.git
   git push new-origin main --force
   ```

### Если Codeberg удалён

1. GitHub имеет основную версию ✅
2. Создайте новый Codeberg репозиторий
3. Запушьте из GitHub:
   ```bash
   git clone https://github.com/zametkikostik/liberty-reach-messenger.git
   cd liberty-reach-messenger
   git remote add new-codeberg https://codeberg.org/.../liberty-reach-messenger.git
   git push new-codeberg main --force
   ```

### Если Cloudflare удалён

1. GitHub и Codeberg работают ✅
2. Разверните новый Worker:
   ```bash
   cd cloudflare/
   npx wrangler deploy
   ```

---

## 📚 Документация

- [ANTI_FRAGILE_DEPLOYMENT.md](ANTI_FRAGILE_DEPLOYMENT.md) — полное руководство
- [CLOUD_CONFIG_GUIDE.md](CLOUD_CONFIG_GUIDE.md) — облачная конфигурация
- [SECURITY_MASTER_GUIDE.md](SECURITY_MASTER_GUIDE.md) — безопасность

---

## ✅ Чек-лист

- [ ] Codeberg добавлен как remote
- [ ] Скрипт `backup-to-all-remotes.sh` работает
- [ ] Cloudflare Worker развёрнут
- [ ] Токен Codeberg настроен (опционально)
- [ ] Мониторинг настроен

---

**«Код должен быть свободным и устойчивым!»** 🔐

*Liberty Reach Security Team*
