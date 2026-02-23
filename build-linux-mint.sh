#!/bin/bash
# Liberty Reach - Сборка Linux Mint клиента
# Полная автоматическая сборка

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     🦅 Liberty Reach - Сборка Linux Mint клиента          ║"
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

cd /home/kostik/liberty-reach-messenger

# Проверка дистрибутива
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    echo -e "${GREEN}[*]${NC} Дистрибутив: $DISTRO $VERSION_ID"
else
    echo -e "${RED}[!] Не удалось определить дистрибутив${NC}"
    exit 1
fi

# Установка зависимостей
echo -e "${YELLOW}[*] Установка зависимостей...${NC}"

case $DISTRO in
    linuxmint|ubuntu|debian)
        sudo apt update
        
        # Основные зависимости
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
            libgstreamer-plugins-base1.0-dev \
            libopus-dev \
            ninja-build \
            || exit 1
        
        # Rust (если нет)
        if ! command -v rustc &> /dev/null; then
            echo -e "${YELLOW}[*] Установка Rust...${NC}"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source $HOME/.cargo/env
        fi
        
        ;;
    fedora)
        sudo dnf install -y \
            gcc gcc-c++ \
            cmake \
            git \
            curl \
            wget \
            curl-devel \
            openssl-devel \
            libsodium-devel \
            gtk3-devel \
            jsoncpp-devel \
            gstreamer1-devel \
            gstreamer1-plugins-base-devel \
            opus-devel \
            rust \
            cargo \
            || exit 1
        ;;
    *)
        echo -e "${YELLOW}[!] Неподдерживаемый дистрибутив: $DISTRO${NC}"
        echo -e "${YELLOW}   Попробуйте установить зависимости вручную${NC}"
        ;;
esac

echo -e "${GREEN}[✓] Зависимости установлены${NC}"
echo ""

# Сборка Rust ядра
echo -e "${YELLOW}[*] Сборка Rust крипто ядра...${NC}"
cd core/crypto
cargo build --release
cd ../..
echo -e "${GREEN}[✓] Rust ядро собрано${NC}"
echo ""

# Создание директории сборки
echo -e "${YELLOW}[*] Настройка CMake...${NC}"
mkdir -p build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTS=ON \
    -DBUILD_DESKTOP=ON \
    -DBUILD_CLI=ON \
    -G Ninja

echo -e "${GREEN}[✓] CMake настроен${NC}"
echo ""

# Компиляция
echo -e "${YELLOW}[*] Компиляция...${NC}"
ninja

cd ..

echo -e "${GREEN}[✓] Компиляция завершена${NC}"
echo ""

# Проверка бинарников
if [ -f "build/liberty_reach_desktop" ]; then
    echo -e "${GREEN}[✓] Desktop клиент собран!${NC}"
    echo "   Путь: build/liberty_reach_desktop"
    echo "   Размер: $(du -h build/liberty_reach_desktop | cut -f1)"
    echo ""
else
    echo -e "${RED}[!] Ошибка сборки Desktop клиента!${NC}"
    exit 1
fi

if [ -f "build/liberty_reach_cli" ]; then
    echo -e "${GREEN}[✓] CLI клиент собран!${NC}"
    echo "   Путь: build/liberty_reach_cli"
    echo "   Размер: $(du -h build/liberty_reach_cli | cut -f1)"
    echo ""
else
    echo -e "${RED}[!] Ошибка сборки CLI клиента!${NC}"
    exit 1
fi

# Создание скрипта установки
echo -e "${YELLOW}[*] Создание скрипта установки...${NC}"
cat > install.sh << 'EOF'
#!/bin/bash
# Liberty Reach - Установка в систему

INSTALL_DIR=${INSTALL_DIR:-/opt/liberty-reach}

echo "Установка Liberty Reach в $INSTALL_DIR..."

sudo mkdir -p $INSTALL_DIR
sudo cp -r build/liberty_reach_desktop $INSTALL_DIR/
sudo cp -r build/liberty_reach_cli $INSTALL_DIR/

# Копирование библиотек
sudo mkdir -p $INSTALL_DIR/lib
sudo cp -r build/lib*.so $INSTALL_DIR/lib/ 2>/dev/null || true

# Создание ссылок
sudo ln -sf $INSTALL_DIR/liberty_reach_desktop /usr/local/bin/liberty-reach
sudo ln -sf $INSTALL_DIR/liberty_reach_cli /usr/local/bin/liberty-reach-cli

# Создание .desktop файла
sudo cat > /usr/share/applications/liberty-reach.desktop << 'DESKTOP'
[Desktop Entry]
Name=Liberty Reach
Comment=Secure & Private Messenger
Exec=/opt/liberty-reach/liberty_reach_desktop
Icon=network-workgroup
Type=Application
Categories=Network;InstantMessaging;Chat;
Terminal=false
DESKTOP

echo ""
echo "✅ Установка завершена!"
echo ""
echo "Запуск:"
echo "   liberty-reach        # Desktop клиент"
echo "   liberty-reach-cli    # CLI клиент"
echo ""
EOF

chmod +x install.sh

echo -e "${GREEN}[✓] Скрипт установки создан${NC}"
echo ""

# Финальное сообщение
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                  ✅ ГОТОВО!                                ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "🖥️ Клиенты собраны:"
echo "   Desktop: build/liberty_reach_desktop ($(du -h build/liberty_reach_desktop | cut -f1))"
echo "   CLI:     build/liberty_reach_cli ($(du -h build/liberty_reach_cli | cut -f1))"
echo ""
echo "🚀 Запуск:"
echo "   ./build/liberty_reach_desktop    # Desktop версия"
echo "   ./build/liberty_reach_cli        # CLI версия"
echo ""
echo "📦 Установка в систему:"
echo "   sudo ./install.sh"
echo ""
echo "🧪 Тесты:"
echo "   cd build && ctest"
echo ""
