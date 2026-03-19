/**
 * 🔐 Liberty Reach Messenger - Cloudflare Worker v0.7.3
 * "Immortal Love" Edition with Vault Protection
 * 
 * Features:
 * - Endpoints: /send, /messages, /delete, /health
 * - D1 Database with immutable love triggers
 * - Vault protection for eternal messages
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS headers for all responses
    const corsHeaders = {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Peer-ID, X-Signature',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // ═══════════════════════════════════════════════════════════════════════
      // ROUTE: GET /health
      // ═══════════════════════════════════════════════════════════════════════
      if (path === '/health' && request.method === 'GET') {
        return new Response(JSON.stringify({
          status: 'ok',
          service: 'Liberty Reach Edge',
          version: 'v0.7.3-immortal-love',
          timestamp: Date.now(),
          vault_protection: 'enabled'
        }), { headers: corsHeaders });
      }

      // ═══════════════════════════════════════════════════════════════════════
      // ROUTE: POST /send
      // Send encrypted message with optional "Love Token" flag
      // ═══════════════════════════════════════════════════════════════════════
      if (path === '/send' && request.method === 'POST') {
        const body = await request.json();
        const {
          sender_id,
          receiver_id,
          encrypted_text,
          nonce,
          signature = '',
          is_love_token = false,  // 🔐 LOVE TOKEN FLAG
          expires_at = null
        } = body;

        // Validation
        if (!sender_id || !receiver_id || !encrypted_text || !nonce) {
          return new Response(JSON.stringify({
            status: 'error',
            message: 'Missing required fields: sender_id, receiver_id, encrypted_text, nonce'
          }), { 
            status: 400,
            headers: corsHeaders 
          });
        }

        // Generate message ID
        const messageId = `msg-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        const createdAt = Date.now();

        try {
          // 🔐 VAULT LOGIC: If is_love_token = true, set is_immutable = 1
          // This message will be protected by database triggers
          // NOTE: DB uses recipient_id, we map receiver_id -> recipient_id
          await env.D1.prepare(`
            INSERT INTO messages (
              id, sender_id, recipient_id, encrypted_text, nonce, 
              signature, is_love_immutable, created_at, expires_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          `)
          .bind(
            messageId,
            sender_id,
            receiver_id,  // receiver_id maps to recipient_id in DB
            encrypted_text,
            nonce,
            signature,
            is_love_token ? 1 : 0,  // 🔐 Set is_immutable = 1 if love token
            createdAt,
            expires_at
          )
          .run();

          return new Response(JSON.stringify({
            status: 'success',
            message_id: messageId,
            is_immutable: is_love_token,
            vault_protected: is_love_token,
            created_at: createdAt
          }), { headers: corsHeaders });

        } catch (dbError) {
          // 🔐 CATCH TRIGGER ERROR: Database rejected the operation
          const errorMessage = dbError.message || String(dbError);
          
          // Check if it's a vault protection error
          if (errorMessage.includes('VAULT PROTECTED') || 
              errorMessage.includes('is_immutable=1') ||
              errorMessage.includes('eternal')) {
            
            console.log('🔒 VAULT BLOCKED:', errorMessage);
            
            return new Response(JSON.stringify({
              status: 'error',
              message: 'This record is eternal',
              vault_error: true,
              details: errorMessage
            }), { 
              status: 403,
              headers: corsHeaders 
            });
          }

          // Other database errors
          console.error('D1 Error:', dbError);
          return new Response(JSON.stringify({
            status: 'error',
            message: 'Database error',
            details: errorMessage
          }), { 
            status: 500,
            headers: corsHeaders 
          });
        }
      }

      // ═══════════════════════════════════════════════════════════════════════
      // ROUTE: GET /messages/:user_id
      // Get all messages for a user
      // ═══════════════════════════════════════════════════════════════════════
      if (path.startsWith('/messages/') && request.method === 'GET') {
        const userId = path.split('/')[2];

        if (!userId) {
          return new Response(JSON.stringify({
            status: 'error',
            message: 'User ID required'
          }), { 
            status: 400,
            headers: corsHeaders 
          });
        }

        const { results } = await env.D1.prepare(`
          SELECT
            id, sender_id, recipient_id as receiver_id, encrypted_text, nonce,
            signature, is_love_immutable, created_at, expires_at
          FROM messages
          WHERE (sender_id = ? OR recipient_id = ?)
            AND (deleted_at IS NULL OR deleted_at = 0)
          ORDER BY created_at DESC
          LIMIT 100
        `)
        .bind(userId, userId)
        .all();

        return new Response(JSON.stringify({
          status: 'success',
          count: results.length,
          messages: results.map(msg => ({
            ...msg,
            is_immutable: msg.is_love_immutable === 1,
            vault_protected: msg.is_love_immutable === 1
          }))
        }), { headers: corsHeaders });
      }

      // ═══════════════════════════════════════════════════════════════════════
      // ROUTE: DELETE /messages/:message_id
      // Soft delete a message (will be blocked by trigger if immutable)
      // ═══════════════════════════════════════════════════════════════════════
      if (path.startsWith('/messages/') && request.method === 'DELETE') {
        const messageId = path.split('/')[2];

        if (!messageId) {
          return new Response(JSON.stringify({
            status: 'error',
            message: 'Message ID required'
          }), { 
            status: 400,
            headers: corsHeaders 
          });
        }

        try {
          // Soft delete: set deleted_at timestamp
          const { success, meta } = await env.D1.prepare(`
            UPDATE messages 
            SET deleted_at = ? 
            WHERE id = ?
          `)
          .bind(Date.now(), messageId)
          .run();

          // Check if any rows were affected
          if (meta.rows_written === 0) {
            return new Response(JSON.stringify({
              status: 'error',
              message: 'Message not found or already deleted'
            }), { 
              status: 404,
              headers: corsHeaders 
            });
          }

          return new Response(JSON.stringify({
            status: 'success',
            message: 'Message deleted',
            message_id: messageId
          }), { headers: corsHeaders });

        } catch (dbError) {
          // 🔐 CATCH TRIGGER ERROR: Vault protection blocked the delete
          const errorMessage = dbError.message || String(dbError);
          
          if (errorMessage.includes('VAULT PROTECTED') || 
              errorMessage.includes('is_immutable=1') ||
              errorMessage.includes('eternal')) {
            
            console.log('🔒 VAULT BLOCKED DELETE:', errorMessage);
            
            return new Response(JSON.stringify({
              status: 'error',
              message: 'This record is eternal - cannot be deleted',
              vault_error: true,
              details: errorMessage
            }), { 
              status: 403,
              headers: corsHeaders 
            });
          }

          console.error('D1 Delete Error:', dbError);
          return new Response(JSON.stringify({
            status: 'error',
            message: 'Database error',
            details: errorMessage
          }), { 
            status: 500,
            headers: corsHeaders 
          });
        }
      }

      // ═══════════════════════════════════════════════════════════════════════
      // ROUTE: PUT /messages/:message_id
      // Update a message (will be blocked by trigger if immutable)
      // ═══════════════════════════════════════════════════════════════════════
      if (path.startsWith('/messages/') && request.method === 'PUT') {
        const messageId = path.split('/')[2];
        const body = await request.json();
        const { encrypted_text, nonce, signature } = body;

        if (!messageId || !encrypted_text || !nonce) {
          return new Response(JSON.stringify({
            status: 'error',
            message: 'Message ID, encrypted_text, and nonce required'
          }), { 
            status: 400,
            headers: corsHeaders 
          });
        }

        try {
          const { success, meta } = await env.D1.prepare(`
            UPDATE messages 
            SET encrypted_text = ?, nonce = ?, signature = ?
            WHERE id = ?
          `)
          .bind(encrypted_text, nonce, signature || '', messageId)
          .run();

          if (meta.rows_written === 0) {
            return new Response(JSON.stringify({
              status: 'error',
              message: 'Message not found'
            }), { 
              status: 404,
              headers: corsHeaders 
            });
          }

          return new Response(JSON.stringify({
            status: 'success',
            message: 'Message updated',
            message_id: messageId
          }), { headers: corsHeaders });

        } catch (dbError) {
          // 🔐 CATCH TRIGGER ERROR: Vault protection blocked the update
          const errorMessage = dbError.message || String(dbError);
          
          if (errorMessage.includes('VAULT PROTECTED') || 
              errorMessage.includes('is_immutable=1') ||
              errorMessage.includes('eternal')) {
            
            console.log('🔒 VAULT BLOCKED UPDATE:', errorMessage);
            
            return new Response(JSON.stringify({
              status: 'error',
              message: 'This record is eternal - cannot be modified',
              vault_error: true,
              details: errorMessage
            }), { 
              status: 403,
              headers: corsHeaders 
            });
          }

          console.error('D1 Update Error:', dbError);
          return new Response(JSON.stringify({
            status: 'error',
            message: 'Database error',
            details: errorMessage
          }), { 
            status: 500,
            headers: corsHeaders 
          });
        }
      }

      // ═══════════════════════════════════════════════════════════════════════
      // ROUTE: 404 for unknown paths
      // ═══════════════════════════════════════════════════════════════════════
      return new Response(JSON.stringify({
        status: 'error',
        message: 'Not found',
        path: path
      }), { 
        status: 404,
        headers: corsHeaders 
      });

    } catch (error) {
      console.error('Worker error:', error);
      return new Response(JSON.stringify({
        status: 'error',
        message: 'Internal server error',
        details: error.message
      }), { 
        status: 500,
        headers: corsHeaders 
      });
    }
  }
};
