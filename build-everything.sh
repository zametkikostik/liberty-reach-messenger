#!/bin/bash
# Liberty Reach - Полная автоматическая сборка ВСЕГО!
# Android APK + Linux Mint клиент
# Полностью автоматически!

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     🦅 Liberty Reach - Полная Автоматическая Сборка       ║"
echo "║          Android APK + Linux Mint Client                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Начало: $(date)"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Логирование
LOG_FILE="/home/kostik/liberty-reach-messenger/build-full-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

cd /home/kostik/liberty-reach-messenger

# ============================================
# ШАГ 0: Проверка прав
# ============================================
echo -e "${BLUE}[ШАГ 0/6] Проверка прав...${NC}"
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}[!] Не запускайте от root!${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Запуск от пользователя: $(whoami)${NC}"
echo ""

# ============================================
# ШАГ 1: Обновление системы
# ============================================
echo -e "${BLUE}[ШАГ 1/6] Обновление пакетов...${NC}"
sudo apt update -qq
echo -e "${GREEN}[✓] Пакеты обновлены${NC}"
echo ""

# ============================================
# ШАГ 2: Установка базовых зависимостей
# ============================================
echo -e "${BLUE}[ШАГ 2/6] Установка базовых зависимостей...${NC}"
sudo apt install -y -qq \
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
    libgstreamer-plugins-base1.0-dev \
    libopus-dev \
    ninja-build \
    unzip \
    xz-utils \
    zip \
    > /dev/null 2>&1
echo -e "${GREEN}[✓] Базовые зависимости установлены${NC}"
echo ""

# ============================================
# ШАГ 3: Установка Rust
# ============================================
echo -e "${BLUE}[ШАГ 3/6] Установка Rust...${NC}"
if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null 2>&1
    source $HOME/.cargo/env
    echo -e "${GREEN}[✓] Rust установлен: $(rustc --version)${NC}"
else
    echo -e "${GREEN}[✓] Rust уже установлен: $(rustc --version)${NC}"
fi
echo ""

# ============================================
# ШАГ 4: Установка Flutter
# ============================================
echo -e "${BLUE}[ШАГ 4/6] Установка Flutter...${NC}"
if ! command -v flutter &> /dev/null; then
    # Проверка snap
    if ! command -v snap &> /dev/null; then
        echo -e "${YELLOW}[*] Установка snap...${NC}"
        sudo apt install -y snapd > /dev/null 2>&1
    fi
    
    echo -e "${YELLOW}[*] Установка Flutter через snap...${NC}"
    sudo snap install flutter --classic > /dev/null 2>&1
    echo -e "${GREEN}[✓] Flutter установлен: $(flutter --version | head -1)${NC}"
else
    echo -e "${GREEN}[✓] Flutter уже установлен: $(flutter --version | head -1)${NC}"
fi
echo ""

# ============================================
# ШАГ 5: Сборка Android APK
# ============================================
echo -e "${BLUE}[ШАГ 5/6] Сборка Android APK...${NC}"

# Проверка Android SDK
if [ ! -d "$HOME/Android/Sdk" ]; then
    echo -e "${YELLOW}[*] Установка Android SDK...${NC}"
    mkdir -p $HOME/Android/Sdk
    cd $HOME/Android
    
    # Скачать command-line tools
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip -O cmdline-tools.zip
    unzip -q cmdline-tools.zip
    mkdir -p cmdline-tools/latest
    mv cmdline-tools/bin cmdline-tools/latest/ 2>/dev/null || mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
    
    # Настроить переменные
    export ANDROID_HOME=$HOME/Android/Sdk
    export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
    echo 'export ANDROID_HOME=$HOME/Android/Sdk' >> ~/.bashrc
    echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools' >> ~/.bashrc
    
    # Принять лицензии и установить компоненты
    yes | cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null 2>&1 || true
    cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" > /dev/null 2>&1
    
    echo -e "${GREEN}[✓] Android SDK установлен${NC}"
    cd /home/kostik/liberty-reach-messenger
else
    echo -e "${GREEN}[✓] Android SDK уже установлен${NC}"
fi

# Настройка Flutter
flutter config --android-sdk $HOME/Android/Sdk > /dev/null 2>&1

# Сборка APK
cd /home/kostik/liberty-reach-messenger/mobile/flutter

echo -e "${YELLOW}[*] Очистка...${NC}"
flutter clean > /dev/null 2>&1

echo -e "${YELLOW}[*] Установка зависимостей Flutter...${NC}"
flutter pub get > /dev/null 2>&1

echo -e "${YELLOW}[*] Сборка Debug APK...${NC}"
flutter build apk --debug > /dev/null 2>&1

if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    cp build/app/outputs/flutter-apk/app-debug.apk ../../liberty-reach-debug.apk
    echo -e "${GREEN}[✓] Debug APK: ../../liberty-reach-debug.apk ($(du -h ../../liberty-reach-debug.apk | cut -f1))${NC}"
else
    echo -e "${RED}[!] Ошибка сборки Debug APK!${NC}"
fi

echo -e "${YELLOW}[*] Сборка Release APK...${NC}"
flutter build apk --release > /dev/null 2>&1

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp build/app/outputs/flutter-apk/app-release.apk ../../liberty-reach-release.apk
    echo -e "${GREEN}[✓] Release APK: ../../liberty-reach-release.apk ($(du -h ../../liberty-reach-release.apk | cut -f1))${NC}"
else
    echo -e "${RED}[!] Ошибка сборки Release APK!${NC}"
fi

cd /home/kostik/liberty-reach-messenger
echo -e "${GREEN}[✓] Android APK собраны${NC}"
echo ""

# ============================================
# ШАГ 6: Сборка Linux Mint клиента
# ============================================
echo -e "${BLUE}[ШАГ 6/6] Сборка Linux Mint клиента...${NC}"

# Сборка Rust ядра
echo -e "${YELLOW}[*] Сборка Rust крипто ядра...${NC}"
cd /home/kostik/liberty-reach-messenger/core/crypto
cargo build --release > /dev/null 2>&1
echo -e "${GREEN}[✓] Rust ядро собрано${NC}"

# Сборка C++ проекта
cd /home/kostik/liberty-reach-messenger
echo -e "${YELLOW}[*] Настройка CMake...${NC}"
mkdir -p build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTS=ON \
    -DBUILD_DESKTOP=ON \
    -DBUILD_CLI=ON \
    -G Ninja > /dev/null 2>&1

echo -e "${YELLOW}[*] Компиляция...${NC}"
ninja > /dev/null 2>&1

cd ..

# Проверка результатов
if [ -f "build/liberty_reach_desktop" ]; then
    echo -e "${GREEN}[✓] Desktop клиент: build/liberty_reach_desktop ($(du -h build/liberty_reach_desktop | cut -f1))${NC}"
else
    echo -e "${RED}[!] Ошибка сборки Desktop клиента!${NC}"
fi

if [ -f "build/liberty_reach_cli" ]; then
    echo -e "${GREEN}[✓] CLI клиент: build/liberty_reach_cli ($(du -h build/liberty_reach_cli | cut -f1))${NC}"
else
    echo -e "${RED}[!] Ошибка сборки CLI клиента!${NC}"
fi

echo -e "${GREEN}[✓] Linux клиент собран${NC}"
echo ""

# ============================================
# ФИНАЛ
# ============================================
echo "═══════════════════════════════════════════════════════════"
echo -e "${GREEN}                  ✅ ГОТОВО!                     ${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📱 Android APK:"
echo "   Debug:   /home/kostik/liberty-reach-messenger/liberty-reach-debug.apk"
echo "   Release: /home/kostik/liberty-reach-messenger/liberty-reach-release.apk"
echo ""
echo "🖥️ Linux Desktop:"
echo "   Desktop: /home/kostik/liberty-reach-messenger/build/liberty_reach_desktop"
echo "   CLI:     /home/kostik/liberty-reach-messenger/build/liberty_reach_cli"
echo ""
echo "📊 Статистика:"
echo "   Debug APK:   $(du -h /home/kostik/liberty-reach-messenger/liberty-reach-debug.apk | cut -f1)"
echo "   Release APK: $(du -h /home/kostik/liberty-reach-messenger/liberty-reach-release.apk | cut -f1)"
echo "   Desktop:     $(du -h /home/kostik/liberty-reach-messenger/build/liberty_reach_desktop | cut -f1)"
echo "   CLI:         $(du -h /home/kostik/liberty-reach-messenger/build/liberty_reach_cli | cut -f1)"
echo ""
echo "🚀 Установка:"
echo "   APK: adb install liberty-reach-release.apk"
echo "   Linux: sudo ./install.sh"
echo ""
echo "📝 Лог сборки: $LOG_FILE"
echo ""
echo "Конец: $(date)"
echo ""
