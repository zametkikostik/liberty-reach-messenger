# 📦 Liberty Reach - Инструкция по Сборке

**Версия**: 0.5.3  
**Дата**: 23 Февраля 2026

---

## 🚀 БЫСТРЫЙ СТАРТ

### Сборка Android APK:

```bash
cd /home/kostik/liberty-reach-messenger
./build-apk-full.sh
```

### Сборка Linux Mint клиента:

```bash
cd /home/kostik/liberty-reach-messenger
./build-linux-mint.sh
```

---

## 📱 СБОРКА ANDROID APK

### Вариант 1: Автоматическая сборка (рекомендуется)

```bash
./build-apk-full.sh
```

**Что делает скрипт:**
1. ✅ Проверяет зависимости
2. ✅ Устанавливает Flutter (если нет)
3. ✅ Устанавливает Android SDK
4. ✅ Собирает Debug APK
5. ✅ Собирает Release APK

**Время сборки**: 15-30 минут (первый раз с установкой SDK)

**Результат:**
```
liberty-reach-debug.apk    (~50MB)
liberty-reach-release.apk  (~45MB)
```

### Вариант 2: Ручная сборка

```bash
# 1. Установить Flutter
sudo snap install flutter --classic

# 2. Настроить Android SDK
flutter config --android-sdk $HOME/Android/Sdk

# 3. Принять лицензии
flutter doctor --android-licenses

# 4. Собрать APK
cd mobile/flutter
flutter build apk --release
```

### Установка на устройство:

```bash
# Через USB
adb install liberty-reach-release.apk

# Или скопировать APK на телефон и установить вручную
```

---

## 🐧 СБОРКА LINUX MINT КЛИЕНТА

### Вариант 1: Автоматическая сборка (рекомендуется)

```bash
./build-linux-mint.sh
```

**Что делает скрипт:**
1. ✅ Проверяет дистрибутив
2. ✅ Устанавливает зависимости
3. ✅ Устанавливает Rust (если нет)
4. ✅ Собирает Rust крипто ядро
5. ✅ Настраивает CMake
6. ✅ Компилирует C++ код
7. ✅ Создаёт скрипт установки

**Время сборки**: 10-20 минут (первый раз с установкой зависимостей)

**Результат:**
```
build/liberty_reach_desktop  (~20MB)
build/liberty_reach_cli      (~5MB)
```

### Вариант 2: Ручная сборка

```bash
# 1. Установить зависимости (Linux Mint)
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

# 2. Собрать Rust ядро
cd core/crypto
cargo build --release
cd ../..

# 3. Собрать C++ проект
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
cd ..
```

### Установка в систему:

```bash
# После сборки
sudo ./install.sh

# Запуск из меню приложений или командой:
liberty-reach
```

---

## 📊 ТРЕБОВАНИЯ

### Для Android APK:

```
Операционная система: Linux Mint/Ubuntu 20.04+
RAM: 4GB минимум (8GB рекомендуется)
Диск: 5GB свободного места
```

### Для Linux Desktop:

```
Операционная система: Linux Mint 20+/Ubuntu 20.04+
RAM: 2GB минимум
Диск: 2GB свободного места
Зависимости: GTK3, libcurl, libsodium
```

---

## 🔧 ЗАВИСИМОСТИ

### Автоматическая установка:

```bash
# Для Android
./build-apk-full.sh  # Сам установит всё

# Для Linux Desktop
./build-linux-mint.sh  # Сам установит всё
```

### Ручная установка зависимостей:

```bash
# Linux Mint/Ubuntu
sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    git \
    curl \
    wget \
    libcurl4-openssl-dev \
    libssl-dev \
    libsodium-dev \
    libgtk-3-dev \
    libjsoncpp-dev \
    libgstreamer1.0-dev \
    rustc \
    cargo \
    snapd

# Flutter
sudo snap install flutter --classic
```

---

## 🧪 ТЕСТЫ

### После сборки:

```bash
# Запустить тесты
cd build
ctest

# Проверить Desktop клиент
./liberty_reach_desktop --version

# Проверить CLI клиент
./liberty_reach_cli --help
```

---

## 📦 РАСПРОСТРАНЕНИЕ

### GitHub Releases:

```bash
# Создать тег
git tag v0.5.3
git push origin --tags

# GitHub Actions автоматически:
# 1. Соберёт APK
# 2. Загрузит в Releases
# 3. Создаст релиз с описанием
```

### Локальное распространение:

```bash
# APK
cp liberty-reach-release.apk /path/to/share/

# Linux Desktop
tar -czf liberty-reach-linux.tar.gz build/liberty_reach_desktop build/liberty_reach_cli
```

---

## ⚠️ ВОЗМОЖНЫЕ ПРОБЛЕМЫ

### Flutter не устанавливается:

```bash
# Проверить snap
sudo systemctl status snapd

# Переустановить snap
sudo apt install --reinstall snapd
```

### Android SDK не находится:

```bash
# Проверить переменные окружения
echo $ANDROID_HOME

# Добавить в ~/.bashrc
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
source ~/.bashrc
```

### Ошибки компиляции C++:

```bash
# Очистить сборку
rm -rf build
mkdir build
cd build

# Пересобрать
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

### Не хватает памяти при сборке:

```bash
# Использовать меньше потоков
make -j2  # вместо make -j$(nproc)

# Или добавить swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

## 📊 ВРЕМЯ СБОРКИ

| Компонент | Первый раз | Повторно |
|-----------|------------|----------|
| Android APK | 15-30 мин | 5-10 мин |
| Linux Desktop | 10-20 мин | 3-5 мин |
| Полная сборка | 25-50 мин | 8-15 мин |

---

## ✅ ПРОВЕРКА РЕЗУЛЬТАТА

### APK:

```bash
# Проверить файл
ls -lh liberty-reach-release.apk

# Проверить версию
unzip -p liberty-reach-release.apk AndroidManifest.xml | grep versionName
```

### Linux Desktop:

```bash
# Проверить бинарник
file build/liberty_reach_desktop

# Проверить зависимости
ldd build/liberty_reach_desktop

# Запустить
./build/liberty_reach_desktop
```

---

## 📖 ДОПОЛНИТЕЛЬНАЯ ДОКУМЕНТАЦИЯ

- [Cloudflare Deploy](CLOUDFLARE_FREE_DEPLOY_COMPLETE.md)
- [Free Translation](docs/FREE_TRANSLATION.md)
- [Features](FEATURES.md)
- [Build Instructions](BUILD_INSTRUCTIONS.md)

---

**ВСЁ ГОТОВО К СБОРКЕ! 🦅🚀**
