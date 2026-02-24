#!/bin/bash
# Запуск сервера Liberty Reach Messenger

echo "🚀 Liberty Reach Messenger Server"
echo "📡 Запуск на ws://localhost:8765"

cd "$(dirname "$0")"

# Проверка зависимостей
if ! python3 -c "import websockets" 2>/dev/null; then
    echo "⚠️ Установка зависимостей..."
    pip3 install websockets
fi

# Запуск сервера
python3 server/server.py
