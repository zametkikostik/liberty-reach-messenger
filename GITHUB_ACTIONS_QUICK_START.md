# 🚀 GitHub Actions: Автономная сборка APK

## Быстрый старт

### 1. Запуск сборки
```
GitHub → Actions → Hybrid CI/CD Build → Run workflow
```

### 2. Параметры (по умолчанию)
- **master_key**: `REDACTED_PASSWORD`
- **build_type**: `release`

### 3. Скачать APK
```
Workflow run → Artifacts → liberty-reach-apks-<номер> → Download
```

---

## 🔐 Что настроено

| Функция | Реализация |
|---------|------------|
| **Manual Trigger** | `workflow_dispatch` с inputs |
| **Keystore** | Генерируется на лету (RSA 2048, 10000 дней) |
| **Master Key** | `--dart-define=MASTER_KEY=...` |
| **Signing** | V2/V3 via `enableV2Signing true` |
| **Artifacts** | app-release.apk (+ ABI splits + AAB) |

---

## 📁 Файлы

- `.github/workflows/hybrid_build.yml` — workflow сборки
- `mobile/android/app/build.gradle` — V2/V3 signing
- `mobile/lib/screens/master_password_screen.dart` — чтение MASTER_KEY

---

## 📊 Артефакты

После сборки доступны **5 файлов**:

1. `app-release.apk` — универсальный (50 MB)
2. `app-release-armeabi-v7a.apk` — старые телефоны (20 MB)
3. `app-release-arm64-v8a.apk` — современные ⭐ (22 MB)
4. `app-release-x86_64.apk` — эмуляторы (23 MB)
5. `app-release.aab` — Google Play (45 MB)

**Хранение:** 30 дней

---

## 🔧 Команды сборки

```bash
# APK с обфускацией и мастер-ключом
flutter build apk --release \
  --split-per-abi \
  --dart-define=MASTER_KEY=REDACTED_PASSWORD \
  --dart-define=BUILD_TYPE=release

# App Bundle
flutter build appbundle --release \
  --dart-define=MASTER_KEY=REDACTED_PASSWORD
```

---

## 🛡️ Безопасность

- ✅ Keystore НЕ в репозитории
- ✅ Keystore НЕ в secrets
- ✅ Генерируется в RAM GitHub Runner
- ✅ Уничтожается после сборки
- ✅ Мастер-пароль через dart-define

---

**Бро, VDS не нужен. GitHub всё сделает сам.** 🔐
