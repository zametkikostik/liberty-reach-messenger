# A Love Story — Cloudflare Worker

Backend для Liberty Reach Messenger на Cloudflare Workers.

## 🚀 Быстрый старт

### 1. Установка зависимостей

```bash
# WASM target
rustup target add wasm32-unknown-unknown

# worker-build
cargo install worker-build

# Wrangler
npm install -g wrangler
```

### 2. Настройка Cloudflare

```bash
# Логин
wrangler login

# Деплой
wrangler deploy
```

### 3. Локальное тестирование

```bash
wrangler dev
```

## 📡 API Endpoints

### POST /register

```bash
curl -X POST https://a-love-story.your-subdomain.workers.dev/register \
  -H "Content-Type: application/json" \
  -d '{"public_key": "base64_ed25519_pubkey"}'
```

Response:
```json
{
  "user_id": "64_char_sha256_hex",
  "short_user_id": "16_char_hex",
  "success": true
}
```

### POST /verify

```bash
curl -X POST https://a-love-story.your-subdomain.workers.dev/verify \
  -H "Content-Type: application/json" \
  -d '{
    "public_key": "base64_pubkey",
    "payload": "base64_data",
    "signature": "base64_signature"
  }'
```

Response:
```json
{
  "valid": true,
  "user_id": "64_char_hex",
  "error": null
}
```

### GET /health

```bash
curl https://a-love-story.your-subdomain.workers.dev/health
```

## 🔐 Криптография

| Компонент | Алгоритм | Размер |
|-----------|----------|--------|
| Публичный ключ | Ed25519 | 32 байта |
| Подпись | Ed25519 | 64 байта |
| User ID | SHA-256 (hex) | 64 символа |

## 📁 Структура

```
backend/
├── src/
│   ├── lib.rs          # Entry point
│   ├── crypto.rs       # Cryptography
│   ├── handlers.rs     # Request handlers
│   └── types.rs        # Data structures
├── Cargo.toml
├── wrangler.toml
└── README.md
```

## 🛠 Деплой через GitHub Actions

1. Добавь секрет `CLOUDFLARE_API_TOKEN` в GitHub
2. Запуш изменения в `backend/`
3. Workflow автоматически задеплоит

## 📄 License

MIT
