-- RPC to toggle pin safely, bypassing standard messages RLS
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
BEGIN
  -- We don't query public.chats for type or owner_id because it doesn't have them!
  -- Instead, we just check if the chat_id exists in public.channels.
  SELECT owner_id INTO v_owner_id FROM public.channels WHERE id = p_chat_id;
  
  IF FOUND THEN
    v_chat_type := 'channel';
  ELSE
    v_chat_type := 'chat';
  END IF;

  -- 1. Check if user is an admin or participant
  IF v_chat_type = 'channel' THEN
    -- For channels, only admins/owner can pin.
    IF auth.uid() = v_owner_id THEN
      v_is_authorized := true;
    ELSE
      SELECT EXISTS (
        SELECT 1 FROM public.channel_admins 
        WHERE channel_id = p_chat_id AND user_id = auth.uid()
      ) INTO v_is_authorized;
    END IF;
  ELSE
    -- For individual/group chats, we check if they are a participant.
    SELECT EXISTS (
      SELECT 1 FROM public.chat_participants 
      WHERE chat_id = p_chat_id AND user_id = auth.uid()
    ) INTO v_is_authorized;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Not authorized to pin in this chat';
  END IF;

  -- 2. If pinning, unpin the previously pinned message for this chat (so only 1 pinned message at a time)
  IF p_is_pinned THEN
    UPDATE public.messages
    SET is_pinned = false
    WHERE chat_id = p_chat_id AND is_pinned = true;
  END IF;

  -- 3. Update the target message securely
  UPDATE public.messages
  SET is_pinned = p_is_pinned
  WHERE id = p_message_id AND chat_id = p_chat_id;

END;
$$;
