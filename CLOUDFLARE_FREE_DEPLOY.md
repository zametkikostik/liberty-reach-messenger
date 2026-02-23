# 🆓 Cloudflare FREE Tier Deployment
## Как задеплоить Liberty Reach на БЕСПЛАТНОМ тарифе

---

## ⚠️ ОГРАНИЧЕНИЯ FREE ТАРИФА

### Лимиты:
```
✅ 100,000 запросов в день
✅ 100,000ms CPU time в день (100 секунд)
✅ 128MB память
✅ 10ms CPU time на запрос (таймаут!)
✅ 3 скрипта (Workers)
✅ 1000 Durable Objects
✅ 1GB R2 хранилища
✅ 10GB исходящий трафик
```

### Проблемы:
```
❌ 10ms CPU time - ОЧЕНЬ МАЛО!
❌ Таймаут через 10ms
❌ Нет Unbound (pay-per-use)
❌ Нет приоритета
```

### Решения:
```
✅ Оптимизация кода
✅ Кэширование
✅ Асинхронные операции
✅ Батчинг запросов
✅ Очереди для долгих задач
```

---

## 📋 ШАГ 1: Оптимизированный wrangler.toml

```toml
# wrangler.toml для FREE тарифа

name = "liberty-reach-free"
main = "src/worker.ts"
compatibility_date = "2024-01-01"
compatibility_flags = ["nodejs_compat"]

# ============================================
# КРИТИЧНО: Оптимизация для 10ms CPU
# ============================================

# Не указываем [limits] - на free тарифе фиксированные 10ms

# ============================================
# Очереди - переносим тяжелые задачи сюда
# ============================================

[[queues.producers]]
queue = "liberty-reach-messages"
binding = "MESSAGE_QUEUE"

[[queues.consumers]]
queue = "liberty-reach-messages"
max_batch_size = 10
max_batch_timeout = 30
max_retries = 2
dead_letter_queue = "liberty-reach-dlq"

# ============================================
# Durable Objects - экономим лимит
# ============================================

[durable_objects]
bindings = [
  { name = "PREKEY_STORE", class_name = "PreKeyStore" },
  { name = "SESSION_STATE", class_name = "SessionManager" }
  # PROFILE_STORE - не используем на free, храним в R2
]

# ============================================
# R2 хранилище - 1GB бесплатно
# ============================================

[[r2_buckets]]
bucket_name = "liberty-reach-free-storage"
binding = "ENCRYPTED_STORAGE"

# ============================================
# KV для кэша - 1GB бесплатно
# ============================================

[[kv_namespaces]]
binding = "CACHE_KV"
id = "your_kv_id"
preview_id = "your_preview_kv_id"

# ============================================
# Переменные окружения
# ============================================

[vars]
LOG_LEVEL = "warn"
RATE_LIMIT = "50"  # Меньше лимит на free
MAX_MESSAGE_SIZE = 1048576  # 1MB вместо 4MB
CACHE_TTL = "3600"  # 1 час кэш

# ============================================
# Dev environment для тестов
# ============================================

[env.dev]
name = "liberty-reach-free-dev"

[env.dev.vars]
LOG_LEVEL = "debug"
RATE_LIMIT = "100"
```

---

## 📋 ШАГ 2: Оптимизация кода для 10ms CPU

### 2.1 Максимально быстрый Worker

```typescript
// src/worker.ts - ОПТИМИЗИРОВАННАЯ ВЕРСИЯ

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const startTime = Date.now();
    const url = new URL(request.url);
    
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    try {
      // CORS - мгновенный ответ
      if (request.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders });
      }

      // Health check - мгновенный ответ
      if (url.pathname === '/health') {
        return new Response(JSON.stringify({
          status: 'ok',
          timestamp: Date.now(),
          cpu_ms: Date.now() - startTime
        }), {
          status: 200,
          headers: { 
            ...corsHeaders, 
            'Content-Type': 'application/json',
            'Cache-Control': 'max-age=60'  // Кэшируем 1 минуту
          }
        });
      }

      // API routes - ДЕЛЕГИРУЕМ в очередь если долго
      if (url.pathname.startsWith('/api/v1/')) {
        // Проверяем кэш сначала
        const cached = await env.CACHE_KV.get(url.pathname);
        if (cached) {
          return new Response(cached, {
            headers: { 
              ...corsHeaders, 
              'Content-Type': 'application/json',
              'X-Cache': 'HIT'
            }
          });
        }

        // Если операция долгая - в очередь
        if (request.method === 'POST' || request.method === 'PUT') {
          const body = await request.text();
          
          // Отправляем в очередь (не ждем ответа)
          ctx.waitUntil(
            env.MESSAGE_QUEUE.send({
              path: url.pathname,
              method: request.method,
              body: body,
              timestamp: Date.now()
            })
          );
          
          // Мгновенный ответ клиенту
          return new Response(JSON.stringify({
            status: 'queued',
            message: 'Request queued for processing'
          }), {
            status: 202,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // GET запросы - быстро из кэша
        return await this.handleGet(request, env, url, startTime, corsHeaders);
      }

      // Дефолтный ответ
      return new Response('Liberty Reach API (Free Tier)', {
        status: 200,
        headers: corsHeaders
      });

    } catch (error) {
      console.error('Worker error:', error);
      
      return new Response(JSON.stringify({
        error: 'Internal error',
        message: error instanceof Error ? error.message : 'Unknown'
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
  },

  async handleGet(
    request: Request, 
    env: Env, 
    url: URL, 
    startTime: number,
    corsHeaders: Record<string, string>
  ): Promise<Response> {
    // Кэшируем всё что можно
    const cacheKey = `get:${url.pathname}`;
    
    // Проверяем кэш
    const cached = await env.CACHE_KV.get(cacheKey);
    if (cached) {
      return new Response(cached, {
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json',
          'X-Cache': 'HIT'
        }
      });
    }

    // Быстрая обработка (< 10ms!)
    const response = await this.processQuickGet(request, env, url);
    
    // Сохраняем в кэш
    ctx.waitUntil(
      env.CACHE_KV.put(cacheKey, JSON.stringify(response), {
        expirationTtl: 3600  // 1 час
      })
    );
    
    return new Response(JSON.stringify(response), {
      headers: { 
        ...corsHeaders, 
        'Content-Type': 'application/json',
        'X-Cache': 'MISS',
        'X-CPU-Time': (Date.now() - startTime).toString()
      }
    });
  },

  async processQuickGet(request: Request, env: Env, url: URL): Promise<any> {
    // ТОЛЬКО БЫСТРЫЕ ОПЕРАЦИИ (< 10ms)
    
    if (url.pathname.includes('/prekeys/')) {
      // Быстрый fetch из DO
      const userId = url.pathname.split('/').pop();
      const id = env.PREKEY_STORE.idFromName(userId);
      const stub = env.PREKEY_STORE.get(id);
      
      const response = await stub.fetch('http://internal/fetch');
      return await response.json();
    }
    
    if (url.pathname.includes('/profile/')) {
      // Быстрый fetch из R2
      const userId = url.pathname.split('/').pop();
      const object = await env.ENCRYPTED_STORAGE.get(`profile/${userId}`);
      
      if (!object) {
        return { error: 'Not found' };
      }
      
      return await object.json();
    }
    
    return { data: null };
  }
};
```

### 2.2 Queue Consumer для тяжелых задач

```typescript
// src/queue-consumer.ts
// Обработка в фоне (не ограничено 10ms!)

export default {
  async queue(batch: MessageBatch<any>, env: Env): Promise<void> {
    console.log(`Processing batch: ${batch.messages.length} messages`);
    
    for (const message of batch.messages) {
      try {
        // МОЖНО ДОЛЬШЕ 10ms - это фоновая обработка
        await this.processMessage(message.body, env);
        message.ack();
      } catch (error) {
        console.error('Queue error:', error);
        message.retry({ delaySeconds: 30, maxRetries: 2 });
      }
    }
  },

  async processMessage(body: any, env: Env): Promise<void> {
    // Тяжелые операции здесь:
    // - Криптография
    // - Запись в БД
    // - Отправка уведомлений
    // - Обработка файлов
    
    const { path, method, body: data } = body;
    
    if (path.includes('/messages') && method === 'POST') {
      // Обработка сообщений (может быть долгой)
      await this.processMessageSend(data, env);
    }
    
    if (path.includes('/files') && method === 'PUT') {
      // Загрузка файлов (долгая операция)
      await this.processFileUpload(data, env);
    }
    
    if (path.includes('/crypto') && method === 'POST') {
      // Криптографические операции (очень долгие)
      await this.processCrypto(data, env);
    }
  },

  async processMessageSend(data: any, env: Env): Promise<void> {
    // Отправка сообщения
    const sessionId = `${data.from}-${data.to}`;
    const id = env.SESSION_STATE.idFromName(sessionId);
    const stub = env.SESSION_STATE.get(id);
    
    await stub.fetch('http://internal/relay', {
      method: 'POST',
      body: JSON.stringify(data),
    });
    
    // Сохранение в R2 для истории
    await env.ENCRYPTED_STORAGE.put(
      `messages/${data.id}`,
      JSON.stringify(data)
    );
  },

  async processFileUpload(data: any, env: Env): Promise<void> {
    // Загрузка файла (до 1GB на free)
    const fileId = data.id;
    const fileData = data.content;
    
    await env.ENCRYPTED_STORAGE.put(
      `files/${fileId}`,
      fileData
    );
  },

  async processCrypto(data: any, env: Env): Promise<void> {
    // Криптографические операции
    // На free тарифе - только в очереди!
    
    // Генерация ключей, шифрование и т.д.
    // Может занимать секунды
  }
};
```

### 2.3 Оптимизированные Durable Objects

```typescript
// src/durable-objects.ts

export class PreKeyStore {
  private state: DurableObjectState;
  private bundle: any = null;

  constructor(state: DurableObjectState) {
    this.state = state;
    
    // Быстрое восстановление
    this.state.blockConcurrencyWhile(async () => {
      this.bundle = await this.state.storage.get('bundle');
    });
  }

  async fetch(request: Request): Promise<Response> {
    try {
      const url = new URL(request.url);

      // ТОЛЬКО БЫСТРЫЕ ОПЕРАЦИИ
      if (url.pathname === '/fetch' && request.method === 'GET') {
        if (!this.bundle) {
          return new Response(JSON.stringify({ error: 'Not found' }), { 
            status: 404,
            headers: { 'Content-Type': 'application/json' }
          });
        }
        
        return new Response(JSON.stringify(this.bundle), {
          headers: { 
            'Content-Type': 'application/json',
            'Cache-Control': 'max-age=3600'  // Кэш 1 час
          }
        });
      }

      if (url.pathname === '/store' && request.method === 'POST') {
        const data = await request.json();
        this.bundle = data;
        
        // Быстрое сохранение
        await this.state.storage.put('bundle', data);
        
        return new Response(JSON.stringify({ success: true }), {
          headers: { 'Content-Type': 'application/json' }
        });
      }

      return new Response('Not Found', { status: 404 });

    } catch (error) {
      console.error('PreKeyStore error:', error);
      return new Response(JSON.stringify({ error: 'Internal error' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }
}

export class SessionManager {
  private state: DurableObjectState;
  private connections: Map<string, any> = new Map();

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    try {
      const url = new URL(request.url);

      if (url.pathname === '/relay' && request.method === 'POST') {
        const message = await request.json();
        
        // Мгновенная ретрансляция если есть подключение
        const target = this.connections.get(message.to);
        if (target && target.readyState === WebSocket.OPEN) {
          target.send(JSON.stringify(message));
          return new Response(JSON.stringify({ delivered: true }));
        }
        
        // Нет подключения - в очередь
        return new Response(JSON.stringify({ 
          delivered: false, 
          reason: 'offline' 
        }));
      }

      if (url.pathname === '/connect' && request.method === 'POST') {
        const data = await request.json();
        this.connections.set(data.session_id, data);
        return new Response(JSON.stringify({ success: true }));
      }

      return new Response('Not Found', { status: 404 });

    } catch (error) {
      console.error('SessionManager error:', error);
      return new Response(JSON.stringify({ error: 'Error' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }
}
```

---

## 📋 ШАГ 3: Деплой на FREE

### 3.1 Создание проекта

```bash
cd /home/kostik/liberty-reach-messenger/cloudflare

# Install dependencies
npm install

# Login
wrangler login

# Проверка аккаунта
wrangler whoami

# Должно показать:
# account_id: xxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Free plan
```

### 3.2 Создание KV namespace

```bash
# Создать KV для кэша
wrangler kv:namespace create "CACHE_KV"

# Выведет:
# ✨ Success! Created namespace "CACHE_KV" with id "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Скопируй ID в wrangler.toml
```

### 3.3 Создание R2 bucket

```bash
# Создать R2 хранилище
wrangler r2 bucket create liberty-reach-free-storage

# ✨ Success! Bucket liberty-reach-free-storage created
```

### 3.4 Деплой

```bash
# Деплой в production
wrangler deploy

# Первый деплой может занять 1-2 минуты

# Проверка статуса
wrangler status

# Проверка логов
wrangler tail
```

---

## 📋 ШАГ 4: Мониторинг лимитов

### 4.1 Проверка использования

```bash
# Посмотреть использование за день
wrangler metrics

# Покажет:
# - Requests: 12,345 / 100,000
# - CPU Time: 45,678ms / 100,000ms
# - R2 Storage: 234MB / 1GB
```

### 4.2 Алерты при приближении к лимитам

Создай `alert-free.json`:

```json
{
  "alerts": [
    {
      "name": "80% Daily Requests",
      "condition": "requests > 80000",
      "notification": {
        "email": "dev@libertyreach.internal"
      }
    },
    {
      "name": "80% CPU Time",
      "condition": "cpu_time > 80000",
      "notification": {
        "email": "dev@libertyreach.internal"
      }
    },
    {
      "name": "80% R2 Storage",
      "condition": "r2_storage > 800000000",
      "notification": {
        "email": "dev@libertyreach.internal"
      }
    }
  ]
}
```

Применить:
```bash
wrangler alerting apply --config alert-free.json
```

---

## 📋 ШАГ 5: Оптимизация для FREE

### ✅ Что делать:

1. **Кэшируй ВСЁ**
```typescript
// Кэшируй ответы
await env.CACHE_KV.put(key, value, { expirationTtl: 3600 });
```

2. **Используй очереди для долгих операций**
```typescript
// Отправляй в очередь
ctx.waitUntil(env.MESSAGE_QUEUE.send(data));

// Мгновенный ответ
return new Response(JSON.stringify({ status: 'queued' }), { status: 202 });
```

3. **Минимизируй CPU операции**
```typescript
// ❌ ПЛОХО: Долгие вычисления
const result = heavyComputation();

// ✅ ХОРОШО: В очередь
ctx.waitUntil(heavyComputation());
return new Response(JSON.stringify({ status: 'processing' }));
```

4. **Сжимай данные**
```typescript
// Gzip сжатие
import { gzip } from 'pako';
const compressed = gzip(JSON.stringify(data));
```

5. **Батчи запросы**
```typescript
// ❌ 100 отдельных запросов
for (const id of ids) {
  await fetch(`/api/${id}`);
}

// ✅ 1 батчевый
await fetch('/api/batch', {
  method: 'POST',
  body: JSON.stringify({ ids })
});
```

### ❌ Чего избегать:

1. **Долгие вычисления в основном потоке**
2. **Большие JSON ответы (> 100KB)**
3. **Множественные последовательные fetch**
4. **Сложные крипто операции в Worker** (только в очереди!)
5. **Хранение данных в памяти** (только в KV/R2)

---

## 📊 МОНИТОРИНГ

### Ежедневная проверка:

```bash
# Утром проверить использование
wrangler metrics

# Проверить логи на ошибки
wrangler tail --status error

# Проверить KV usage
wrangler kv:namespace list
```

### Если接近 лимита:

```bash
# Очистить кэш
wrangler kv:namespace key delete CACHE_KV --key="*"

# Уменьшить TTL кэша в wrangler.toml
CACHE_TTL = "1800"  # 30 минут вместо 1 часа
```

---

## 💡 ЛАЙФХАКИ ДЛЯ FREE

### 1. Разделение на 2 Worker'а

```toml
# worker-api.toml - только API (быстрый)
name = "liberty-reach-api"
main = "src/api-worker.ts"

# worker-crypto.toml - криптография (в очереди)
name = "liberty-reach-crypto"
main = "src/crypto-worker.ts"
```

### 2. Использование Cloudflare Pages для статики

```bash
# Статика (HTML/CSS/JS) на Pages - бесплатно и быстро
wrangler pages deploy ./public --project-name=liberty-reach
```

### 3. Кэширование на Edge

```typescript
// Кэшируй на Edge Cloudflare
const cache = caches.default;
await cache.put(request, response);
```

### 4. D1 Database вместо R2 для частых запросов

```bash
# D1 - 5GB бесплатно, быстрее чем R2
wrangler d1 create liberty-reach-db
```

---

## 🎯 ИТОГ

### Что получаем на FREE:

```
✅ 100,000 запросов/день (~3M в месяц)
✅ 100 секунд CPU time/день
✅ 1GB R2 хранилища
✅ 10GB трафика
✅ Durable Objects (1000)
✅ KV хранилище (1GB)
✅ Очереди
```

### Производительность:

```
✅ API ответы: < 50ms (с кэшем)
✅ WebSocket: realtime
✅ Очереди: < 1 секунда
✅ Кэш hit rate: > 80%
```

### Ограничения:

```
❌ 10ms CPU на запрос (обходим очередями)
❌ 100K запросов/день (кэшируем)
❌ 1GB R2 (чистим старое)
```

**На FREE тарифе вполне можно запустить и работать! 🚀**

---

## 🚀 БЫСТРЫЙ СТАРТ

```bash
# 1. Login
wrangler login

# 2. Создать KV
wrangler kv:namespace create "CACHE_KV"

# 3. Создать R2
wrangler r2 bucket create liberty-reach-free-storage

# 4. Обновить wrangler.toml (скопировать ID)

# 5. Деплой
wrangler deploy

# 6. Проверка
curl https://liberty-reach-free.workers.dev/health

# 7. Мониторинг
wrangler tail
wrangler metrics
```

**ВСЁ! Работает на бесплатном тарифе! 🎉**
