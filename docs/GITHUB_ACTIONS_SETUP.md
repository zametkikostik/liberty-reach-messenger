# 🤖 GitHub Actions Setup for Liberty Reach

## 📱 Android Build Workflow

### Файлы:
- `.github/workflows/android_build.yml` - GitHub Actions workflow
- `scripts/setup_android_build.sh` - Setup helper script

---

## 🔐 Setup Instructions

### Шаг 1: Создай Keystore

```bash
cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign

# Если есть Flutter проект (mobile/)
cd mobile

# Создай keystore
keytool -genkey -v \
  -keystore android/app/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

# Введи пароль когда спросит
```

**Запомни пароль!** Он понадобится для secrets.

---

### Шаг 2: Создай key.properties

```bash
cd mobile

nano android/key.properties
```

**Вставь:**
```properties
storePassword=твой_пароль_от_keystore
keyPassword=твой_пароль_от_key
keyAlias=upload
storeFile=upload-keystore.jks
```

---

### Шаг 3: Запусти Setup Script

```bash
cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign

./scripts/setup_android_build.sh
```

Скрипт:
- ✅ Проверит keystore
- ✅ Закодирует в base64
- ✅ Покажет инструкции

---

### Шаг 4: Добавь Secrets в GitHub

1. Открой: https://github.com/zametkikostik/liberty-reach-messenger/settings/secrets/actions

2. Добавь 4 secrets:

| Name | Value |
|------|-------|
| `KEYSTORE_BASE64` | Base64 строка из скрипта |
| `KEYSTORE_PASSWORD` | Пароль от keystore |
| `KEY_PASSWORD` | Пароль от key |
| `KEY_ALIAS` | `upload` (по умолчанию) |

**Как получить KEYSTORE_BASE64:**
```bash
cd mobile
base64 -w 0 android/app/upload-keystore.jks | xclip -selection clipboard
```

---

## 🚀 Build Triggers

### Автоматический билд при теге:

```bash
# Создай тег
git tag v0.4.0-fortress-stable

# Пуш тега
git push origin v0.4.0-fortress-stable
```

GitHub Actions автоматически:
1. ✅ Checkout код
2. ✅ Setup Java 17 + Flutter
3. ✅ Decode keystore
4. ✅ Build APK
5. ✅ Build App Bundle (AAB)
6. ✅ Создаст GitHub Release с APK

---

### Ручной билд:

1. Открой: https://github.com/zametkikostik/liberty-reach-messenger/actions
2. Выбери "Android Build & Release"
3. Нажми "Run workflow"
4. Выбери ветку
5. Нажми "Run workflow"

---

## 📦 Build Outputs

После билда будут доступны:

### APK (для прямой установки):
- `app-armeabi-v7a-release.apk` (32-bit)
- `app-arm64-v8a-release.apk` (64-bit)
- `app-x86_64-release.apk` (emulator)

### AAB (для Google Play):
- `app-release.aab`

---

## 🧪 Local Testing

Перед пушем протестируй локально:

```bash
cd mobile

# Clean
flutter clean

# Get dependencies
flutter pub get

# Build APK
flutter build apk --release --split-per-abi

# Build AAB (для Play Store)
flutter build appbundle --release

# APK будет в:
ls -lh build/app/outputs/flutter-apk/
```

---

## 📊 Workflow Status

После пуша проверь статус:

```
https://github.com/zametkikostik/liberty-reach-messenger/actions
```

Зелёная галочка ✅ = билд успешен!

---

## 🔧 Troubleshooting

### Ошибка: "Keystore not found"
```bash
# Проверь путь
ls -la mobile/android/app/upload-keystore.jks

# Если нет - создай заново
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Ошибка: "Signing failed"
```bash
# Проверь key.properties
cat mobile/android/key.properties

# Убедись что пароли правильные
# Пересоздай secrets в GitHub
```

### Ошибка: "Flutter not found"
```bash
# Workflow использует Flutter 3.24.0
# Проверь что версия в .github/workflows/android_build.yml правильная
```

---

## 📝 Environment Variables

В `android_build.yml` можно изменить:

```yaml
env:
  FLUTTER_VERSION: '3.24.0'  # Версия Flutter
  JAVA_VERSION: '17'         # Версия Java
```

---

## 🎯 Next Steps

1. ✅ Создать keystore
2. ✅ Добавить secrets в GitHub
3. ✅ Протестировать локально
4. ✅ Создать тег
5. ✅ Пуш в GitHub
6. ✅ Скачать APK из Release!

---

**Built for freedom, encrypted for life.** 🏰
