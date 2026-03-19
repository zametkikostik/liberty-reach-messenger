/**
 * 🔌 WebSocket Server for Liberty Reach
 * Real-time message synchronization
 * 
 * Deploy to Cloudflare Workers
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    
    // Upgrade to WebSocket
    if (url.pathname === '/ws') {
      return handleWebSocket(request, env);
    }
    
    // Health check
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({
        status: 'ok',
        websocket: 'ready',
        timestamp: Date.now()
      }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    return new Response('Not found', { status: 404 });
  }
};

/**
 * Handle WebSocket upgrade
 */
function handleWebSocket(request, env) {
  const [client, server] = Object.values(new WebSocketPair());
  
  server.accept();
  
  console.log('📡 New WebSocket connection');
  
  const channels = new Map(); // chatId -> Set<userId>
  
  server.addEventListener('message', async (event) => {
    try {
      const data = JSON.parse(event.data);
      
      switch (data.type) {
        case 'subscribe':
          await handleSubscribe(server, data.channel, data.token, env);
          break;
          
        case 'unsubscribe':
          handleUnsubscribe(server, data.channel);
          break;
          
        case 'message':
          await handleNewMessage(server, data, env);
          break;
          
        case 'typing':
          broadcastToChannel(data.channel, {
            type: 'typing',
            payload: data.payload
          }, server);
          break;
          
        case 'ping':
          server.send(JSON.stringify({ type: 'pong' }));
          break;
      }
    } catch (error) {
      console.error('❌ WebSocket message error:', error);
    }
  });
  
  server.addEventListener('close', () => {
    console.log('📡 WebSocket disconnected');
    // Cleanup channels
  });
  
  server.addEventListener('error', (error) => {
    console.error('❌ WebSocket error:', error);
  });
  
  return new Response(null, {
    status: 101,
    webSocket: client
  });
}

/**
 * Subscribe to chat channel
 */
async function handleSubscribe(ws, channel, token, env) {
  try {
    // Verify token (implement your auth logic)
    // const valid = await verifyToken(token, env);
    // if (!valid) throw new Error('Invalid token');
    
    console.log(`✅ Subscribed to ${channel}`);
    
    ws.send(JSON.stringify({
      type: 'subscribed',
      channel: channel
    }));
  } catch (error) {
    ws.send(JSON.stringify({
      type: 'error',
      message: error.message
    }));
  }
}

/**
 * Unsubscribe from chat channel
 */
function handleUnsubscribe(ws, channel) {
  console.log(`❌ Unsubscribed from ${channel}`);
}

/**
 * Handle new message - broadcast to channel
 */
async function handleNewMessage(ws, data, env) {
  try {
    // Save to D1
    if (env.D1) {
      await env.D1.prepare(`
        INSERT INTO messages (id, sender_id, recipient_id, encrypted_text, nonce, created_at)
        VALUES (?, ?, ?, ?, ?, strftime('%s', 'now') * 1000)
      `).bind(
        data.payload.id,
        data.payload.sender_id,
        data.payload.recipient_id,
        data.payload.encrypted_text,
        data.payload.nonce
      ).run();
    }
    
    // Broadcast to channel
    broadcastToChannel(`chat:${data.payload.recipient_id}`, {
      type: 'message',
      payload: data.payload
    }, ws);
    
  } catch (error) {
    console.error('❌ Save message error:', error);
  }
}

/**
 * Broadcast message to all clients in channel
 */
function broadcastToChannel(channel, message, excludeWs) {
  // Implement channel logic here
  // For now, just echo back
  excludeWs.send(JSON.stringify(message));
}
