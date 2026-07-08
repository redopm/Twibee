import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { broadcast_chat_id, sender_id, message_type, content, media_url } = await req.json()

    if (!broadcast_chat_id || !sender_id) {
      return new Response(JSON.stringify({ error: 'Missing required parameters' }), { 
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 1. Fetch broadcast list recipients from the chat table
    const { data: chatData, error: chatError } = await supabase
      .from('chats')
      .select('broadcast_recipients')
      .eq('id', broadcast_chat_id)
      .single()

    if (chatError || !chatData) throw chatError || new Error('Broadcast list not found')

    const recipients = chatData.broadcast_recipients || []
    if (recipients.length === 0) {
      return new Response(JSON.stringify({ success: true, count: 0 }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      })
    }

    // 2. We need to find or create individual 1-on-1 chats between sender and each recipient
    // Since doing 256 individual find-or-create queries is slow, we should fetch existing chats first
    // Note: For simplicity in Edge function, we can rely on a fast Postgres RPC function to bulk create/find chats, 
    // or we can just iterate. Since this runs on the server, looping 256 times is much faster than from mobile client, 
    // but ideally we call a custom RPC `get_or_create_chats_bulk`.
    // Assuming we have an RPC `get_or_create_direct_chat(user1, user2)`:
    
    const messagesToInsert = []

    for (const recipientId of recipients) {
      // Get or create chat via RPC (You need to create this RPC in Supabase SQL)
      const { data: indChatId, error: rpcError } = await supabase
        .rpc('get_or_create_direct_chat', {
          user_a_id: sender_id,
          user_b_id: recipientId
        })

      if (!rpcError && indChatId) {
        messagesToInsert.push({
          chat_id: indChatId,
          sender_id: sender_id,
          content: content,
          message_type: message_type,
          media_url: media_url,
          created_at: new Date().toISOString()
        })
      }
    }

    // 3. Bulk insert the messages
    if (messagesToInsert.length > 0) {
      const { error: insertError } = await supabase
        .from('messages')
        .insert(messagesToInsert)
        
      if (insertError) throw insertError
    }

    return new Response(JSON.stringify({ success: true, count: messagesToInsert.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error: any) {
    console.error("Broadcast Error:", error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
