#!/bin/bash
# Liberty Reach - Сборка БЕЗ sudo
# Для уже настроенной системы

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🦅 Liberty Reach - Сборка (БЕЗ sudo)                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

cd /home/kostik/liberty-reach-messenger

# ============================================
# ПРОВЕРКА зависимостей
# ============================================
echo "[*] Проверка зависимостей..."
echo ""

MISSING_DEPS=()

# Проверка Rust
if ! command -v rustc &> /dev/null; then
    MISSING_DEPS+=("Rust")
    echo "❌ Rust не установлен"
else
    echo "✅ Rust: $(rustc --version)"
fi

# Проверка Flutter
if ! command -v flutter &> /dev/null; then
    MISSING_DEPS+=("Flutter")
    echo "❌ Flutter не установлен"
else
    echo "✅ Flutter: $(flutter --version | head -1)"
fi

# Проверка cmake
if ! command -v cmake &> /dev/null; then
    MISSING_DEPS+=("CMake")
    echo "❌ CMake не установлен"
else
    echo "✅ CMake: $(cmake --version | head -1)"
fi

# Проверка ninja
if ! command -v ninja &> /dev/null; then
    MISSING_DEPS+=("Ninja")
    echo "❌ Ninja не установлен"
else
    echo "✅ Ninja: $(ninja --version)"
fi

echo ""

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "⚠️  ОТСУТСТВУЮТ ЗАВИСИМОСТИ:"
    echo "═══════════════════════════════════════════════════════════"
    for dep in "${MISSING_DEPS[@]}"; do
        echo "  ❌ $dep"
    done
    echo ""
    echo "Установи их командой:"
    echo ""
    echo "  sudo ./install-dependencies.sh"
    echo ""
    echo "Или вручную:"
    echo ""
    echo "  # Rust"
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo ""
    echo "  # Flutter"
    echo "  sudo snap install flutter --classic"
    echo ""
    echo "  # Остальное"
    echo "  sudo apt install -y build-essential cmake ninja-build"
    echo ""
    exit 1
fi

echo "✅ Все зависимости установлены!"
echo ""

# ============================================
# СБОРКА Android APK
# ============================================
echo "═══════════════════════════════════════════════════════════"
echo "📱 СБОРКА ANDROID APK"
echo "═══════════════════════════════════════════════════════════"
echo ""

cd /home/kostik/liberty-reach-messenger/mobile/flutter

echo "[*] Очистка..."
flutter clean

echo "[*] Установка зависимостей..."
flutter pub get

echo "[*] Сборка Debug APK..."
flutter build apk --debug

if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    cp build/app/outputs/flutter-apk/app-debug.apk ../../liberty-reach-debug.apk
    echo "✅ Debug APK: ../../liberty-reach-debug.apk"
else
    echo "❌ Ошибка сборки Debug APK!"
    exit 1
fi

echo "[*] Сборка Release APK..."
flutter build apk --release

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp build/app/outputs/flutter-apk/app-release.apk ../../liberty-reach-release.apk
    echo "✅ Release APK: ../../liberty-reach-release.apk"
else
    echo "❌ Ошибка сборки Release APK!"
    exit 1
fi

cd /home/kostik/liberty-reach-messenger
echo ""

# ============================================
# СБОРКА Linux клиента
# ============================================
echo "═══════════════════════════════════════════════════════════"
echo "🖥️  СБОРКА LINUX КЛИЕНТА"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "[*] Сборка Rust ядра..."
cd core/crypto
cargo build --release
cd ../..

echo "[*] Настройка CMake..."
mkdir -p build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTS=ON \
    -DBUILD_DESKTOP=ON \
    -DBUILD_CLI=ON \
    -G Ninja

echo "[*] Компиляция..."
ninja

cd ..

echo ""

# ============================================
# ПРОВЕРКА результатов
# ============================================
echo "═══════════════════════════════════════════════════════════"
echo "✅ СБОРКА ЗАВЕРШЕНА!"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -f "liberty-reach-debug.apk" ]; then
    echo "📱 Debug APK:   liberty-reach-debug.apk ($(du -h liberty-reach-debug.apk | cut -f1))"
fi

if [ -f "liberty-reach-release.apk" ]; then
    echo "📱 Release APK: liberty-reach-release.apk ($(du -h liberty-reach-release.apk | cut -f1))"
fi

if [ -f "build/liberty_reach_desktop" ]; then
    echo "🖥️  Desktop:    build/liberty_reach_desktop ($(du -h build/liberty_reach_desktop | cut -f1))"
fi

if [ -f "build/liberty_reach_cli" ]; then
    echo "🖥️  CLI:        build/liberty_reach_cli ($(du -h build/liberty_reach_cli | cut -f1))"
fi

echo ""
echo "🚀 Установка:"
echo "   APK:  adb install liberty-reach-release.apk"
echo "   Linux: sudo ./install.sh"
echo ""
