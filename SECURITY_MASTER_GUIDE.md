# 🔐 SECURITY MASTER GUIDE

**Версия:** v0.16.0-secure  
**Статус:** ✅ Безопасно для production

---

## ⚠️ КРИТИЧЕСКИ ВАЖНО

### Файлы, которые НИКОГДА не должны быть в git

| Файл | Почему | Статус |
|------|--------|--------|
| `.env.local` | Содержит ADMIN_MASTER_KEY и все секреты | ✅ В .gitignore |
| `passwords.txt` | Содержит старые пароли для замены | ✅ В .gitignore |
| `password-replacements.txt` | Содержит старые пароли для замены | ✅ В .gitignore |
| `android/key.properties` | Пароли keystore | ✅ В .gitignore |
| `*.jks`, `*.keystore` | Файлы подписи APK | ✅ В .gitignore |

---

## 📋 Чек-лист безопасности

### Перед коммитом

```bash
# 1. Проверка на утечки паролей
git grep "18051940Alberto@"
git grep "ADMIN_MASTER_KEY="

# 2. Проверка .gitignore
git check-ignore -v .env.local
git check-ignore -v passwords.txt

# 3. Проверка staged файлов
git status
git diff --cached
```

**Ожидается:** пусто (ничего чувствительного не найдено)

---

## 🔐 Настройка секретов

### 1. Локальная разработка

```bash
# Скопируйте .env.example
cp .env.example .env.local

# Отредактируйте .env.local
nano .env.local

# Сгенерируйте надёжный ADMIN_MASTER_KEY
openssl rand -base64 32
# ИЛИ
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### 2. GitHub Actions

1. GitHub → Settings → Secrets and variables → Actions
2. New repository secret
3. Добавьте:
   - `MASTER_KEY` — ваш секретный пароль
   - `KEYSTORE_BASE64` — keystore для подписи
   - `KEYSTORE_PASSWORD` — пароль keystore
   - `KEY_ALIAS` — алиас ключа
   - `KEY_PASSWORD` — пароль ключа

---

## 🚀 Безопасная сборка

### Локально

```bash
# Установите переменную окружения
export ADMIN_MASTER_KEY='YourSecurePassword2026!'

# Запустите сборку
./build_apk.sh
```

### GitHub Actions

```yaml
- name: Build Release APK
  run: |
    flutter build apk --release \
      --dart-define=ADMIN_MASTER_KEY=${{ secrets.MASTER_KEY }}
```

---

## 🛡️ Защита от утечек

### Автоматическая проверка

Добавьте в `.git/hooks/pre-commit`:

```bash
#!/bin/bash

# Проверка на пароли
if git diff --cached | grep -E "18051940|ADMIN_MASTER_KEY=" > /dev/null; then
    echo "❌ ERROR: Potential password leak detected!"
    echo "Remove sensitive data before committing."
    exit 1
fi

# Проверка .env.local
if git diff --cached --name-only | grep ".env.local" > /dev/null; then
    echo "❌ ERROR: .env.local should never be committed!"
    exit 1
fi
```

### Если случайно закоммитили секрет

```bash
# 1. Немедленно удалите из истории
git filter-repo --replace-text password-replacements.txt --force

# 2. Отправьте с force push
git push --force --all origin

# 3. Смените скомпрометированный ключ!
```

---

## 📊 Архитектура безопасности

```
┌─────────────────────────────────────────────────────────┐
│  .env.local (gitignored)                                │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ADMIN_MASTER_KEY=YourSecretPassword2026!         │  │
│  │ OPENROUTER_API_KEY=sk-or-...                     │  │
│  │ SECRET_LOVE_KEY=...                              │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  GitHub Secrets (encrypted)                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │ MASTER_KEY=...                                   │  │
│  │ KEYSTORE_BASE64=...                              │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  Build Process                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ --dart-define=ADMIN_MASTER_KEY=${{ secrets... }} │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  Dart Code                                              │
│  ┌──────────────────────────────────────────────────┐  │
│  │ String.fromEnvironment('ADMIN_MASTER_KEY')       │  │
│  │ if (key == 'NOT_SET') → BLOCK                    │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 🧪 Проверка безопасности

### 1. Поиск утечек в истории

```bash
# Поиск по всем коммитам
git log -p --all | grep -E "password|secret|key" | grep -v "example\|template"

# Поиск конкретных паттернов
git log -p --all -S "18051940" --oneline
```

### 2. Проверка .gitignore

```bash
# Проверка что .env.local игнорируется
git check-ignore -v .env.local
# Ожидается: .gitignore:.env.local

# Проверка что passwords.txt игнорируется
git check-ignore -v passwords.txt
# Ожидается: .gitignore:passwords.txt
```

### 3. Сканирование на секреты

```bash
# Установите gitleaks
sudo apt install gitleaks

# Запустите сканирование
gitleaks detect --source . --verbose
```

---

## 📚 Документы

- [GITHUB_SECRETS_SETUP.md](GITHUB_SECRETS_SETUP.md) — настройка секретов GitHub
- [FINAL_SECURITY_REPORT.md](FINAL_SECURITY_REPORT.md) — полный отчёт
- [PUSH_INSTRUCTIONS.md](PUSH_INSTRUCTIONS.md) — инструкция по отправке

---

## ⚠️ ЕСЛИ СЕКРЕТ УТЕК

### Немедленные действия

1. **Смените скомпрометированный ключ**
2. **Удалите из истории git:**
   ```bash
   git filter-repo --replace-text password-replacements.txt --force
   git push --force --all origin
   ```
3. **Проверьте логи доступа**
4. **Уведомите команду**

---

**«Безопасность — это процесс, а не результат»** 🔐

*Liberty Reach Security Team*
