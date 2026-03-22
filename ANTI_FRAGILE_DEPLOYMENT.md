# 🛡️ ANTI-FRAGILE DEPLOYMENT GUIDE

**Версия:** v0.16.1-cloud  
**Статус:** ✅ Устойчиво к цензуре

---

## 🎯 Архитектура устойчивости

Liberty Reach использует **многоуровневую систему зеркалирования** для защиты от удаления:

```
┌─────────────────────────────────────────────────────────┐
│                 LIBERTY REACH                           │
│         Anti-Fragile Architecture                       │
└─────────────────────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
   ┌────────┐     ┌──────────┐    ┌──────────┐
   │GitHub  │────▶│ Codeberg │    │Cloudflare│
   │(US/EU) │     │(Germany) │    │(Global)  │
   └────────┘     └──────────┘    └──────────┘
        │               │               │
        │               │               └─▶ Static Site
        │               │                   (Workers)
        │               │
        └───────────────┘
                │
                ▼
        Full Git Mirror
        (All branches + tags)
```

---

## 📊 Уровни защиты

### Уровень 1: GitHub (Основной)

**Статус:** Основной репозиторий  
**URL:** https://github.com/zametkikostik/liberty-reach-messenger

**Преимущества:**
- ✅ Основная разработка
- ✅ GitHub Actions CI/CD
- ✅ Issues & Discussions

**Риски:**
- ⚠️ Может быть удалён по DMCA
- ⚠️ Требует 2FA
- ⚠️ US юрисдикция

---

### Уровень 2: Codeberg (Резерв)

**Статус:** Полное зеркало  
**URL:** https://codeberg.org/zametkikostik/liberty-reach-messenger

**Преимущества:**
- ✅ Немецкая юрисдикция
- ✅ Нет DMCA
- ✅ Поддержка FOSS
- ✅ Не требует 2FA

**Как работает:**
```bash
# Автоматическое зеркалирование
./backup-to-all-remotes.sh

# Или вручную
git push codeberg main --force
git push codeberg --tags --force
```

---

### Уровень 3: Cloudflare Workers (Статика)

**Статус:** Статический хостинг  
**URL:** https://liberty-reach-messenger.zametkikostik.workers.dev

**Преимущества:**
- ✅ Глобальная CDN (275+ locations)
- ✅ DDoS защита
- ✅ Работает даже если GitHub/Codeberg упали
- ✅ Кэширование документации

**Что хостится:**
- Главная страница
- Документация
- API Health Check
- Статические файлы

---

## 🚀 Деплой

### 1. Отправка на все зеркала

```bash
cd /path/to/liberty-sovereign

# Автоматически (рекомендуется)
./backup-to-all-remotes.sh

# Вручную
git push origin main --force      # GitHub
git push codeberg main --force   # Codeberg
```

### 2. Деплой на Cloudflare Workers

```bash
cd cloudflare/

# Логин (один раз)
npx wrangler login

# Деплой
npx wrangler deploy

# Проверка
curl https://liberty-reach-messenger.zametkikostik.workers.dev/api/health
```

---

## 🔄 Автоматическое зеркалирование

### GitHub Actions Workflow

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

### Локальный cron (для разработчиков)

```bash
# Добавить в crontab (каждые 6 часов)
0 */6 * * * cd /path/to/liberty-sovereign && ./backup-to-all-remotes.sh
```

---

## 🛡️ Сценарии восстановления

### Сценарий 1: GitHub удалён

**Действия:**
1. ✅ Codeberg имеет полную копию
2. ✅ Cloudflare показывает статику
3. ✅ Разрабатываем через Codeberg
4. ✅ Создаём новый GitHub, пушим из Codeberg

**Время восстановления:** < 1 часа

---

### Сценарий 2: Codeberg удалён

**Действия:**
1. ✅ GitHub имеет основную версию
2. ✅ Cloudflare показывает статику
3. ✅ Создаём новый Codeberg, пушим из GitHub

**Время восстановления:** < 30 минут

---

### Сценарий 3: Cloudflare Workers удалён

**Действия:**
1. ✅ GitHub и Codeberg работают
2. ✅ Разворачиваем новый Worker за 2 минуты
3. ✅ Деплоим через `npx wrangler deploy`

**Время восстановления:** < 5 минут

---

### Сценарий 4: Всё удалено одновременно ⚠️

**Действия:**
1. ✅ Локальные копии у разработчиков
2. ✅ Собираемся, создаём новый репо
3. ✅ Пушим из любой локальной копии
4. ✅ Пересоздаём Workers

**Время восстановления:** < 1 дня

---

## 📋 Чек-лист устойчивости

### Регулярные проверки

- [ ] **Еженедельно:** Запуск `./backup-to-all-remotes.sh`
- [ ] **Ежемесячно:** Проверка доступности всех зеркал
- [ ] **Ежеквартально:** Тест восстановления из бэкапа

### Мониторинг

```bash
# Проверка GitHub
curl -I https://github.com/zametkikostik/liberty-reach-messenger

# Проверка Codeberg
curl -I https://codeberg.org/zametkikostik/liberty-reach-messenger

# Проверка Cloudflare
curl https://liberty-reach-messenger.zametkikostik.workers.dev/api/health
```

---

## 🔐 Безопасность зеркалирования

### НИКОГДА не делайте

❌ Не храните токены в коде  
❌ Не коммитьте `.env` с секретами  
❌ Не используйте один пароль везде

### ВСЕГДА делайте

✅ Используйте GitHub Secrets  
✅ Используйте Codeberg SSH keys  
✅ Храните токены в `.env.local` (gitignored)

---

## 📊 Статистика зеркалирования

| Платформа | Роль | Юрисдикция | Статус |
|-----------|------|------------|--------|
| GitHub | Основная | US | ✅ Active |
| Codeberg | Резерв | Germany (EU) | ✅ Active |
| Cloudflare | Статика | Global | ✅ Active |

---

## 🆘 Экстренная помощь

### Контакты

- **GitHub Support:** https://support.github.com
- **Codeberg Support:** https://codeberg.org/contact
- **Cloudflare Support:** https://support.cloudflare.com

### Recovery Plan

1. **Оцените ущерб** — что удалено?
2. **Найдите последнюю копию** — Codeberg/GitHub/локально
3. **Создайте новый репо** — на уцелевшей платформе
4. **Пушите копию** — `git push --force`
5. **Обновите документацию** — укажите новые URL

---

## 📚 Дополнительные ресурсы

- [GitHub Repository](https://github.com/zametkikostik/liberty-reach-messenger)
- [Codeberg Mirror](https://codeberg.org/zametkikostik/liberty-reach-messenger)
- [Cloudflare Worker](https://liberty-reach-messenger.zametkikostik.workers.dev)
- [CloudConfig Guide](CLOUD_CONFIG_GUIDE.md)
- [Security Master Guide](SECURITY_MASTER_GUIDE.md)

---

**«Свобода требует защиты. Защита требует устойчивости.»** 🔐

*Liberty Reach Security Team*  
*22 марта 2026 г.*
