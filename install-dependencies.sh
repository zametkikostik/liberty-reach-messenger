#!/bin/bash
# Liberty Reach - Быстрая установка зависимостей
# Для Linux Mint

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🦅 Liberty Reach - Установка зависимостей                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Проверка прав
if [ "$EUID" -eq 0 ]; then 
    echo "[!] Не запускайте от root!"
    exit 1
fi

echo "[*] Обновление пакетов..."
sudo apt update

echo ""
echo "[*] Установка базовых зависимостей..."
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
    unzip \
    xz-utils

echo ""
echo "[*] Установка Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

echo ""
echo "[*] Установка Flutter..."
sudo snap install flutter --classic

echo ""
echo "[*] Проверка установки..."
rustc --version
cargo --version
flutter --version

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "                  ✅ ГОТОВО!                               "
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Теперь можешь запустить:"
echo "  ./build-apk-full.sh      # Сборка Android APK"
echo "  ./build-linux-mint.sh    # Сборка Linux клиента"
echo ""
