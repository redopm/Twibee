-- Add columns for End-to-End Encryption Cloud Backup via PIN
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS public_key TEXT,
ADD COLUMN IF NOT EXISTS encrypted_private_key TEXT;
