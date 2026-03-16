/**
 * A Love Story - Cloudflare Worker v0.6.0 (JavaScript)
 * 
 * Features:
 * - Ed25519 signature verification
 * - D1 database storage
 * - 🛡 Immutable Love Protocol (messages with "Love" cannot be deleted)
 * - 🔐 Message encryption endpoints
 * 
 * Backend URL: https://a-love-story-js.zametkikostik.workers.dev
 */

// Convert Base64 to Uint8Array
function base64ToBytes(base64) {
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

// Convert bytes to Base64
function bytesToBase64(bytes) {
  const binary = String.fromCharCode.apply(null, bytes);
  return btoa(binary);
}

// Convert bytes to hex string
function bytesToHex(bytes) {
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');
}

// SHA-256 hash
async function sha256(data) {
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = new Uint8Array(hashBuffer);
  return bytesToHex(hashArray);
}

// Get user ID from public key (SHA-256 hash)
async function getUserId(publicKeyBytes) {
  return await sha256(publicKeyBytes);
}

// Verify Ed25519 signature using crypto.subtle
async function verifyEd25519(publicKeyBytes, messageBytes, signatureBytes) {
  try {
    const key = await crypto.subtle.importKey(
      'raw',
      publicKeyBytes,
      { name: 'Ed25519', namedCurve: 'Ed25519' },
      true,
      ['verify']
    );

    const isValid = await crypto.subtle.verify(
      'Ed25519',
      key,
      signatureBytes,
      messageBytes
    );

    return isValid;
  } catch (error) {
    console.error('Verification error:', error);
    return false;
  }
}

// Generate unique message ID
function generateMessageId() {
  const array = new Uint8Array(16);
  crypto.getRandomValues(array);
  return Array.from(array, b => b.toString(16).padStart(2, '0')).join('');
}

// Check if message contains "Love" (case-insensitive)
function containsLove(text) {
  return /\blove\b/i.test(text);
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // Handle OPTIONS (CORS preflight)
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Health check
    if (url.pathname === '/health' && request.method === 'GET') {
      return new Response(JSON.stringify({
        status: 'ok',
        service: 'A Love Story',
        database: 'connected',
        version: 'js-0.6.0',
        features: ['immutable-love', 'encrypted-messages']
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Register user
    if (url.pathname === '/register' && request.method === 'POST') {
      try {
        const body = await request.json();
        const publicKeyBase64 = body.public_key;

        if (!publicKeyBase64) {
          return new Response(JSON.stringify({
            success: false,
            error: 'Missing public_key'
          }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const publicKeyBytes = base64ToBytes(publicKeyBase64);
        
        if (publicKeyBytes.length !== 32) {
          return new Response(JSON.stringify({
            success: false,
            error: 'Invalid public key length (expected 32 bytes)'
          }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const userId = await getUserId(publicKeyBytes);
        const shortUserId = userId.substring(0, 16);

        // Store in D1
        let message = null;
        try {
          const existing = await env.DB.prepare('SELECT id FROM users WHERE id = ?')
            .bind(userId)
            .first();

          if (existing) {
            message = 'User already exists';
          } else {
            await env.DB.prepare('INSERT INTO users (id, public_key) VALUES (?, ?)')
              .bind(userId, publicKeyBase64)
              .run();
            message = 'User registered in database';
          }
        } catch (dbError) {
          console.error('D1 error:', dbError);
          message = `Registration succeeded but DB error: ${dbError.message}`;
        }

        return new Response(JSON.stringify({
          user_id: userId,
          short_user_id: shortUserId,
          success: true,
          message: message
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });

      } catch (error) {
        return new Response(JSON.stringify({
          success: false,
          error: error.message
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
    }

    // Send message (NEW in v0.6.0)
    if (url.pathname === '/send_message' && request.method === 'POST') {
      try {
        const body = await request.json();
        const senderId = body.sender_id;
        const recipientId = body.recipient_id;
        const encryptedText = body.encrypted_text;
        const nonce = body.nonce;

        if (!senderId || !recipientId || !encryptedText || !nonce) {
          return new Response(JSON.stringify({
            success: false,
            error: 'Missing required fields (sender_id, recipient_id, encrypted_text, nonce)'
          }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const messageId = generateMessageId();
        
        // 🛡 IMMUTABLE LOVE PROTOCOL
        // Decrypt to check if message contains "Love" (for demonstration)
        // In production, this would be done client-side and the flag sent encrypted
        const isLoveImmutable = containsLove(body.text_hint || '');

        try {
          await env.DB.prepare(`
            INSERT INTO messages (id, sender_id, recipient_id, encrypted_text, nonce, is_love_immutable)
            VALUES (?, ?, ?, ?, ?, ?)
          `).bind(messageId, senderId, recipientId, encryptedText, nonce, isLoveImmutable ? 1 : 0).run();

          return new Response(JSON.stringify({
            success: true,
            message_id: messageId,
            is_love_immutable: isLoveImmutable,
            message: isLoveImmutable ? '💖 Love message stored immutably' : 'Message stored'
          }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });

        } catch (dbError) {
          console.error('D1 error:', dbError);
          return new Response(JSON.stringify({
            success: false,
            error: `Database error: ${dbError.message}`
          }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

      } catch (error) {
        return new Response(JSON.stringify({
          success: false,
          error: error.message
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
    }

    // Delete message (with Immutable Love protection)
    if (url.pathname === '/delete_message' && request.method === 'POST') {
      try {
        const body = await request.json();
        const messageId = body.message_id;
        const userId = body.user_id;

        if (!messageId || !userId) {
          return new Response(JSON.stringify({
            success: false,
            error: 'Missing required fields (message_id, user_id)'
          }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        try {
          // 🛡 IMMUTABLE LOVE PROTOCOL
          // Check if message contains "Love" - if so, it CANNOT be deleted
          const message = await env.DB.prepare(`
            SELECT is_love_immutable, sender_id FROM messages WHERE id = ?
          `).bind(messageId).first();

          if (!message) {
            return new Response(JSON.stringify({
              success: false,
              error: 'Message not found'
            }), {
              status: 404,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
          }

          // Only sender can delete their own messages
          if (message.sender_id !== userId) {
            return new Response(JSON.stringify({
              success: false,
              error: 'Unauthorized: Can only delete your own messages'
            }), {
              status: 403,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
          }

          // 🛡 HARD LOCK: Cannot delete messages containing "Love"
          if (message.is_love_immutable === 1) {
            return new Response(JSON.stringify({
              success: false,
              error: '💖 Cannot delete: Love messages are immutable (Bulgarian marriage legitimation)',
              is_love_immutable: true
            }), {
              status: 403,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
          }

          // Soft delete (allowed for non-love messages)
          await env.DB.prepare(`
            UPDATE messages SET deleted_at = CURRENT_TIMESTAMP WHERE id = ?
          `).bind(messageId).run();

          return new Response(JSON.stringify({
            success: true,
            message: 'Message deleted'
          }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });

        } catch (dbError) {
          console.error('D1 error:', dbError);
          return new Response(JSON.stringify({
            success: false,
            error: `Database error: ${dbError.message}`
          }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

      } catch (error) {
        return new Response(JSON.stringify({
          success: false,
          error: error.message
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
    }

    // Get messages for user
    if (url.pathname === '/messages' && request.method === 'GET') {
      try {
        const userId = url.searchParams.get('user_id');
        const limit = parseInt(url.searchParams.get('limit') || '50');

        if (!userId) {
          return new Response(JSON.stringify({
            success: false,
            error: 'Missing user_id parameter'
          }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const { results } = await env.DB.prepare(`
          SELECT id, sender_id, recipient_id, encrypted_text, nonce, is_love_immutable, created_at
          FROM messages
          WHERE (sender_id = ? OR recipient_id = ?) AND deleted_at IS NULL
          ORDER BY created_at DESC
          LIMIT ?
        `).bind(userId, userId, limit).all();

        return new Response(JSON.stringify({
          success: true,
          messages: results || [],
          count: results ? results.length : 0
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });

      } catch (error) {
        return new Response(JSON.stringify({
          success: false,
          error: error.message
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
    }

    // Verify signature
    if (url.pathname === '/verify' && request.method === 'POST') {
      try {
        const body = await request.json();
        const publicKeyBase64 = body.public_key;
        const payloadBase64 = body.payload;
        const signatureBase64 = body.signature;

        if (!publicKeyBase64 || !payloadBase64 || !signatureBase64) {
          return new Response(JSON.stringify({
            valid: false,
            error: 'Missing required fields'
          }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const publicKeyBytes = base64ToBytes(publicKeyBase64);
        const payloadBytes = base64ToBytes(payloadBase64);
        const signatureBytes = base64ToBytes(signatureBase64);

        if (publicKeyBytes.length !== 32) {
          return new Response(JSON.stringify({
            valid: false,
            error: 'Invalid public key length'
          }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        if (signatureBytes.length !== 64) {
          return new Response(JSON.stringify({
            valid: false,
            error: 'Invalid signature length'
          }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const isValid = await verifyEd25519(publicKeyBytes, payloadBytes, signatureBytes);
        const userId = await getUserId(publicKeyBytes);

        if (isValid) {
          return new Response(JSON.stringify({
            valid: true,
            user_id: userId
          }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        } else {
          return new Response(JSON.stringify({
            valid: false,
            error: 'Bad signature'
          }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

      } catch (error) {
        return new Response(JSON.stringify({
          valid: false,
          error: error.message
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
    }

    // DB Status endpoint
    if (url.pathname === '/db/status' && request.method === 'GET') {
      try {
        const userResult = await env.DB.prepare('SELECT COUNT(*) as count FROM users').first();
        const messageResult = await env.DB.prepare('SELECT COUNT(*) as count FROM messages').first();
        const loveResult = await env.DB.prepare('SELECT COUNT(*) as count FROM messages WHERE is_love_immutable = 1').first();

        return new Response(JSON.stringify({
          status: 'connected',
          database: 'liberty-db',
          user_count: userResult.count,
          message_count: messageResult.count,
          love_messages: loveResult.count,
          schema_version: 2
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      } catch (error) {
        return new Response(JSON.stringify({
          status: 'error',
          error: error.message
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
    }

    // 404 for unknown routes
    return new Response(JSON.stringify({
      error: 'Not found'
    }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
};
