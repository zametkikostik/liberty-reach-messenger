# 🚀 Cloudflare Deployment Guide
## Как задеплоить Liberty Reach в Cloudflare и не упасть

---

## ⚠️ ВАЖНО: Почему Cloudflare может "обвалиться"

### Основные проблемы:
1. ❌ **Превышение лимитов** - CPU time, memory, requests
2. ❌ **Нет обработки ошибок** - crash при exception
3. ❌ **Утечки памяти** - не освобождаемые ресурсы
4. ❌ **Бесконечные циклы** - timeout через 10ms (free) / 50ms (paid)
5. ❌ **Слишком большие данные** - лимит 128KB на request/response

### Решения:
✅ Правильная конфигурация wrangler.toml  
✅ Обработка ошибок везде  
✅ Оптимизация кода  
✅ Rate limiting  
✅ Monitoring и alerting  

---

## 📋 ШАГ 1: Подготовка Cloudflare аккаунта

### 1.1 Регистрация и вход

```bash
# Установить Wrangler CLI
npm install -g wrangler

# Login в Cloudflare
wrangler login

# Проверить аккаунт
wrangler whoami
```

### 1.2 Тарифы Cloudflare

| Тариф | Цена | Worker CPU | Memory | Рекомендация |
|-------|------|------------|--------|--------------|
| **Free** | $0 | 10ms CPU | 128MB | ❌ Только для тестов |
| **Paid** | $5/мес | 50ms CPU | 128MB | ✅ Для начала |
| **Unbound** | Pay-per-use | до 500ms | 128MB | ✅ Для продакшена |
| **Enterprise** | Custom | до 30s | 512MB | ✅ Для больших нагрузок |

**Рекомендация**: Начни с **Paid** ($5/мес), потом перейди на **Unbound**

---

## 📋 ШАГ 2: Правильная конфигурация wrangler.toml

### 2.1 Базовая конфигурация

```toml
# wrangler.toml

name = "liberty-reach-messenger"
main = "src/worker.ts"
compatibility_date = "2024-01-01"
compatibility_flags = ["nodejs_compat"]

# ============================================
# ВАЖНО: Настройки производительности
# ============================================

# Включить Unbound (pay-per-use) для продакшена
workers_dev = true
route = { pattern = "libertyreach.internal/*", zone_name = "libertyreach.internal" }

# Лимиты
[limits]
cpu_ms = 50  # 50ms для Paid тарифа
# Для Unbound: не указывай, будет pay-per-use

# ============================================
# Очереди для обработки сообщений
# ============================================

[[queues.producers]]
queue = "liberty-reach-messages"
binding = "MESSAGE_QUEUE"

[[queues.consumers]]
queue = "liberty-reach-messages"
max_batch_size = 100
max_batch_timeout = 30
max_retries = 3
dead_letter_queue = "liberty-reach-dlq"

# ============================================
# Durable Objects с настройками
# ============================================

[durable_objects]
bindings = [
  { name = "PREKEY_STORE", class_name = "PreKeyStore" },
  { name = "SESSION_STATE", class_name = "SessionManager" },
  { name = "PROFILE_STORE", class_name = "ProfileManager" }
]

# ============================================
# R2 хранилища
# ============================================

[[r2_buckets]]
bucket_name = "liberty-reach-encrypted-storage"
binding = "ENCRYPTED_STORAGE"

[[r2_buckets]]
bucket_name = "liberty-reach-profile-backup"
binding = "PROFILE_BACKUP"

# ============================================
# Переменные окружения
# ============================================

[vars]
TURN_SECRET = "${TURN_SECRET}"
MAX_MESSAGE_SIZE = 4194304
BULGARIA_EDGE = "sofia.libertyreach.internal"
LOG_LEVEL = "warn"  # "debug" | "info" | "warn" | "error"
RATE_LIMIT = "100"  # запросов в минуту на пользователя

# ============================================
# Environment для разработки
# ============================================

[env.dev]
name = "liberty-reach-dev"
route = { pattern = "dev.libertyreach.internal/*", zone_name = "libertyreach.internal" }

[env.dev.vars]
LOG_LEVEL = "debug"
RATE_LIMIT = "1000"

# ============================================
# Environment для production
# ============================================

[env.production]
name = "liberty-reach-production"
route = { pattern = "libertyreach.internal/*", zone_name = "libertyreach.internal" }

[env.production.vars]
LOG_LEVEL = "error"
RATE_LIMIT = "100"
```

---

## 📋 ШАГ 3: Оптимизация кода Worker

### 3.1 Обработка ошибок (ОБЯЗАТЕЛЬНО!)

```typescript
// src/worker.ts

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    try {
      // Handle CORS
      if (request.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders });
      }

      // WebSocket
      if (request.headers.get('Upgrade') === 'websocket') {
        return await this.handleWebSocket(request, env);
      }

      // API routes
      if (url.pathname.startsWith('/api/v1/')) {
        return await this.handleAPI(request, env, url);
      }

      // Health check
      if (url.pathname === '/health') {
        return new Response(JSON.stringify({
          status: 'ok',
          timestamp: Date.now(),
          version: '0.3.0'
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      return new Response('Liberty Reach API', {
        status: 200,
        headers: corsHeaders
      });

    } catch (error) {
      // ЛОВИМ ВСЕ ОШИБКИ - НЕ ДАЕМ УПАСТЬ
      console.error('Worker error:', error);
      
      return new Response(JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
        path: url.pathname,
        method: request.method
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
  },

  // ============================================
  // Rate Limiting (защита от DDoS)
  // ============================================

  async handleAPI(request: Request, env: Env, url: URL): Promise<Response> {
    const userId = request.headers.get('X-User-ID');
    
    // Проверка rate limit
    if (userId) {
      const rateLimitKey = `rate:${userId}`;
      const current = await env.RATE_LIMITER.get(rateLimitKey);
      
      if (current && parseInt(current) >= parseInt(env.RATE_LIMIT)) {
        return new Response(JSON.stringify({
          error: 'Rate limit exceeded',
          retry_after: 60
        }), {
          status: 429,
          headers: { 'Retry-After': '60' }
        });
      }
      
      // Увеличиваем счетчик
      await env.RATE_LIMITER.set(rateLimitKey, (parseInt(current || '0') + 1).toString(), { expirationTtl: 60 });
    }

    // Обработка API с таймаутом
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 5000); // 5 секунд
      
      const result = await Promise.race([
        this.processAPI(request, env, url),
        new Promise((_, reject) => {
          controller.signal.addEventListener('abort', () => {
            clearTimeout(timeout);
            reject(new Error('Request timeout'));
          });
        })
      ]);
      
      clearTimeout(timeout);
      return result;
      
    } catch (error) {
      console.error('API error:', error);
      
      if (error instanceof Error && error.message === 'Request timeout') {
        return new Response(JSON.stringify({
          error: 'Request timeout',
          message: 'Request took too long to process'
        }), {
          status: 504,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      
      return new Response(JSON.stringify({
        error: 'Processing error',
        message: error instanceof Error ? error.message : 'Unknown error'
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  },

  async processAPI(request: Request, env: Env, url: URL): Promise<Response> {
    // Твоя логика обработки API
    // ...
  }
};
```

### 3.2 Оптимизация Durable Objects

```typescript
// src/durable-objects.ts

export class PreKeyStore {
  private state: DurableObjectState;
  private bundle: PreKeyBundle | null = null;

  constructor(state: DurableObjectState) {
    this.state = state;
    
    // ВАЖНО: Восстанавливаем состояние при перезапуске
    this.state.blockConcurrencyWhile(async () => {
      const stored = await this.state.storage.get<PreKeyBundle>('bundle');
      if (stored) {
        this.bundle = stored;
      }
    });
  }

  async fetch(request: Request): Promise<Response> {
    try {
      const url = new URL(request.url);

      if (url.pathname === '/store' && request.method === 'POST') {
        return await this.store(request);
      }

      if (url.pathname === '/fetch' && request.method === 'GET') {
        return await this.fetchBundle();
      }

      return new Response('Not Found', { status: 404 });

    } catch (error) {
      console.error('PreKeyStore error:', error);
      
      return new Response(JSON.stringify({
        error: 'Internal error',
        message: error instanceof Error ? error.message : 'Unknown error'
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }

  private async store(request: Request): Promise<Response> {
    try {
      const data = await request.json<PreKeyBundle>();
      this.bundle = data;

      // Сохраняем в storage с TTL (опционально)
      await this.state.storage.put('bundle', data);
      
      // ВАЖНО: Очищаем старые данные если превышен лимит
      const keys = await this.state.storage.list();
      if (keys.size > 1000) {
        // Удаляем старые записи
        const oldest = keys.keys().next().value;
        if (oldest) {
          await this.state.storage.delete(oldest);
        }
      }

      return new Response(JSON.stringify({ success: true }));

    } catch (error) {
      console.error('PreKeyStore store error:', error);
      throw error;
    }
  }

  private async fetchBundle(): Promise<Response> {
    if (!this.bundle) {
      return new Response(JSON.stringify({ error: 'No prekeys' }), { status: 404 });
    }

    return new Response(JSON.stringify(this.bundle));
  }
}
```

### 3.3 Правильная работа с очередями

```typescript
// src/queue-consumer.ts

export default {
  async queue(batch: MessageBatch<MessageEnvelope>, env: Env): Promise<void> {
    console.log(`Processing batch of ${batch.messages.length} messages`);
    
    for (const message of batch.messages) {
      try {
        await this.processMessage(message.body, env);
        message.ack();
      } catch (error) {
        console.error('Failed to process message:', error);
        
        // Не ack - сообщение будет retried
        // Или отправляем в dead letter queue
        message.retry({
          delaySeconds: 60,  // Ждем 1 минуту перед retry
          maxRetries: 3      // Максимум 3 попытки
        });
      }
    }
  },

  async processMessage(envelope: MessageEnvelope, env: Env): Promise<void> {
    // Обработка сообщения
    // ВАЖНО: Не превышай лимит CPU time
    
    const sessionId = `${envelope.from}-${envelope.to}`;
    const id = env.SESSION_STATE.idFromName(sessionId);
    const stub = env.SESSION_STATE.get(id);
    
    await stub.fetch('http://internal/relay', {
      method: 'POST',
      body: JSON.stringify(envelope),
    });
  }
};
```

---

## 📋 ШАГ 4: Деплой

### 4.1 Деплой в dev environment

```bash
cd /home/kostik/liberty-reach-messenger/cloudflare

# Install dependencies
npm install

# Deploy to dev
wrangler deploy --env dev

# Проверить статус
wrangler status --env dev
```

### 4.2 Деплой в production

```bash
# Deploy to production
wrangler deploy --env production

# Проверить логи
wrangler tail --env production

# Проверить метрики
wrangler metrics --env production
```

### 4.3 Rollback (если что-то пошло не так)

```bash
# Посмотреть версии
wrangler versions list

# Откатиться к предыдущей
wrangler versions rollback 1
```

---

## 📋 ШАГ 5: Monitoring и Alerting

### 5.1 Cloudflare Analytics

```bash
# Включить analytics
wrangler analytics enable

# Посмотреть метрики
wrangler metrics
```

### 5.2 Настройка алертов

Создай файл `alerting.json`:

```json
{
  "alerts": [
    {
      "name": "High Error Rate",
      "description": "Error rate > 5%",
      "condition": "error_rate > 0.05",
      "period": "5m",
      "notification": {
        "email": "dev@libertyreach.internal",
        "webhook": "https://hooks.slack.com/..."
      }
    },
    {
      "name": "High Latency",
      "description": "P99 latency > 500ms",
      "condition": "latency_p99 > 500",
      "period": "5m",
      "notification": {
        "email": "dev@libertyreach.internal"
      }
    },
    {
      "name": "High CPU Usage",
      "description": "CPU usage > 80%",
      "condition": "cpu_usage > 0.8",
      "period": "5m",
      "notification": {
        "email": "dev@libertyreach.internal"
      }
    }
  ]
}
```

Применить алерты:

```bash
wrangler alerting apply --config alerting.json
```

### 5.3 Логи

```bash
# Tail логи в реальном времени
wrangler tail --env production

# Фильтровать по уровню
wrangler tail --env production --status error

# Сохранить логи
wrangler tail --env production > logs.txt
```

---

## 📋 ШАГ 6: Оптимизация производительности

### 6.1 Кэширование

```typescript
// src/caching.ts

export async function cachedFetch(
  key: string,
  fetcher: () => Promise<any>,
  ttl: number = 3600
): Promise<any> {
  // Проверяем кэш
  const cached = await caches.default.match(key);
  if (cached) {
    return await cached.json();
  }

  // Fetch новые данные
  const data = await fetcher();

  // Сохраняем в кэш
  const response = new Response(JSON.stringify(data), {
    headers: { 'Content-Type': 'application/json' }
  });
  
  const cacheResponse = new Response(response.body, response);
  cacheResponse.headers.set('Cache-Control', `public, max-age=${ttl}`);
  
  await caches.default.put(key, cacheResponse);

  return data;
}
```

### 6.2 Батчинг запросов

```typescript
// Вместо 100 отдельных запросов
// Делаем 1 батчевый

// ❌ ПЛОХО:
for (const userId of userIds) {
  await fetch(`/api/v1/users/${userId}`);
}

// ✅ ХОРОШО:
const response = await fetch('/api/v1/users/batch', {
  method: 'POST',
  body: JSON.stringify({ user_ids: userIds })
});
```

### 6.3 Сжатие данных

```typescript
// Сжимаем большие ответы
import { gzip, ungzip } from 'pako';

async function compressResponse(data: any): Promise<Response> {
  const json = JSON.stringify(data);
  const compressed = gzip(json);
  
  return new Response(compressed, {
    headers: {
      'Content-Type': 'application/json',
      'Content-Encoding': 'gzip'
    }
  });
}
```

---

## 📋 ШАГ 7: Best Practices

### ✅ DO:

1. **Всегда обрабатывай ошибки**
```typescript
try {
  // код
} catch (error) {
  console.error('Error:', error);
  return errorResponse;
}
```

2. **Используй rate limiting**
```typescript
const limit = await checkRateLimit(userId);
if (limit.exceeded) {
  return new Response('Rate limit', { status: 429 });
}
```

3. **Кэшируй данные**
```typescript
const cached = await cache.get(key);
if (cached) return cached;
```

4. **Логируй всё**
```typescript
console.log('Request:', request.method, request.url);
console.error('Error:', error);
```

5. **Мониторь метрики**
```bash
wrangler metrics
wrangler tail
```

### ❌ DON'T:

1. **Не делай бесконечные циклы**
```typescript
// ❌ ПЛОХО:
while (true) {
  // timeout через 10ms
}
```

2. **Не храни большие данные в памяти**
```typescript
// ❌ ПЛОХО:
const hugeArray = new Array(1000000).fill(data);

// ✅ ХОРОШО:
await storage.put(key, data);
```

3. **Не игнорируй ошибки**
```typescript
// ❌ ПЛОХО:
try { something(); } catch (e) {}

// ✅ ХОРОШО:
try { something(); } catch (e) {
  console.error('Error:', e);
  throw e;
}
```

4. **Не превышай лимиты**
- Max CPU: 50ms (Paid) / 500ms (Unbound)
- Max Memory: 128MB
- Max Request/Response: 128KB

---

## 📋 ШАГ 8: Troubleshooting

### Проблема: Worker падает с timeout

**Решение**:
```toml
# wrangler.toml
[limits]
cpu_ms = 50  # Увеличь для Paid
# Или используй Unbound для pay-per-use
```

### Проблема: Превышен лимит памяти

**Решение**:
```typescript
// Не храни данные в памяти, используй storage
await this.state.storage.put('key', data);
```

### Проблема: Слишком много ошибок

**Решение**:
```typescript
// Добавь больше try-catch
// Включи detailed logging
wrangler tail --status error
```

### Проблема: DDoS атака

**Решение**:
```typescript
// Включи Cloudflare DDoS protection
// Добавь rate limiting
// Используй Cloudflare Rules
```

---

## 📊 ИТОГ

### Чеклист перед деплоем:

- [ ] wrangler.toml настроен правильно
- [ ] Обработка ошибок везде
- [ ] Rate limiting включен
- [ ] Логи настроены
- [ ] Алерты настроены
- [ ] Тесты пройдены
- [ ] Monitoring включен
- [ ] Backup план есть

### Команды для деплоя:

```bash
# 1. Login
wrangler login

# 2. Deploy dev
wrangler deploy --env dev

# 3. Тесты
curl https://dev.libertyreach.internal/health

# 4. Deploy production
wrangler deploy --env production

# 5. Проверка
curl https://libertyreach.internal/health

# 6. Мониторинг
wrangler tail --env production
wrangler metrics --env production
```

**Всё готово! Worker будет работать стабильно! 🚀**
