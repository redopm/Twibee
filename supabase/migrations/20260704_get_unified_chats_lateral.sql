-- 1. Drop existing functions
DROP FUNCTION IF EXISTS get_unified_chats();
DROP FUNCTION IF EXISTS get_unified_chats(UUID);

-- 2. Create the updated function with dynamic last message resolution
CREATE OR REPLACE FUNCTION get_unified_chats()
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
  unread_mentions_count INT,
  other_user_id UUID,
  other_user_name TEXT,
  other_user_avatar TEXT,
  other_user_color TEXT,
  other_last_read_at TIMESTAMPTZ,
  last_message_is_deleted_for_everyone BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id AS chat_id,
    c.is_group,
    c.group_name,
    c.group_avatar_url,
    COALESCE(lm.created_at, c.last_message_at) AS last_message_at,
    COALESCE(lm.content, c.last_message_preview) AS last_message_preview,
    COALESCE(lm.sender_id, c.last_message_sender_id) AS last_message_sender_id,
    sender_prof.name AS last_message_sender_name,
    cp.is_pinned,
    cp.is_archived,
    cp.is_muted,
    cp.unread_count,
    cp.unread_mentions_count,
    other_cp.user_id AS other_user_id,
    other_prof.name AS other_user_name,
    CASE 
      WHEN other_prof.avatar_url IS NOT NULL AND can_view_target_status(other_cp.user_id, 'privacy_profile_photo') THEN other_prof.avatar_url 
      ELSE NULL 
    END AS other_user_avatar,
    NULL::TEXT AS other_user_color,
    other_cp.last_read_at AS other_last_read_at,
    COALESCE(lm.is_deleted_for_everyone, false) AS last_message_is_deleted_for_everyone
  FROM public.chat_participants cp
  JOIN public.chats c ON c.id = cp.chat_id
  -- Dynamic Last Message for the calling user
  LEFT JOIN LATERAL (
    SELECT 
      m.created_at,
      m.content,
      m.sender_id,
      m.is_deleted_for_everyone
    FROM public.messages m
    WHERE m.chat_id = c.id
      AND NOT (auth.uid() = ANY(COALESCE(m.deleted_by, '{}'::uuid[])))
    ORDER BY m.created_at DESC
    LIMIT 1
  ) lm ON true
  LEFT JOIN public.profiles sender_prof ON sender_prof.id = COALESCE(lm.sender_id, c.last_message_sender_id)
  -- Join other participant ONLY if it's an individual chat
  LEFT JOIN public.chat_participants other_cp ON other_cp.chat_id = c.id AND other_cp.user_id != auth.uid() AND c.is_group = false
  LEFT JOIN public.profiles other_prof ON other_prof.id = other_cp.user_id
  WHERE cp.user_id = auth.uid()
  ORDER BY 
    cp.is_pinned DESC,
    COALESCE(lm.created_at, c.last_message_at) DESC NULLS LAST;
END;
$$;
