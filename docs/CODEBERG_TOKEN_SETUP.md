# 🔐 CODEBERG TOKEN - ИНСТРУКЦИЯ

**Дата:** 22 марта 2026 г.  
**Статус:** ✅ Готово к использованию

---

## 📋 ЧТО НУЖНО

**CODEBERG_TOKEN** — это личный токен доступа для автоматической отправки кода на Codeberg.

**Зачем нужен:**
- ✅ Автоматическое зеркалирование
- ✅ Скрипт `./backup-to-all-remotes.sh` работает без ручного ввода пароля
- ✅ GitHub Actions для авто-зеркалирования

---

## 🚀 БЫСТРАЯ ИНСТРУКЦИЯ (5 минут)

### Шаг 1: Откройте Codeberg

Перейдите на: **https://codeberg.org/settings/applications**

### Шаг 2: Авторизуйтесь

- Если нет аккаунта → **Sign Up** (регистрация)
- Если есть → **Sign In** (логин)

### Шаг 3: Создайте токен

1. Нажмите кнопку **"Generate New Token"**

2. Заполните форму:
   ```
   Name: liberty-reach-mirror
   Expiry Date: [оставьте пустым]
   ```

3. Выберите разрешения (Scopes):
   - ☑️ **repository** — доступ к репозиториям
   - ☑️ **write:repository** — запись в репозитории

4. Нажмите **"Generate Token"**

### Шаг 4: Скопируйте токен

⚠️ **ВАЖНО:** Токен показывается ТОЛЬКО ОДИН РАЗ!

Выглядит как:
```
cb_1234567890abcdef1234567890abcdef
```

**СКОПИРУЙТЕ и СОХРАНИТЕ** в надёжном месте!

### Шаг 5: Добавьте в окружение

#### Вариант 1: Для текущей сессии (быстро)

```bash
export CODEBERG_TOKEN=cb_ваш_токен
```

#### Вариант 2: Постоянно (рекомендуется)

```bash
# Добавьте в .env.local
echo "CODEBERG_TOKEN=cb_ваш_токен" >> .env.local
```

#### Вариант 3: Для всех сессий

```bash
# Добавьте в ~/.bashrc
echo "export CODEBERG_TOKEN=cb_ваш_токен" >> ~/.bashrc
source ~/.bashrc
```

### Шаг 6: Проверка

```bash
./backup-to-all-remotes.sh
```

**Ожидается:**
```
[2/3] Codeberg...
✅ Codeberg: OK
```

---

## 🔐 АЛЬТЕРНАТИВА: SSH КЛЮЧ (более безопасно)

Если не хотите использовать токен:

### 1. Создайте SSH ключ

```bash
ssh-keygen -t ed25519 -C "liberty-reach-mirror"
# Нажмите Enter для сохранения по умолчанию
```

### 2. Скопируйте публичный ключ

```bash
cat ~/.ssh/id_ed25519.pub
```

### 3. Добавьте на Codeberg

1. Откройте: https://codeberg.org/settings/keys
2. Нажмите **"Add Key"**
3. Вставьте содержимое `id_ed25519.pub`
4. Нажмите **"Add Key"**

### 4. Измените remote на SSH

```bash
git remote set-url codeberg git@codeberg.org:zametkikostik/liberty-reach-messenger.git
```

### 5. Отправьте

```bash
./backup-to-all-remotes.sh
# ИЛИ вручную
git push codeberg main --force
```

---

## 📊 СРАВНЕНИЕ МЕТОДОВ

| Метод | Безопасность | Удобство | Рекомендуется |
|-------|--------------|----------|---------------|
| **Token** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Для автоматизации |
| **SSH Key** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Для ручной отправки |
| **Password** | ⭐⭐ | ⭐⭐ | ❌ Не рекомендуется |

---

## 🛡️ БЕЗОПАСНОСТЬ

### ✅ ХОРОШО

- ✅ Храните токен в менеджере паролей (Bitwarden, KeePass)
- ✅ Используйте `.env.local` (файл в .gitignore)
- ✅ Создавайте отдельные токены для разных проектов
- ✅ Меняйте токены раз в 6 месяцев

### ❌ ПЛОХО

- ❌ НЕ делитесь токеном с кем-либо
- ❌ НЕ коммитьте в репозиторий
- ❌ НЕ используйте в публичных скриптах
- ❌ НЕ логируйте токен

---

## 🆘 ПРОБЛЕМЫ И РЕШЕНИЯ

### Проблема: "Token expired"

**Решение:**
1. Создайте новый токен на Codeberg
2. Обновите в окружении
3. Запустите скрипт снова

### Проблема: "Invalid token"

**Решение:**
1. Проверьте что скопировали весь токен
2. Убедитесь что нет пробелов
3. Проверьте разрешения (repository + write:repository)

### Проблема: "Repository not found"

**Решение:**
1. Убедитесь что репозиторий существует на Codeberg
2. Создайте вручную: https://codeberg.org/repo/create
3. Проверьте что у токена есть права на запись

---

## 📞 ПОДДЕРЖКА

- **Codeberg Docs:** https://docs.codeberg.org/
- **Codeberg Support:** https://codeberg.org/contact

---

## 📚 СВЯЗАННАЯ ДОКУМЕНТАЦИЯ

- [MIRROR_QUICK_START.md](MIRROR_QUICK_START.md) — быстрое зеркалирование
- [ANTI_FRAGILE_DEPLOYMENT.md](ANTI_FRAGILE_DEPLOYMENT.md) — полное руководство
- [SECURITY_MASTER_GUIDE.md](SECURITY_MASTER_GUIDE.md) — безопасность

---

**«Автоматизация — ключ к устойчивости!»** 🔐

*Liberty Reach Security Team*
