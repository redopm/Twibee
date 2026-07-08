-- Add is_pinned and starred_by columns to messages table
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS starred_by UUID[] DEFAULT '{}'::uuid[];

-- RPC to safely toggle starred_by
CREATE OR REPLACE FUNCTION toggle_message_star(message_id UUID)
RETURNS void AS $$
DECLARE
  current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.messages
  SET starred_by = 
    CASE 
      WHEN current_user_id = ANY(starred_by) THEN array_remove(starred_by, current_user_id)
      ELSE array_append(starred_by, current_user_id)
    END
  WHERE id = message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
