/**
 * 🔔 Push Notification Server
 * Cloudflare Worker + Firebase Cloud Messaging
 * 
 * Features:
 * - Register device tokens
 * - Send push notifications
 * - Topic-based subscriptions
 * - Scheduled notifications
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS headers
    const corsHeaders = {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // ═══════════════════════════════════════════════════════════════════════
      // ROUTE: POST /push/register
      // Register device token for push notifications
      // ═══════════════════════════════════════════════════════════════════════
      if (path === '/push/register' && request.method === 'POST') {
        const body = await request.json();
        const { user_id, device_token, device_type = 'android' } = body;

        if (!user_id || !device_token) {
          return new Response(JSON.stringify({
            status: 'error',
            message: 'Missing user_id or device_token'
          }), { status: 400, headers: corsHeaders });
        }

        // Store in D1
        await env.D1.prepare(`
          INSERT INTO push_tokens (user_id, device_token, device_type, created_at)
          VALUES (?, ?, ?, strftime('%s', 'now') * 1000)
          ON CONFLICT(user_id, device_token) DO UPDATE SET
            device_type = excluded.device_type,
            last_seen = strftime('%s', 'now') * 1000
        `).bind(user_id, device_token, device_type).run();

        return new Response(JSON.stringify({
          status: 'success',
          message: 'Device registered'
        }), { headers: corsHeaders });
      }

      // ═══════════════════════════════════════════════════════════════════════
      // ROUTE: POST /push/send
      // Send push notification to user
      // ═══════════════════════════════════════════════════════════════════════
      if (path === '/push/send' && request.method === 'POST') {
        const body = await request.json();
        const {
          user_id,
          title,
          body: messageBody,
          data = {},
          priority = 'high'
        } = body;

        if (!user_id || !title || !messageBody) {
          return new Response(JSON.stringify({
            status: 'error',
            message: 'Missing required fields'
          }), { status: 400, headers: corsHeaders });
        }

        // Get user's device tokens from D1
        const { results } = await env.D1.prepare(`
          SELECT device_token, device_type FROM push_tokens
          WHERE user_id = ? AND last_seen > (strftime('%s', 'now') - 30*24*60*60) * 1000
        `).bind(user_id).all();

        if (!results || results.length === 0) {
          return new Response(JSON.stringify({
            status: 'success',
            message: 'No active devices found',
            sent: 0
          }), { headers: corsHeaders });
        }

        // Send to FCM
        const fcmPromises = results.map(async (token) => {
          try {
            await sendFCMNotification({
              token: token.device_token,
              title,
              body: messageBody,
              data,
              priority,
              fcmKey: env.FCM_SERVER_KEY,
            });
            return true;
          } catch (error) {
            console.error('FCM send error:', error);
            return false;
          }
        });

        const results_array = await Promise.all(fcmPromises);
        const sentCount = results_array.filter(r => r).length;

        return new Response(JSON.stringify({
          status: 'success',
          message: `Sent to ${sentCount}/${results.length} devices`,
          sent: sentCount,
          total: results.length
        }), { headers: corsHeaders });
      }

      // ═══════════════════════════════════════════════════════════════════════
      // ROUTE: POST /push/broadcast
      // Send push to all users (for announcements)
      // ═══════════════════════════════════════════════════════════════════════
      if (path === '/push/broadcast' && request.method === 'POST') {
        const body = await request.json();
        const { title, body: messageBody, data = {} } = body;

        // Get all active tokens
        const { results } = await env.D1.prepare(`
          SELECT DISTINCT device_token, device_type FROM push_tokens
          WHERE last_seen > (strftime('%s', 'now') - 30*24*60*60) * 1000
        `).all();

        if (!results || results.length === 0) {
          return new Response(JSON.stringify({
            status: 'success',
            message: 'No active devices found',
            sent: 0
          }), { headers: corsHeaders });
        }

        // Send to all
        const fcmPromises = results.map(async (token) => {
          try {
            await sendFCMNotification({
              token: token.device_token,
              title,
              body: messageBody,
              data,
              fcmKey: env.FCM_SERVER_KEY,
            });
            return true;
          } catch (error) {
            return false;
          }
        });

        const results_array = await Promise.all(fcmPromises);
        const sentCount = results_array.filter(r => r).length;

        return new Response(JSON.stringify({
          status: 'success',
          message: `Broadcast sent to ${sentCount}/${results.length} devices`,
          sent: sentCount,
          total: results.length
        }), { headers: corsHeaders });
      }

      // ═══════════════════════════════════════════════════════════════════════
      // ROUTE: DELETE /push/unregister
      // Unregister device token
      // ═══════════════════════════════════════════════════════════════════════
      if (path === '/push/unregister' && request.method === 'DELETE') {
        const body = await request.json();
        const { user_id, device_token } = body;

        await env.D1.prepare(`
          DELETE FROM push_tokens
          WHERE user_id = ? AND device_token = ?
        `).bind(user_id, device_token).run();

        return new Response(JSON.stringify({
          status: 'success',
          message: 'Device unregistered'
        }), { headers: corsHeaders });
      }

      // ═══════════════════════════════════════════════════════════════════════
      // ROUTE: GET /health
      // Health check
      // ═══════════════════════════════════════════════════════════════════════
      if (path === '/health' && request.method === 'GET') {
        return new Response(JSON.stringify({
          status: 'ok',
          service: 'Liberty Reach Push',
          version: 'v0.7.9',
          timestamp: Date.now()
        }), { headers: corsHeaders });
      }

      // 404
      return new Response(JSON.stringify({
        status: 'error',
        message: 'Not found'
      }), { status: 404, headers: corsHeaders });

    } catch (error) {
      console.error('Worker error:', error);
      return new Response(JSON.stringify({
        status: 'error',
        message: 'Internal server error',
        details: error.message
      }), { status: 500, headers: corsHeaders });
    }
  }
};

/**
 * Send notification via Firebase Cloud Messaging
 */
async function sendFCMNotification({ token, title, body, data, priority = 'high', fcmKey }) {
  const fcmUrl = 'https://fcm.googleapis.com/fcm/send';

  const payload = {
    to: token,
    notification: {
      title,
      body,
      sound: 'default',
      badge: '1',
    },
    data: data || {},
    priority,
    content_available: true,
  };

  const response = await fetch(fcmUrl, {
    method: 'POST',
    headers: {
      'Authorization': `key=${fcmKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`FCM error: ${response.status} - ${error}`);
  }

  return await response.json();
}
