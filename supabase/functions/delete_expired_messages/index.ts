import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

serve(async (req) => {
  try {
    // BUG 1 FIX: Added 'created_at' to the select query
    const { data: expiredMessages, error: fetchError } = await supabase
      .from('messages')
      .select('id, media_url, created_at, chats!inner(disappearing_timer)')
      .gt('chats.disappearing_timer', 0); // Only chats with timer enabled

    if (fetchError) throw fetchError;

    if (!expiredMessages || expiredMessages.length === 0) {
      return new Response(JSON.stringify({ message: "No messages to check." }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }

    // 2. Filter mathematically
    const now = new Date();
    const toDelete = expiredMessages.filter((msg: any) => {
      if (!msg.created_at) return false;
      const createdAt = new Date(msg.created_at);
      const timerHours = msg.chats.disappearing_timer;
      const expiryTime = new Date(createdAt.getTime() + timerHours * 60 * 60 * 1000);
      return now > expiryTime;
    });

    if (toDelete.length === 0) {
      return new Response(JSON.stringify({ message: "No messages are past their expiry time yet." }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }

    const mediaPathsToDelete: string[] = [];
    const messageIdsToDelete: string[] = [];

    toDelete.forEach((msg: any) => {
      messageIdsToDelete.push(msg.id);
      
      if (msg.media_url && msg.media_url.includes('/chat-media/')) {
        const urlParts = msg.media_url.split('/chat-media/');
        if (urlParts.length > 1) {
          // BUG 2 FIX: Stripping query parameters like '?t=123'
          const cleanPath = urlParts[1].split('?')[0]; 
          mediaPathsToDelete.push(cleanPath);
        }
      }
    });

    // 3. Delete media files from Storage safely
    if (mediaPathsToDelete.length > 0) {
      const { error: storageError } = await supabase
        .storage
        .from('chat-media')
        .remove(mediaPathsToDelete);

      if (storageError) {
        console.error("Storage deletion error:", storageError);
      }
    }

    // 4. Delete messages from database
    const { error: deleteError } = await supabase
      .from('messages')
      .delete()
      .in('id', messageIdsToDelete);

    if (deleteError) throw deleteError;

    return new Response(JSON.stringify({ 
      message: `Successfully deleted ${messageIdsToDelete.length} messages and ${mediaPathsToDelete.length} media files.` 
    }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error: any) {
    console.error("Error executing delete function:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
})
