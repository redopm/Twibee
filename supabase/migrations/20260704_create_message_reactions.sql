CREATE TABLE public.message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    chat_id UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (message_id, user_id)
);

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all users" ON public.message_reactions 
FOR SELECT USING (true);

CREATE POLICY "Enable insert for users" ON public.message_reactions 
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable update for users" ON public.message_reactions 
FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Enable delete for users" ON public.message_reactions 
FOR DELETE USING (auth.uid() = user_id);

ALTER PUBLICATION supabase_realtime ADD TABLE message_reactions;
