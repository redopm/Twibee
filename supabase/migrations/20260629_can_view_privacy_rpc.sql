-- Secure RPC to evaluate privacy rules on the backend without leaking data
DROP FUNCTION IF EXISTS can_view_target_status(UUID, TEXT);

CREATE OR REPLACE FUNCTION can_view_target_status(target_id UUID, setting_key TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_settings JSONB;
  target_val TEXT;
  requester_id UUID := auth.uid();
BEGIN
  -- 1. If we are checking ourselves, always return true
  IF target_id = requester_id THEN
    RETURN TRUE;
  END IF;

  -- 2. PERFORMANCE FIX: Fetch the entire settings JSONB object ONLY ONCE
  SELECT settings INTO target_settings
  FROM public.user_settings 
  WHERE user_id = target_id;

  -- If user has no settings row, default to Everyone (TRUE)
  IF target_settings IS NULL THEN
    RETURN TRUE;
  END IF;

  -- Extract the specific setting value, default to 'Everyone'
  target_val := COALESCE(target_settings->>setting_key, 'Everyone');

  -- 3. Evaluate rules
  IF target_val = 'Nobody' THEN
    RETURN FALSE;
    
  ELSIF target_val = 'Everyone' THEN
    RETURN TRUE;
    
  ELSIF target_val = 'Same as last seen' THEN
    -- CRITICAL BUG FIX: Prevent Infinite Recursion Crash
    IF setting_key = 'privacy_last_seen' THEN
      RETURN TRUE; -- Fallback safe behavior if data is corrupted
    END IF;
    -- Recurse safely
    RETURN can_view_target_status(target_id, 'privacy_last_seen');
    
  ELSIF target_val = 'My contacts except...' THEN
    -- PERFORMANCE FIX: Use JSONB '?' operator to instantly check if UUID exists in the JSON array
    IF (target_settings->(setting_key || '_excluded')) ? requester_id::TEXT THEN
      RETURN FALSE; -- Requester IS in the excluded list, deny access
    END IF;
    RETURN TRUE; -- Not in excluded list, allow access
    
  ELSIF target_val = 'My contacts' THEN
    -- Assume true for now (until a real contacts system is added)
    RETURN TRUE;
  END IF;

  -- Default fallback
  RETURN TRUE;
END;
$$;

-- Revoke public execution and grant to authenticated users ONLY
REVOKE EXECUTE ON FUNCTION can_view_target_status(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION can_view_target_status(UUID, TEXT) TO authenticated;
