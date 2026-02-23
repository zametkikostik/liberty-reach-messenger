#!/bin/bash
# Liberty Reach - Установка с sudo паролем
# Автоматический ввод пароля

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🦅 Liberty Reach - Установка зависимостей                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Запрос пароля один раз
echo "[*] Введите sudo пароль:"
read -s SUDO_PASSWORD
echo ""

export SUDO_PASSWORD

# Функция для выполнения sudo команд
run_sudo() {
    echo "$SUDO_PASSWORD" | sudo -S "$@"
}

echo "[*] Обновление пакетов..."
run_sudo apt update

echo "[*] Установка базовых зависимостей..."
run_sudo apt install -y \
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
    zip

echo "[*] Установка Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

echo "[*] Установка Flutter..."
if ! command -v snap &> /dev/null; then
    run_sudo apt install -y snapd
    sudo systemctl enable snapd
    sudo systemctl start snapd
fi

run_sudo snap install flutter --classic

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "                  ✅ ГОТОВО!                               "
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Теперь запусти:"
echo "  ./build-no-sudo.sh"
echo ""
