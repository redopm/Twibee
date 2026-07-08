-- 1. Create or replace the RPC to toggle pin safely (Multi-Pin Support with Limit)
CREATE OR REPLACE FUNCTION public.toggle_message_pin(p_message_id UUID, p_is_pinned BOOLEAN, p_chat_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_authorized BOOLEAN := false;
  v_chat_type TEXT;
  v_owner_id UUID;
  v_pin_count INT;
  v_oldest_pin_id UUID;
BEGIN
  -- Check if it's a channel
  SELECT owner_id INTO v_owner_id FROM public.channels WHERE id = p_chat_id;
  
  IF FOUND THEN
    v_chat_type := 'channel';
  ELSE
    v_chat_type := 'chat';
  END IF;

  -- 1. Check authorization
  IF v_chat_type = 'channel' THEN
    IF auth.uid() = v_owner_id THEN
      v_is_authorized := true;
    ELSE
      SELECT EXISTS (
        SELECT 1 FROM public.channel_admins 
        WHERE channel_id = p_chat_id AND user_id = auth.uid()
      ) INTO v_is_authorized;
    END IF;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM public.chat_participants 
      WHERE chat_id = p_chat_id AND user_id = auth.uid()
    ) INTO v_is_authorized;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Not authorized to pin in this chat';
  END IF;

  -- MULTI-PIN UPDATE: Allow multiple pins, but enforce a hard limit of 10.
  IF p_is_pinned THEN
    SELECT COUNT(*) INTO v_pin_count FROM public.messages WHERE chat_id = p_chat_id AND is_pinned = true;
    IF v_pin_count >= 10 THEN
      -- Find the oldest pinned message to unpin it automatically (FIFO)
      SELECT id INTO v_oldest_pin_id FROM public.messages 
      WHERE chat_id = p_chat_id AND is_pinned = true 
      ORDER BY created_at ASC LIMIT 1;
      
      IF v_oldest_pin_id IS NOT NULL THEN
        UPDATE public.messages SET is_pinned = false WHERE id = v_oldest_pin_id;
      END IF;
    END IF;
  END IF;

  -- 2. Update the target message securely
  UPDATE public.messages
  SET is_pinned = p_is_pinned
  WHERE id = p_message_id AND chat_id = p_chat_id;

END;
$$;
