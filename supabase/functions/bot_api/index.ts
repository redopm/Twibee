import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Helper: Verify Token and Get Bot
async function authenticateBot(req: Request, supabaseAdmin: any) {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new Error('Unauthorized: Missing or invalid token');
  }
  
  const token = authHeader.split(' ')[1];
  
  // Hash the token
  const msgUint8 = new TextEncoder().encode(token);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);
  const hashHex = Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
    
  const { data: bot, error } = await supabaseAdmin
    .from('bots')
    .select('id, profiles!inner(name, username, about)')
    .eq('token_hash', hashHex)
    .single();
    
  if (error || !bot) {
    throw new Error('Unauthorized: Invalid token');
  }
  
  return bot;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // Parse URL to route the method (e.g., /getMe, /sendMessage)
    const url = new URL(req.url);
    // Split the path and find the method name. Example: https://.../bot_api/getMe
    const pathParts = url.pathname.split('/');
    const method = pathParts[pathParts.length - 1];

    // Authenticate the bot
    let bot;
    try {
      bot = await authenticateBot(req, supabaseAdmin);
    } catch (e: any) {
      return new Response(JSON.stringify({ ok: false, error_code: 401, description: e.message }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
    }

    // Process body if present
    let body = {};
    if (req.method === 'POST') {
      try {
        body = await req.json();
      } catch (_) {}
    }

    // BOT API ROUTER
    if (method === 'getMe') {
      return new Response(JSON.stringify({
        ok: true,
        result: {
          id: bot.id,
          is_bot: true,
          first_name: bot.profiles.name,
          username: bot.profiles.username,
        }
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
    }

    if (method === 'getUpdates') {
      // Polling updates: ?offset=X&limit=100
      let offset = url.searchParams.get('offset') || (body as any).offset;
      let limit = url.searchParams.get('limit') || (body as any).limit || 100;
      
      // Cleanup acknowledged updates (update_id < offset)
      if (offset) {
        await supabaseAdmin
          .from('bot_updates')
          .delete()
          .eq('bot_id', bot.id)
          .lt('update_id', parseInt(offset));
      }

      let query = supabaseAdmin
        .from('bot_updates')
        .select('*')
        .eq('bot_id', bot.id)
        .order('update_id', { ascending: true })
        .limit(parseInt(limit));
        
      if (offset) {
        query = query.gte('update_id', parseInt(offset));
      }

      const { data: updates, error } = await query;
      if (error) throw error;

      // Transform format to telegram-like
      const formattedUpdates = updates.map((u: any) => ({
        update_id: u.update_id,
        [u.update_type]: u.payload
      }));

      return new Response(JSON.stringify({
        ok: true,
        result: formattedUpdates
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
    }

    if (method === 'sendMessage') {
      const channel_id = (body as any).chat_id; // For bots, chat_id is the channel_id
      const text = (body as any).text;
      const reply_markup = (body as any).reply_markup;
      
      if (!channel_id || !text) {
        return new Response(JSON.stringify({ ok: false, description: 'Missing chat_id (channel_id) or text' }), { status: 400, headers: corsHeaders });
      }

      // 1. Verify Authorization: Bot must be an owner or admin of the channel
      const { data: channel, error: channelError } = await supabaseAdmin
        .from('channels')
        .select('owner_id')
        .eq('id', channel_id)
        .maybeSingle();

      if (!channel) {
        return new Response(JSON.stringify({ ok: false, error_code: 404, description: 'Channel not found' }), { status: 404, headers: corsHeaders });
      }

      let isAuthorized = (channel.owner_id === bot.id);

      if (!isAuthorized) {
        // Check if bot is an admin
        const { data: adminCheck } = await supabaseAdmin
          .from('channel_admins')
          .select('user_id')
          .eq('channel_id', channel_id)
          .eq('user_id', bot.id)
          .maybeSingle();
          
        if (adminCheck) {
          isAuthorized = true;
        }
      }

      if (!isAuthorized) {
        return new Response(JSON.stringify({ ok: false, error_code: 403, description: 'Forbidden: bot is not an admin of this channel' }), { status: 403, headers: corsHeaders });
      }

      // 2. Insert Message directly into messages (acting as channel post)
      const { data: message, error: msgError } = await supabaseAdmin
        .from('messages')
        .insert({
          chat_id: channel_id, // In MissMe, channel posts use chat_id column
          sender_id: bot.id,
          content: text,
          message_type: 'text',
          reply_markup: reply_markup || null
        })
        .select()
        .single();

      if (msgError) throw msgError;

      return new Response(JSON.stringify({
        ok: true,
        result: {
          message_id: message.id,
          chat: { id: channel_id, type: 'channel' },
          date: new Date(message.created_at).getTime() / 1000,
          text: message.content
        }
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
    }

    if (method === 'answerCallbackQuery') {
      const callback_query_id = (body as any).callback_query_id;
      const text = (body as any).text;
      const show_alert = (body as any).show_alert === true;

      if (!callback_query_id) {
        return new Response(JSON.stringify({ ok: false, description: 'Missing callback_query_id' }), { status: 400, headers: corsHeaders });
      }

      const { error: updError } = await supabaseAdmin
        .from('callback_responses')
        .update({ text: text || null, show_alert })
        .eq('callback_query_id', callback_query_id);

      if (updError) throw updError;

      return new Response(JSON.stringify({ ok: true, result: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
    }

    return new Response(JSON.stringify({ ok: false, error_code: 404, description: 'Method not found' }), { status: 404, headers: corsHeaders });

  } catch (error: any) {
    return new Response(JSON.stringify({ ok: false, error_code: 500, description: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
