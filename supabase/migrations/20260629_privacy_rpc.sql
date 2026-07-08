-- Create the get_user_privacy RPC function
-- Run this in Supabase SQL Editor

CREATE OR REPLACE FUNCTION get_user_privacy(target_user_id UUID)
RETURNS TABLE (
  privacy_last_seen TEXT,
  privacy_last_seen_excluded TEXT[],
  privacy_online TEXT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    COALESCE(settings->>'privacy_last_seen', 'Everyone') AS privacy_last_seen,
    ARRAY(
      SELECT jsonb_array_elements_text(
        COALESCE(settings->'privacy_last_seen_excluded', '[]'::jsonb)
      )
    ) AS privacy_last_seen_excluded,
    COALESCE(settings->>'privacy_online', 'Everyone') AS privacy_online
  FROM public.user_settings 
  WHERE user_id = target_user_id;
$$;

-- Grant access to authenticated users
GRANT EXECUTE ON FUNCTION get_user_privacy(UUID) TO authenticated;
