const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres.xfynwiyungfkckhjhzsg:P$7rK9#mX2vL5@aws-0-ap-south-1.pooler.supabase.com:6543/postgres'
});

async function run() {
  await client.connect();
  const sql = `
CREATE OR REPLACE FUNCTION get_unified_chats(caller_id UUID)
RETURNS TABLE (
  chat_id UUID,
  is_group BOOLEAN,
  group_name TEXT,
  group_avatar_url TEXT,
  last_message_at TIMESTAMPTZ,
  last_message_preview TEXT,
  last_message_sender_id UUID,
  last_message_sender_name TEXT,
  is_pinned BOOLEAN,
  is_archived BOOLEAN,
  is_muted BOOLEAN,
  unread_count INT,
  other_user_id UUID,
  other_user_name TEXT,
  other_user_avatar TEXT,
  other_user_color TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id AS chat_id,
    c.is_group,
    c.group_name,
    c.group_avatar_url,
    c.last_message_at,
    c.last_message_preview,
    c.last_message_sender_id,
    sender_prof.name AS last_message_sender_name,
    cp.is_pinned,
    cp.is_archived,
    cp.is_muted,
    cp.unread_count,
    other_cp.user_id AS other_user_id,
    other_prof.name AS other_user_name,
    other_prof.avatar_text AS other_user_avatar,
    other_prof.avatar_color AS other_user_color
  FROM public.chat_participants cp
  JOIN public.chats c ON c.id = cp.chat_id
  LEFT JOIN public.profiles sender_prof ON sender_prof.id = c.last_message_sender_id
  LEFT JOIN public.chat_participants other_cp ON other_cp.chat_id = c.id AND other_cp.user_id != caller_id AND c.is_group = false
  LEFT JOIN public.profiles other_prof ON other_prof.id = other_cp.user_id
  WHERE cp.user_id = caller_id
  ORDER BY 
    cp.is_pinned DESC,
    c.last_message_at DESC NULLS LAST;
END;
$$;
  `;
  try {
    await client.query(sql);
    console.log('RPC created successfully!');
  } catch(e) {
    console.error(e);
  }
  await client.end();
}
run();
