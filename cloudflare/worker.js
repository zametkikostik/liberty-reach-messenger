/**
 * 🌐 LIBERTY REACH - Cloudflare Worker
 * 
 * Устойчивый хостинг для:
 * - Статической версии сайта
 * - Резервного доступа к документации
 * - API проксирование
 * 
 * URL: liberty-reach-messenger.zametkikostik.workers.dev
 */

// ============================================================================
// КОНФИГУРАЦИЯ
// ============================================================================
const CONFIG = {
  // Репозитории
  GITHUB_URL: 'https://github.com/zametkikostik/liberty-reach-messenger',
  CODEBERG_URL: 'https://codeberg.org/zametkikostik/liberty-reach-messenger',
  
  // API endpoints (резервные)
  API_TIMEOUT: 10000,
  
  // Кэширование
  CACHE_TTL: 3600, // 1 час
};

// ============================================================================
// ОСНОВНОЙ ОБРАБОТЧИК
// ============================================================================
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
  const url = new URL(request.url);
  const path = url.pathname;
  
  // 🔐 CORS headers для API
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
  
  // Обработка OPTIONS запросов
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      headers: corsHeaders,
    });
  }
  
  try {
    // ========================================================================
    // МАРШРУТИЗАЦИЯ
    // ========================================================================
    
    // Главная страница
    if (path === '/') {
      return new Response(renderHomePage(), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/html',
        },
      });
    }
    
    // API Health Check
    if (path === '/api/health') {
      return new Response(JSON.stringify({
        status: 'ok',
        timestamp: new Date().toISOString(),
        version: 'v0.16.1-cloud',
        mirrors: {
          github: CONFIG.GITHUB_URL,
          codeberg: CONFIG.CODEBERG_URL,
        },
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      });
    }
    
    // Редирект на GitHub
    if (path === '/github' || path === '/gh') {
      return Response.redirect(CONFIG.GITHUB_URL, 302);
    }
    
    // Редирект на Codeberg
    if (path === '/codeberg' || path === '/cb') {
      return Response.redirect(CONFIG.CODEBERG_URL, 302);
    }
    
    // Документация
    if (path.startsWith('/docs/')) {
      return new Response(renderDocs(path), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/html',
        },
      });
    }
    
    // API прокси (резервный endpoint)
    if (path.startsWith('/api/')) {
      return await handleApiProxy(request, path);
    }
    
    // Статические файлы
    if (path.startsWith('/static/')) {
      return await handleStaticFile(request, path);
    }
    
    // 404
    return new Response(renderNotFound(), {
      status: 404,
      headers: {
        ...corsHeaders,
        'Content-Type': 'text/html',
      },
    });
    
  } catch (error) {
    return new Response(renderError(error.message), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'text/html',
      },
    });
  }
}

// ============================================================================
// ОБРАБОТЧИКИ
// ============================================================================

async function handleApiProxy(request, path) {
  // Проксирование API запросов к резервным endpoint'ам
  
  const cache = caches.default;
  const cacheKey = new Request(path, request);
  
  // Проверка кэша
  let response = await cache.match(cacheKey);
  if (response) {
    return response;
  }
  
  // Пример: проксирование к GitHub API
  if (path === '/api/repos') {
    try {
      const githubResponse = await fetch('https://api.github.com/repos/zametkikostik/liberty-reach-messenger', {
        method: 'GET',
        headers: {
          'User-Agent': 'Liberty-Reach-Worker/1.0',
        },
      });
      
      const data = await githubResponse.json();
      
      response = new Response(JSON.stringify({
        name: data.name,
        description: data.description,
        stars: data.stargazers_count,
        forks: data.forks_count,
        updated: data.updated_at,
        mirrors: {
          github: CONFIG.GITHUB_URL,
          codeberg: CONFIG.CODEBERG_URL,
        },
      }), {
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': `public, max-age=${CONFIG.CACHE_TTL}`,
        },
      });
      
      // Кэширование
      event.waitUntil(cache.put(cacheKey, response.clone()));
      
      return response;
    } catch (error) {
      return new Response(JSON.stringify({
        error: 'API unavailable',
        fallback: 'Try Codeberg mirror',
        codeberg: CONFIG.CODEBERG_URL,
      }), {
        status: 503,
        headers: {
          'Content-Type': 'application/json',
        },
      });
    }
  }
  
  return new Response(JSON.stringify({ error: 'Unknown API endpoint' }), {
    status: 404,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function handleStaticFile(request, path) {
  // Обработка статических файлов
  
  const cache = caches.default;
  const cacheKey = new Request(path, request);
  
  // Проверка кэша
  let response = await cache.match(cacheKey);
  if (response) {
    return response;
  }
  
  // Заглушка для статических файлов
  response = new Response('Static file: ' + path, {
    headers: {
      'Content-Type': 'text/plain',
      'Cache-Control': `public, max-age=${CONFIG.CACHE_TTL}`,
    },
  });
  
  event.waitUntil(cache.put(cacheKey, response.clone()));
  
  return response;
}

// ============================================================================
// РЕНДЕРИНГ HTML
// ============================================================================

function renderHomePage() {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Liberty Reach - Decentralized Messenger</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Courier New', monospace;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
      color: #fff;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .container {
      max-width: 800px;
      text-align: center;
    }
    h1 {
      font-size: 3rem;
      margin-bottom: 20px;
      background: linear-gradient(90deg, #FF0080, #BD00FF);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .subtitle {
      font-size: 1.2rem;
      color: #aaa;
      margin-bottom: 40px;
    }
    .mirrors {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin-top: 40px;
    }
    .mirror-card {
      background: rgba(255,255,255,0.05);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 12px;
      padding: 20px;
      transition: transform 0.3s;
    }
    .mirror-card:hover {
      transform: translateY(-5px);
      border-color: #FF0080;
    }
    .mirror-card h3 {
      color: #FF0080;
      margin-bottom: 10px;
    }
    .mirror-card a {
      color: #fff;
      text-decoration: none;
      display: block;
      padding: 10px;
      background: rgba(255,0,128,0.1);
      border-radius: 6px;
      margin-top: 10px;
    }
    .mirror-card a:hover {
      background: rgba(255,0,128,0.2);
    }
    .status {
      margin-top: 40px;
      padding: 20px;
      background: rgba(0,255,0,0.1);
      border: 1px solid rgba(0,255,0,0.3);
      border-radius: 8px;
    }
    .status-ok {
      color: #00ff00;
      font-weight: bold;
    }
    footer {
      margin-top: 60px;
      color: #666;
      font-size: 0.9rem;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>🏰 Liberty Reach</h1>
    <p class="subtitle">Decentralized Sovereign Messenger & Financial Freedom Platform</p>
    
    <div class="status">
      <span class="status-ok">●</span> All Systems Operational
      <br><small>v0.16.1-cloud | Multi-Mirror Deployment</small>
    </div>
    
    <div class="mirrors">
      <div class="mirror-card">
        <h3>🐙 GitHub</h3>
        <p>Main Repository</p>
        <a href="${CONFIG.GITHUB_URL}" target="_blank">
          View Repository →
        </a>
      </div>
      
      <div class="mirror-card">
        <h3>🏔️ Codeberg</h3>
        <p>Backup Mirror</p>
        <a href="${CONFIG.CODEBERG_URL}" target="_blank">
          View Mirror →
        </a>
      </div>
      
      <div class="mirror-card">
        <h3>📚 Documentation</h3>
        <p>Security Guides</p>
        <a href="/docs/security" target="_blank">
          Read Docs →
        </a>
      </div>
      
      <div class="mirror-card">
        <h3>🔐 Security</h3>
        <p>Status & Health</p>
        <a href="/api/health" target="_blank">
          Check Status →
        </a>
      </div>
    </div>
    
    <footer>
      <p>Built for freedom, encrypted for life.</p>
      <p>Liberty Reach v0.16.1-cloud</p>
    </footer>
  </div>
</body>
</html>
  `;
}

function renderDocs(path) {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Documentation - Liberty Reach</title>
  <style>
    body {
      font-family: 'Courier New', monospace;
      background: #1a1a2e;
      color: #fff;
      padding: 40px 20px;
      line-height: 1.6;
    }
    .container { max-width: 900px; margin: 0 auto; }
    h1 { color: #FF0080; }
    h2 { color: #BD00FF; margin-top: 30px; }
    code {
      background: rgba(255,255,255,0.1);
      padding: 2px 6px;
      border-radius: 4px;
    }
    pre {
      background: rgba(0,0,0,0.3);
      padding: 15px;
      border-radius: 8px;
      overflow-x: auto;
    }
    a { color: #FF0080; }
    .back-link {
      display: inline-block;
      margin-bottom: 20px;
      padding: 10px 20px;
      background: rgba(255,0,128,0.2);
      border-radius: 6px;
      text-decoration: none;
    }
  </style>
</head>
<body>
  <div class="container">
    <a href="/" class="back-link">← Back to Home</a>
    
    <h1>📚 Liberty Reach Documentation</h1>
    
    <h2>🔐 Security</h2>
    <p>Liberty Reach uses end-to-end encryption with post-quantum algorithms (Kyber1024).</p>
    
    <h2>🌐 Multi-Mirror Deployment</h2>
    <p>Code is mirrored across multiple platforms for maximum resilience:</p>
    <ul>
      <li><strong>GitHub:</strong> Primary repository</li>
      <li><strong>Codeberg:</strong> Backup mirror</li>
      <li><strong>Cloudflare Workers:</strong> Static hosting</li>
    </ul>
    
    <h2>🚀 Installation</h2>
    <pre><code>git clone https://github.com/zametkikostik/liberty-reach-messenger.git
cd liberty-reach-messenger/mobile
flutter pub get
flutter run</code></pre>
    
    <h2>📖 More Documentation</h2>
    <p>Visit the repository for complete documentation:</p>
    <ul>
      <li><a href="${CONFIG.GITHUB_URL}" target="_blank">GitHub Repository</a></li>
      <li><a href="${CONFIG.CODEBERG_URL}" target="_blank">Codeberg Mirror</a></li>
    </ul>
  </div>
</body>
</html>
  `;
}

function renderNotFound() {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>404 - Liberty Reach</title>
  <style>
    body {
      font-family: 'Courier New', monospace;
      background: #1a1a2e;
      color: #fff;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      text-align: center;
    }
    h1 { color: #FF0080; font-size: 4rem; }
    p { color: #aaa; }
    a { color: #FF0080; }
  </style>
</head>
<body>
  <div>
    <h1>404</h1>
    <p>Page not found</p>
    <p><a href="/">Return Home →</a></p>
  </div>
</body>
</html>
  `;
}

function renderError(message) {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Error - Liberty Reach</title>
  <style>
    body {
      font-family: 'Courier New', monospace;
      background: #1a1a2e;
      color: #fff;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      text-align: center;
    }
    h1 { color: #ff0000; }
    code {
      background: rgba(255,255,255,0.1);
      padding: 10px;
      border-radius: 4px;
    }
    a { color: #FF0080; }
  </style>
</head>
<body>
  <div>
    <h1>⚠️ Error</h1>
    <code>${message}</code>
    <p><a href="/">Return Home →</a></p>
  </div>
</body>
</html>
  `;
}
