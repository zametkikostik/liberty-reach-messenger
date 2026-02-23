# 🚀 Liberty Reach - Полная Инструкция по Деплою
## Web (Cloudflare Pages) + Android (Native APK)

---

## 📋 ЧТО БУДЕМ ДЕЛАТЬ

```
┌─────────────────────────────────────────────────────────┐
│  Web Version (Cloudflare Pages)                         │
│  ├── Git интеграция (авто-деплой)                       │
│  ├── HTTPS через Cloudflare                             │
│  ├── CDN по всему миру                                  │
│  └── Бесплатно до 100K запросов/день                    │
├─────────────────────────────────────────────────────────┤
│  Android Version (Native APK)                           │
│  ├── Кроссплатформенный Flutter                         │
│  ├── Нативный Android (Kotlin)                          │
│  ├── APK файл для установки                             │
│  └── Публикация в Google Play (опционально)             │
└─────────────────────────────────────────────────────────┘
```

---

## 🌐 ЧАСТЬ 1: WEB ВЕРСИЯ НА CLOUDFLARE PAGES

### Шаг 1: Подготовка Git репозитория

```bash
# 1. Создать репозиторий на GitHub
# https://github.com/new
# Название: liberty-reach-messenger

# 2. Инициализировать Git локально
cd /home/kostik/liberty-reach-messenger
git init

# 3. Добавить все файлы
git add .

# 4. Сделать коммит
git commit -m "Initial commit: Liberty Reach v0.3.0"

# 5. Добавить remote
git remote add origin https://github.com/YOUR_USERNAME/liberty-reach-messenger.git

# 6. Запушить
git push -u origin main
```

### Шаг 2: Создать Cloudflare Pages проект

```bash
# 1. Login в Cloudflare
wrangler login

# 2. Проверить аккаунт
wrangler whoami
```

### Шаг 3: Настроить Pages через Dashboard

1. **Зайти на** https://pages.cloudflare.com/

2. **Нажать** "Create a project"

3. **Выбрать** "Connect to Git"

4. **Выбрать репозиторий** `liberty-reach-messenger`

5. **Настроить build:**

```
Project name: liberty-reach-messenger
Production branch: main

Build Settings:
├── Build command: npm run build
├── Build output directory: dist
├── Root directory: web
└── Environment variables:
    ├── NODE_VERSION: 18
    └── CLOUDFLARE_ACCOUNT_ID: твой_id
```

6. **Нажать** "Save and Deploy"

### Шаг 4: Создать Web версию (Flutter Web)

Создай файл `web/index.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="Liberty Reach Messenger - Secure & Private">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="Liberty Reach">
  
  <title>Liberty Reach Messenger</title>
  
  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png" />
  
  <!-- Flutter Web -->
  <script src="flutter_bootstrap.js" async></script>
  
  <!-- Cloudflare Analytics -->
  <script defer src='https://static.cloudflareinsights.com/beacon.min.js' 
          data-cf-beacon='{"token": "your_token"}'></script>
</head>
<body>
  <div id="loading">Loading Liberty Reach...</div>
  <script>
    // Service Worker для offline режима
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', function () {
        navigator.serviceWorker.register('flutter_service_worker.js');
      });
    }
  </script>
</body>
</html>
```

Создай `web/manifest.json`:

```json
{
    "name": "Liberty Reach Messenger",
    "short_name": "LibertyReach",
    "description": "Secure & Private Messenger",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#1976D2",
    "theme_color": "#1976D2",
    "orientation": "portrait-primary",
    "prefer_related_applications": false,
    "icons": [
        {
            "src": "icons/Icon-192.png",
            "sizes": "192x192",
            "type": "image/png"
        },
        {
            "src": "icons/Icon-512.png",
            "sizes": "512x512",
            "type": "image/png"
        }
    ]
}
```

### Шаг 5: Build скрипт для Web

Создай `web/build.sh`:

```bash
#!/bin/bash

echo "🔨 Building Liberty Reach Web..."

# Перейти в директорию Flutter
cd mobile/flutter

# Build для Web
flutter build web --release \
    --base-href="/" \
    --output=../../web/dist

# Копировать assets
cp -r assets/* ../../web/dist/assets/ 2>/dev/null || true

# Оптимизация
cd ../../web/dist

# Gzip сжатие
find . -type f \( -name "*.js" -o -name "*.css" -o -name "*.html" \) \
    -exec gzip -9 -k {} \;

# Brotli сжатие
find . -type f \( -name "*.js" -o -name "*.css" -o -name "*.html" \) \
    -exec brotli -9 -k {} \;

echo "✅ Web build complete!"
echo "📁 Output: web/dist/"
```

### Шаг 6: Автоматический деплой через GitHub Actions

Создай `.github/workflows/deploy-web.yml`:

```yaml
name: Deploy Web to Cloudflare Pages

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: |
          cd mobile/flutter
          flutter pub get
          npm install -g wrangler
      
      - name: Build Web
        run: |
          cd mobile/flutter
          flutter build web --release --base-href="/"
      
      - name: Deploy to Cloudflare Pages
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          command: pages deploy mobile/flutter/build/web --project-name=liberty-reach-messenger
```

### Шаг 7: Настроить API Token

1. **Зайти на** https://dash.cloudflare.com/profile/api-tokens

2. **Создать токен:**
```
Token name: liberty-reach-github
Permissions:
  - Account -> Cloudflare Pages -> Edit
  - Zone -> DNS -> Edit
TTL: No expiration
```

3. **Добавить в GitHub Secrets:**
```
GitHub Repo → Settings → Secrets and variables → Actions
New repository secret:
  Name: CLOUDFLARE_API_TOKEN
  Value: твой_токен
```

### Шаг 8: Проверка деплоя

```bash
# Локальный тест
cd mobile/flutter
flutter build web
flutter run -d chrome

# После пуша в Git:
# 1. GitHub Actions запустится автоматически
# 2. Deploy на Cloudflare Pages
# 3. Web версия доступна по:
#    https://liberty-reach-messenger.pages.dev
```

---

## 📱 ЧАСТЬ 2: ANDROID ПРИЛОЖЕНИЕ

### Вариант A: Flutter (Кроссплатформенный)

#### Шаг 1: Настройка Flutter для Android

```bash
# Проверить Flutter
flutter doctor

# Должно показать:
# ✓ Android toolchain
# ✓ Android Studio
# ✓ Connected devices
```

#### Шаг 2: Создать Android манифест

Файл `mobile/flutter/android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="internal.libertyreach.messenger">
    
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.READ_CONTACTS"/>
    <uses-permission android:name="android.permission.WRITE_CONTACTS"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.BLUETOOTH"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    
    <application
        android:label="Liberty Reach"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true"
        android:networkSecurityConfig="@xml/network_security_config">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

#### Шаг 3: Build APK

Создай `mobile/flutter/build-apk.sh`:

```bash
#!/bin/bash

echo "🔨 Building Liberty Reach Android APK..."

cd mobile/flutter

# Clean
flutter clean

# Get dependencies
flutter pub get

# Build APK (Debug)
echo "Building Debug APK..."
flutter build apk --debug --output=build/app/outputs/flutter-apk/app-debug.apk

# Build APK (Release)
echo "Building Release APK..."
flutter build apk --release --output=build/app/outputs/flutter-apk/app-release.apk

# Build App Bundle (для Google Play)
echo "Building App Bundle..."
flutter build appbundle --release

echo ""
echo "✅ Build complete!"
echo ""
echo "📁 APK Files:"
echo "   Debug:   build/app/outputs/flutter-apk/app-debug.apk"
echo "   Release: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "📁 App Bundle:"
echo "   build/app/outputs/bundle/release/app-release.aab"
echo ""

# Подписать APK (если есть keystore)
if [ -f "../../android-keystore.jks" ]; then
    echo "🔐 Signing APK..."
    # jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 \
    #     -keystore ../../android-keystore.jks \
    #     -storepass YOUR_PASSWORD \
    #     build/app/outputs/flutter-apk/app-release.apk \
    #     libertyreach
fi
```

#### Шаг 4: Запуск на устройстве

```bash
# Включить USB Debugging на телефоне
# Подключить телефон к компьютеру

# Проверить устройства
flutter devices

# Запустить
flutter run

# Или установить APK
adb install mobile/flutter/build/app/outputs/flutter-apk/app-release.apk
```

### Вариант B: Нативный Android (Kotlin)

Создай `mobile/android-native/`:

```
mobile/android-native/
├── app/
│   ├── src/
│   │   └── main/
│   │       ├── java/internal/libertyreach/
│   │       │   ├── MainActivity.kt
│   │       │   ├── CryptoManager.kt
│   │       │   └── NetworkManager.kt
│   │       └── res/
│   ├── build.gradle
│   └── proguard-rules.pro
├── build.gradle
└── settings.gradle
```

`MainActivity.kt`:

```kotlin
package internal.libertyreach

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.webkit.WebViewCompat
import android.webkit.WebView
import android.webkit.WebViewClient

class MainActivity : AppCompatActivity() {
    
    private lateinit var webView: WebView
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        webView = WebView(this)
        setContentView(webView)
        
        // Настройки WebView
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = true
            allowContentAccess = true
            mixedContentMode = WebView.MIXED_CONTENT_ALWAYS_ALLOW
        }
        
        webView.webViewClient = WebViewClient()
        
        // Загрузить Web версию с Cloudflare
        webView.loadUrl("https://liberty-reach-messenger.pages.dev")
    }
    
    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }
}
```

`build.gradle` (app):

```gradle
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}

android {
    namespace 'internal.libertyreach'
    compileSdk 34

    defaultConfig {
        applicationId "internal.libertyreach.messenger"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "0.3.0"
    }

    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.webkit:webkit:1.8.0'
    implementation 'com.google.android.material:material:1.11.0'
}
```

---

## 🔄 ЧАСТЬ 3: CI/CD ДЛЯ ANDROID

### GitHub Actions для Android APK

Создай `.github/workflows/build-android.yml`:

```yaml
name: Build Android APK

on:
  push:
    tags:
      - 'v*'
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'temurin'
          java-version: '17'
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'
      
      - name: Install dependencies
        run: |
          cd mobile/flutter
          flutter pub get
      
      - name: Build APK
        run: |
          cd mobile/flutter
          flutter build apk --release
      
      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: app-release.apk
          path: mobile/flutter/build/app/outputs/flutter-apk/app-release.apk
      
      - name: Create Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: mobile/flutter/build/app/outputs/flutter-apk/app-release.apk
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 📊 ЧАСТЬ 4: СТРУКТУРА ПРОЕКТА

Обнови структуру:

```
liberty-reach-messenger/
├── .github/
│   └── workflows/
│       ├── deploy-web.yml      # ✅ Web деплой
│       └── build-android.yml   # ✅ Android билд
├── web/                        # ✅ Web версия
│   ├── index.html
│   ├── manifest.json
│   ├── build.sh
│   └── dist/
├── mobile/
│   ├── flutter/                # ✅ Кроссплатформенный
│   │   ├── lib/
│   │   ├── android/
│   │   ├── build-apk.sh
│   │   └── pubspec.yaml
│   └── android-native/         # ✅ Нативный Android
│       └── app/
├── cloudflare/                 # ✅ Backend
│   └── wrangler.toml
├── core/                       # ✅ Ядро
├── wallet/                     # ✅ Кошелек
└── README.md
```

---

## 🚀 ЧАСТЬ 5: БЫСТРЫЙ СТАРТ

### Web (Cloudflare Pages):

```bash
# 1. Создать репозиторий на GitHub
# 2. Запушить код
git push -u origin main

# 3. Подключить в Cloudflare Pages
# https://pages.cloudflare.com/

# 4. Автоматический деплой при каждом push!
# Web доступен по: https://liberty-reach-messenger.pages.dev
```

### Android (Flutter APK):

```bash
# 1. Перейти в директорию
cd mobile/flutter

# 2. Собрать APK
chmod +x build-apk.sh
./build-apk.sh

# 3. Установить на телефон
adb install build/app/outputs/flutter-apk/app-release.apk

# 4. Или скачать из GitHub Releases
# https://github.com/YOUR_USERNAME/liberty-reach-messenger/releases
```

---

## ✅ ЧЕКЛИСТ

### Web:
- [ ] Git репозиторий создан
- [ ] Код запушен
- [ ] Cloudflare Pages подключен
- [ ] Build настроен
- [ ] Web версия доступна
- [ ] GitHub Actions работает

### Android:
- [ ] Flutter установлен
- [ ] Android SDK настроен
- [ ] APK собирается
- [ ] Тест на устройстве пройден
- [ ] GitHub Actions для APK настроен

---

## 🔗 ПОЛЕЗНЫЕ ССЫЛКИ

- Cloudflare Pages: https://pages.cloudflare.com/
- GitHub Actions: https://github.com/features/actions
- Flutter Web: https://docs.flutter.dev/platform-integration/web
- Android Build: https://developer.android.com/studio/build

---

**ВСЁ ГОТОВО! Web через Cloudflare, Android через APK! 🚀**
