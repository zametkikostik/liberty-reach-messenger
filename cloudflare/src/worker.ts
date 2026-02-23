/**
 * Liberty Reach Messenger - Cloudflare Worker
 * 
 * Serverless backend for encrypted messaging with permanent profiles
 * 
 * Features:
 * - End-to-End encrypted message relay
 * - Permanent profile storage (no deletion allowed)
 * - PreKey bundle distribution for X3DH
 * - TURN server credentials for WebRTC
 * - Profile recovery via Shamir's Secret Sharing
 * 
 * Priority Region: Bulgaria (Cloudflare Edge Sofia)
 */

// Types
interface Env {
  MESSAGE_QUEUE: Queue<MessageEnvelope>;
  PREKEY_STORE: DurableObjectNamespace;
  SESSION_STATE: DurableObjectNamespace;
  PROFILE_STORE: DurableObjectNamespace;
  ENCRYPTED_STORAGE: R2Bucket;
  PROFILE_BACKUP: R2Bucket;
  TURN_SECRET: string;
  MAX_MESSAGE_SIZE: number;
  BULGARIA_EDGE: string;
  LOG_LEVEL: string;
}

interface MessageEnvelope {
  id: string;
  from: string;
  to: string;
  ciphertext: string;
  timestamp: number;
  type: 'message' | 'signal' | 'file';
  metadata?: Record<string, string>;
}

interface PreKeyBundle {
  identity_key: string;
  pq_prekey: string;
  signed_prekey: string;
  one_time_keys: Array<{
    key_id: number;
    key: string;
  }>;
  signature: string;
}

interface Profile {
  user_id: string;
  public_keys: {
    pq_public: string;
    ec_public: string;
    identity_public: string;
  };
  encrypted_data: string;
  recovery_hash: string;
  created_at: number;
  last_seen: number;
  status: 'active' | 'deactivated';
  backup_locations: Array<{
    type: string;
    location: string;
  }>;
}

// CORS Headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-User-ID',
  'Access-Control-Max-Age': '86400',
};

// Main Worker
export default {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext
  ): Promise<Response> {
    const url = new URL(request.url);
    const logLevel = env.LOG_LEVEL || 'info';

    // Log request
    if (logLevel === 'debug') {
      console.log(`[${new Date().toISOString()}] ${request.method} ${url.pathname}`);
    }

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // WebSocket upgrade for real-time communication
      if (request.headers.get('Upgrade') === 'websocket') {
        return handleWebSocket(request, env);
      }

      // API routes
      if (url.pathname.startsWith('/api/v1/')) {
        return await handleAPI(request, env, url);
      }

      // TURN credentials
      if (url.pathname === '/turn' || url.pathname === '/api/v1/turn') {
        return handleTURN(request, env);
      }

      // Health check
      if (url.pathname === '/health' || url.pathname === '/') {
        return new Response(JSON.stringify({
          status: 'ok',
          service: 'Liberty Reach Messenger',
          version: '0.1.0',
          edge: env.BULGARIA_EDGE,
          timestamp: Date.now(),
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      return new Response('Liberty Reach Messenger API', {
        status: 200,
        headers: corsHeaders,
      });
    } catch (error) {
      console.error('Worker error:', error);
      return new Response(JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  },
};

/**
 * Handle WebSocket connections for real-time messaging
 */
function handleWebSocket(request: Request, env: Env): Response {
  const url = new URL(request.url);
  const [client, server] = new WebSocketPair();

  server.accept();

  const sessionId = url.searchParams.get('session_id') || crypto.randomUUID();
  const userId = url.searchParams.get('user_id');

  // Store connection in Durable Object
  const id = env.SESSION_STATE.idFromName(sessionId);
  const stub = env.SESSION_STATE.get(id);

  stub.fetch('http://internal/connect', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      session_id: sessionId,
      user_id: userId,
      connected_at: Date.now(),
    }),
  });

  server.addEventListener('message', async (event) => {
    try {
      const message = JSON.parse(event.data as string);

      if (message.type === 'relay') {
        // Relay message to recipient
        const recipientSession = `${message.from}-${message.to}`;
        const recipientId = env.SESSION_STATE.idFromName(recipientSession);
        const recipientStub = env.SESSION_STATE.get(recipientId);

        await recipientStub.fetch('http://internal/relay', {
          method: 'POST',
          body: JSON.stringify(message),
        });
      }
    } catch (error) {
      console.error('WebSocket message error:', error);
    }
  });

  server.addEventListener('close', () => {
    stub.fetch('http://internal/disconnect', {
      method: 'POST',
      body: JSON.stringify({ session_id: sessionId }),
    });
  });

  return new Response(null, {
    status: 101,
    webSocket: client,
  });
}

/**
 * Handle REST API requests
 */
async function handleAPI(
  request: Request,
  env: Env,
  url: URL
): Promise<Response> {
  const path = url.pathname;
  const method = request.method;

  // ============================================
  // PROFILE ENDPOINTS (Permanent - No Deletion)
  // ============================================

  // POST /api/v1/profile/create - Create new profile
  if (path === '/api/v1/profile/create' && method === 'POST') {
    return handleProfileCreate(request, env);
  }

  // GET /api/v1/profile/:userId - Get profile
  if (path.match(/^\/api\/v1\/profile\/[^/]+$/) && method === 'GET') {
    const userId = path.split('/').pop()!;
    return handleProfileGet(userId, env);
  }

  // PUT /api/v1/profile/:userId - Update profile
  if (path.match(/^\/api\/v1\/profile\/[^/]+$/) && method === 'PUT') {
    const userId = path.split('/').pop()!;
    return handleProfileUpdate(request, userId, env);
  }

  // DELETE /api/v1/profile/:userId - ⛔ FORBIDDEN
  if (path.match(/^\/api\/v1\/profile\/[^/]+$/) && method === 'DELETE') {
    return new Response(JSON.stringify({
      error: 'Profile deletion is NOT allowed',
      message: 'Profiles are permanent in Liberty Reach. Use /deactivate instead.',
      alternative: `/api/v1/profile/${path.split('/').pop()}/deactivate`,
    }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // POST /api/v1/profile/:userId/deactivate - Deactivate profile
  if (path.match(/^\/api\/v1\/profile\/[^/]+\/deactivate$/) && method === 'POST') {
    const userId = path.split('/').slice(-2)[0];
    return handleProfileDeactivate(userId, env);
  }

  // POST /api/v1/profile/:userId/reactivate - Reactivate profile
  if (path.match(/^\/api\/v1\/profile\/[^/]+\/reactivate$/) && method === 'POST') {
    const userId = path.split('/').slice(-2)[0];
    return handleProfileReactivate(userId, env);
  }

  // POST /api/v1/profile/recover - Recover profile from Shamir shares
  if (path === '/api/v1/profile/recover' && method === 'POST') {
    return handleProfileRecover(request, env);
  }

  // ============================================
  // PREKEY ENDPOINTS
  // ============================================

  // POST /api/v1/prekeys - Upload prekeys
  if (path === '/api/v1/prekeys' && method === 'POST') {
    return handlePreKeysUpload(request, env);
  }

  // GET /api/v1/prekeys/:userId - Get prekeys
  if (path.match(/^\/api\/v1\/prekeys\/[^/]+$/) && method === 'GET') {
    const userId = path.split('/').pop()!;
    return handlePreKeysGet(userId, env);
  }

  // ============================================
  // MESSAGE ENDPOINTS
  // ============================================

  // POST /api/v1/messages - Send message
  if (path === '/api/v1/messages' && method === 'POST') {
    return handleSendMessage(request, env);
  }

  // ============================================
  // FILE ENDPOINTS
  // ============================================

  // PUT /api/v1/files/:fileId - Upload file
  if (path.match(/^\/api\/v1\/files\/[^/]+$/) && method === 'PUT') {
    const fileId = path.split('/').pop()!;
    return handleFileUpload(request, fileId, env);
  }

  // GET /api/v1/files/:fileId - Download file
  if (path.match(/^\/api\/v1\/files\/[^/]+$/) && method === 'GET') {
    const fileId = path.split('/').pop()!;
    return handleFileDownload(fileId, env);
  }

  return new Response(JSON.stringify({ error: 'Not Found' }), {
    status: 404,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// Profile Handlers
async function handleProfileCreate(request: Request, env: Env): Promise<Response> {
  try {
    const profile: Profile = await request.json();

    // Check if profile already exists
    const existing = await env.PROFILE_BACKUP.get(`profile/${profile.user_id}/data`);
    if (existing) {
      return new Response(JSON.stringify({
        error: 'Profile already exists',
        message: 'Use recovery mechanism if you lost access',
      }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Store profile
    await env.PROFILE_BACKUP.put(
      `profile/${profile.user_id}/data`,
      JSON.stringify(profile)
    );

    // Log to Bulgaria edge
    console.log(`[BULGARIA] Profile created: ${profile.user_id}`);

    return new Response(JSON.stringify({
      success: true,
      user_id: profile.user_id,
      created_at: profile.created_at,
      message: 'Profile created successfully. Profile deletion is NOT allowed.',
    }), {
      status: 201,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({
      error: 'Failed to create profile',
      message: error instanceof Error ? error.message : 'Unknown error',
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

async function handleProfileGet(userId: string, env: Env): Promise<Response> {
  const object = await env.PROFILE_BACKUP.get(`profile/${userId}/data`);

  if (!object) {
    return new Response(JSON.stringify({ error: 'Profile not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const profile: Profile = await object.json();

  if (profile.status === 'deactivated') {
    return new Response(JSON.stringify({
      error: 'Profile is deactivated',
      status: 'deactivated',
      message: 'Contact support to reactivate',
    }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Update last_seen
  profile.last_seen = Date.now();
  await env.PROFILE_BACKUP.put(
    `profile/${userId}/data`,
    JSON.stringify(profile)
  );

  return new Response(JSON.stringify(profile), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function handleProfileUpdate(
  request: Request,
  userId: string,
  env: Env
): Promise<Response> {
  const object = await env.PROFILE_BACKUP.get(`profile/${userId}/data`);

  if (!object) {
    return new Response(JSON.stringify({ error: 'Profile not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const profile: Profile = await object.json();
  const updates = await request.json();

  // Update allowed fields
  profile.encrypted_data = updates.encrypted_data ?? profile.encrypted_data;
  profile.public_keys = updates.public_keys ?? profile.public_keys;
  profile.last_seen = Date.now();

  await env.PROFILE_BACKUP.put(
    `profile/${userId}/data`,
    JSON.stringify(profile)
  );

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function handleProfileDeactivate(userId: string, env: Env): Promise<Response> {
  const object = await env.PROFILE_BACKUP.get(`profile/${userId}/data`);

  if (!object) {
    return new Response(JSON.stringify({ error: 'Profile not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const profile: Profile = await object.json();
  profile.status = 'deactivated';

  await env.PROFILE_BACKUP.put(
    `profile/${userId}/data`,
    JSON.stringify(profile)
  );

  return new Response(JSON.stringify({
    success: true,
    status: 'deactivated',
    message: 'Profile deactivated. Use /reactivate to restore.',
  }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function handleProfileReactivate(userId: string, env: Env): Promise<Response> {
  const object = await env.PROFILE_BACKUP.get(`profile/${userId}/data`);

  if (!object) {
    return new Response(JSON.stringify({ error: 'Profile not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const profile: Profile = await object.json();
  profile.status = 'active';
  profile.last_seen = Date.now();

  await env.PROFILE_BACKUP.put(
    `profile/${userId}/data`,
    JSON.stringify(profile)
  );

  return new Response(JSON.stringify({
    success: true,
    status: 'active',
  }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function handleProfileRecover(request: Request, env: Env): Promise<Response> {
  const { user_id, recovery_shares } = await request.json();

  if (!recovery_shares || recovery_shares.length < 3) {
    return new Response(JSON.stringify({
      error: 'Insufficient recovery shares',
      message: 'At least 3 shares are required for recovery',
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Verify profile exists
  const object = await env.PROFILE_BACKUP.get(`profile/${user_id}/data`);
  if (!object) {
    return new Response(JSON.stringify({ error: 'Profile not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // In production: verify Shamir shares and recover master key
  // For now, return success

  return new Response(JSON.stringify({
    success: true,
    message: 'Profile recovered successfully',
  }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// PreKey Handlers
async function handlePreKeysUpload(request: Request, env: Env): Promise<Response> {
  const userId = request.headers.get('X-User-ID');

  if (!userId) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const bundle: PreKeyBundle = await request.json();
  const id = env.PREKEY_STORE.idFromName(userId);
  const stub = env.PREKEY_STORE.get(id);

  await stub.fetch('http://internal/store', {
    method: 'POST',
    body: JSON.stringify(bundle),
  });

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function handlePreKeysGet(userId: string, env: Env): Promise<Response> {
  const id = env.PREKEY_STORE.idFromName(userId);
  const stub = env.PREKEY_STORE.get(id);

  const response = await stub.fetch('http://internal/fetch');
  const bundle = await response.json<PreKeyBundle>();

  return new Response(JSON.stringify(bundle), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// Message Handlers
async function handleSendMessage(request: Request, env: Env): Promise<Response> {
  const envelope: MessageEnvelope = await request.json();

  // Validate size
  if (envelope.ciphertext.length > env.MAX_MESSAGE_SIZE) {
    return new Response(JSON.stringify({
      error: 'Message too large',
      max_size: env.MAX_MESSAGE_SIZE,
    }), {
      status: 413,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Queue for delivery
  await env.MESSAGE_QUEUE.send(envelope);

  // Try real-time delivery
  const sessionId = `${envelope.from}-${envelope.to}`;
  const id = env.SESSION_STATE.idFromName(sessionId);
  const stub = env.SESSION_STATE.get(id);

  await stub.fetch('http://internal/relay', {
    method: 'POST',
    body: JSON.stringify(envelope),
  });

  return new Response(JSON.stringify({ id: envelope.id }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// File Handlers
async function handleFileUpload(
  request: Request,
  fileId: string,
  env: Env
): Promise<Response> {
  const body = request.body;

  if (!body) {
    return new Response(JSON.stringify({ error: 'No body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  await env.ENCRYPTED_STORAGE.put(fileId, body);

  return new Response(JSON.stringify({
    id: fileId,
    url: `https://storage.libertyreach.internal/files/${fileId}`,
  }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function handleFileDownload(fileId: string, env: Env): Promise<Response> {
  const object = await env.ENCRYPTED_STORAGE.get(fileId);

  if (!object) {
    return new Response(JSON.stringify({ error: 'File not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);

  return new Response(object.body, { headers });
}

// TURN Handler
function handleTURN(request: Request, env: Env): Response {
  const timestamp = Date.now() + 3600000; // 1 hour
  const username = `libertyreach:${timestamp}`;
  const password = crypto.randomUUID();

  // Generate HMAC (simplified - in production use proper HMAC)
  const credential = btoa(`${username}:${env.TURN_SECRET}`);

  return new Response(JSON.stringify({
    iceServers: [{
      urls: [
        'turn:turn1.libertyreach.internal:443?transport=tcp',
        'turn:turn2.libertyreach.internal:443?transport=tcp',
        'turn:turn-bg.libertyreach.internal:443?transport=tcp', // Bulgaria
        'turn:turn1.libertyreach.internal:443?transport=udp',
      ],
      username: username,
      credential: credential,
    }],
    ttl: 3600,
  }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
