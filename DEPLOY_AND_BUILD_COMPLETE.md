# 🚀 Liberty Reach - Полная Инструкция по Деплою и Сборке

**Версия**: 0.5.1  
**Дата**: 23 Февраля 2026

---

## 📋 СОДЕРЖАНИЕ

1. [Cloudflare FREE Deploy](#cloudflare-free-deploy)
2. [Сборка Android APK](#сборка-android-apk)
3. [Сборка Linux Desktop](#сборка-linux-desktop)
4. [Быстрый старт](#быстрый-старт)

---

## ☁️ CLOUDFLARE FREE DEPLOY

### Шаг 1: Установка Wrangler

```bash
# Установить Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Установить Wrangler
npm install -g wrangler

# Login
wrangler login
```

### Шаг 2: Создание ресурсов

```bash
cd /home/kostik/liberty-reach-messenger/cloudflare

# Создать KV namespace
wrangler kv:namespace create "CACHE_KV"
# Скопируй ID в wrangler.toml

# Создать R2 bucket
wrangler r2 bucket create liberty-reach-free-storage

# Создать Queue
wrangler queues create liberty-reach-messages
```

### Шаг 3: Настройка wrangler.toml

Обнови `cloudflare/wrangler.toml`:

```toml
name = "liberty-reach-messenger"
main = "src/worker.ts"
compatibility_date = "2024-01-01"

[[kv_namespaces]]
binding = "CACHE_KV"
id = "YOUR_KV_ID_HERE"  # Вставь ID из шага 2

[[r2_buckets]]
bucket_name = "liberty-reach-free-storage"
binding = "ENCRYPTED_STORAGE"

[[queues.producers]]
queue = "liberty-reach-messages"
binding = "MESSAGE_QUEUE"
```

### Шаг 4: Деплой

```bash
cd cloudflare
npm install

# Деплой на production
wrangler deploy --env production

# Проверка
curl https://liberty-reach-messenger-<your-subdomain>.workers.dev/health
```

### Шаг 5: Мониторинг

```bash
# Логи
wrangler tail --env production

# Метрики
wrangler metrics
```

**📖 Полная инструкция:** [CLOUDFLARE_FREE_DEPLOY_COMPLETE.md](CLOUDFLARE_FREE_DEPLOY_COMPLETE.md)

---

## 📱 СБОРКА ANDROID APK

### Быстрая сборка

```bash
cd /home/kostik/liberty-reach-messenger

# Запустить скрипт сборки
./mobile/flutter/build-apk.sh

# APK будут в корне проекта:
# - liberty-reach-debug.apk
# - liberty-reach-release.apk
```

### Ручная сборка

```bash
cd mobile/flutter

# Очистка
flutter clean

# Зависимости
flutter pub get

# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# APK находятся в:
# build/app/outputs/flutter-apk/
```

### Установка на устройство

```bash
# Через ADB
adb install build/app/outputs/flutter-apk/app-release.apk

# Или скопировать APK на телефон и установить вручную
```

### Автоматическая сборка через GitHub Actions

При пуше тега `v*` APK автоматически соберётся и загрузится в Releases!

```bash
# Создать тег
git tag v0.5.1
git push origin --tags

# GitHub Actions соберёт APK и создаст релиз
# https://github.com/zametkikostik/liberty-reach-messenger/releases
```

---

## 🐧 СБОРКА LINUX DESKTOP

### Быстрая сборка

```bash
cd /home/kostik/liberty-reach-messenger

# Запустить скрипт сборки
./build-linux.sh

# Клиент будет в:
# build/liberty_reach_desktop
```

### Ручная сборка

```bash
# Установить зависимости (Linux Mint/Ubuntu)
sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    libcurl4-openssl-dev \
    libssl-dev \
    libsodium-dev \
    libgtk-3-dev \
    libjsoncpp-dev \
    rustc \
    cargo

# Собрать Rust ядро
cd core/crypto
cargo build --release
cd ../..

# Собрать C++ проект
mkdir -p build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_DESKTOP=ON

make -j$(nproc)
cd ..

# Запустить
./build/liberty_reach_desktop
```

### Установка в систему

```bash
# После сборки
sudo ./install.sh

# Теперь можно запустить из меню или командой:
liberty-reach
```

---

## ⚡ БЫСТРЫЙ СТАРТ

### 1. Cloudflare (Web версия)

```bash
# 1. Login
wrangler login

# 2. Создать ресурсы
wrangler kv:namespace create "CACHE_KV"
wrangler r2 bucket create liberty-reach-free-storage

# 3. Деплой
cd cloudflare
npm install
wrangler deploy

# 4. Открыть в браузере
# https://liberty-reach-messenger-<subdomain>.workers.dev
```

### 2. Android APK

```bash
# Сборка
./mobile/flutter/build-apk.sh

# Установка
adb install liberty-reach-release.apk
```

### 3. Linux Desktop

```bash
# Сборка
./build-linux.sh

# Запуск
./build/liberty_reach_desktop
```

---

## 📊 ОЖИДАЕМАЯ ПРОИЗВОДИТЕЛЬНОСТЬ

### Cloudflare FREE:

```
✅ API ответы: < 50ms (с кэшем)
✅ WebSocket: realtime
✅ Очереди: < 1 секунда
✅ Кэш hit rate: > 80%
✅ Uptime: 99.9%
✅ Лимиты: 100K запросов/день
```

### Android APK:

```
✅ Размер APK: ~50MB
✅ Время сборки: 5-10 минут
✅ Поддержка: Android 5.0+
```

### Linux Desktop:

```
✅ Размер бинарника: ~20MB
✅ Время сборки: 10-15 минут
✅ Поддержка: Linux Mint/Ubuntu/Debian
```

---

## 🔗 ПОЛЕЗНЫЕ ССЫЛКИ

### Деплой:
- [Cloudflare FREE Deploy](CLOUDFLARE_FREE_DEPLOY_COMPLETE.md)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)
- [Cloudflare Limits](https://developers.cloudflare.com/workers/platform/limits/)

### Сборка:
- [Flutter Install](https://docs.flutter.dev/get-started/install/linux)
- [CMake Docs](https://cmake.org/documentation/)
- [Rust Install](https://www.rust-lang.org/tools/install)

### Репозиторий:
- [GitHub Releases](https://github.com/zametkikostik/liberty-reach-messenger/releases)
- [Web Version](https://liberty-reach-messenger.pages.dev)
- [Documentation](docs/)

---

## 🆘 ТРАБЛШУТИНГ

### Cloudflare падает:

```bash
# Проверить логи
wrangler tail --status error

# Проверить лимиты
wrangler metrics

# Если превышен лимит CPU:
# - Включить кэширование
# - Перенести долгие задачи в очереди
# - Уменьшить RATE_LIMIT в wrangler.toml
```

### APK не собирается:

```bash
# Проверить Flutter
flutter doctor

# Очистить кэш
flutter clean
flutter pub cache clean

# Пересобрать
flutter build apk --release
```

### Linux клиент не запускается:

```bash
# Проверить зависимости
ldd build/liberty_reach_desktop

# Установить недостающие
sudo apt install -y libgtk-3-0 libjsoncpp24
```

---

## ✅ ЧЕКЛИСТ

### Cloudflare:
- [ ] Wrangler установлен
- [ ] Login выполнен
- [ ] KV namespace создан
- [ ] R2 bucket создан
- [ ] Queue создана
- [ ] wrangler.toml настроен
- [ ] Деплой успешен
- [ ] Health check работает

### Android:
- [ ] Flutter установлен
- [ ] Android SDK настроен
- [ ] APK собран
- [ ] Тест на устройстве пройден

### Linux:
- [ ] Зависимости установлены
- [ ] Rust ядро собрано
- [ ] C++ проект собран
- [ ] Клиент запускается

---

**ВСЁ ГОТОВО! 🦅🚀**
