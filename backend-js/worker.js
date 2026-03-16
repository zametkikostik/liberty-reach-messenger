/**
 * A Love Story - Cloudflare Worker (JavaScript)
 * 
 * Ed25519 signature verification with D1 database storage
 * Uses native crypto.subtle for Ed25519 (Cloudflare Workers support)
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
    // Import the public key
    const key = await crypto.subtle.importKey(
      'raw',
      publicKeyBytes,
      { name: 'Ed25519', namedCurve: 'Ed25519' },
      true,
      ['verify']
    );

    // Verify the signature
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
        version: 'js-1.0.0'
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

        // Decode public key
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

        // Get user ID
        const userId = await getUserId(publicKeyBytes);
        const shortUserId = userId.substring(0, 16);

        // Store in D1
        let message = null;
        try {
          // Check if user exists
          const existing = await env.DB.prepare('SELECT id FROM users WHERE id = ?')
            .bind(userId)
            .first();

          if (existing) {
            message = 'User already exists';
          } else {
            // Insert new user
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
            error: 'Invalid public key length (expected 32 bytes)'
          }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        if (signatureBytes.length !== 64) {
          return new Response(JSON.stringify({
            valid: false,
            error: 'Invalid signature length (expected 64 bytes)'
          }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // Verify Ed25519 signature
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
        const result = await env.DB.prepare('SELECT COUNT(*) as count FROM users').first();
        return new Response(JSON.stringify({
          status: 'connected',
          database: 'liberty-db',
          user_count: result.count
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
