#!/bin/bash

# --- НАСТРОЙКИ ---
PROJECT_DIR="/home/kostik/Рабочий стол/папка для программирования/liberty-sovereign"
CONTINUE_CONFIG="$HOME/.continue/config.json"
GEMINI_KEY="AIzaSyBvqfED6MwFBj-Bej6e6ubUepmC1bZJuIo"

echo "🚀 Запускаю инфраструктуру Liberty Sovereign..."
cd "$PROJECT_DIR" || exit

# 1. ПРОВЕРКА CONFIG.JSON (Авто-исправление для Continue)
echo "🔍 Проверка конфигурации расширения Continue..."
if [ -f "$CONTINUE_CONFIG" ]; then
    # Проверяем, правильная ли модель Gemini прописана
    if grep -q "gemini-2.0-pro-exp-02-05" "$CONTINUE_CONFIG"; then
        echo "✅ Конфиг Continue в порядке."
    else
        echo "⚠️  Обнаружена ошибка в модели Gemini. Исправляю..."
        # Заменяем старую модель на правильную
        sed -i 's/gemini-2.0-pro/gemini-2.0-pro-exp-02-05/g' "$CONTINUE_CONFIG"
        # На всякий случай фиксим провайдера
        sed -i 's/"provider": "gemini"/"provider": "google"/g' "$CONTINUE_CONFIG"
        echo "✨ Исправлено! Перезапусти VS Code, если будут ошибки."
    fi
else
    echo "❌ Файл config.json не найден по пути $CONTINUE_CONFIG"
fi

# 2. ЗАПУСК DOCKER
echo "🐳 Поднимаю контейнеры (Ollama + Rust Core)..."
docker compose up -d --build

# 3. ПРОВЕРКА МОДЕЛЕЙ (Фоновая загрузка)
echo "📦 Проверка наличия моделей в Ollama..."
# Функция для проверки и скачивания
check_model() {
    MODEL_NAME=$1
    echo "Проверяю $MODEL_NAME..."
    docker exec -it ollama ollama list | grep -q "$MODEL_NAME"
    if [ $? -ne 0 ]; then
        echo "📥 Модель $MODEL_NAME не найдена. Начинаю скачивание..."
        docker exec -d ollama ollama pull "$MODEL_NAME"
        echo "⏳ Скачивание запущено в фоне. Можно работать."
    else
        echo "✅ Модель $MODEL_NAME уже готова."
    fi
}

check_model "nomic-embed-text"
check_model "qwen2.5-coder:7b"

# 4. ФИНАЛ
echo "------------------------------------------------"
echo "✅ Все системы инициализированы!"
echo "📡 Подключаюсь к логам твоего мессенджера..."
echo "------------------------------------------------"
docker compose logs -f messenger_core
