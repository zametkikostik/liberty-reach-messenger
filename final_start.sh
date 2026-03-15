#!/bin/bash
echo "🚀 Запуск Liberty Sovereign: Полная интеграция..."

# 1. Исправляем права и чистим Cargo.toml от дублей
sudo chown -R $USER:$USER .
if [ -f "Cargo.toml" ]; then
    echo "📦 Чистка зависимостей в Cargo.toml..."
    # Удаляем все строки с упоминанием serde, чтобы не было дубликатов
    sed -i '/serde =/d' Cargo.toml
    # Добавляем одну корректную строку в секцию зависимостей
    sed -i '/\[dependencies\]/a serde = { version = "1.0", features = ["derive"] }' Cargo.toml
fi

# 2. Перезапуск инфраструктуры
echo "🐳 Перезагрузка Docker..."
docker-compose down
docker-compose up -d --build

# 3. Умное ожидание Ollama
echo "⏳ Ждем пробуждения ИИ..."
until docker exec ollama ollama list >/dev/null 2>&1; do
  echo -n "."
  sleep 2
done
echo -e "\n✅ Ollama готова!"

# 4. Проверка модели Qwen
echo "🧠 Проверка модели Qwen..."
docker exec -it ollama ollama pull qwen2.5-coder:7b

echo "------------------------------------------------"
echo "📡 Все системы в норме. Вывожу эфир мессенджера:"
echo "------------------------------------------------"

# Пробуем подключиться к логам. Сначала проверяем имя 'messenger', если нет - 'messenger_core'
docker-compose logs -f messenger || docker-compose logs -f messenger_core
