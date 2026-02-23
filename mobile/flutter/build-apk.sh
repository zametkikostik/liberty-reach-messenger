#!/bin/bash
# Liberty Reach - Build APK for Android
# Автоматическая сборка APK

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         🦅 Liberty Reach - Build Android APK              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}[!] Flutter не установлен!${NC}"
    echo ""
    echo "   Установить Flutter:"
    echo "   sudo snap install flutter --classic"
    echo ""
    exit 1
fi

# Navigate to Flutter project
cd mobile/flutter

echo -e "${GREEN}[*]${NC} Flutter version:"
flutter --version
echo ""

# Clean
echo -e "${YELLOW}[*] Очистка...${NC}"
flutter clean
echo ""

# Get dependencies
echo -e "${YELLOW}[*] Установка зависимостей...${NC}"
flutter pub get
echo ""

# Build Debug APK
echo -e "${YELLOW}[*] Сборка Debug APK...${NC}"
flutter build apk --debug --output=build/app/outputs/flutter-apk/app-debug.apk

if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    echo -e "${GREEN}[✓] Debug APK собран!${NC}"
    echo "   Путь: build/app/outputs/flutter-apk/app-debug.apk"
    echo ""
else
    echo -e "${RED}[!] Ошибка сборки Debug APK!${NC}"
    exit 1
fi

# Build Release APK
echo -e "${YELLOW}[*] Сборка Release APK...${NC}"
flutter build apk --release --output=build/app/outputs/flutter-apk/app-release.apk

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo -e "${GREEN}[✓] Release APK собран!${NC}"
    echo "   Путь: build/app/outputs/flutter-apk/app-release.apk"
    echo ""
else
    echo -e "${RED}[!] Ошибка сборки Release APK!${NC}"
    exit 1
fi

# Copy to project root
echo -e "${YELLOW}[*] Копирование APK в корень проекта...${NC}"
cp build/app/outputs/flutter-apk/app-debug.apk ../../liberty-reach-debug.apk
cp build/app/outputs/flutter-apk/app-release.apk ../../liberty-reach-release.apk
echo -e "${GREEN}[✓] APK скопированы!${NC}"
echo ""

# Show file sizes
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                  ✅ ГОТОВО!                                ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "📱 APK файлы:"
echo "   Debug:   ../../liberty-reach-debug.apk ($(du -h ../../liberty-reach-debug.apk | cut -f1))"
echo "   Release: ../../liberty-reach-release.apk ($(du -h ../../liberty-reach-release.apk | cut -f1))"
echo ""
echo "🚀 Установка на устройство:"
echo "   adb install ../../liberty-reach-release.apk"
echo ""
echo "📥 Скачать из GitHub Releases:"
echo "   https://github.com/zametkikostik/liberty-reach-messenger/releases"
echo ""
