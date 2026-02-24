/**
 * Durable Objects for Liberty Reach Messenger - Fixed Version
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
      return this.getBundle();
    }

    if (url.pathname === '/consume-otk' && request.method === 'POST') {
      return this.consumeOneTimeKey();
    }

    return new Response('Not Found', { status: 404 });
  }

  private async store(request: Request): Promise<Response> {
    const data = await request.json() as PreKeyBundle & { one_time_keys?: Array<{ key_id: number; key: string }> };
    this.bundle = data;

    if (data.one_time_keys) {
      for (const otk of data.one_time_keys) {
        this.oneTimeKeys.set(otk.key_id, otk.key);
      }
    }

    await this.state.storage.put('bundle', this.bundle);
    await this.state.storage.put('otks', Array.from(this.oneTimeKeys.entries()));

    return new Response(JSON.stringify({ success: true }));
  }

  private async getBundle(): Promise<Response> {
    if (!this.bundle) {
      this.bundle = await this.state.storage.get('bundle') as PreKeyBundle | null;
      const otks = await this.state.storage.get<Array<[number, string]>>('otks');
      if (otks) {
        this.oneTimeKeys = new Map(otks);
      }
    }

    if (!this.bundle) {
      return new Response(JSON.stringify({ error: 'No prekeys found' }), { status: 404 });
    }

    const response: PreKeyBundle = { ...this.bundle };

    if (this.oneTimeKeys.size > 0) {
      const entry = this.oneTimeKeys.entries().next();
      if (!entry.done) {
        const [keyId, key] = entry.value;
        response.one_time_keys = [{ key_id: keyId, key }];
        this.oneTimeKeys.delete(keyId);
        await this.state.storage.put('otks', Array.from(this.oneTimeKeys.entries()));
      }
    }

    return new Response(JSON.stringify(response));
  }

  private async consumeOneTimeKey(): Promise<Response> {
    if (this.oneTimeKeys.size === 0) {
      return new Response(JSON.stringify({ error: 'No OTKs available' }), { status: 404 });
    }

    const entry = this.oneTimeKeys.entries().next();
    if (!entry.done) {
      const [keyId, key] = entry.value;
      this.oneTimeKeys.delete(keyId);
      await this.state.storage.put('otks', Array.from(this.oneTimeKeys.entries()));
      return new Response(JSON.stringify({ key_id: keyId, key }));
    }

    return new Response(JSON.stringify({ error: 'No OTKs available' }), { status: 404 });
  }
}

// ============================================
// SESSION MANAGER
// ============================================

export class SessionManager {
  private connections: Map<string, WebSocket> = new Map();

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/connect' && request.method === 'POST') {
      const data = await request.json() as { session_id: string; user_id: string };
      this.connections.set(data.session_id, {} as WebSocket);
      return new Response(JSON.stringify({ success: true }));
    }

    if (url.pathname === '/relay' && request.method === 'POST') {
      const data = await request.json() as { from: string; to: string; message: string };
      // Find recipient connection and relay
      for (const [sessionId, ws] of this.connections.entries()) {
        if (sessionId.startsWith(data.to)) {
          ws?.send(JSON.stringify(data));
        }
      }
      return new Response(JSON.stringify({ success: true }));
    }

    return new Response('Not Found', { status: 404 });
  }
}

// ============================================
// PROFILE MANAGER
// ============================================

export class ProfileManager {
  private state: DurableObjectState;
  private profile: ProfileData | null = null;

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/get' && request.method === 'GET') {
      return this.getProfile();
    }

    if (url.pathname === '/update' && request.method === 'PUT') {
      return this.updateProfile(request);
    }

    if (url.pathname === '/delete' && request.method === 'DELETE') {
      return this.deleteProfile();
    }

    return new Response('Not Found', { status: 404 });
  }

  private async getProfile(): Promise<Response> {
    if (!this.profile) {
      this.profile = await this.state.storage.get('profile') as ProfileData | null;
    }

    if (!this.profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), { status: 404 });
    }

    return new Response(JSON.stringify(this.profile));
  }

  private async updateProfile(request: Request): Promise<Response> {
    const updates = await request.json() as Partial<ProfileData>;
    
    if (!this.profile) {
      this.profile = updates as ProfileData;
    } else {
      this.profile = { ...this.profile, ...updates };
    }

    await this.state.storage.put('profile', this.profile);
    return new Response(JSON.stringify(this.profile));
  }

  private async deleteProfile(): Promise<Response> {
    // Profiles are permanent - reject deletion
    return new Response(JSON.stringify({ error: 'Profile deletion not allowed' }), { status: 403 });
  }
}

// Type definitions
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

interface ProfileData {
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
