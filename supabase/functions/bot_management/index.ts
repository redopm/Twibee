import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

// Cryptography utility
async function generateBotToken(botId: string): Promise<{ token: string; hash: string }> {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  const randomHex = Array.from(array)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
  const plaintextToken = `${botId}:${randomHex}`;
  const msgUint8 = new TextEncoder().encode(plaintextToken);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);
  const hashHex = Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
  return { token: plaintextToken, hash: hashHex };
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // IMPORTANT: Use SUPABASE_SERVICE_ROLE_KEY — this is auto-injected by Supabase runtime
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    console.log('supabaseUrl:', supabaseUrl ? 'OK' : 'MISSING');
    console.log('supabaseServiceKey:', supabaseServiceKey ? 'OK (length=' + supabaseServiceKey.length + ')' : 'MISSING');

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    });

    // Verify caller JWT
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const userToken = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(userToken);

    if (authError || !user) {
      console.error('Auth error:', JSON.stringify(authError));
      return new Response(JSON.stringify({ error: 'Unauthorized', detail: authError?.message }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const body = await req.json();
    const action = body.action;

    if (action === 'create_bot') {
      const { name, username, short_description, description } = body;

      if (!name || !username) {
        return new Response(JSON.stringify({ error: 'name and username are required' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const botId = crypto.randomUUID();
      const { token, hash } = await generateBotToken(botId);

      // 1. Insert into profiles
      const { error: profileError } = await supabaseAdmin
        .from('profiles')
        .insert({
          id: botId,
          name: name,
          username: username.toLowerCase(),
          about: short_description || null,
          phone_number: `bot_${botId}`, // bots don't have phone numbers, use placeholder
        });

      if (profileError) {
        console.error('Profile insert error:', JSON.stringify(profileError));
        throw new Error(`Profile insert failed: ${profileError.message}`);
      }

      // 2. Insert into bots
      const { error: botError } = await supabaseAdmin
        .from('bots')
        .insert({
          id: botId,
          owner_id: user.id,
          token_hash: hash,
          short_description: short_description || null,
          description: description || null,
          privacy_mode: true,
        });

      if (botError) {
        // Rollback profile
        await supabaseAdmin.from('profiles').delete().eq('id', botId);
        console.error('Bot insert error:', JSON.stringify(botError));
        throw new Error(`Bot insert failed: ${botError.message}`);
      }

      return new Response(JSON.stringify({ bot_id: botId, token }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });

    } else if (action === 'regenerate_token') {
      const { bot_id } = body;

      const { data: bot, error: fetchError } = await supabaseAdmin
        .from('bots')
        .select('owner_id')
        .eq('id', bot_id)
        .single();

      if (fetchError || !bot) throw new Error('Bot not found');
      if (bot.owner_id !== user.id) {
        return new Response(JSON.stringify({ error: 'Forbidden' }), {
          status: 403, headers: corsHeaders
        });
      }

      const { token, hash } = await generateBotToken(bot_id);

      const { error: updateError } = await supabaseAdmin
        .from('bots')
        .update({ token_hash: hash })
        .eq('id', bot_id);

      if (updateError) throw updateError;

      return new Response(JSON.stringify({ token }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });

    } else if (action === 'delete_bot') {
      const { bot_id } = body;

      const { data: bot, error: fetchError } = await supabaseAdmin
        .from('bots')
        .select('owner_id')
        .eq('id', bot_id)
        .single();

      if (fetchError || !bot) throw new Error('Bot not found');
      if (bot.owner_id !== user.id) {
        return new Response(JSON.stringify({ error: 'Forbidden' }), {
          status: 403, headers: corsHeaders
        });
      }

      // Deleting profile cascades to bots table
      await supabaseAdmin.from('profiles').delete().eq('id', bot_id);

      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });

    } else {
      return new Response(JSON.stringify({ error: 'Invalid action' }), {
        status: 400, headers: corsHeaders
      });
    }

  } catch (error: any) {
    console.error('Unhandled error:', error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
