#!/bin/bash
# Liberty Reach Messenger - Build Script
# За Linux Mint/Debian/Ubuntu

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         🦅 Liberty Reach - Build Script                   ║"
echo "║         Версия 0.1.0                                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Моля не стартирайте като root!"
    exit 1
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    print_error "Не може да се определи дистрибуцията"
    exit 1
fi

print_status "Дистрибуция: $DISTRO"

# Install dependencies
print_status "Инсталиране на зависимости..."

case $DISTRO in
    ubuntu|debian|linuxmint)
        sudo apt update
        sudo apt install -y \
            build-essential \
            cmake \
            git \
            libssl-dev \
            libsodium-dev \
            libblake3-dev \
            libgtk-3-dev \
            libjsoncpp-dev \
            libgstreamer1.0-dev \
            libgstreamer-plugins-base1.0-dev \
            libopus-dev \
            rustc \
            cargo \
            nodejs \
            npm \
            flutter \
            || exit 1
        ;;
    fedora)
        sudo dnf install -y \
            gcc gcc-c++ \
            cmake \
            git \
            openssl-devel \
            libsodium-devel \
            gtk3-devel \
            jsoncpp-devel \
            gstreamer1-devel \
            gstreamer1-plugins-base-devel \
            opus-devel \
            rust \
            cargo \
            nodejs \
            npm \
            || exit 1
        ;;
    arch|manjaro)
        sudo pacman -S --noconfirm \
            base-devel \
            cmake \
            git \
            openssl \
            libsodium \
            gtk3 \
            jsoncpp \
            gstreamer \
            gst-plugins-base \
            opus \
            rust \
            cargo \
            nodejs \
            npm \
            || exit 1
        ;;
    *)
        print_warning "Неподдържана дистрибуция: $DISTRO"
        print_warning "Моля инсталирайте зависимостите ръчно"
        ;;
esac

# Build Rust crypto core
print_status "Сглобяване на Rust крипто ядро..."
cd core/crypto
cargo build --release
cd ../..

# Build C++ project
print_status "Сглобяване на C++ проект..."
mkdir -p build
cd build
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTS=ON \
    -DBUILD_DESKTOP=ON \
    -DBUILD_CLI=ON
make -j$(nproc)
cd ..

# Build Cloudflare Worker
print_status "Сглобяване на Cloudflare Worker..."
cd cloudflare
npm install
npm run build
cd ..

# Run tests
print_status "Стартиране на тестове..."
cd build
ctest --output-on-failure
cd ..

# Create installation script
print_status "Създаване на инсталационен скрипт..."
cat > install.sh << 'EOF'
#!/bin/bash
# Installation script

INSTALL_DIR=${INSTALL_DIR:-/opt/liberty-reach}

echo "Installing Liberty Reach to $INSTALL_DIR..."

sudo mkdir -p $INSTALL_DIR
sudo cp -r build/liberty_reach_desktop $INSTALL_DIR/
sudo cp -r build/liberty_reach_cli $INSTALL_DIR/
sudo cp -r build/lib*.so $INSTALL_DIR/ 2>/dev/null || true

# Create symlinks
sudo ln -sf $INSTALL_DIR/liberty_reach_desktop /usr/local/bin/liberty-reach
sudo ln -sf $INSTALL_DIR/liberty_reach_cli /usr/local/bin/liberty-reach-cli

echo "Installation complete!"
echo "Run 'liberty-reach' for desktop client"
echo "Run 'liberty-reach-cli' for CLI client"
EOF

chmod +x install.sh

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              ✓ Build Complete!                            ║"
echo "║                                                           ║"
echo "║  Стартиране:                                              ║"
echo "║    Desktop: ./build/liberty_reach_desktop                 ║"
echo "║    CLI:     ./build/liberty_reach_cli                     ║"
echo "║    Tests:   cd build && ctest                             ║"
echo "║                                                           ║"
echo "║  Инсталация:                                              ║"
echo "║    sudo ./install.sh                                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
