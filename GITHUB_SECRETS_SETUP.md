# 🔐 Настройка GitHub Secrets

## Необходимые секреты

Для безопасной сборки APK необходимо установить следующие секреты в репозитории GitHub:

### 1. MASTER_KEY (Критично)

**Название:** `MASTER_KEY`  
**Значение:** Ваш секретный мастер-пароль  
**Пример:** `YourSecretKey2026!`

⚠️ **ВАЖНО:**
- Никогда не используйте пароль по умолчанию в production
- Сгенерируйте случайный надёжный пароль (минимум 16 символов)
- Этот ключ используется для:
  - Доступа к админ-панели (Sovereign Mode)
  - Шифрования сообщений
  - PANIC WIPE функции

### 2. Keystore Secrets (для подписи APK)

| Название | Описание | Пример |
|----------|----------|--------|
| `KEYSTORE_BASE64` | BASE64 кодировка keystore файла | `MIIEpAIBAAKCAQEA...` |
| `KEYSTORE_PASSWORD` | Пароль keystore | `YourStorePassword` |
| `KEY_ALIAS` | Алиас ключа | `upload` |
| `KEY_PASSWORD` | Пароль ключа | `YourKeyPassword` |

### 3. Дополнительные секреты (опционально)

| Название | Описание |
|----------|----------|
| `RPC_URL` | RPC endpoint для blockchain |
| `OPENROUTER_API_KEY` | API ключ для AI функций |
| `SECRET_LOVE_KEY` | Ключ для Immutable Love |
| `PINATA_API_KEY` | IPFS Pinata API key |
| `PINATA_SECRET_KEY` | IPFS Pinata secret |

---

## 📋 Пошаговая инструкция

### Шаг 1: Генерация MASTER_KEY

```bash
# Сгенерировать случайный пароль (Linux/Mac)
openssl rand -base64 32

# Или использовать Python
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### Шаг 2: Добавление секрета в GitHub

1. Перейдите в репозиторий на GitHub
2. **Settings** → **Secrets and variables** → **Actions**
3. **New repository secret**
4. Заполните:
   - **Name:** `MASTER_KEY`
   - **Value:** ваш сгенерированный пароль
5. **Add secret**

### Шаг 3: Проверка

После установки секрета:

1. Запустите workflow **Hybrid CI/CD Build**
2. Проверьте логи сборки — должна быть строка:
   ```
   🔐 Building with ADMIN_MASTER_KEY...
   ```
3. Если ключ не установлен, сборка продолжится, но админка не будет работать

---

## ⚠️ Предупреждения

### НИКОГДА не делайте:

❌ Не коммитьте реальный пароль в код  
❌ Не используйте пароль по умолчанию в production  
❌ Не передавайте пароль через issue/pull request  
❌ Не логируйте пароль в CI/CD

### ВСЕГДА делайте:

✅ Используйте GitHub Secrets  
✅ Генерируйте случайные пароли  
✅ Меняйте пароль периодически  
✅ Храните резервную копию в безопасном месте

---

## 🔍 Проверка установки

После установки секрета проверьте workflow лог:

```yaml
- name: Build Release APK
  run: |
    flutter build apk --release \
      --dart-define=ADMIN_MASTER_KEY=${{ secrets.MASTER_KEY }}
```

Если видите эту строку в логе — секрет используется правильно.

---

## 🚨 PANIC WIPE

Если кто-то попытается войти с неверным паролем 3 раза:

1. Активируется PANIC WIPE
2. Все данные будут удалены
3. Потребуется полная переустановка

---

**Безопасность начинается с правильного управления секретами!** 🔐

*Liberty Reach Security Team*
