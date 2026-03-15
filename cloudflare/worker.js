export default {
  async fetch(request, env) {
    return new Response(JSON.stringify({
      status: 'ok',
      service: 'Liberty Reach Edge',
      timestamp: Date.now()
    }), {
      headers: { 'Content-Type': 'application/json' }
    });
  }
};
