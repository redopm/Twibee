
-- 20260703_add_reported_chat_id.sql
ALTER TABLE public.reports ADD COLUMN reported_chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE;
ALTER TABLE public.reports ALTER COLUMN reported_user_id DROP NOT NULL;
