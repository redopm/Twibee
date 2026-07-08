-- Ensure pg_net is enabled
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 1. Create Webhook Trigger for call_participants to call push-call Edge Function
CREATE OR REPLACE FUNCTION trigger_push_call()
RETURNS trigger AS $$
DECLARE
  v_payload jsonb; -- [FIX 2] Changed from json to jsonb
  v_supabase_url text;
  v_supabase_anon_key text;
BEGIN
  IF NEW.status = 'invited' THEN
    -- Fallback to the project URL if custom setting not found
    v_supabase_url := 'https://xfynwiyungfkckhjhzsg.supabase.co';
    v_supabase_anon_key := 'sb_publishable_OK7XVN9Mq4qZiGYva-TCgQ_jFzrphag';

    -- [FIX 2] jsonb_build_object returns jsonb directly
    v_payload := jsonb_build_object('type', 'INSERT', 'table', 'call_participants', 'record', row_to_json(NEW));

    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/push-call',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_supabase_anon_key),
      body := v_payload
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_call_participant_invited ON call_participants;

CREATE TRIGGER on_call_participant_invited
  AFTER INSERT ON call_participants FOR EACH ROW
  EXECUTE FUNCTION trigger_push_call();


-- 2. Create pg_cron job for Auto-Hangup
-- [FIX 1] Unschedule existing job before creating a new one to prevent errors on re-run
SELECT cron.unschedule('auto_hangup_calls');

SELECT cron.schedule('auto_hangup_calls', '* * * * *',
  $$
    UPDATE call_participants SET status = 'missed' 
    WHERE status = 'invited' AND joined_at IS NULL AND created_at < NOW() - INTERVAL '60 seconds';
      
    UPDATE call_logs SET status = 'completed', ended_at = NOW() 
    WHERE status = 'ongoing' AND created_at < NOW() - INTERVAL '60 seconds' 
      AND NOT EXISTS (SELECT 1 FROM call_participants WHERE call_id = call_logs.id AND status = 'joined');
  $$
);
