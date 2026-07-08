import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // Verify the calling user is authenticated
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), { status: 401, headers: corsHeaders });
    }

    // Verify JWT with Supabase
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(
      authHeader.replace('Bearer ', '')
    );
    if (userError || !user) {
      return new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), { status: 401, headers: corsHeaders });
    }

    const body = await req.json();
    const { bot_id, message_id, data } = body;

    if (!bot_id || !message_id || data === undefined) {
      return new Response(JSON.stringify({ ok: false, error: 'Missing bot_id, message_id, or data' }), { status: 400, headers: corsHeaders });
    }

    // Generate unique callback_query_id
    const callbackQueryId = crypto.randomUUID();

    // 1. Insert a placeholder row into callback_responses
    const { error: insertError } = await supabaseAdmin
      .from('callback_responses')
      .insert({
        callback_query_id: callbackQueryId,
        requesting_user_id: user.id,
        text: null,
        show_alert: false,
      });

    if (insertError) throw insertError;

    // 2. Insert a callback_query update into bot_updates for the bot to pick up
    const { error: updateError } = await supabaseAdmin
      .from('bot_updates')
      .insert({
        bot_id: bot_id,
        update_type: 'callback_query',
        payload: {
          id: callbackQueryId,
          from: { id: user.id },
          message: { message_id: message_id },
          data: data,
        },
      });

    if (updateError) throw updateError;

    return new Response(JSON.stringify({
      ok: true,
      result: { callback_query_id: callbackQueryId }
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  } catch (error: any) {
    return new Response(JSON.stringify({ ok: false, error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
