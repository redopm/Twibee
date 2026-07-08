CREATE POLICY "Users can update their own messages" ON public.messages
FOR UPDATE USING (
  auth.uid() = sender_id 
  AND (now() - created_at) <= interval '5 minutes'
);
