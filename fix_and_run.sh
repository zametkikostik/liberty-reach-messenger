#!/bin/bash

echo "🛠 Финальная калибровка Liberty Sovereign..."

# 1. Сбрасываем права
sudo chown -R $USER:$USER .

# 2. Очистка Docker
echo "🐳 Перезапуск контейнеров..."
docker-compose down

# 3. Сборка БЕЗ изменения Cargo.toml (мы его поправили руками выше)
echo "🚀 Сборка образа..."
docker-compose up -d --build

# 4. Проверка и запуск Ollama
echo "🧠 Проверка нейросети..."
# Ждем чуть дольше, чтобы контейнер точно успел создаться
for i in {1..5}; do
    if [ "$(docker ps -q -f name=ollama)" ]; then
        echo "✅ Ollama запущена. Тяну модель..."
        docker exec -it ollama ollama pull qwen2.5-coder:7b
        break
    fi
    echo "⏳ Жду запуска контейнера Ollama (попытка $i)..."
    sleep 3
done

echo "------------------------------------------------"
echo "📡 Подключение к эфиру..."
echo "------------------------------------------------"
docker-compose logs -f
