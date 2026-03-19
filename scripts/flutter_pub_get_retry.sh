#!/bin/bash
#
# 🔥 FLUTTER PUB GET С АВТОВОЗОБНОВЛЕНИЕМ
# Для нестабильных соединений в РФ/CIS
# Версия 2.0 с российскими зеркалами
#

set -e

# Настраиваем зеркала (приоритет: Китай → Россия → Официальный)
MIRRORS=(
    "https://mirrors.cloud.tencent.com/dart-pub|https://mirrors.cloud.tencent.com/flutter"
    "https://storage.yandexcloud.net/flutter/dart-pub|https://storage.yandexcloud.net/flutter"
    "https://mirrors.selectel.ru/dart-pub|https://mirrors.selectel.ru/flutter"
    "https://pub.dev|https://storage.googleapis.com"
)

export PATH="$PATH:/home/kostik/Flutter/bin"

cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign/mobile

echo "🔥 Запуск flutter pub get с авторезюме..."
echo "🇷🇺🇨🇳 Мультизеркало: Китай → Россия → Официальный"
echo ""

# Цикл с проверкой (максимум 10 попыток)
for i in {1..10}; do
    # Выбираем зеркало (циклически)
    MIRROR_IDX=$(( (i - 1) % ${#MIRRORS[@]} ))
    IFS='|' read -r PUB_URL FLUTTER_URL <<< "${MIRRORS[$MIRROR_IDX]}"
    
    export PUB_HOSTED_URL="$PUB_URL"
    export FLUTTER_STORAGE_BASE_URL="$FLUTTER_URL"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 Попытка $i/10"
    echo "📡 Зеркало: $PUB_HOSTED_URL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Запускаем pub get с таймаутом 5 минут
    if timeout 300 flutter pub get; then
        echo ""
        echo "✅ ✅ ✅ УСПЕХ! ✅ ✅ ✅"
        echo ""
        flutter --version
        echo ""
        echo "📦 Установленные пакеты:"
        flutter pub deps --style=compact | head -30
        exit 0
    else
        EXIT_CODE=$?
        echo ""
        echo "❌ Попытка $i не удалась (код: $EXIT_CODE)"
        
        # Проверяем была ли это полная ошибка или таймаут
        if [ $EXIT_CODE -eq 124 ]; then
            echo "⏰ Таймаут 5 минут - сеть слишком медленная"
        elif [ $EXIT_CODE -eq 1 ]; then
            echo "🔴 Ошибка соединения — пробуем другое зеркало"
        fi
        
        echo "⏳ Ждём 10 секунд перед следующей попыткой..."
        sleep 10
        
        # Очищаем временные файлы перед следующей попыткой
        rm -rf .dart_tool/pub_cache/_temp/* 2>/dev/null || true
        rm -rf ~/.pub-cache/_temp/* 2>/dev/null || true
        
        if [ $i -eq 10 ]; then
            echo ""
            echo "❌ ❌ ❌ НЕ УДАЛОСЬ ПОСЛЕ 10 ПОПЫТОК ❌ ❌ ❌"
            echo ""
            echo "💡 Попробуйте вручную:"
            echo "   export PUB_HOSTED_URL=\"https://mirrors.cloud.tencent.com/dart-pub\""
            echo "   cd mobile && flutter pub get"
            echo ""
            exit 1
        fi
    fi
done
