-- Create saved_messages table
CREATE TABLE IF NOT EXISTS public.saved_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, message_id)
);

-- Enable RLS
ALTER TABLE public.saved_messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own saved messages
CREATE POLICY "Users can view their own saved messages"
ON public.saved_messages
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own saved messages
CREATE POLICY "Users can insert their own saved messages"
ON public.saved_messages
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own saved messages
CREATE POLICY "Users can delete their own saved messages"
ON public.saved_messages
FOR DELETE
USING (auth.uid() = user_id);

-- Create index for performance
CREATE INDEX IF NOT EXISTS saved_messages_user_id_idx ON public.saved_messages(user_id);
