#!/bin/bash
# Liberty Reach - Безопасный Git Push
# Проверяет и выкладывает ТОЛЬКО безопасные файлы

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         🦅 Liberty Reach - Безопасный Push                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция проверки на критические файлы
check_critical_files() {
    echo -e "${YELLOW}[*] Проверка на критические файлы...${NC}"
    
    CRITICAL_PATTERNS=(
        "*.key"
        "*.pem"
        "*.secret"
        "*.private"
        "*.env"
        "*.jks"
        "*.keystore"
        "*_secret.*"
        "*_private.*"
        "wrangler-secrets.*"
        ".cloudflare.*"
        "api_token.*"
        "access_token.*"
        "master_key.*"
        "identity_key.*"
        "session_key.*"
        "encryption_key.*"
        "recovery_phrase.*"
        "mnemonic.*"
        "seed.*"
        "credentials.*"
        "*.db"
        "*.sqlite"
        "data/"
        "storage/"
    )
    
    FOUND_CRITICAL=0
    
    for pattern in "${CRITICAL_PATTERNS[@]}"; do
        FILES=$(git ls-files --cached --others --exclude-standard | grep -E "^${pattern//\*/.*}$" 2>/dev/null || true)
        if [ ! -z "$FILES" ]; then
            echo -e "${RED}[!] НАЙДЕНЫ КРИТИЧЕСКИЕ ФАЙЛЫ:${NC}"
            echo "$FILES"
            FOUND_CRITICAL=1
        fi
    done
    
    if [ $FOUND_CRITICAL -eq 1 ]; then
        echo ""
        echo -e "${RED}❌ ОБНАРУЖЕНЫ КРИТИЧЕСКИЕ ФАЙЛЫ!${NC}"
        echo -e "${RED}   НЕ ПУШЬТЕ ЭТИ ФАЙЛЫ В GIT!${NC}"
        echo ""
        echo "   Удалите их из staging area:"
        echo "   git reset HEAD <файл>"
        echo ""
        echo "   Или добавьте в .gitignore"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}[✓] Критические файлы не найдены${NC}"
    echo ""
}

# Функция проверки коммитов
check_commits() {
    echo -e "${YELLOW}[*] Проверка коммитов...${NC}"
    
    # Показать что будет запушено
    echo ""
    echo "Файлы для пуша:"
    git status --short
    echo ""
    
    # Подсчитать количество файлов
    FILE_COUNT=$(git status --short | wc -l)
    echo "Всего файлов: $FILE_COUNT"
    echo ""
}

# Функция безопасного пуша
safe_push() {
    echo -e "${YELLOW}[*] Выполнение безопасного пуша...${NC}"
    echo ""
    
    # Проверка наличия remote
    if ! git remote | grep -q "origin"; then
        echo -e "${RED}[!] Remote 'origin' не найден!${NC}"
        echo ""
        echo "   Добавьте remote:"
        echo "   git remote add origin https://github.com/YOUR_USERNAME/liberty-reach-messenger.git"
        echo ""
        exit 1
    fi
    
    # Push
    echo -e "${GREEN}[✓] Все проверки пройдены${NC}"
    echo ""
    read -p "Продолжить пуш? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Pushing to origin..."
        git push -u origin main 2>&1 || git push -u origin master 2>&1
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✅ Пуш успешен!${NC}"
            echo ""
            echo "🌐 Репозиторий:"
            echo "   https://github.com/YOUR_USERNAME/liberty-reach-messenger"
            echo ""
            echo "📱 Web версия (после деплоя):"
            echo "   https://liberty-reach-messenger.pages.dev"
            echo ""
        else
            echo ""
            echo -e "${RED}❌ Ошибка пуша!${NC}"
            echo ""
            exit 1
        fi
    else
        echo "Пуш отменен"
        exit 0
    fi
}

# Основная функция
main() {
    echo "Проверка репозитория..."
    echo ""
    
    # Проверка что мы в git репозитории
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}[!] Это не git репозиторий!${NC}"
        echo ""
        echo "   Инициализируйте git:"
        echo "   git init"
        echo ""
        exit 1
    fi
    
    # Проверка что есть файлы для коммита
    STAGED=$(git diff --cached --name-only)
    if [ -z "$STAGED" ]; then
        echo -e "${YELLOW}[!] Нет файлов в staging area${NC}"
        echo ""
        echo "   Добавьте файлы:"
        echo "   git add ."
        echo ""
        read -p "Добавить все файлы? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git add -A
        else
            exit 0
        fi
    fi
    
    # Запустить проверки
    check_critical_files
    check_commits
    
    # Выполнить пуш
    safe_push
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                  ✅ ГОТОВО!                                 ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Запуск
main
