/**
 * Liberty Reach - WebRTC Signaling Server
 * 
 * Эндпоинты:
 * - POST /signal/offer - Отправка SDP Offer
 * - POST /signal/answer - Отправка SDP Answer
 * - POST /signal/ice-candidate - Отправка ICE кандидата
 * - GET /signal/:peer_id - Получение сигнальных сообщений для пира
 * - POST /verify - Проверка подписи сообщения
 * 
 * KV Storage:
 * - SIGNALS_KV: Временное хранение сигнальных данных (TTL 60 сек)
 */

export interface Env {
  SIGNALS_KV: KVNamespace;
  ALLOWED_PEERS?: string; // Список разрешённых PeerID (опционально)
}

// Сигнальное сообщение
interface SignalingMessage {
  type: 'offer' | 'answer' | 'ice-candidate';
  from_peer_id: string;
  to_peer_id: string;
  call_id: string;
  sdp?: string;
  candidate?: RTCIceCandidateInit;
  signature?: string; // Подпись сообщения
  timestamp: number;
}

// Ответ API
interface APIResponse {
  success: boolean;
  data?: any;
  error?: string;
}

// Проверка подписи сообщения (упрощённая)
async function verifySignature(
  message: SignalingMessage,
  signature: string | undefined
): Promise<boolean> {
  if (!signature) return false;

  // В продакшене здесь была бы проверка Ed25519 подписи
  // Для примера просто проверяем наличие подписи
  return signature.length > 64;
}

// Создание подписи сообщения
async function signMessage(
  message: SignalingMessage,
  privateKey: string
): Promise<string> {
  // В продакшене здесь была бы Ed25519 подпись
  // Для примера создаём псевдо-подпись
  const encoder = new TextEncoder();
  const data = encoder.encode(JSON.stringify(message));
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

// Обработка OPTIONS запросов (CORS)
function handleCORS(): Headers {
  return new Headers({
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Peer-ID, X-Signature',
    'Access-Control-Max-Age': '86400',
  });
}

// Главная функция handler
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: handleCORS() });
    }

    try {
      // GET /signal/:peer_id - Получение сообщений для пира
      if (path.startsWith('/signal/') && request.method === 'GET') {
        const peerId = path.split('/')[2];
        if (!peerId) {
          return jsonResponse({ success: false, error: 'Peer ID required' }, 400);
        }

        return await getMessagesForPeer(peerId, env);
      }

      // POST /signal/offer - Отправка SDP Offer
      if (path === '/signal/offer' && request.method === 'POST') {
        const body: SignalingMessage = await request.json();
        return await handleOffer(body, env);
      }

      // POST /signal/answer - Отправка SDP Answer
      if (path === '/signal/answer' && request.method === 'POST') {
        const body: SignalingMessage = await request.json();
        return await handleAnswer(body, env);
      }

      // POST /signal/ice-candidate - Отправка ICE кандидата
      if (path === '/signal/ice-candidate' && request.method === 'POST') {
        const body: SignalingMessage = await request.json();
        return await handleIceCandidate(body, env);
      }

      // POST /verify - Проверка подписи
      if (path === '/verify' && request.method === 'POST') {
        const body = await request.json();
        const isValid = await verifySignature(body.message, body.signature);
        return jsonResponse({ success: isValid, verified: isValid });
      }

      // GET / - Health check
      if (path === '/') {
        return jsonResponse({
          success: true,
          service: 'Liberty Reach Signaling',
          version: '1.0.0',
          endpoints: [
            'POST /signal/offer',
            'POST /signal/answer',
            'POST /signal/ice-candidate',
            'GET /signal/:peer_id',
            'POST /verify'
          ]
        });
      }

      return jsonResponse({ success: false, error: 'Not found' }, 404);

    } catch (error) {
      console.error('Signaling error:', error);
      return jsonResponse(
        { success: false, error: error instanceof Error ? error.message : 'Unknown error' },
        500
      );
    }
  },
};

// Обработка SDP Offer
async function handleOffer(message: SignalingMessage, env: Env): Promise<Response> {
  // Проверка подписи
  if (!await verifySignature(message, message.signature)) {
    return jsonResponse({ success: false, error: 'Invalid signature' }, 401);
  }

  // Сохранение оффера в KV с TTL 60 секунд
  const key = `offer:${message.to_peer_id}:${message.call_id}`;
  await env.SIGNALS_KV.put(key, JSON.stringify(message), { expirationTtl: 60 });

  console.log(`Offer stored for ${message.to_peer_id} (call: ${message.call_id})`);

  return jsonResponse({
    success: true,
    message: 'Offer stored',
    call_id: message.call_id
  });
}

// Обработка SDP Answer
async function handleAnswer(message: SignalingMessage, env: Env): Promise<Response> {
  // Проверка подписи
  if (!await verifySignature(message, message.signature)) {
    return jsonResponse({ success: false, error: 'Invalid signature' }, 401);
  }

  // Сохранение ответа в KV с TTL 60 секунд
  const key = `answer:${message.to_peer_id}:${message.call_id}`;
  await env.SIGNALS_KV.put(key, JSON.stringify(message), { expirationTtl: 60 });

  console.log(`Answer stored for ${message.to_peer_id} (call: ${message.call_id})`);

  return jsonResponse({
    success: true,
    message: 'Answer stored',
    call_id: message.call_id
  });
}

// Обработка ICE кандидата
async function handleIceCandidate(message: SignalingMessage, env: Env): Promise<Response> {
  // Проверка подписи
  if (!await verifySignature(message, message.signature)) {
    return jsonResponse({ success: false, error: 'Invalid signature' }, 401);
  }

  // Сохранение кандидата в KV с TTL 60 секунд
  const key = `ice:${message.to_peer_id}:${message.call_id}:${Date.now()}`;
  await env.SIGNALS_KV.put(key, JSON.stringify(message), { expirationTtl: 60 });

  return jsonResponse({
    success: true,
    message: 'ICE candidate stored'
  });
}

// Получение сообщений для пира
async function getMessagesForPeer(peerId: string, env: Env): Promise<Response> {
  const messages: SignalingMessage[] = [];

  // Получение всех ключей для этого пира
  const prefixOffer = `offer:${peerId}:`;
  const prefixAnswer = `answer:${peerId}:`;
  const prefixIce = `ice:${peerId}:`;

  // Получение offer сообщений
  const offerKeys = await env.SIGNALS_KV.list({ prefix: prefixOffer });
  for (const key of offerKeys.keys) {
    const value = await env.SIGNALS_KV.get(key.name);
    if (value) {
      messages.push(JSON.parse(value));
      // Удаление после прочтения (опционально)
      // await env.SIGNALS_KV.delete(key.name);
    }
  }

  // Получение answer сообщений
  const answerKeys = await env.SIGNALS_KV.list({ prefix: prefixAnswer });
  for (const key of answerKeys.keys) {
    const value = await env.SIGNALS_KV.get(key.name);
    if (value) {
      messages.push(JSON.parse(value));
    }
  }

  // Получение ICE кандидатов
  const iceKeys = await env.SIGNALS_KV.list({ prefix: prefixIce });
  for (const key of iceKeys.keys) {
    const value = await env.SIGNALS_KV.get(key.name);
    if (value) {
      messages.push(JSON.parse(value));
    }
  }

  return jsonResponse({
    success: true,
    messages,
    count: messages.length
  });
}

// Helper для JSON ответов
function jsonResponse(data: APIResponse, status: number = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...handleCORS() as any,
    },
  });
}
