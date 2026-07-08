-- 1. Helper function to evaluate status privacy rules for Realtime RLS
DROP FUNCTION IF EXISTS can_view_status(UUID, UUID);
CREATE OR REPLACE FUNCTION can_view_status(viewer_id UUID, target_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_privacy JSONB;
  privacy_type TEXT;
BEGIN
  -- 1. Always true for self
  IF viewer_id = target_id THEN
    RETURN TRUE;
  END IF;

  -- 2. Fetch target's status_privacy from profiles
  SELECT COALESCE(status_privacy, '{"type": "everyone", "included": [], "excluded": []}'::jsonb)
  INTO target_privacy
  FROM public.profiles
  WHERE id = target_id;

  IF target_privacy IS NULL THEN
    RETURN TRUE;
  END IF;

  privacy_type := target_privacy->>'type';

  -- 3. Evaluate rules
  IF privacy_type = 'everyone' THEN
    RETURN TRUE;
  ELSIF privacy_type = 'except' THEN
    -- If viewer is IN the excluded list, deny
    IF (target_privacy->'excluded') ? viewer_id::TEXT THEN
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  ELSIF privacy_type = 'only' THEN
    -- If viewer is IN the included list, allow
    IF (target_privacy->'included') ? viewer_id::TEXT THEN
      RETURN TRUE;
    END IF;
    RETURN FALSE;
  END IF;

  RETURN TRUE;
END;
$$;

REVOKE EXECUTE ON FUNCTION can_view_status(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION can_view_status(UUID, UUID) TO authenticated;


-- 2. Drop existing RLS policy for statuses
DROP POLICY IF EXISTS "Users can view others statuses based on privacy settings" ON public.statuses;

-- 3. Recreate the RLS Policy using the helper function
CREATE POLICY "Users can view others statuses based on privacy settings" ON public.statuses
FOR SELECT USING (
  expires_at > NOW() AND can_view_status(auth.uid(), user_id)
);
