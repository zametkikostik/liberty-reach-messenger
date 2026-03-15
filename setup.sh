#!/bin/bash
echo "🚀 Запуск Liberty Sovereign с мозгами Qwen..."

# 1. Останавливаем старое и собираем новое
docker-compose down
docker-compose up -d --build

# 2. Небольшая пауза, чтобы Ollama успела инициализироваться
echo "⏳ Ждем инициализации Ollama..."
sleep 5

# 3. Проверяем модель в контейнере
echo "🤖 Проверка модели Qwen..."
if docker exec -it ollama ollama list | grep -q "qwen2.5-coder:7b"; then
    echo "✅ Модель на месте."
else
    echo "📥 Модель не найдена. Начинаю быструю загрузку..."
    docker exec -it ollama ollama pull qwen2.5-coder:7b
fi

echo "✅ Все системы запущены!"
echo "📡 Подключаюсь к логам (нажми Ctrl+C, чтобы выйти из логов, но оставить ноду работать)..."
echo "------------------------------------------------"

# 4. Захват логов в файл и вывод на экран
docker-compose logs -f messenger_core | tee sovereign.log
