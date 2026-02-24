#!/bin/bash
# Запуск Desktop клиента Liberty Reach Messenger

echo "💬 Запуск Liberty Reach Desktop Client..."

cd "$(dirname "$0")"

# Проверка зависимостей
if ! python3 -c "import websockets" 2>/dev/null; then
    echo "⚠️ Установка зависимостей..."
    pip3 install websockets
fi

# Запуск клиента
python3 desktop/client.py
