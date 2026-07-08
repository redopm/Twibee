-- 1. chats table: add denormalized preview + per-participant columns
ALTER TABLE public.chats
  ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_message_preview TEXT,
  ADD COLUMN IF NOT EXISTS last_message_sender_id UUID REFERENCES public.profiles(id);

-- 2. chat_participants: per-user chat state
ALTER TABLE public.chat_participants
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_muted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS unread_count INT DEFAULT 0;

-- Ensure users can update their own participant rows
ALTER TABLE public.chat_participants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can update their own chat state" ON public.chat_participants;
CREATE POLICY "Users can update their own chat state" ON public.chat_participants
  FOR UPDATE USING (auth.uid() = user_id);

-- Prevent users from reassigning chat_id or user_id on their chat_participants rows
CREATE OR REPLACE FUNCTION public.prevent_chat_participant_reassignment()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.chat_id != OLD.chat_id OR NEW.user_id != OLD.user_id THEN
    RAISE EXCEPTION 'chat_id and user_id cannot be changed';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS lock_chat_participant_identity ON public.chat_participants;
CREATE TRIGGER lock_chat_participant_identity
  BEFORE UPDATE ON public.chat_participants
  FOR EACH ROW EXECUTE FUNCTION public.prevent_chat_participant_reassignment();

-- 3. Trigger: update chats.last_message_at + preview on message insert
CREATE OR REPLACE FUNCTION update_chat_last_message()
RETURNS TRIGGER 
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.chats
  SET last_message_at = NEW.created_at,
      last_message_preview = NEW.content,
      last_message_sender_id = NEW.sender_id
  WHERE id = NEW.chat_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_message_insert ON public.messages;
CREATE TRIGGER on_message_insert
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION update_chat_last_message();

-- 4. Trigger: increment unread_count for all participants except sender
CREATE OR REPLACE FUNCTION increment_unread_count()
RETURNS TRIGGER
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.chat_participants
  SET unread_count = unread_count + 1
  WHERE chat_id = NEW.chat_id
    AND user_id != NEW.sender_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_message_insert_unread ON public.messages;
CREATE TRIGGER on_message_insert_unread
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION increment_unread_count();

-- Helper function to check if users are contacts (assuming chat_participants means they have a chat history, or a real contacts table exists. Using a basic function for extensibility)
CREATE OR REPLACE FUNCTION public.is_contact(user_a UUID, user_b UUID)
RETURNS BOOLEAN
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Simple check: do they share a chat?
  RETURN EXISTS (
    SELECT 1 FROM public.chat_participants cp1
    JOIN public.chat_participants cp2 ON cp1.chat_id = cp2.chat_id
    WHERE cp1.user_id = user_a AND cp2.user_id = user_b
  );
END;
$$ LANGUAGE plpgsql;

-- 5. Statuses table (24h expiry enforced via expires_at)
CREATE TABLE IF NOT EXISTS public.statuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('text', 'photo', 'video')),
  content TEXT,
  media_url TEXT,
  bg_color TEXT,
  font_style TEXT,
  allow_forward BOOLEAN DEFAULT true,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.statuses ENABLE ROW LEVEL SECURITY;
-- Real privacy enforcement at RLS level
CREATE POLICY "Users can view others statuses based on privacy settings" ON public.statuses
  FOR SELECT USING (
    expires_at > NOW() AND (
      auth.uid() = user_id OR 
      (
        COALESCE((SELECT settings->>'privacy_status' FROM public.user_settings WHERE user_id = statuses.user_id), 'Everyone')
      ) = 'Everyone' OR
      (
        COALESCE((SELECT settings->>'privacy_status' FROM public.user_settings WHERE user_id = statuses.user_id), 'Everyone') = 'My contacts'
        AND public.is_contact(statuses.user_id, auth.uid())
      )
      -- Explicit 'Nobody' is handled by the above falling through
    )
  );
CREATE POLICY "Users can insert own status" ON public.statuses
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own status" ON public.statuses
  FOR DELETE USING (auth.uid() = user_id);

-- 6. Status views
CREATE TABLE IF NOT EXISTS public.status_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status_id UUID NOT NULL REFERENCES public.statuses(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(status_id, viewer_id)
);
ALTER TABLE public.status_views ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can log own views" ON public.status_views
  FOR INSERT WITH CHECK (auth.uid() = viewer_id);
CREATE POLICY "Status owners can see views" ON public.status_views
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.statuses WHERE statuses.id = status_views.status_id AND statuses.user_id = auth.uid())
    OR auth.uid() = viewer_id
  );

-- 7. Status mutes (independent from chat mute)
CREATE TABLE IF NOT EXISTS public.status_mutes (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  muted_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, muted_user_id)
);
ALTER TABLE public.status_mutes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage their own status mutes" ON public.status_mutes
  FOR ALL USING (auth.uid() = user_id);

-- 8. Status reactions
CREATE TABLE IF NOT EXISTS public.status_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status_id UUID NOT NULL REFERENCES public.statuses(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(status_id, user_id)
);
ALTER TABLE public.status_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can add own reactions" ON public.status_reactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own reactions" ON public.status_reactions
  FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Status owners and reactors can see reactions" ON public.status_reactions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.statuses WHERE statuses.id = status_reactions.status_id AND statuses.user_id = auth.uid())
    OR auth.uid() = user_id
  );
