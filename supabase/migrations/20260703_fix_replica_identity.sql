-- Enable replica identity full
ALTER TABLE public.message_reactions REPLICA IDENTITY FULL;

-- Enable realtime for this table (if not already enabled)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND schemaname = 'public'
    AND tablename = 'message_reactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
  END IF;
END
$$;
