# 🚀 Liberty Reach - Бърз Старт

## За Linux Mint/Ubuntu/Debian

### 1. Инсталиране на зависимости

```bash
# Update
sudo apt update

# Install dependencies
sudo apt install -y \
    build-essential \
    cmake \
    git \
    libssl-dev \
    libsodium-dev \
    libgtk-3-dev \
    libjsoncpp-dev \
    libgstreamer1.0-dev \
    libopus-dev \
    rustc \
    cargo \
    nodejs \
    npm
```

### 2. Сглобяване

```bash
# Navigate to project
cd liberty-reach-messenger

# Run build script
./build.sh

# Wait for build to complete (5-10 minutes)
```

### 3. Стартиране

```bash
# Desktop клиент
./build/liberty_reach_desktop

# CLI клиент
./build/liberty_reach_cli

# Тестове
cd build && ctest
```

### 4. Инсталация (опционално)

```bash
# Install to /opt/liberty-reach
sudo ./install.sh

# Сега можете да стартирате от всякъде
liberty-reach        # Desktop
liberty-reach-cli    # CLI
```

---

## За Android

### Изисквания
- Android Studio Arctic Fox или по-нов
- Android SDK 30+
- Android NDK 25+

### Сглобяване

```bash
cd mobile/android
./gradlew assembleDebug

# APK файлът ще бъде в:
# app/build/outputs/apk/debug/app-debug.apk
```

### Инсталиране на устройство

```bash
# Чрез ADB
adb install app/build/outputs/apk/debug/app-debug.apk

# Или копирайте APK на устройството и инсталирайте ръчно
```

---

## За Cloudflare Worker

### Инсталиране

```bash
cd cloudflare
npm install
```

### Деплой

```bash
# Login to Cloudflare
npx wrangler login

# Deploy
npx wrangler deploy

# Dev mode
npx wrangler dev
```

---

## Тестване

### Crypto тестове

```bash
cd build
./crypto_tests
```

### VoIP тестове

```bash
cd build
./voip_tests
```

### Mesh тестове

```bash
cd build
./mesh_tests
```

---

## Команди (CLI)

```bash
# Стартиране
liberty-reach-cli

# Команди:
/help              - Помощ
/profile           - Инфо за профила
/send <текст>      - Изпрати съобщение
/mesh              - Mesh статус
/encrypt <текст>   - Тест криптиране
/quit              - Изход
```

---

## Структура на проекта

```
liberty-reach-messenger/
├── core/               # Крипто ядро (Rust + C++)
├── cloudflare/         # Cloudflare Worker
├── mobile/
│   ├── flutter/       # Flutter UI
│   └── android/       # Native Android
├── desktop/           # Linux Desktop клиент
├── cli/               # CLI клиент
├── webrtc/            # VoIP модул
├── mesh/              # Mesh мрежа
├── tests/             # Тестове
└── build.sh           # Build скрипт
```

---

## Често срещани проблеми

### Грешка при сглобяване на Rust

```bash
# Update Rust
rustup update

# Clean and rebuild
cd core/crypto
cargo clean
cargo build --release
```

### Грешка с GTK3

```bash
# Install GTK3 dev packages
sudo apt install libgtk-3-dev
```

### VoIP не работи

```bash
# Install GStreamer plugins
sudo apt install \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly
```

---

## Контакти и Поддръжка

- **Website**: https://libertyreach.internal
- **Email**: dev@libertyreach.internal
- **Docs**: /docs/

---

## Лиценз

MIT License

🦅🇧🇬 Liberty Reach - Свобода достигайки всеки
