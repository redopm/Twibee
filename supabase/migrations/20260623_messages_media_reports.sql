-- 1. Messages Table Policy
CREATE POLICY "Users can insert messages in their chats" ON public.messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id AND 
    EXISTS (SELECT 1 FROM public.chat_participants WHERE chat_id = messages.chat_id AND user_id = auth.uid())
  );

-- 2. Create Private Bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('chat_media', 'chat_media', false) ON CONFLICT (id) DO NOTHING;

-- 3. Storage Policies
-- Helper to safely check uuid
CREATE OR REPLACE FUNCTION public.is_valid_uuid(text) RETURNS boolean AS $$
BEGIN
  RETURN (CAST($1 AS uuid) IS NOT NULL);
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Allow upload if the user is a participant of the chat (chatId is the root folder)
CREATE POLICY "Users can upload media to their chats" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'chat_media' AND
    public.is_valid_uuid((string_to_array(name, '/'))[1]) AND
    EXISTS (
      SELECT 1 FROM public.chat_participants 
      WHERE chat_id = (string_to_array(name, '/'))[1]::uuid 
      AND user_id = auth.uid()
    )
  );

-- Allow viewing/downloading if the user is a participant of the chat
CREATE POLICY "Users can view media in their chats" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'chat_media' AND
    public.is_valid_uuid((string_to_array(name, '/'))[1]) AND
    EXISTS (
      SELECT 1 FROM public.chat_participants 
      WHERE chat_id = (string_to_array(name, '/'))[1]::uuid 
      AND user_id = auth.uid()
    )
  );

-- 4. User Reports Table
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE POLICY "Users can insert their own reports" ON public.reports
    FOR INSERT WITH CHECK (auth.uid() = reporter_id);
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
