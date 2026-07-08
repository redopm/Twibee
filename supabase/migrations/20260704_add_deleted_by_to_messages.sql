-- Add deleted_by column to messages to track "Delete for me" functionality
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS deleted_by UUID[] DEFAULT '{}'::UUID[];
