/**
 * Durable Objects for Liberty Reach Messenger
 * 
 * - PreKeyStore: Store and distribute PreKey bundles
 * - SessionManager: Manage WebSocket connections and message relay
 * - ProfileManager: Manage permanent profiles
 */

// ============================================
// PREKEY STORE
// ============================================

export class PreKeyStore {
  private state: DurableObjectState;
  private bundle: PreKeyBundle | null = null;
  private oneTimeKeys: Map<number, string> = new Map();

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/store' && request.method === 'POST') {
      return this.store(request);
    }

    if (url.pathname === '/fetch' && request.method === 'GET') {
      return this.fetch();
    }

    if (url.pathname === '/consume-otk' && request.method === 'POST') {
      return this.consumeOneTimeKey();
    }

    return new Response('Not Found', { status: 404 });
  }

  private async store(request: Request): Promise<Response> {
    const data = await request.json<PreKeyBundle & { one_time_keys?: Array<{ key_id: number; key: string }> }>();
    this.bundle = data;

    if (data.one_time_keys) {
      for (const otk of data.one_time_keys) {
        this.oneTimeKeys.set(otk.key_id, otk.key);
      }
    }

    // Persist to storage
    await this.state.storage.put('bundle', this.bundle);
    await this.state.storage.put('otks', Array.from(this.oneTimeKeys.entries()));

    return new Response(JSON.stringify({ success: true }));
  }

  private async fetch(): Promise<Response> {
    // Load from storage if not in memory
    if (!this.bundle) {
      this.bundle = await this.state.storage.get('bundle');
      const otks = await this.state.storage.get<Array<[number, string]>>('otks');
      if (otks) {
        this.oneTimeKeys = new Map(otks);
      }
    }

    if (!this.bundle) {
      return new Response(JSON.stringify({ error: 'No prekeys found' }), { status: 404 });
    }

    // Return bundle with one OTK if available
    const response: PreKeyBundle = { ...this.bundle };
    
    if (this.oneTimeKeys.size > 0) {
      const [keyId, key] = this.oneTimeKeys.entries().next().value;
      response.one_time_keys = [{ key_id: keyId, key }];
      this.oneTimeKeys.delete(keyId);
      
      // Persist remaining OTKs
      await this.state.storage.put('otks', Array.from(this.oneTimeKeys.entries()));
    } else {
      response.one_time_keys = [];
    }

    return new Response(JSON.stringify(response));
  }

  private async consumeOneTimeKey(): Promise<Response> {
    if (this.oneTimeKeys.size === 0) {
      return new Response(JSON.stringify({ one_time_key: null }));
    }

    const [keyId, key] = this.oneTimeKeys.entries().next().value;
    this.oneTimeKeys.delete(keyId);

    await this.state.storage.put('otks', Array.from(this.oneTimeKeys.entries()));

    return new Response(JSON.stringify({
      key_id: keyId,
      key,
    }));
  }
}

// ============================================
// SESSION MANAGER
// ============================================

interface SessionInfo {
  session_id: string;
  user_id?: string;
  connected_at: number;
  websocket?: WebSocket;
}

export class SessionManager {
  private state: DurableObjectState;
  private connections: Map<string, SessionInfo> = new Map();

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/connect' && request.method === 'POST') {
      return this.connect(request);
    }

    if (url.pathname === '/disconnect' && request.method === 'POST') {
      return this.disconnect(request);
    }

    if (url.pathname === '/relay' && request.method === 'POST') {
      return this.relay(request);
    }

    if (url.pathname === '/status' && request.method === 'GET') {
      return this.status();
    }

    return new Response('Not Found', { status: 404 });
  }

  private async connect(request: Request): Promise<Response> {
    const data = await request.json<SessionInfo>();
    this.connections.set(data.session_id, data);

    console.log(`Session connected: ${data.session_id} (user: ${data.user_id || 'anonymous'})`);

    return new Response(JSON.stringify({ success: true }));
  }

  private async disconnect(request: Request): Promise<Response> {
    const data = await request.json<{ session_id: string }>();
    this.connections.delete(data.session_id);

    console.log(`Session disconnected: ${data.session_id}`);

    return new Response(JSON.stringify({ success: true }));
  }

  private async relay(request: Request): Promise<Response> {
    const message = await request.json();
    
    // Find recipient connection
    const recipientSession = `${message.from}-${message.to}`;
    const connection = this.connections.get(recipientSession);

    if (connection?.websocket && connection.websocket.readyState === WebSocket.OPEN) {
      connection.websocket.send(JSON.stringify(message));
      return new Response(JSON.stringify({ delivered: true }));
    }

    // Recipient not connected - message will be delivered via queue
    return new Response(JSON.stringify({ 
      delivered: false, 
      reason: 'recipient_offline' 
    }));
  }

  private async status(): Promise<Response> {
    return new Response(JSON.stringify({
      active_connections: this.connections.size,
      connections: Array.from(this.connections.values()),
    }));
  }
}

// ============================================
// PROFILE MANAGER
// ============================================

interface ProfileData {
  user_id: string;
  encrypted_data: string;
  status: 'active' | 'deactivated';
  created_at: number;
  last_seen: number;
}

export class ProfileManager {
  private state: DurableObjectState;
  private profile: ProfileData | null = null;

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/create' && request.method === 'POST') {
      return this.create(request);
    }

    if (url.pathname === '/get' && request.method === 'GET') {
      return this.get();
    }

    if (url.pathname === '/update' && request.method === 'PUT') {
      return this.update(request);
    }

    if (url.pathname === '/deactivate' && request.method === 'POST') {
      return this.deactivate();
    }

    if (url.pathname === '/reactivate' && request.method === 'POST') {
      return this.reactivate();
    }

    // ⛔ Deletion is NOT allowed
    if (url.pathname === '/delete' && request.method === 'POST') {
      return new Response(JSON.stringify({
        error: 'Profile deletion is NOT allowed',
        message: 'Profiles are permanent in Liberty Reach',
      }), { status: 403 });
    }

    return new Response('Not Found', { status: 404 });
  }

  private async create(request: Request): Promise<Response> {
    const data = await request.json<ProfileData>();
    
    // Check if already exists
    const existing = await this.state.storage.get<ProfileData>('profile');
    if (existing) {
      return new Response(JSON.stringify({
        error: 'Profile already exists',
        message: 'Use recovery mechanism if needed',
      }), { status: 409 });
    }

    this.profile = data;
    await this.state.storage.put('profile', data);

    return new Response(JSON.stringify({ success: true }));
  }

  private async get(): Promise<Response> {
    if (!this.profile) {
      this.profile = await this.state.storage.get<ProfileData>('profile');
    }

    if (!this.profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), { status: 404 });
    }

    if (this.profile.status === 'deactivated') {
      return new Response(JSON.stringify({
        error: 'Profile is deactivated',
        status: 'deactivated',
      }), { status: 403 });
    }

    // Update last_seen
    this.profile.last_seen = Date.now();
    await this.state.storage.put('profile', this.profile);

    return new Response(JSON.stringify(this.profile));
  }

  private async update(request: Request): Promise<Response> {
    const updates = await request.json<Partial<ProfileData>>();

    if (!this.profile) {
      this.profile = await this.state.storage.get<ProfileData>('profile');
    }

    if (!this.profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), { status: 404 });
    }

    // Update allowed fields
    if (updates.encrypted_data) {
      this.profile.encrypted_data = updates.encrypted_data;
    }
    this.profile.last_seen = Date.now();

    await this.state.storage.put('profile', this.profile);

    return new Response(JSON.stringify({ success: true }));
  }

  private async deactivate(): Promise<Response> {
    if (!this.profile) {
      this.profile = await this.state.storage.get<ProfileData>('profile');
    }

    if (!this.profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), { status: 404 });
    }

    this.profile.status = 'deactivated';
    await this.state.storage.put('profile', this.profile);

    return new Response(JSON.stringify({
      success: true,
      status: 'deactivated',
    }));
  }

  private async reactivate(): Promise<Response> {
    if (!this.profile) {
      this.profile = await this.state.storage.get<ProfileData>('profile');
    }

    if (!this.profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), { status: 404 });
    }

    this.profile.status = 'active';
    this.profile.last_seen = Date.now();
    await this.state.storage.put('profile', this.profile);

    return new Response(JSON.stringify({
      success: true,
      status: 'active',
    }));
  }
}

// ============================================
// TYPES
// ============================================

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
