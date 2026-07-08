-- Enable case-insensitive text extension for unique usernames
CREATE EXTENSION IF NOT EXISTS citext;

-- Add username to profiles (Affects both bots and humans)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS username citext UNIQUE;

-- BOTS TABLE
CREATE TABLE IF NOT EXISTS public.bots (
    id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    short_description TEXT,
    description TEXT,
    privacy_mode BOOLEAN DEFAULT true,
    webhook_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: Only the owner can view and manage their bot settings.
-- (Edge Functions bypass this via Service Role)
ALTER TABLE public.bots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Bot owners can view their bots" ON public.bots FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Bot owners can update their bots" ON public.bots FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Bot owners can insert bots" ON public.bots FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Bot owners can delete bots" ON public.bots FOR DELETE USING (auth.uid() = owner_id);

-- BOT COMMANDS TABLE
CREATE TABLE IF NOT EXISTS public.bot_commands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id UUID NOT NULL REFERENCES public.bots(id) ON DELETE CASCADE,
    command TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(bot_id, command)
);

ALTER TABLE public.bot_commands ENABLE ROW LEVEL SECURITY;
-- INTENTIONAL: Anyone can view commands so the composer menu can suggest them
CREATE POLICY "Anyone can view bot commands" ON public.bot_commands FOR SELECT USING (true);
CREATE POLICY "Owners can manage bot commands" ON public.bot_commands FOR ALL USING (
    EXISTS (SELECT 1 FROM public.bots WHERE bots.id = bot_commands.bot_id AND bots.owner_id = auth.uid())
);

-- BOT UPDATES TABLE (Polling Queue)
CREATE TABLE IF NOT EXISTS public.bot_updates (
    update_id BIGSERIAL PRIMARY KEY,
    bot_id UUID NOT NULL REFERENCES public.bots(id) ON DELETE CASCADE,
    update_type TEXT NOT NULL, -- 'message', 'callback_query'
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: Deny ALL to authenticated/anon.
-- Only Edge Functions acting as the bot via Service Role, or DB triggers can read/write this.
ALTER TABLE public.bot_updates ENABLE ROW LEVEL SECURITY;
-- No policies created. Default is deny all.
