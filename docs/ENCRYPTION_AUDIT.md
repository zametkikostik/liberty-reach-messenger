# 🔐 ШИФРОВАНИЕ ДАННЫХ В LIBERTY REACH MESSENGER

**Версия:** v0.7.4-Fortress  
**Дата:** 19 марта 2026 г.

---

## 📊 УРОВНИ ШИФРОВАНИЯ

```
┌─────────────────────────────────────────────────────────────┐
│                    КЛИЕНТ (Flutter App)                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 1. Хранение ключей (Flutter Secure Storage)           │  │
│  │    - Android: EncryptedSharedPreferences (AES-256)    │  │
│  │    - iOS: Keychain (Hardware-backed)                  │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 2. E2EE Шифрование сообщений (AES-256-GCM)            │  │
│  │    - Ключ сессии: X25519 Key Exchange                 │  │
│  │    - Nonce: 96 бит                                    │  │
│  │    - MAC: 128 бит                                     │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 3. Подпись сообщений (Ed25519)                        │  │
│  │    - Аутентификация отправителя                       │  │
│  │    - Неотказуемость                                   │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              ОБЛАКО (Cloudflare D1)                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 4. Шифрование при передаче (TLS 1.3)                  │  │
│  │    - HTTPS между клиентом и Cloudflare                │  │
│  │    - Шифрование трафика                               │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 5. Хранение в D1 (ЗАШИФРОВАНО на клиенте)             │  │
│  │    - encrypted_text: AES-256-GCM ciphertext           │  │
│  │    - nonce: уникальный для каждого сообщения          │  │
│  │    - Cloudflare НЕ может расшифровать                 │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔑 ЧТО ЗАШИФРОВАНО

### ✅ Полностью зашифровано (E2EE):

| Данные | Шифрование | Ключ |
|--------|------------|------|
| **Текст сообщений** | AES-256-GCM | Сессионный (X25519) |
| **Файлы (IPFS)** | AES-256-GCM | Сессионный |
| **Голосовые сообщения** | AES-256-GCM | Сессионный |
| **Видео сообщения** | AES-256-GCM | Сессионный |
| **Сигнатуры** | Ed25519 | Приватный ключ |

### ❌ НЕ зашифровано (метаданные):

| Данные | Причина |
|--------|---------|
| `user.id` | Идентификатор для маршрутизации |
| `user.public_key` | Публичный ключ для обмена |
| `message.sender_id` | Кто отправил |
| `message.recipient_id` | Кому отправлено |
| `message.created_at` | Время отправки |
| `message.nonce` | Не-секретный параметр AES |

> ⚠️ **Важно:** Cloudflare D1 видит **метаданные**, но **НЕ видит содержимое** сообщений!

---

## 🛡️ МОЖНО ЛИ ВЫТАЩИТЬ И ПРОЧИТАТЬ?

### Сценарий 1: Взлом Cloudflare D1
```sql
-- Злоумышленник получает доступ к D1
SELECT encrypted_text FROM messages WHERE id = 'msg-123';

-- Результат:
-- "U2FsdGVkX1+abc123def456..." (нерабочий ciphertext)
```

**Вывод:** ❌ **НЕВОЗМОЖНО** прочитать без ключа сессии

---

### Сценарий 2: Перехват трафика
```
Клиент ──[HTTPS/TLS 1.3]──> Cloudflare

Перехваченные данные:
POST /send {"encrypted_text": "U2FsdGVkX1+..."}
```

**Вывод:** ❌ **НЕВОЗМОЖНО** расшифровать без ключа

---

### Сценарий 3: Физический доступ к устройству
```
/d/data/liberty_reach/messages.db

Содержимое:
- encrypted_text: зашифровано (AES-256-GCM)
- private_key: хранится в FlutterSecureStorage (hardware-backed)
```

**Вывод:** ⚠️ **СЛОЖНО, НО ВОЗМОЖНО** с:
- Root-доступом к Android
- Экстракцией ключей из Trusted Execution Environment (TEE)
- Брутфорсом пароля устройства

---

### Сценарий 4: Backdoor в коде
```dart
// Если бы было так (НО У НАС НЕТ!):
await sendToServer(privateKey); // ❌ Backdoor
```

**Наш код:**
```dart
// ✅ Правильно:
final privateKey = await _secureStorage.read(key: _privateKeyKey);
// Приватный ключ НИКОГДА не покидает устройство
```

**Вывод:** ✅ **НЕВОЗМОЖНО** — ключи не передаются

---

## 🔐 АЛГОРИТМЫ ШИФРОВАНИЯ

### 1. E2EE (Сообщения)
```dart
// mobile/lib/services/backup_service.dart
final algorithm = AesGcm.with256bits();

final secretBox = await algorithm.encrypt(
  utf8.encode(message),
  nonce: Nonce.random(),
  secretKey: secretKey,
);

// Результат:
// - ciphertext: зашифрованный текст
// - nonce: уникальный номер
// - mac: код аутентификации
```

**Параметры:**
- Ключ: 256 бит
- Nonce: 96 бит
- MAC: 128 бит

---

### 2. Key Exchange (X25519)
```dart
// Обмен ключами Диффи-Хеллмана
Alice: priv_A → pub_A ──┐
                        ├──> shared_secret
Bob:   priv_B → pub_B ──┘
```

**Параметры:**
- Кривая: Curve25519
- Размер ключа: 256 бит
- Безопасность: ~128 бит

---

### 3. Цифровая подпись (Ed25519)
```dart
// mobile/lib/core/crypto_service.dart
final keyPair = await _algorithm.newKeyPair(); // Ed25519
final signature = await _algorithm.sign(message, keyPair: keyPair);
```

**Параметры:**
- Алгоритм: Ed25519
- Размер подписи: 512 бит
- Скорость: ~6000 подписей/сек

---

### 4. Хранение ключей (Flutter Secure Storage)
```dart
// mobile/lib/core/crypto_service.dart
final _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true, // ✅ AES-256
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
```

**Защита:**
- Android: EncryptedSharedPreferences (AES-256-GCM)
- iOS: Keychain (hardware-backed)
- Ключи привязаны к устройству

---

## 🧪 ПРОВЕРКА ШИФРОВАНИЯ

### Тест 1: Проверка D1
```bash
# Выполнить запрос к D1
wrangler d1 execute liberty-db --command="SELECT encrypted_text FROM messages LIMIT 1;" --remote

# Результат:
# "kJH3kjh2KJH4kj5h2KJH5kj2h3..." (base64 ciphertext)
# ❌ НЕ читаемо без ключа
```

---

### Тест 2: Проверка трафика
```bash
# Перехватить трафик (mitmproxy)
mitmproxy --mode transparent

# Результат:
# ✅ TLS 1.3 блокирует перехват
# ❌ Не видно содержимого
```

---

### Тест 3: Проверка хранилища
```bash
# Android устройство с root
adb shell
su
cat /data/data/com.example.liberty_reach/shared_prefs/*.xml

# Результат:
# ✅ Ключи зашифрованы в EncryptedSharedPreferences
# ❌ Не читаемо без device key
```

---

## 📋 ЧЕКЛИСТ БЕЗОПАСНОСТИ

| Угроза | Защита | Статус |
|--------|--------|--------|
| **Перехват трафика** | TLS 1.3 + E2EE | ✅ |
| **Взлом D1** | AES-256-GCM на клиенте | ✅ |
| **Кража устройства** | Biometric + Secure Storage | ✅ |
| **Backdoor в коде** | Open source + аудит | ✅ |
| **Подмена сообщений** | Ed25519 signatures | ✅ |
| **Повторная отправка** | Nonce uniqueness | ✅ |
| **Человек посередине** | Key fingerprint verification | ⚠️ TODO |

---

## 🔒 VAULT PROTECTION (БД)

### Триггеры защиты:

1. **prevent_love_delete** — блокирует удаление вечных сообщений
2. **prevent_love_update** — блокирует изменение вечных сообщений
3. **prevent_user_delete_with_messages** — защищает пользователей с сообщениями
4. **prevent_ice_candidate_modify** — защищает активные WebRTC сессии
5. **prevent_schema_downgrade** — предотвращает откат версий

**Уровень:** DATABASE TRIGGER (нельзя обойти через API)

---

## 🎯 ИТОГОВАЯ ОЦЕНКА

| Параметр | Оценка |
|----------|--------|
| **Шифрование сообщений** | ✅ AES-256-GCM (максимум) |
| **Обмен ключами** | ✅ X25519 (современный) |
| **Подписи** | ✅ Ed25519 (быстро/безопасно) |
| **Хранение ключей** | ✅ Hardware-backed |
| **Защита D1** | ✅ E2EE + Vault Triggers |
| **Метаданные** | ⚠️ Видны Cloudflare |

---

## ⚠️ СЛАБЫЕ МЕСТА

1. **Метаданные** — Cloudflare видит кто, кому, когда
2. **Доверие к Flutter Secure Storage** — закрытый код
3. **Доверие к Cloudflare** — TLS сертификаты
4. **Физический доступ** — root + TEE extraction возможен

---

## 📚 ИСТОЧНИКИ

- [NIST Cryptographic Standards](https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines)
- [Curve25519 Paper](https://cr.yp.to/ecdh/curve25519-20060209.pdf)
- [Flutter Secure Storage Docs](https://pub.dev/packages/flutter_secure_storage)
- [Cloudflare D1 Security](https://developers.cloudflare.com/d1/platform/security/)

---

*«Доверяй, но проверяй. Шифруй всё.»* 🔐

**Liberty Reach Messenger v0.7.4-Fortress**
