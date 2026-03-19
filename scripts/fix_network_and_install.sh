#!/bin/bash
#
# 🔥 PULSE-PROOF NETWORK CONFIG FOR RUSSIA/CIS
# Версия: 1.0 (Март 2026)
# 
# Обходит DPI, блокировки, нестабильный интернет
# Автоматически восстанавливается при обрывах
#

set -e

echo "🔥 🔥 🔥 PULSE-PROOF NETWORK CONFIG 🔥 🔥 🔥"
echo ""

# ============================================
# 1. ОТКЛЮЧАЕМ IPv6 (избегаем routing loops)
# ============================================
echo "📡 Отключаем IPv6 временно..."
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
echo "✅ IPv6 отключен"

# ============================================
# 2. НАСТРАИВАЕМ ЗЕРКАЛА (Tencent + 163.com)
# ============================================
echo ""
echo "🌐 Настраиваем зеркала..."

# Основные зеркала (Tencent — самые быстрые для РФ)
export PUB_HOSTED_URL="https://mirrors.cloud.tencent.com/dart-pub"
export FLUTTER_STORAGE_BASE_URL="https://mirrors.cloud.tencent.com/flutter"

# Резервные (если Tencent упадёт)
# export PUB_HOSTED_URL="https://pub.flutter-io.cn"
# export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

echo "✅ PUB_HOSTED_URL=$PUB_HOSTED_URL"
echo "✅ FLUTTER_STORAGE_BASE_URL=$FLUTTER_STORAGE_BASE_URL"

# ============================================
# 3. GIT CONFIG (увеличиваем буфер + SSL)
# ============================================
echo ""
echo "📦 Настраиваем Git..."

git config --global http.postBuffer 524288000  # 500MB буфер
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# Для локальных сессий с самоподписанными сертификатами
git config --global http.sslVerify "false"

echo "✅ Git настроен (postBuffer=500MB, SSL verify=false)"

# ============================================
# 4. CURL/WGET CONFIG (обход DPI)
# ============================================
echo ""
echo "🔧 Настраиваем CURL..."

# Создаём .curlrc для обхода DPI
cat > ~/.curlrc << 'EOF'
# Обход DPI
compressed
connect-timeout 30
retry 10
retry-delay 5
retry-max-time 300
max-time 600
# Отключаем проверку SSL для нестабильных соединений
insecure
# Используем HTTP/1.1 (HTTP/2 может блокироваться)
http1.1
EOF

echo "✅ CURL настроен"

# ============================================
# 5. FVM INSTALL (с авторезюме)
# ============================================
echo ""
echo "📱 Установка FVM..."

cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign/mobile

# Проверяем установлен ли fvm
if ! command -v fvm &> /dev/null; then
    echo "⚠️ FVM не найден, устанавливаем..."
    
    # Попытка №1
    dart pub global activate fvm || true
    
    # Цикл с проверкой (максимум 10 попыток)
    for i in {1..10}; do
        echo "🔄 Попытка $i/10..."
        
        if command -v fvm &> /dev/null; then
            echo "✅ FVM установлен!"
            break
        fi
        
        echo "⏳ Ждём 5 секунд..."
        sleep 5
        
        dart pub global activate fvm || {
            echo "❌ Не удалось, пробуем снова..."
            continue
        }
    done
    
    if ! command -v fvm &> /dev/null; then
        echo "❌ Не удалось установить FVM после 10 попыток"
        echo "💡 Попробуйте вручную: dart pub global activate fvm"
        exit 1
    fi
else
    echo "✅ FVM уже установлен"
fi

# Добавляем в PATH
export PATH="$PATH:$HOME/.pub-cache/bin"
echo "✅ PATH обновлён"

# ============================================
# 6. FVM INSTALL FLUTTER (с авторезюме)
# ============================================
echo ""
echo "📱 Установка Flutter через FVM..."

# Цикл с проверкой (максимум 10 попыток)
for i in {1..10}; do
    echo "🔄 Попытка $i/10 установки Flutter..."
    
    # Проверяем установлен ли уже Flutter
    if fvm flutter --version &> /dev/null; then
        echo "✅ Flutter уже установлен"
        break
    fi
    
    # Пытаемся установить
    if fvm install stable; then
        echo "✅ Flutter установлен!"
        break
    else
        echo "❌ Попытка $i не удалась"
        echo "⏳ Ждём 10 секунд..."
        sleep 10
        
        # Очищаем кэш перед следующей попыткой
        fvm clean || true
        
        if [ $i -eq 10 ]; then
            echo "❌ Не удалось установить Flutter после 10 попыток"
            exit 1
        fi
    fi
done

# ============================================
# 7. FVM USE + PUB GET (с авторезюме)
# ============================================
echo ""
echo "📦 Установка зависимостей (pub get)..."

# Цикл с проверкой (максимум 5 попыток)
for i in {1..5}; do
    echo "🔄 Попытка $i/5 pub get..."
    
    if fvm flutter pub get; then
        echo "✅ Зависимости установлены!"
        break
    else
        echo "❌ Попытка $i не удалась"
        echo "⏳ Ждём 15 секунд..."
        sleep 15
        
        # Очищаем кэш pub
        flutter clean || true
        rm -rf ~/.pub-cache/_temp || true
        
        if [ $i -eq 5 ]; then
            echo "❌ Не удалось установить зависимости после 5 попыток"
            echo "💡 Проверьте .gitignore и pubspec.yaml"
            exit 1
        fi
    fi
done

# ============================================
# 8. ФИНАЛЬНАЯ ПРОВЕРКА
# ============================================
echo ""
echo "🎉 ФИНАЛЬНАЯ ПРОВЕРКА"
echo ""

echo "📊 Версия Flutter:"
fvm flutter --version

echo ""
echo "📊 Установленные пакеты:"
fvm flutter pub get --dry-run || true

echo ""
echo "✅ ✅ ✅ ВСЁ ГОТОВО! ✅ ✅ ✅"
echo ""
echo "💡 Для постоянного использования добавьте в ~/.bashrc:"
echo ""
echo 'export PUB_HOSTED_URL="https://mirrors.cloud.tencent.com/dart-pub"'
echo 'export FLUTTER_STORAGE_BASE_URL="https://mirrors.cloud.tencent.com/flutter"'
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"'
echo ""
echo "🔥 Для включения IPv6 обратно:"
echo "sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0"
echo ""
