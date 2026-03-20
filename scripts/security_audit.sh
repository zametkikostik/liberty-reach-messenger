#!/bin/bash
# ============================================================================
# LIBERTY REACH - SECURITY AUDIT SCRIPT
# Проверка на утечки API ключей и секретов
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Liberty Reach Security Audit..."
echo ""

# Счётчики
WARNINGS=0
CRITICAL=0

# Функция проверки паттерна
check_pattern() {
    local pattern=$1
    local description=$2
    local severity=$3
    
    echo -n "Проверка: $description... "
    
    # Ищем в tracked файлах git
    if git grep -q "$pattern" 2>/dev/null; then
        if [ "$severity" == "CRITICAL" ]; then
            echo -e "${RED}❌ НАЙДЕНО!${NC}"
            ((CRITICAL++))
        else
            echo -e "${YELLOW}⚠️  НАЙДЕНО${NC}"
            ((WARNINGS++))
        fi
        git grep -n "$pattern" 2>/dev/null | head -5
    else
        echo -e "${GREEN}✅${NC}"
    fi
}

# Функция проверки файла
check_file_not_tracked() {
    local file=$1
    local description=$2
    
    echo -n "Проверка: $description... "
    
    if git ls-files --error-unmatch "$file" 2>/dev/null; then
        echo -e "${RED}❌ Файл в git!${NC}"
        ((CRITICAL++))
    else
        echo -e "${GREEN}✅ Не в git${NC}"
    fi
}

echo "═══════════════════════════════════════════════════════════"
echo "1️⃣  ПРОВЕРКА API КЛЮЧЕЙ В GIT"
echo "═══════════════════════════════════════════════════════════"

check_pattern "sk-or-v1-[a-zA-Z0-9]" "OpenRouter API ключ" "CRITICAL"
check_pattern "AIzaSy[a-zA-Z0-9_-]" "Gemini API ключ" "CRITICAL"
check_pattern "eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*" "JWT токен" "CRITICAL"
check_pattern "pk_live_[a-zA-Z0-9]" "Stripe live ключ" "CRITICAL"
check_pattern "xox[baprs]-[a-zA-Z0-9]" "Slack токен" "CRITICAL"

echo ""
echo "═══════════════════════════════════════════════════════════"
2️⃣  ПРОВЕРКА ФАЙЛОВ С СЕКРЕТАМИ"
echo "═══════════════════════════════════════════════════════════"

check_file_not_tracked ".env.local" ".env.local"
check_file_not_tracked ".continue/config.json" ".continue/config.json"
check_file_not_tracked "android/app/upload-keystore.jks" "Android Keystore"
check_file_not_tracked "android/key.properties" "Android Key Properties"

echo ""
echo "═══════════════════════════════════════════════════════════"
3️⃣  ПРОВЕРКА .GITIGNORE"
echo "═══════════════════════════════════════════════════════════"

echo -n "Проверка: .env.local в .gitignore... "
if grep -q "\.env\.local" .gitignore 2>/dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ Нет в .gitignore!${NC}"
    ((CRITICAL++))
fi

echo -n "Проверка: .continue/config.json в .gitignore... "
if grep -q "\.continue/config\.json" .gitignore 2>/dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ Нет в .gitignore!${NC}"
    ((CRITICAL++))
fi

echo -n "Проверка: *.jks в .gitignore... "
if grep -q "\*\.jks" .gitignore 2>/dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ Нет в .gitignore!${NC}"
    ((CRITICAL++))
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
📊 ИТОГИ"
echo "═══════════════════════════════════════════════════════════"

if [ $CRITICAL -gt 0 ]; then
    echo -e "${RED}❌ КРИТИЧНО: $CRITICAL проблем${NC}"
    echo "СРОЧНО отзови API ключи и удали секреты из git!"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  ПРЕДУПРЕЖДЕНИЯ: $WARNINGS${NC}"
    echo "Рекомендуется проверить"
    exit 0
else
    echo -e "${GREEN}✅ ВСЁ ЧИСТО!${NC}"
    echo "Нет известных утечек ключей"
    exit 0
fi
