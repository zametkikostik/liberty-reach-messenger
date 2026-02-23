#!/bin/bash
# Liberty Reach - Установка Flutter и сборка APK
# Для Linux Mint/Ubuntu

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🦅 Liberty Reach - Установка Flutter и сборка APK        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Проверка прав
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}[!] Не запускайте от root!${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] Проверка зависимостей...${NC}"

# Проверка наличия snap
if ! command -v snap &> /dev/null; then
    echo -e "${YELLOW}[!] snap не установлен. Установка...${NC}"
    sudo apt update
    sudo apt install -y snapd
    sudo systemctl enable snapd
    sudo systemctl start snapd
fi

# Установка Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${YELLOW}[*] Установка Flutter...${NC}"
    sudo snap install flutter --classic
    echo -e "${GREEN}[✓] Flutter установлен${NC}"
else
    echo -e "${GREEN}[✓] Flutter уже установлен${NC}"
fi

# Проверка версии
flutter --version
echo ""

# Установка Android SDK (если нет)
if [ ! -d "$HOME/Android/Sdk" ]; then
    echo -e "${YELLOW}[*] Установка Android SDK...${NC}"
    
    mkdir -p $HOME/Android/Sdk
    cd $HOME/Android
    
    # Скачать command-line tools
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip -O cmdline-tools.zip
    unzip -q cmdline-tools.zip
    mkdir -p cmdline-tools/latest
    mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
    
    # Настроить переменные окружения
    echo 'export ANDROID_HOME=$HOME/Android/Sdk' >> ~/.bashrc
    echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools' >> ~/.bashrc
    source ~/.bashrc
    
    # Принять лицензии и установить компоненты
    yes | cmdline-tools/latest/bin/sdkmanager --licenses
    cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
    
    echo -e "${GREEN}[✓] Android SDK установлен${NC}"
    echo ""
else
    echo -e "${GREEN}[✓] Android SDK уже установлен${NC}"
fi

# Перейти в проект Flutter
cd /home/kostik/liberty-reach-messenger/mobile/flutter

echo -e "${YELLOW}[*] Настройка Flutter...${NC}"
flutter config --android-sdk $HOME/Android/Sdk
flutter doctor -v
echo ""

echo -e "${YELLOW}[*] Очистка...${NC}"
flutter clean
echo ""

echo -e "${YELLOW}[*] Установка зависимостей...${NC}"
flutter pub get
echo ""

echo -e "${YELLOW}[*] Сборка Debug APK...${NC}"
flutter build apk --debug

if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    echo -e "${GREEN}[✓] Debug APK собран!${NC}"
    cp build/app/outputs/flutter-apk/app-debug.apk ../../liberty-reach-debug.apk
    echo "   Путь: ../../liberty-reach-debug.apk"
    echo "   Размер: $(du -h ../../liberty-reach-debug.apk | cut -f1)"
    echo ""
else
    echo -e "${RED}[!] Ошибка сборки Debug APK!${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] Сборка Release APK...${NC}"
flutter build apk --release

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo -e "${GREEN}[✓] Release APK собран!${NC}"
    cp build/app/outputs/flutter-apk/app-release.apk ../../liberty-reach-release.apk
    echo "   Путь: ../../liberty-reach-release.apk"
    echo "   Размер: $(du -h ../../liberty-reach-release.apk | cut -f1)"
    echo ""
else
    echo -e "${RED}[!] Ошибка сборки Release APK!${NC}"
    exit 1
fi

echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                  ✅ ГОТОВО!                                ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "📱 APK файлы:"
echo "   Debug:   /home/kostik/liberty-reach-messenger/liberty-reach-debug.apk"
echo "   Release: /home/kostik/liberty-reach-messenger/liberty-reach-release.apk"
echo ""
echo "🚀 Установка на устройство:"
echo "   adb install liberty-reach-release.apk"
echo ""
echo "📥 Скачать из GitHub:"
echo "   https://github.com/zametkikostik/liberty-reach-messenger/releases"
echo ""
