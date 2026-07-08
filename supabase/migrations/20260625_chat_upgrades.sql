-- 1. Add columns to chat_participants and messages
ALTER TABLE public.chat_participants
  ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS unread_mentions_count INT DEFAULT 0;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS mentioned_user_ids UUID[] DEFAULT '{}';

-- 2. Add GIN index on messages.content for Full Text Search
CREATE INDEX IF NOT EXISTS messages_content_fts_idx ON public.messages USING GIN (to_tsvector('english', coalesce(content, '')));

-- 3. Update the get_unified_chats RPC to include the new fields and FIX the missing avatar_text column error
DROP FUNCTION IF EXISTS get_unified_chats();
DROP FUNCTION IF EXISTS get_unified_chats(UUID);

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
  other_last_read_at TIMESTAMPTZ
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
    c.last_message_at,
    c.last_message_preview,
    c.last_message_sender_id,
    sender_prof.name AS last_message_sender_name,
    cp.is_pinned,
    cp.is_archived,
    cp.is_muted,
    cp.unread_count,
    cp.unread_mentions_count,
    other_cp.user_id AS other_user_id,
    other_prof.name AS other_user_name,
    other_prof.avatar_url AS other_user_avatar, -- FIXED: profiles table uses avatar_url, not avatar_text
    NULL::TEXT AS other_user_color, -- FIXED: profiles table does not have avatar_color
    other_cp.last_read_at AS other_last_read_at
  FROM public.chat_participants cp
  JOIN public.chats c ON c.id = cp.chat_id
  LEFT JOIN public.profiles sender_prof ON sender_prof.id = c.last_message_sender_id
  -- Join other participant ONLY if it's an individual chat
  LEFT JOIN public.chat_participants other_cp ON other_cp.chat_id = c.id AND other_cp.user_id != auth.uid() AND c.is_group = false
  LEFT JOIN public.profiles other_prof ON other_prof.id = other_cp.user_id
  WHERE cp.user_id = auth.uid()
  ORDER BY 
    cp.is_pinned DESC,
    c.last_message_at DESC NULLS LAST;
END;
$$;

-- 4. Create search_messages RPC
CREATE OR REPLACE FUNCTION search_messages(search_query TEXT)
RETURNS TABLE (
  message_id UUID,
  chat_id UUID,
  content TEXT,
  created_at TIMESTAMPTZ,
  sender_name TEXT,
  chat_name TEXT,
  is_group BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.id AS message_id,
    m.chat_id,
    m.content,
    m.created_at,
    p.name AS sender_name,
    COALESCE(c.group_name, other_prof.name) AS chat_name,
    c.is_group
  FROM public.messages m
  JOIN public.chat_participants cp ON cp.chat_id = m.chat_id AND cp.user_id = auth.uid()
  JOIN public.chats c ON c.id = m.chat_id
  LEFT JOIN public.profiles p ON p.id = m.sender_id
  LEFT JOIN public.chat_participants other_cp ON other_cp.chat_id = c.id AND other_cp.user_id != auth.uid() AND c.is_group = false
  LEFT JOIN public.profiles other_prof ON other_prof.id = other_cp.user_id
  WHERE to_tsvector('english', coalesce(m.content, '')) @@ plainto_tsquery('english', search_query)
  ORDER BY m.created_at DESC
  LIMIT 50;
END;
$$;

-- 5. Update the increment_unread_count trigger to also handle mentions via the new array
CREATE OR REPLACE FUNCTION increment_unread_count()
RETURNS TRIGGER
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Increment unread_count for all participants except sender
  UPDATE public.chat_participants
  SET unread_count = unread_count + 1
  WHERE chat_id = NEW.chat_id
    AND user_id != NEW.sender_id;

  -- Handle mentions based on mentioned_user_ids array populated by frontend
  IF NEW.mentioned_user_ids IS NOT NULL AND array_length(NEW.mentioned_user_ids, 1) > 0 THEN
    UPDATE public.chat_participants
    SET unread_mentions_count = unread_mentions_count + 1
    WHERE chat_id = NEW.chat_id
      AND user_id = ANY(NEW.mentioned_user_ids)
      AND user_id != NEW.sender_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
