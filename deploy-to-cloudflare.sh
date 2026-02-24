#!/bin/bash
# Liberty Reach - Быстрый Деплой в Cloudflare

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🚀 Liberty Reach - Cloudflare Deploy Script             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/cloudflare"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

# Check if wrangler is installed
if ! command -v npx &> /dev/null; then
    print_error "Node.js не найден! Установите Node.js 20+"
    exit 1
fi

print_status "Checking Node.js..."
node --version

# Step 1: Login
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ШАГ 1: Аутентификация в Cloudflare"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_warning "Откроется браузер для входа в Cloudflare"
read -p "Нажмите Enter для продолжения..."
npx wrangler login

# Step 2: Check account
echo ""
print_status "Проверка аккаунта..."
npx wrangler whoami

# Step 3: Create D1 Database
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ШАГ 2: Создание D1 Базы Данных"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_warning "База будет создана с именем: liberty-reach-db"
read -p "Продолжить? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    DATABASE_OUTPUT=$(npx wrangler d1 create liberty-reach-db 2>&1 || true)
    echo "$DATABASE_OUTPUT"
    
    # Extract database_id
    DATABASE_ID=$(echo "$DATABASE_OUTPUT" | grep -oP 'database_id = "\K[^"]+' || true)
    
    if [ -n "$DATABASE_ID" ]; then
        print_status "База создана: $DATABASE_ID"
        
        # Update wrangler.toml
        print_status "Обновление wrangler.toml..."
        sed -i "s/database_id = \"[^\"]*\"/database_id = \"$DATABASE_ID\"/" wrangler.toml
    else
        print_warning "Не удалось извлечь database_id. Обновите wrangler.toml вручную!"
    fi
fi

# Step 4: Apply migrations
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ШАГ 3: Применение Миграций"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create migrations directory
mkdir -p migrations

# Create migration file
cat > migrations/0001_init.sql << 'EOF'
-- Users table
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    public_key TEXT,
    created_at INTEGER NOT NULL,
    last_seen INTEGER NOT NULL,
    status TEXT DEFAULT 'offline' CHECK(status IN ('online', 'offline'))
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    from_user TEXT NOT NULL,
    to_user TEXT NOT NULL,
    content TEXT NOT NULL,
    encrypted INTEGER DEFAULT 1,
    created_at INTEGER NOT NULL,
    read INTEGER DEFAULT 0
);

-- Insert demo users
INSERT INTO users (id, username, public_key, created_at, last_seen, status) VALUES 
    ('user_pavel', 'Павел', 'pq_key_pavel', 1708700000000, 1708700000000, 'online'),
    ('user_elon', 'Илон', 'pq_key_elon', 1708700000000, 1708700000000, 'online'),
    ('user_news', 'LibertyNews', 'pq_key_news', 1708700000000, 1708700000000, 'online');
EOF

print_status "Миграции созданы"
print_warning "Применение миграций..."
npx wrangler d1 migrations apply liberty-reach-db

# Step 5: Create R2 Buckets
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ШАГ 4: Создание R2 Хранилищ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_status "Создание бакетов..."
npx wrangler r2 bucket create liberty-reach-encrypted-storage || print_warning "Бакет уже существует"
npx wrangler r2 bucket create liberty-reach-profile-backup || print_warning "Бакет уже существует"

# Step 6: Create Queues
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ШАГ 5: Создание Очереди"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_status "Создание очереди..."
npx wrangler queues create liberty-reach-messages || print_warning "Очередь уже существует"

# Step 7: Build
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ШАГ 6: Сборка Проекта"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_status "Сборка TypeScript..."
npm run build || {
    print_error "Сборка не удалась! Исправьте ошибки в worker.ts"
    exit 1
}

# Step 8: Deploy
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ШАГ 7: Деплой"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_warning "Деплой в Cloudflare Workers..."
read -p "Продолжить? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    DEPLOY_OUTPUT=$(npx wrangler deploy 2>&1 || true)
    echo "$DEPLOY_OUTPUT"
    
    # Extract URL
    DEPLOY_URL=$(echo "$DEPLOY_OUTPUT" | grep -oP 'https://[^\s]+' | head -1 || true)
    
    if [ -n "$DEPLOY_URL" ]; then
        print_status "Деплой успешен!"
        print_status "URL: $DEPLOY_URL"
        
        # Open in browser
        print_warning "Открыть в браузере?"
        read -p "(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            xdg-open "$DEPLOY_URL" 2>/dev/null || open "$DEPLOY_URL" 2>/dev/null || echo "Откройте вручную: $DEPLOY_URL"
        fi
    else
        print_warning "Не удалось извлечь URL. Проверьте вывод выше."
    fi
fi

# Step 9: Test
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ШАГ 8: Тестирование"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$DEPLOY_URL" ]; then
    print_status "Health check..."
    curl -s "$DEPLOY_URL" | python3 -m json.tool || print_warning "Health check не удался"
    
    echo ""
    print_status "Получение пользователей..."
    curl -s "$DEPLOY_URL/api/v1/users" | python3 -m json.tool | head -20 || print_warning "API не отвечает"
fi

# Final summary
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           ✓ Деплой Завершен!                             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Созданные ресурсы:"
echo "  • D1 Database: liberty-reach-db"
echo "  • R2 Buckets: liberty-reach-encrypted-storage, liberty-reach-profile-backup"
echo "  • Queues: liberty-reach-messages"
echo ""
echo "🌐 URL:"
if [ -n "$DEPLOY_URL" ]; then
    echo "  $DEPLOY_URL"
else
    echo "  Проверьте Cloudflare Dashboard"
fi
echo ""
echo "📝 Команды:"
echo "  • Логи:        npx wrangler tail"
echo "  • Деплой:      npx wrangler deploy"
echo "  • Секреты:     npx wrangler secret put <NAME>"
echo ""
echo "📁 Документация:"
echo "  • CLOUDFLARE_DEPLOY_GUIDE.md"
echo ""
