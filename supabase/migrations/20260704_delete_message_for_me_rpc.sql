CREATE OR REPLACE FUNCTION delete_message_for_me(msg_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_chat_id UUID;
  v_deleted_by UUID[];
BEGIN
  -- 1. Verify message exists and user is a participant of the chat
  SELECT m.chat_id, m.deleted_by INTO v_chat_id, v_deleted_by
  FROM public.messages m
  JOIN public.chat_participants cp ON cp.chat_id = m.chat_id
  WHERE m.id = msg_id AND cp.user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Message not found or you do not have access to it.';
  END IF;

  -- 2. Add user to deleted_by array if not already present
  IF v_deleted_by IS NULL OR NOT (auth.uid() = ANY(v_deleted_by)) THEN
    UPDATE public.messages
    SET deleted_by = array_append(COALESCE(deleted_by, '{}'::uuid[]), auth.uid())
    WHERE id = msg_id;
  END IF;
END;
$$;

-- Also update the UPDATE policy to allow 10 minutes instead of 5 minutes as requested earlier
DROP POLICY IF EXISTS "Users can update their own messages" ON public.messages;
CREATE POLICY "Users can update their own messages" ON public.messages
FOR UPDATE USING (
  auth.uid() = sender_id 
  AND (now() - created_at) <= interval '10 minutes'
);
