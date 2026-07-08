-- ============================================================
-- 1. Create Webhook Trigger for messages to call push-message Edge Function
-- ============================================================
CREATE OR REPLACE FUNCTION trigger_push_message()
RETURNS trigger AS $$
DECLARE
  v_payload jsonb;
  v_supabase_url text;
  v_supabase_anon_key text;
BEGIN
  -- We only want to trigger this for actual user messages
  IF NEW.message_type != 'event' AND NEW.message_type != 'system' THEN
    -- Fallback to the project URL if custom setting not found
    v_supabase_url := 'https://xfynwiyungfkckhjhzsg.supabase.co';
    v_supabase_anon_key := 'sb_publishable_OK7XVN9Mq4qZiGYva-TCgQ_jFzrphag';

    v_payload := jsonb_build_object('type', 'INSERT', 'table', 'messages', 'record', row_to_json(NEW));

    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/push-message',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_supabase_anon_key),
      body := v_payload
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_message_insert_push ON messages;

CREATE TRIGGER on_message_insert_push
  AFTER INSERT ON messages FOR EACH ROW
  EXECUTE FUNCTION trigger_push_message();
