# 🚀 QUICK SETUP GUIDE - Liberty Reach v0.7.5

## ⚡ Быстрый старт за 5 минут

### Шаг 1: Настройка Pinata API

1. Открой https://app.pinata.cloud/developers
2. Залогинься или создай аккаунт
3. Создай новый API ключ (Admin type)
4. Скопируй JWT токен

### Шаг 2: Создание .env.local

1. В корне `mobile/` создай файл `.env.local`
2. Вставь свой JWT:

```env
PINATA_JWT=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...твои_ключи...
```

### Шаг 3: Установка зависимостей

```bash
cd mobile
flutter pub get
```

### Шаг 4: Сборка APK

```bash
# Debug версия (для тестирования)
flutter build apk --debug

# Release версия (для публикации)
flutter build apk --release
```

**Результат:**
- Debug: `mobile/build/app/outputs/flutter-apk/app-debug.apk`
- Release: `mobile/build/app/outputs/flutter-apk/app-release.apk`

### Шаг 5: Установка на телефон

```bash
# Через USB
adb install build/app/outputs/flutter-apk/app-debug.apk

# Или скопируй файл на телефон и установи вручную
```

---

## 🔐 Что нужно знать

### Ключи безопасности

| Ключ | Где взять | Зачем |
|------|-----------|-------|
| `PINATA_JWT` | https://pinata.cloud | Загрузка файлов в IPFS |
| `CLOUDFLARE_WORKER_URL` | Твой Worker на dash.cloudflare.com | Backend API |

### Где хранятся ключи

- **Файл:** `mobile/.env.local`
- **НЕ в git:** Добавлен в `.gitignore` ✅
- **Загрузка:** `flutter_dotenv` автоматически

---

## 📱 Что работает в v0.7.5

### ✅ Реализовано:

- [x] **Tor Ritual Widget** - 🧅 лук с прогрессом
- [x] **Theme Switcher** - Ghost/Love темы
- [x] **Profile Setup** - Имя + аватар + bio
- [x] **IPFS Integration** - Загрузка файлов через Pinata
- [x] **E2EE Encryption** - AES-256-GCM шифрование
- [x] **MessageBubble** - Сообщения с изображениями
- [x] **Love Effect** - Золотые частицы для "love"
- [x] **Biometric Auth** - Отпечаток/лицо
- [x] **Vault Protection** - 9 триггеров в D1

### ⚠️ Временно не работает:

- [ ] **WebRTC Calls** - Проблемы компиляции flutter_webrtc
  - Решение: Ждём обновления плагина или фикс от сообщества

---

## 🧪 Тестирование

### 1. Проверка Pinata

```dart
// В любом месте app:
import 'package:liberty_reach/services/storage_service.dart';

final storage = StorageService();
// Pick file и upload
final cid = await storage.uploadAvatar(file);
print('CID: $cid');
```

### 2. Проверка D1

```bash
# Через wrangler
wrangler d1 execute liberty-db --command="SELECT * FROM users LIMIT 5;" --remote
```

### 3. Проверка триггеров

```bash
# Попытка удалить вечное сообщение (должна быть ошибка)
wrangler d1 execute liberty-db --command="DELETE FROM messages WHERE is_love_immutable=1;" --remote
```

---

## 🐛 Troubleshooting

### Ошибка: "Invalid JWT"

**Решение:**
1. Проверь что JWT скопирован без пробелов
2. Убедись что `.env.local` существует
3. Перезапусти app: `flutter run`

### Ошибка: "Failed to upload"

**Причины:**
- Нет интернета
- Неверный JWT
- Превышен лимит Pinata (1 GB на free тарифе)

### Ошибка компиляции: "SimulcastVideoEncoderFactoryWrapper"

**Это известная проблема flutter_webrtc**

**Решение:**
1. Использовать версию 0.9.x (старая)
2. Или ждать фикс в новых версиях
3. Или собрать без WebRTC (как сейчас)

---

## 📊 Структура проекта

```
mobile/
├── .env.example          # Шаблон переменных
├── .env.local            # Твои ключи (НЕ в git!)
├── lib/
│   ├── services/
│   │   ├── storage_service.dart    # Pinata IPFS
│   │   ├── profile_service.dart    # Профиль пользователя
│   │   └── call_service.dart       # WebRTC звонки
│   ├── providers/
│   │   └── profile_provider.dart   # State management
│   ├── screens/
│   │   └── setup_profile_screen.dart  # Настройка профиля
│   └── widgets/
│       ├── message_bubble.dart     # Сообщения с фото
│       └── calling_overlay.dart    # UI звонков
└── PINATA_SETUP.md       # Подробная инструкция
```

---

## 🎯 Следующие шаги

1. ✅ **Настроить Pinata** (5 минут)
2. ✅ **Собрать APK** (2 минуты)
3. ✅ **Протестировать** на телефоне
4. ⏳ **Исправить WebRTC** (ждём фикс)
5. ⏳ **Добавить реальные звонки**

---

## 📞 Контакты

- **Документация:** `/docs/`
- **Pinata Guide:** `PINATA_SETUP.md`
- **Security:** `docs/SECURITY_SUMMARY.md`

---

**Удачи! 🚀**

*Built for freedom, encrypted for life.*
