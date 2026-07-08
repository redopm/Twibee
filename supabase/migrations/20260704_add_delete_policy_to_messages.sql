CREATE POLICY "Users can delete their own messages" ON public.messages
FOR DELETE USING (
  auth.uid() = sender_id 
  AND (now() - created_at) <= interval '5 minutes'
);
