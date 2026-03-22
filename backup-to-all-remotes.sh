#!/bin/bash
# ============================================================================
# LIBERTY REACH - MULTI-REMOTE BACKUP SCRIPT
# ============================================================================
# Автоматическая отправка кода на все зеркала:
# - GitHub (основной)
# - Codeberg (резерв)
# - Cloudflare Workers (статичный сайт)
# ============================================================================

set -e

echo "🔐 LIBERTY REACH - Multi-Remote Backup"
echo "======================================="
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# 1. GITHUB (основной репозиторий)
# ============================================================================
echo -e "${BLUE}[1/3] GitHub...${NC}"

if git push origin main --force 2>/dev/null; then
    echo -e "${GREEN}✅ GitHub: OK${NC}"
else
    echo -e "${RED}❌ GitHub: FAILED${NC}"
    echo "   Проверьте: git remote -v"
fi

# ============================================================================
# 2. CODEBERG (резервное зеркало)
# ============================================================================
echo -e "${BLUE}[2/3] Codeberg...${NC}"

# Проверка наличия токена
if [ -z "$CODEBERG_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  CODEBERG_TOKEN не установлен${NC}"
    echo "   Для автоматической отправки создайте токен:"
    echo "   1. https://codeberg.org/settings/applications"
    echo "   2. Создайте Personal Access Token"
    echo "   3. export CODEBERG_TOKEN=your_token"
    echo ""
    
    # Пробуем интерактивную отправку
    if git push codeberg main --force; then
        echo -e "${GREEN}✅ Codeberg: OK (interactive)${NC}"
    else
        echo -e "${RED}❌ Codeberg: FAILED${NC}"
    fi
else
    # Отправка с токеном
    CODEBERG_URL="https://zametkikostik:${CODEBERG_TOKEN}@codeberg.org/zametkikostik/liberty-reach-messenger.git"
    
    if git push "$CODEBERG_URL" main --force 2>/dev/null; then
        echo -e "${GREEN}✅ Codeberg: OK${NC}"
    else
        echo -e "${RED}❌ Codeberg: FAILED${NC}"
    fi
fi

# ============================================================================
# 3. TAGS (все теги)
# ============================================================================
echo -e "${BLUE}[3/3] Tags...${NC}"

if git push origin --tags --force 2>/dev/null; then
    echo -e "${GREEN}✅ GitHub Tags: OK${NC}"
else
    echo -e "${YELLOW}⚠️  GitHub Tags: SKIPPED${NC}"
fi

if [ -n "$CODEBERG_TOKEN" ]; then
    CODEBERG_URL="https://zametkikostik:${CODEBERG_TOKEN}@codeberg.org/zametkikostik/liberty-reach-messenger.git"
    if git push "$CODEBERG_URL" --tags --force 2>/dev/null; then
        echo -e "${GREEN}✅ Codeberg Tags: OK${NC}"
    else
        echo -e "${YELLOW}⚠️  Codeberg Tags: SKIPPED${NC}"
    fi
fi

# ============================================================================
# ИТОГИ
# ============================================================================
echo ""
echo "======================================="
echo -e "${GREEN}✅ BACKUP COMPLETE${NC}"
echo ""
echo "📍 Репозитории:"
echo "   • GitHub:    https://github.com/zametkikostik/liberty-reach-messenger"
echo "   • Codeberg:  https://codeberg.org/zametkikostik/liberty-reach-messenger"
echo ""
echo "🌐 Cloudflare Workers:"
echo "   • liberty-reach-messenger.zametkikostik.workers.dev"
echo ""
echo "💡 Для автоматизации добавьте CODEBERG_TOKEN в .env.local"
echo ""
