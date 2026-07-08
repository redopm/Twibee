-- Create linked_devices table
CREATE TABLE IF NOT EXISTS public.linked_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_name TEXT,
    device_type TEXT, -- e.g., 'desktop', 'web', 'tablet'
    os_name TEXT,
    browser_name TEXT,
    last_active TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fcm_token TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.linked_devices ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own linked devices
CREATE POLICY "Users can view their own linked devices"
ON public.linked_devices
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own linked devices
CREATE POLICY "Users can insert their own linked devices"
ON public.linked_devices
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own linked devices (e.g. for fcm_token or last_active)
CREATE POLICY "Users can update their own linked devices"
ON public.linked_devices
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own linked devices
CREATE POLICY "Users can delete their own linked devices"
ON public.linked_devices
FOR DELETE
USING (auth.uid() = user_id);

-- Create index for performance
CREATE INDEX IF NOT EXISTS linked_devices_user_id_idx ON public.linked_devices(user_id);
