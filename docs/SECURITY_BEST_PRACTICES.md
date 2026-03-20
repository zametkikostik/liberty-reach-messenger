# 🔐 LIBERTY REACH - SECURITY BEST PRACTICES

## ⚠️ КРИТИЧЕСКИ ВАЖНО

### Никогда не коммить в git:

```
❌ .env.local
❌ .continue/config.json (с API ключами)
❌ *.jks, *.keystore (Android ключи)
❌ android/key.properties
❌ identity.key, *.pem (приватные ключи)
❌ Любой файл с API ключами
```

---

## 🛡️ ЗАЩИТА API КЛЮЧЕЙ

### 1. **Используй .env.local для секретов**

```bash
# .env.local (в .gitignore!)
OPENROUTER_API_KEY=sk-or-v1-...
PINATA_API_KEY=...
PINATA_SECRET_KEY=...
```

### 2. **Шаблон для других разработчиков**

```bash
# .env.example (можно коммить в git)
OPENROUTER_API_KEY=YOUR_KEY_HERE
PINATA_API_KEY=YOUR_KEY_HERE
PINATA_SECRET_KEY=YOUR_SECRET_HERE
```

### 3. **Continue IDE - только локальные модели**

```json
// .continue/config.json.example (без API ключей!)
{
  "models": [
    {
      "title": "Qwen-Coder-Local",
      "provider": "ollama",
      "model": "qwen2.5-coder:3b",
      "apiBase": "http://localhost:11434"
    }
  ]
}
```

---

## 🚨 ЕСЛИ КЛЮЧИ УТЕКЛИ

### Шаг 1: Проверь git историю

```bash
# Проверка на утечки
./scripts/security_audit.sh

# Или вручную
git log --all --full-history -- ".env.local"
git log --all --full-history -- "*.jks"
```

### Шаг 2: ОТОЗВИ КЛЮЧИ СРОЧНО!

| Сервис | Где отозвать |
|--------|--------------|
| **OpenRouter** | https://openrouter.ai/keys |
| **Pinata** | https://app.pinata.cloud/developers/api-keys |
| **Gemini** | https://aistudio.google.com/apikey |
| **Lava Network** | https://www.lavanet.xyz/dashboard |
| **Cloudflare** | https://dash.cloudflare.com/profile/api-tokens |

### Шаг 3: Создай новые ключи

1. Создай новые ключи в сервисах
2. Обнови `.env.local`
3. **НЕ КОММЬ** `.env.local` в git!

### Шаг 4: Очисти git историю (если ключи закоммичены)

```bash
# ⚠️ ОПАСНО - переписывает историю!
# Только если ключи в коммитах!

# Вариант 1: BFG Repo-Cleaner (рекомендуется)
bfg --delete-files .env.local
bfg --delete-files "*.jks"

# Вариант 2: git filter-branch (сложнее)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env.local" \
  --prune-empty --tag-name-filter cat -- --all

# Затем
git push origin main --force
```

---

## 🔒 БЕЗОПАСНАЯ РАЗРАБОТКА

### 1. Проверяй перед коммитом

```bash
# Что будет закоммичено?
git status
git diff --cached

# Проверка на секреты
./scripts/security_audit.sh
```

### 2. Используй pre-commit хуки

```bash
# .git/hooks/pre-commit
#!/bin/bash
if git diff --cached --name-only | grep -q ".env.local"; then
    echo "❌ Нельзя коммить .env.local!"
    exit 1
fi

if git diff --cached --name-only | grep -q "\.jks$"; then
    echo "❌ Нельзя коммить .jks файлы!"
    exit 1
fi
```

### 3. GitHub Secrets для CI/CD

```yaml
# .github/workflows/build.yml
env:
  OPENROUTER_API_KEY: ${{ secrets.OPENROUTER_API_KEY }}
  PINATA_API_KEY: ${{ secrets.PINATA_API_KEY }}
```

**Добавь секреты:**
GitHub → Settings → Secrets and variables → Actions

---

## 📋 ЧЕКЛИСТ ПЕРЕД ПУШЕМ

- [ ] `.env.local` не в коммитах
- [ ] `.continue/config.json` без API ключей
- [ ] Нет `.jks` файлов в индексе
- [ ] `./scripts/security_audit.sh` проходит ✅
- [ ] Все секреты в GitHub Secrets (для CI/CD)

---

## 🎯 ПРАВИЛА

1. **Все секреты только в `.env.local`**
2. **`.env.local` всегда в `.gitignore`**
3. **API ключи только в GitHub Secrets для CI/CD**
4. **Регулярно проверяй `./scripts/security_audit.sh`**
5. **При подозрении на утечку — СРОЧНО отзови ключи!**

---

## 📞 ЭКСТРЕННАЯ ПОМОЩЬ

Если ключи утекли:

1. **НЕ ПАНИКУЙ**
2. **ОТОЗВИ КЛЮЧИ** (см. таблицу выше)
3. **Запусти `./scripts/security_audit.sh`**
4. **Очисти git историю если нужно**
5. **Создай новые ключи**
6. **Обнови `.env.local`**

---

*«Безопасность — это процесс, а не результат»* 🔐

**Liberty Reach Security Team**
