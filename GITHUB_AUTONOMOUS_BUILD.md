# 🚀 GitHub Autonomous Build Setup

## Полностью автономная сборка в GitHub без VDS

### 🔥 Возможности

- ✅ **Manual Trigger**: Кнопка "Run workflow" в Actions
- ✅ **On-the-Fly Keystore**: Генерация ключа прямо в GitHub Runner
- ✅ **Dart Defines**: Мастер-пароль передаётся через `--dart-define`
- ✅ **V2/V3 Signing**: Полная подпись APK
- ✅ **Artifacts**: Готовый APK скачивается сразу после сборки

---

## 📋 Как использовать

### 1. Открой GitHub Actions

Перейди в репозиторий → **Actions** → **Hybrid CI/CD Build**

### 2. Нажми "Run workflow"

![Run workflow](https://docs.github.com/assets/cb-43263/mw-1440/images/help/repository/manually-run-workflow-action-button.webp)

### 3. Заполни параметры

| Параметр | Значение по умолчанию | Описание |
|----------|----------------------|----------|
| `master_key` | `REDACTED_PASSWORD` | Мастер-пароль для шифрования |
| `build_type` | `release` | Тип сборки (release/debug) |

### 4. Нажми "Run workflow"

Сборка займёт ~5-10 минут.

### 5. Скачай APK

После завершения:
1. Кликни на завершённый workflow run
2. Прокрути вниз до секции **Artifacts**
3. Кликни `liberty-reach-apks-<номер>`
4. Скачай `app-release.apk` (универсальный) или `app-release-arm64-v8a.apk` (для современных телефонов)

---

## 🔐 Что происходит во время сборки

```yaml
1. Checkout → Клонируем репозиторий
2. Setup Java → Устанавливаем Java 17
3. Setup Flutter → Устанавливаем Flutter 3.24.0
4. Generate Keystore → Создаём ключ в RAM
   - RSA 2048 бит
   - Validity: 10000 дней
   - Пароль: REDACTED_PASSWORD
5. Create key.properties → Настраиваем подписывание
6. Build APK → Собираем с --dart-define=MASTER_KEY
   - V2/V3 signing
   - Obfuscation (minifyEnabled true)
   - Split per ABI
7. Upload Artifacts → Загружаем APK на 30 дней
```

---

## 📱 Версии APK

| Файл | Описание | Размер |
|------|----------|--------|
| `app-release.apk` | Универсальный (все архитектуры) | ~50 MB |
| `app-release-armeabi-v7a.apk` | Для старых телефонов (32-bit) | ~20 MB |
| `app-release-arm64-v8a.apk` | Для современных (64-bit) ⭐ | ~22 MB |
| `app-release-x86_64.apk` | Для эмуляторов | ~23 MB |
| `app-release.aab` | Android App Bundle (Google Play) | ~45 MB |

**Рекомендация:** Скачивай `app-release-arm64-v8a.apk` для лучшего соотношения размер/производительность.

---

## 🔐 Безопасность

### Keystore генерируется каждый раз заново

```bash
keytool -genkey -v \
  -keystore android/app/upload-keystore.jks \
  -storetype PKCS12 \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "upload" \
  -storepass "REDACTED_PASSWORD" \
  -keypass "REDACTED_PASSWORD"
```

**Важно:**
- Ключ **НЕ** хранится в репозитории
- Ключ **НЕ** сохраняется в secrets
- Ключ существует только во время сборки в RAM GitHub Runner
- После сборки ключ уничтожается вместе с Runner

### Мастер-пароль передаётся через dart-define

```bash
flutter build apk --release \
  --dart-define=MASTER_KEY=REDACTED_PASSWORD \
  --dart-define=BUILD_TYPE=release
```

В коде Flutter:
```dart
const masterKey = String.fromEnvironment('MASTER_KEY');
```

---

## 🛠️ Troubleshooting

### Ошибка: "Keystore not found"

**Решение:** Убедись, что шаг "Generate Release Keystore" выполнился успешно.

### Ошибка: "Signing failed"

**Решение:** Проверь, что `key.properties` создан правильно:
```bash
storePassword=REDACTED_PASSWORD
keyPassword=REDACTED_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

### Ошибка: "Artifact not found"

**Решение:** 
- Проверь, что сборка завершилась успешно (зелёная галочка)
- Артефакты хранятся 30 дней
- Попробуй скачать другой APK (например, arm64-v8a)

---

## 📊 Build Summary

После каждой сборки в workflow появляется summary:

```markdown
## 📱 Build Summary

✅ **Build Type:** release
✅ **Master Key:** Set via --dart-define
✅ **Keystore:** Generated on-the-fly (RSA 2048, 10000 days)
✅ **Signing:** V2/V3 enabled via key.properties

### Download Links
- APKs will be available in **Artifacts** section
- Click on the workflow run → **Artifacts** → Download
```

---

## 🔗 Ссылки

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Flutter Build APK](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)

---

**Бро, теперь всё автономно. VDS не нужен. GitHub сам всё соберёт и подпишет.** 🔐
