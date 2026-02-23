#!/bin/bash
# Liberty Reach - Build Linux Desktop Client
# Автоматическая сборка для Linux Mint/Ubuntu/Debian

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║      🦅 Liberty Reach - Build Linux Desktop Client        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}[!] Моля не стартирайте като root!${NC}"
    exit 1
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo -e "${RED}[!] Не може да се определи дистрибуцията${NC}"
    exit 1
fi

echo -e "${GREEN}[*]${NC} Дистрибуция: $DISTRO"
echo ""

# Install dependencies
echo -e "${YELLOW}[*] Инсталиране на зависимости...${NC}"

case $DISTRO in
    ubuntu|debian|linuxmint)
        sudo apt update
        sudo apt install -y \
            build-essential \
            cmake \
            git \
            libcurl4-openssl-dev \
            libssl-dev \
            libsodium-dev \
            libgtk-3-dev \
            libjsoncpp-dev \
            libgstreamer1.0-dev \
            libgstreamer-plugins-base1.0-dev \
            libopus-dev \
            rustc \
            cargo \
            || exit 1
        ;;
    fedora)
        sudo dnf install -y \
            gcc gcc-c++ \
            cmake \
            git \
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
    arch|manjaro)
        sudo pacman -S --noconfirm \
            base-devel \
            cmake \
            git \
            curl \
            openssl \
            libsodium \
            gtk3 \
            jsoncpp \
            gstreamer \
            gst-plugins-base \
            opus \
            rust \
            cargo \
            || exit 1
        ;;
    *)
        echo -e "${YELLOW}[!] Неподдържана дистрибуция: $DISTRO${NC}"
        echo -e "${YELLOW}   Моля инсталирайте зависимостите ръчно${NC}"
        ;;
esac

echo -e "${GREEN}[✓] Зависимостите са инсталирани${NC}"
echo ""

# Build Rust crypto core
echo -e "${YELLOW}[*] Сглобяване на Rust крипто ядро...${NC}"
cd core/crypto
cargo build --release
cd ../..
echo -e "${GREEN}[✓] Rust крипто ядро сглобено${NC}"
echo ""

# Build C++ project
echo -e "${YELLOW}[*] Сглобяване на C++ проект...${NC}"
mkdir -p build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTS=ON \
    -DBUILD_DESKTOP=ON \
    -DBUILD_CLI=ON

make -j$(nproc)

cd ..

echo -e "${GREEN}[✓] C++ проект сглобен${NC}"
echo ""

# Create installation script
echo -e "${YELLOW}[*] Създаване на инсталационен скрипт...${NC}"
cat > install.sh << 'EOF'
#!/bin/bash
# Liberty Reach - Installation Script

INSTALL_DIR=${INSTALL_DIR:-/opt/liberty-reach}

echo "Installing Liberty Reach to $INSTALL_DIR..."

sudo mkdir -p $INSTALL_DIR
sudo cp -r build/liberty_reach_desktop $INSTALL_DIR/
sudo cp -r build/liberty_reach_cli $INSTALL_DIR/
sudo cp -r build/lib*.so $INSTALL_DIR/ 2>/dev/null || true

# Create symlinks
sudo ln -sf $INSTALL_DIR/liberty_reach_desktop /usr/local/bin/liberty-reach
sudo ln -sf $INSTALL_DIR/liberty_reach_cli /usr/local/bin/liberty-reach-cli

# Create desktop file
sudo cat > /usr/share/applications/liberty-reach.desktop << 'DESKTOP'
[Desktop Entry]
Name=Liberty Reach
Comment=Secure & Private Messenger
Exec=/opt/liberty-reach/liberty_reach_desktop
Icon=liberty-reach
Type=Application
Categories=Network;InstantMessaging;
DESKTOP

echo "Installation complete!"
echo ""
echo "Run 'liberty-reach' for desktop client"
echo "Run 'liberty-reach-cli' for CLI client"
EOF

chmod +x install.sh

echo -e "${GREEN}[✓] Инсталационен скрипт създаден${NC}"
echo ""

# Show summary
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                  ✅ ГОТОВО!                                ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "🖥️ Стартиране:"
echo "   Desktop: ./build/liberty_reach_desktop"
echo "   CLI:     ./build/liberty_reach_cli"
echo ""
echo "📦 Инсталация:"
echo "   sudo ./install.sh"
echo ""
echo "🧪 Тестове:"
echo "   cd build && ctest"
echo ""
