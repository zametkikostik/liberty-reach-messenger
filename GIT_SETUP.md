# 🔒 Безопасная публикация репозитория Liberty Reach

## ⚠️ ВАЖНО: ЧТО МОЖНО И НЕЛЬЗЯ ВЫКЛАДЫВАТЬ

### ✅ МОЖНО ВЫКЛАДЫВАТЬ:
- ✅ Исходный код (без секретов)
- ✅ Документация (README, инструкции)
- ✅ Конфигурация (wrangler.toml БЕЗ секретов)
- ✅ Тесты
- ✅ CI/CD конфигурация (.github/workflows)
- ✅ .gitignore
- ✅ Скрипты сборки

### ❌ НЕЛЬЗЯ ВЫКЛАДЫВАТЬ:
- ❌ Приватные ключи (*.key, *.pem, *.secret)
- ❌ API токены и секреты
- ❌ Файлы .env с секретами
- ❌ Keystore файлы (*.jks, *.keystore)
- ❌ Базы данных и хранилища
- ❌ Логи с секретами
- ❌ Recovery фразы и seed
- ❌ Cloudflare credentials

---

## 📋 ПОШАГОВАЯ ИНСТРУКЦИЯ

### Шаг 1: Проверка файлов

```bash
cd /home/kostik/liberty-reach-messenger

# Проверить что есть в репозитории
git status

# Проверить на критические файлы
./safe-push.sh
```

### Шаг 2: Инициализация Git

```bash
# Инициализировать репозиторий
git init

# Добавить все файлы
git add .

# Проверить что добавлено
git status
```

### Шаг 3: Первый коммит

```bash
# Сделать коммит
git commit -m "Initial commit: Liberty Reach v0.3.0

Features:
- Post-Quantum encryption
- Crypto wallet (15+ blockchains)
- VoIP + SIP telephony
- PTT radio
- Video conferences
- Family statuses
- Mesh network
- Cloudflare backend

Security:
- E2EE encryption
- Double Ratchet
- Shamir's Secret Sharing

Platforms:
- Web (Cloudflare Pages)
- Android (Flutter)
- Linux Desktop"
```

### Шаг 4: Создание репозитория на GitHub

1. Зайти на https://github.com/new
2. Название: `liberty-reach-messenger`
3. Описание: "Secure & Private Messenger - Post-Quantum Encryption + Crypto Wallet"
4. Visibility: Public
5. **НЕ** нажимать "Initialize with README" (у нас уже есть)
6. Нажать "Create repository"

### Шаг 5: Добавление remote

```bash
# Добавить remote (замени zametkikostik на свой)
git remote add origin https://github.com/zametkikostik/liberty-reach-messenger.git

# Проверить
git remote -v
```

### Шаг 6: Безопасный пуш

```bash
# Использовать безопасный скрипт
./safe-push.sh

# ИЛИ обычный пуш (если уверен что нет секретов)
git push -u origin main
```

### Шаг 7: Проверка на GitHub

1. Открыть https://github.com/zametkikostik/liberty-reach-messenger
2. Проверить что файлы загрузились
3. Проверить что README отображается красиво

---

## 🔐 НАСТРОЙКА GITHUB SECRETS

### Для Cloudflare деплоя:

1. Зайти в репозиторий на GitHub
2. Settings → Secrets and variables → Actions
3. New repository secret:

```
Name: CLOUDFLARE_API_TOKEN
Value: <твой токен из Cloudflare>

Name: CLOUDFLARE_ACCOUNT_ID
Value: <твой account ID>
```

### Как получить Cloudflare API Token:

1. https://dash.cloudflare.com/profile/api-tokens
2. Create Token → Custom Token
3. Permissions:
   - Account → Cloudflare Pages → Edit
   - Zone → DNS → Edit (опционально)
4. TTL: No expiration
5. Copy token и добавь в GitHub Secrets

---

## 🎨 ОФОРМЛЕНИЕ РЕПОЗИТОРИЯ

### Файлы которые делают репозиторий красивым:

```
liberty-reach-messenger/
├── README.md              # ✅ Главный файл (уже есть)
├── LICENSE                # ✅ Лицензия (MIT)
├── .gitignore            # ✅ Игнор файлы (уже есть)
├── .github/
│   ├── workflows/        # ✅ CI/CD (уже есть)
│   └── ISSUE_TEMPLATE/   # ⬜ Шаблоны issues
├── docs/                 # ✅ Документация
├── SECURITY.md           # ⬜ Security policy
├── CONTRIBUTING.md       # ⬜ Как контрибьютить
└── CODE_OF_CONDUCT.md    # ⬜ Кодекс поведения
```

### Создать LICENSE:

```bash
# MIT License
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2026 Liberty Reach

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
```

### Создать SECURITY.md:

```bash
cat > SECURITY.md << 'EOF'
# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please send an email to:
security@libertyreach.internal

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will respond within 48 hours.
EOF
```

### Создать CONTRIBUTING.md:

```bash
cat > CONTRIBUTING.md << 'EOF'
# Contributing to Liberty Reach

## How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Code Style

- Follow existing code style
- Add comments for complex logic
- Write tests for new features
- Update documentation

## Security

- Do not commit secrets or keys
- Use environment variables for config
- Follow security best practices
EOF
```

---

## ✅ ЧЕКЛИСТ ПЕРЕД ПУШЕМ

### Проверить:
- [ ] Нет файлов *.key, *.pem, *.secret в git
- [ ] Нет .env файлов с секретами
- [ ] Нет баз данных и хранилищ
- [ ] .gitignore настроен правильно
- [ ] README.md красивый и информативный
- [ ] LICENSE добавлен
- [ ] GitHub workflows настроены
- [ ] GitHub secrets добавлены (для деплоя)

### После пуша:
- [ ] Репозиторий отображается на GitHub
- [ ] README рендерится правильно
- [ ] GitHub Actions запустился
- [ ] Web деплой на Cloudflare сработал
- [ ] APK билд работает

---

## 🚀 БЫСТРЫЕ КОМАНДЫ

```bash
# Инициализация
git init
git add .
git commit -m "Initial commit"

# Создание remote
git remote add origin https://github.com/zametkikostik/liberty-reach-messenger.git

# Пуш
git push -u origin main

# Или безопасный пуш
./safe-push.sh
```

---

## 📊 ССЫЛКИ

- Репозиторий: https://github.com/zametkikostik/liberty-reach-messenger
- Web версия: https://liberty-reach-messenger.pages.dev
- Документация: /docs/

---

**ВСЁ ГОТОВО! Репозиторий создан и оформлен! 🎉**
