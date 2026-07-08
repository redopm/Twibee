-- Migration for Permanent Call Logs Deletion RPCs
-- These RPCs allow users to permanently delete their call logs, bypassing any restrictive RLS policies for updates.

CREATE OR REPLACE FUNCTION clear_user_call_logs(p_user_id UUID)
RETURNS void AS $$
BEGIN
  -- Mark all call participants rows for this user as cleared
  UPDATE call_participants 
  SET status = 'cleared_by_user'
  WHERE user_id = p_user_id AND status != 'cleared_by_user';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION delete_user_call_logs(p_user_id UUID, p_call_ids TEXT[])
RETURNS void AS $$
BEGIN
  -- Mark specific call participants rows for this user as deleted
  UPDATE call_participants 
  SET status = 'deleted_by_user'
  WHERE user_id = p_user_id AND call_id = ANY(p_call_ids);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
