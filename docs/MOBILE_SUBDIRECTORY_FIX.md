# 🔧 MOBILE/ SUBDIRECTORY FIX

## Проблема
Flutter проект находится в поддиректории `mobile/`, а не в корне репозитория.

## Решение

### ✅ GitHub Actions Workflow

**Файл:** `.github/workflows/build.yml`

**Ключевые изменения:**

```yaml
jobs:
  build-flutter:
    name: Build Flutter APK
    runs-on: ubuntu-latest
    
    # Все команды выполняются в mobile/
    defaults:
      run:
        working-directory: mobile
    
    steps:
      # Decode keystore в mobile/android/app/
      - name: Decode Keystore
        run: |
          mkdir -p android/app
          echo "$KEYSTORE_BASE64" | base64 --decode > android/app/upload-keystore.jks
      
      # key.properties в mobile/android/
      - name: Create key.properties
        run: |
          cat > android/key.properties << EOF
          storePassword=...
          EOF
      
      # Сборка APK
      - name: Build Release APK
        run: |
          flutter clean
          flutter pub get
          flutter build apk --release
      
      # Артефакты из mobile/build/
      - name: Upload APK Artifacts
        uses: actions/upload-artifact@v4
        with:
          path: |
            build/app/outputs/flutter-apk/*.apk
            build/app/outputs/bundle/release/*.aab
```

---

### ✅ Android build.gradle

**Файл:** `mobile/android/app/build.gradle`

**Правильные пути:**

```groovy
// Относительно mobile/android/
def keystorePropertiesFile = rootProject.file('key.properties')

// При загрузке:
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

// Подпись:
signingConfigs {
    release {
        storeFile file(keystoreProperties['storeFile'])  // upload-keystore.jks
        storePassword keystoreProperties['storePassword']
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
    }
}
```

---

## 📁 СТРУКТУРА ПРОЕКТА

```
liberty-sovereign/
├── .github/workflows/
│   └── build.yml              # working-directory: mobile
├── mobile/                     # ← Flutter проект здесь
│   ├── android/
│   │   ├── app/
│   │   │   ├── build.gradle   # ← Правильные пути
│   │   │   └── upload-keystore.jks
│   │   └── key.properties
│   ├── lib/
│   │   └── services/
│   │       └── api_service.dart
│   └── pubspec.yaml
├── src/                        # ← Rust проект
│   └── main.rs
└── Cargo.toml
```

---

## ✅ ПРОВЕРКА ПУТЕЙ

### В GitHub Actions:

```bash
# working-directory: mobile
pwd  # /home/runner/work/liberty-reach-messenger/liberty-reach-messenger/mobile

# Keystore сохраняется в:
android/app/upload-keystore.jks  # ✅

# key.properties создается в:
android/key.properties  # ✅

# APK собирается в:
build/app/outputs/flutter-apk/app-release.apk  # ✅
```

### Локально:

```bash
cd mobile

# Сборка APK
flutter build apk --release

# APK будет в:
ls -lh build/app/outputs/flutter-apk/
```

---

## 🚀 ТЕПЕРЬ МОЖНО ПУШИТЬ

```bash
# Добавь исправления
git add .github/workflows/build.yml mobile/android/app/build.gradle

# Закоммить
git commit -m "🔧 Fix: mobile/ subdirectory paths"

# Пуш
git push -u origin main

# Создай тег для сборки
git tag v0.4.1-hybrid-cicd
git push origin v0.4.1-hybrid-cicd
```

---

## 📊 ОЖИДАЕМЫЙ РЕЗУЛЬТАТ

После пуша тега GitHub Actions:

1. ✅ Checkout в root
2. ✅ Перейти в `mobile/`
3. ✅ Decode keystore в `mobile/android/app/`
4. ✅ Создать `mobile/android/key.properties`
5. ✅ Собрать APK в `mobile/build/app/outputs/flutter-apk/`
6. ✅ Загрузить артефакты
7. ✅ Создать GitHub Release

---

**Built for freedom, encrypted for life.** 🏰
