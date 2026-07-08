ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS forwarded_from_id UUID REFERENCES public.messages(id) ON DELETE SET NULL;
