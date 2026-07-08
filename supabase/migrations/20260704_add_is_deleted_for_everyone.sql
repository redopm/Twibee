-- Add is_deleted_for_everyone boolean for tombstone delete logic
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_deleted_for_everyone BOOLEAN DEFAULT FALSE;
