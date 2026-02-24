/**
 * Liberty Reach Messenger - Cloudflare Worker (Simple Version)
 * Без Durable Objects - само D1 + R2
 */

interface Env {
  DATABASE: D1Database;
  ENCRYPTED_STORAGE: R2Bucket;
  PROFILE_BACKUP: R2Bucket;
  TURN_SECRET: string;
  MAX_MESSAGE_SIZE: number;
  BULGARIA_EDGE: string;
  LOG_LEVEL: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-User-ID',
  'Access-Control-Max-Age': '86400',
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Health check
    if (url.pathname === '/' || url.pathname === '/health') {
      return new Response(JSON.stringify({
        status: 'ok',
        service: 'Liberty Reach Messenger',
        version: '0.2.0',
        edge: env.BULGARIA_EDGE,
        timestamp: Date.now(),
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // API Routes
    if (url.pathname.startsWith('/api/v1/')) {
      return await handleAPI(request, env, url);
    }

    // TURN
    if (url.pathname === '/turn') {
      return handleTURN(request, env);
    }

    return new Response('Liberty Reach API', {
      status: 200,
      headers: corsHeaders,
    });
  },
};

async function handleAPI(request: Request, env: Env, url: URL): Promise<Response> {
  const path = url.pathname;
  const method = request.method;

  // POST /api/v1/register - Register new user
  if (path === '/api/v1/register' && method === 'POST') {
    return handleRegister(request, env);
  }

  // GET /api/v1/users - List all users
  if (path === '/api/v1/users' && method === 'GET') {
    return handleListUsers(env);
  }

  // GET /api/v1/users/:userId - Get user
  if (path.match(/^\/api\/v1\/users\/[^/]+$/) && method === 'GET') {
    const userId = path.split('/').pop()!;
    return handleGetUser(userId, env);
  }

  // POST /api/v1/users/:userId/online
  if (path.match(/^\/api\/v1\/users\/[^/]+\/online$/) && method === 'POST') {
    const userId = path.split('/').pop()!;
    return handleSetOnline(userId, env);
  }

  // POST /api/v1/users/:userId/offline
  if (path.match(/^\/api\/v1\/users\/[^/]+\/offline$/) && method === 'POST') {
    const userId = path.split('/').pop()!;
    return handleSetOffline(userId, env);
  }

  // POST /api/v1/messages - Send message
  if (path === '/api/v1/messages' && method === 'POST') {
    return handleSendMessage(request, env);
  }

  // GET /api/v1/messages/:userId - Get messages
  if (path.match(/^\/api\/v1\/messages\/[^/]+$/) && method === 'GET') {
    const userId = path.split('/').pop()!;
    return handleGetMessages(userId, env);
  }

  // GET /api/v1/chats/:userId - Get chats
  if (path.match(/^\/api\/v1\/chats\/[^/]+$/) && method === 'GET') {
    const userId = path.split('/').pop()!;
    return handleGetChats(userId, env);
  }

  return new Response(JSON.stringify({ error: 'Not found' }), {
    status: 404,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// ============================================
// USER FUNCTIONS
// ============================================

async function handleRegister(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json() as any;
    const username = body.username as string;
    const public_key = body.public_key as string || '';

    if (!username || username.length < 3) {
      return new Response(JSON.stringify({
        error: 'Invalid username',
        message: 'Username must be at least 3 characters',
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const existing = await env.DATABASE.prepare(
      'SELECT id FROM users WHERE username = ?'
    ).bind(username).first();

    if (existing) {
      return new Response(JSON.stringify({
        error: 'Username taken',
        message: 'This username is already registered',
      }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const userId = 'user_' + crypto.randomUUID().replace(/-/g, '').slice(0, 16);
    const now = Date.now();

    await env.DATABASE.prepare(
      'INSERT INTO users (id, username, public_key, created_at, last_seen, status) VALUES (?, ?, ?, ?, ?, ?)'
    ).bind(userId, username, public_key, now, now, 'online').run();

    return new Response(JSON.stringify({
      success: true,
      user: { id: userId, username, public_key, created_at: now, status: 'online' },
    }), {
      status: 201,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Register error:', error);
    return new Response(JSON.stringify({ error: 'Registration failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

async function handleListUsers(env: Env): Promise<Response> {
  try {
    const { results } = await env.DATABASE.prepare(
      'SELECT id, username, public_key, created_at, last_seen, status FROM users ORDER BY last_seen DESC'
    ).all();

    return new Response(JSON.stringify({
      users: results || [],
      total: results?.length || 0,
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: 'Failed to list users' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

async function handleGetUser(userId: string, env: Env): Promise<Response> {
  try {
    const user = await env.DATABASE.prepare(
      'SELECT id, username, public_key, created_at, last_seen, status FROM users WHERE id = ?'
    ).bind(userId).first();

    if (!user) {
      return new Response(JSON.stringify({ error: 'User not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ user }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: 'Failed to get user' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

async function handleSetOnline(userId: string, env: Env): Promise<Response> {
  try {
    await env.DATABASE.prepare(
      'UPDATE users SET status = ?, last_seen = ? WHERE id = ?'
    ).bind('online', Date.now(), userId).run();

    return new Response(JSON.stringify({ success: true, status: 'online' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: 'Failed to set status' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

async function handleSetOffline(userId: string, env: Env): Promise<Response> {
  try {
    await env.DATABASE.prepare(
      'UPDATE users SET status = ?, last_seen = ? WHERE id = ?'
    ).bind('offline', Date.now(), userId).run();

    return new Response(JSON.stringify({ success: true, status: 'offline' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: 'Failed to set status' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

// ============================================
// MESSAGE FUNCTIONS
// ============================================

async function handleSendMessage(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json() as any;
    const from_user = body.from_user as string;
    const to_user = body.to_user as string;
    const content = body.content as string;
    const encrypted = body.encrypted !== undefined ? body.encrypted : true;

    if (!from_user || !to_user || !content) {
      return new Response(JSON.stringify({
        error: 'Missing required fields',
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const messageId = 'msg_' + crypto.randomUUID().replace(/-/g, '');
    const chatId = [from_user, to_user].sort().join('_');
    const now = Date.now();

    await env.DATABASE.prepare(
      'INSERT INTO messages (id, chat_id, from_user, to_user, content, encrypted, created_at, read) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    ).bind(messageId, chatId, from_user, to_user, content, encrypted ? 1 : 0, now, 0).run();

    return new Response(JSON.stringify({
      success: true,
      message: {
        id: messageId,
        chat_id: chatId,
        from_user,
        to_user,
        content,
        encrypted,
        created_at: now,
        read: false,
      },
    }), {
      status: 201,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Send message error:', error);
    return new Response(JSON.stringify({ error: 'Failed to send message' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

async function handleGetMessages(userId: string, env: Env): Promise<Response> {
  try {
    const { results } = await env.DATABASE.prepare(
      `SELECT m.*, u.username as from_username 
       FROM messages m 
       LEFT JOIN users u ON m.from_user = u.id
       WHERE m.to_user = ? OR m.from_user = ?
       ORDER BY m.created_at DESC 
       LIMIT 100`
    ).bind(userId, userId).all();

    await env.DATABASE.prepare(
      'UPDATE messages SET read = 1 WHERE to_user = ? AND read = 0'
    ).bind(userId).run();

    return new Response(JSON.stringify({
      messages: results || [],
      total: results?.length || 0,
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: 'Failed to get messages' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

async function handleGetChats(userId: string, env: Env): Promise<Response> {
  try {
    const { results } = await env.DATABASE.prepare(
      `SELECT DISTINCT 
        CASE WHEN m.from_user = ? THEN m.to_user ELSE m.from_user END as chat_user_id,
        u.username as chat_user_name,
        u.status as chat_user_status,
        (SELECT content FROM messages 
         WHERE (from_user = ? AND to_user = chat_user_id) 
            OR (from_user = chat_user_id AND to_user = ?)
         ORDER BY created_at DESC LIMIT 1) as last_message,
        (SELECT created_at FROM messages 
         WHERE (from_user = ? AND to_user = chat_user_id) 
            OR (from_user = chat_user_id AND to_user = ?)
         ORDER BY created_at DESC LIMIT 1) as last_message_time,
        (SELECT COUNT(*) FROM messages 
         WHERE to_user = ? AND from_user = chat_user_id AND read = 0) as unread_count
       FROM messages m
       LEFT JOIN users u ON u.id = chat_user_id
       WHERE m.from_user = ? OR m.to_user = ?
       ORDER BY last_message_time DESC`
    ).bind(
      userId, userId, userId, userId, userId, userId, userId, userId, userId, userId, userId
    ).all();

    return new Response(JSON.stringify({
      chats: results || [],
      total: results?.length || 0,
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: 'Failed to get chats' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

// ============================================
// TURN Handler
// ============================================

function handleTURN(_request: Request, env: Env): Response {
  const timestamp = Date.now() + 3600000;
  const username = `libertyreach:${timestamp}`;
  const credential = btoa(`${username}:${env.TURN_SECRET || 'secret'}`);

  return new Response(JSON.stringify({
    iceServers: [{
      urls: [
        'turn:turn1.libertyreach.internal:443?transport=tcp',
        'turn:turn2.libertyreach.internal:443?transport=tcp',
        'turn:turn-bg.libertyreach.internal:443?transport=tcp',
        'turn:turn1.libertyreach.internal:443?transport=udp',
      ],
      username,
      credential,
    }],
    ttl: 3600,
  }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
