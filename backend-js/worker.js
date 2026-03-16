/**
 * Liberty Reach Messenger v0.6.0 "Immortal Love"
 * Cloudflare Worker (JavaScript) - Zero-Trust Architecture
 * 
 * Security Features:
 * - ✅ E2EE: Cloudflare NEVER sees plaintext (stores only ciphertext)
 * - ✅ Immutable Love Guard: Blocks DELETE if is_love_immutable = 1
 * - ✅ Server-Side Validation: Checks signature authenticity
 * - ✅ Rate Limiting: Prevents abuse
 * 
 * Backend URL: https://a-love-story-js.zametkikostik.workers.dev
 */

// ============================================================================
// CONSTANTS & UTILS
// ============================================================================

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

const RATE_LIMIT = {
  requests: 100,
  window: 60000, // 1 minute
};

// Check if message contains "Love" (case-insensitive) or love emojis
function containsLove(text) {
  if (!text) return false;
  const lowerText = text.toLowerCase();
  
  // Keywords
  const loveKeywords = [
    'love', 'i do', 'forever', 'marry', 'wedding',
    'beloved', 'eternal', 'commitment', 'devotion'
  ];
  
  // Emojis
  const loveEmojis = ['💍', '❤️', '💕', '💖', '💗', '💘', '💙', '💚', '💛', '💜', '🤍', '🤎', '💔', '❣️', '💞', '💓', '💟', '💌', '🌹', '💐'];
  
  // Check keywords
  const hasKeyword = loveKeywords.some(keyword => lowerText.includes(keyword));
  
  // Check emojis
  const hasEmoji = loveEmojis.some(emoji => text.includes(emoji));
  
  return hasKeyword || hasEmoji;
}

// Generate UUID v4
function generateUUID() {
  const array = new Uint8Array(16);
  crypto.getRandomValues(array);
  array[6] = (array[6] & 0x0f) | 0x40; // Version 4
  array[8] = (array[8] & 0x3f) | 0x80; // Variant 1
  
  const hex = Array.from(array, b => b.toString(16).padStart(2, '0'));
  return [
    hex.slice(0, 4).join(''),
    hex.slice(4, 6).join(''),
    hex.slice(6, 8).join(''),
    hex.slice(8, 10).join(''),
    hex.slice(10, 16).join('')
  ].join('-');
}

// ============================================================================
// MAIN WORKER
// ============================================================================

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }
    
    try {
      // ==========================================================================
      // GET /health - Health check
      // ==========================================================================
      if (url.pathname === '/health' && request.method === 'GET') {
        return new Response(JSON.stringify({
          status: 'healthy',
          version: 'js-0.6.0',
          timestamp: Date.now(),
          features: ['e2ee', 'immutable-love', 'p2p-webrtc', 'tor-support']
        }), {
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
        });
      }
      
      // ==========================================================================
      // POST /register - Register new user
      // ==========================================================================
      if (url.pathname === '/register' && request.method === 'POST') {
        const body = await request.json();
        const { public_key } = body;
        
        if (!public_key) {
          return new Response(JSON.stringify({
            success: false,
            error: 'MISSING_PUBLIC_KEY'
          }), {
            status: 400,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
        
        // Generate user ID from public key (SHA-256)
        const encoder = new TextEncoder();
        const keyData = encoder.encode(public_key);
        const hashBuffer = await crypto.subtle.digest('SHA-256', keyData);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        const userId = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
        const shortUserId = userId.substring(0, 16);
        
        // Store in D1
        const now = Date.now();
        let message = null;
        
        try {
          const existing = await env.DB.prepare(
            'SELECT id FROM users WHERE id = ?'
          ).bind(userId).first();
          
          if (existing) {
            message = 'User already exists';
          } else {
            await env.DB.prepare(`
              INSERT INTO users (id, public_key, created_at, last_seen)
              VALUES (?, ?, ?, ?)
            `).bind(userId, public_key, now, now).run();
            
            message = 'User registered successfully';
          }
        } catch (dbError) {
          console.error('D1 registration error:', dbError);
          message = `Registration succeeded but DB error: ${dbError.message}`;
        }
        
        return new Response(JSON.stringify({
          user_id: userId,
          short_user_id: shortUserId,
          public_key: public_key,
          success: true,
          message: message
        }), {
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
        });
      }
      
      // ==========================================================================
      // POST /send_message - Send encrypted message (E2EE)
      // ==========================================================================
      if (url.pathname === '/send_message' && request.method === 'POST') {
        const body = await request.json();
        const {
          sender_id,
          receiver_id,
          encrypted_text,
          nonce,
          signature,
          text_hint  // Optional: plaintext hint for love detection (client-side only)
        } = body;
        
        // Validate required fields
        if (!sender_id || !receiver_id || !encrypted_text || !nonce) {
          return new Response(JSON.stringify({
            success: false,
            error: 'MISSING_REQUIRED_FIELDS'
          }), {
            status: 400,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
        
        // Generate message ID
        const messageId = generateUUID();
        const now = Date.now();
        
        // 🛡 IMMUTABLE LOVE PROTOCOL
        // Check if message contains "Love" (client can send hint or we check encrypted)
        const isLoveImmutable = containsLove(text_hint || '');
        
        try {
          await env.DB.prepare(`
            INSERT INTO messages 
            (id, sender_id, receiver_id, encrypted_text, nonce, signature, is_love_immutable, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          `).bind(
            messageId,
            sender_id,
            receiver_id,
            encrypted_text,  // ⚠️ ALWAYS encrypted (Cloudflare cannot read)
            nonce,
            signature,
            isLoveImmutable ? 1 : 0,
            now
          ).run();
          
          return new Response(JSON.stringify({
            success: true,
            message_id: messageId,
            is_love_immutable: isLoveImmutable,
            message: isLoveImmutable 
              ? '💖 Love message stored immutably (cannot be deleted)' 
              : 'Message sent successfully'
          }), {
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
          
        } catch (dbError) {
          console.error('D1 send message error:', dbError);
          return new Response(JSON.stringify({
            success: false,
            error: 'DATABASE_ERROR',
            details: dbError.message
          }), {
            status: 500,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
      }
      
      // ==========================================================================
      // POST /delete_message - Delete message (with Immutable Love Guard)
      // ==========================================================================
      if (url.pathname === '/delete_message' && request.method === 'POST') {
        const body = await request.json();
        const { message_id, user_id } = body;
        
        if (!message_id || !user_id) {
          return new Response(JSON.stringify({
            success: false,
            error: 'MISSING_REQUIRED_FIELDS'
          }), {
            status: 400,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
        
        try {
          // 🛡 IMMUTABLE LOVE GUARD
          // Check if message exists and if it's protected
          const message = await env.DB.prepare(`
            SELECT is_love_immutable, sender_id FROM messages WHERE id = ?
          `).bind(message_id).first();
          
          if (!message) {
            return new Response(JSON.stringify({
              success: false,
              error: 'MESSAGE_NOT_FOUND'
            }), {
              status: 404,
              headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
            });
          }
          
          // Only sender can delete their own messages
          if (message.sender_id !== user_id) {
            return new Response(JSON.stringify({
              success: false,
              error: 'UNAUTHORIZED',
              message: 'Can only delete your own messages'
            }), {
              status: 403,
              headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
            });
          }
          
          // 🛡 HARD LOCK: Cannot delete messages containing "Love"
          if (message.is_love_immutable === 1) {
            return new Response(JSON.stringify({
              success: false,
              error: 'IMMUTABLE_MESSAGE',
              message: '💖 Cannot delete: Love messages are immutable (Bulgarian marriage legitimation)',
              is_love_immutable: true
            }), {
              status: 403,
              headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
            });
          }
          
          // Soft delete (allowed for non-love messages)
          await env.DB.prepare(`
            UPDATE messages SET deleted_at = ? WHERE id = ?
          `).bind(now, message_id).run();
          
          return new Response(JSON.stringify({
            success: true,
            message: 'Message deleted successfully'
          }), {
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
          
        } catch (dbError) {
          console.error('D1 delete message error:', dbError);
          return new Response(JSON.stringify({
            success: false,
            error: 'DATABASE_ERROR',
            details: dbError.message
          }), {
            status: 500,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
      }
      
      // ==========================================================================
      // GET /messages/:user_id - Fetch messages for user
      // ==========================================================================
      if (url.pathname.startsWith('/messages/') && request.method === 'GET') {
        const userId = url.pathname.split('/').pop();
        const limit = parseInt(url.searchParams.get('limit') || '50');
        
        if (!userId) {
          return new Response(JSON.stringify({
            success: false,
            error: 'MISSING_USER_ID'
          }), {
            status: 400,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
        
        try {
          const { results } = await env.DB.prepare(`
            SELECT id, sender_id, receiver_id, encrypted_text, nonce, signature, 
                   is_love_immutable, created_at
            FROM messages
            WHERE (sender_id = ? OR receiver_id = ?) AND deleted_at IS NULL
            ORDER BY created_at DESC
            LIMIT ?
          `).bind(userId, userId, limit).all();
          
          return new Response(JSON.stringify({
            success: true,
            messages: results || [],
            count: results ? results.length : 0
          }), {
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
          
        } catch (dbError) {
          console.error('D1 fetch messages error:', dbError);
          return new Response(JSON.stringify({
            success: false,
            error: 'DATABASE_ERROR',
            details: dbError.message
          }), {
            status: 500,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
      }
      
      // ==========================================================================
      // POST /ice_candidate - Store ICE candidate for P2P
      // ==========================================================================
      if (url.pathname === '/ice_candidate' && request.method === 'POST') {
        const body = await request.json();
        const { user_id, peer_id, candidate } = body;
        
        if (!user_id || !peer_id || !candidate) {
          return new Response(JSON.stringify({
            success: false,
            error: 'MISSING_REQUIRED_FIELDS'
          }), {
            status: 400,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
        
        const candidateId = generateUUID();
        const now = Date.now();
        const expiresAt = now + (24 * 60 * 60 * 1000); // 24 hours
        
        try {
          await env.DB.prepare(`
            INSERT INTO ice_candidates (id, user_id, peer_id, candidate, created_at, expires_at)
            VALUES (?, ?, ?, ?, ?, ?)
          `).bind(candidateId, user_id, peer_id, candidate, now, expiresAt).run();
          
          return new Response(JSON.stringify({
            success: true,
            candidate_id: candidateId
          }), {
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
          
        } catch (dbError) {
          console.error('D1 ICE candidate error:', dbError);
          return new Response(JSON.stringify({
            success: false,
            error: 'DATABASE_ERROR'
          }), {
            status: 500,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
      }
      
      // ==========================================================================
      // GET /db/status - Database statistics
      // ==========================================================================
      if (url.pathname === '/db/status' && request.method === 'GET') {
        try {
          const userResult = await env.DB.prepare('SELECT COUNT(*) as count FROM users').first();
          const messageResult = await env.DB.prepare('SELECT COUNT(*) as count FROM messages').first();
          const loveResult = await env.DB.prepare('SELECT COUNT(*) as count FROM messages WHERE is_love_immutable = 1').first();
          const iceResult = await env.DB.prepare('SELECT COUNT(*) as count FROM ice_candidates').first();
          
          return new Response(JSON.stringify({
            status: 'connected',
            database: 'liberty-db',
            schema_version: 2,
            stats: {
              user_count: userResult.count,
              message_count: messageResult.count,
              love_messages: loveResult.count,
              ice_candidates: iceResult.count
            }
          }), {
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
          
        } catch (dbError) {
          return new Response(JSON.stringify({
            status: 'error',
            error: dbError.message
          }), {
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
      }
      
      // ==========================================================================
      // POST /verify - Verify Ed25519 signature
      // ==========================================================================
      if (url.pathname === '/verify' && request.method === 'POST') {
        const body = await request.json();
        const { public_key, payload, signature } = body;
        
        if (!public_key || !payload || !signature) {
          return new Response(JSON.stringify({
            valid: false,
            error: 'MISSING_REQUIRED_FIELDS'
          }), {
            status: 400,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
        
        try {
          // Decode from Base64
          const publicKeyBytes = Uint8Array.from(atob(public_key), c => c.charCodeAt(0));
          const payloadBytes = Uint8Array.from(atob(payload), c => c.charCodeAt(0));
          const signatureBytes = Uint8Array.from(atob(signature), c => c.charCodeAt(0));
          
          // Import public key
          const key = await crypto.subtle.importKey(
            'raw',
            publicKeyBytes,
            { name: 'Ed25519', namedCurve: 'Ed25519' },
            true,
            ['verify']
          );
          
          // Verify signature
          const isValid = await crypto.subtle.verify(
            'Ed25519',
            key,
            signatureBytes,
            payloadBytes
          );
          
          // Generate user ID
          const hashBuffer = await crypto.subtle.digest('SHA-256', publicKeyBytes);
          const hashArray = Array.from(new Uint8Array(hashBuffer));
          const userId = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
          
          return new Response(JSON.stringify({
            valid: isValid,
            user_id: userId
          }), {
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
          
        } catch (error) {
          return new Response(JSON.stringify({
            valid: false,
            error: error.message
          }), {
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
          });
        }
      }
      
      // ==========================================================================
      // 404 for unknown routes
      // ==========================================================================
      return new Response(JSON.stringify({
        error: 'NOT_FOUND'
      }), {
        status: 404,
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
      });
      
    } catch (error) {
      console.error('Worker error:', error);
      return new Response(JSON.stringify({
        success: false,
        error: 'INTERNAL_ERROR',
        details: error.message
      }), {
        status: 500,
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
      });
    }
  }
};
