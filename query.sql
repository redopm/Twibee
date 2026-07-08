SELECT conname FROM pg_constraint WHERE conrelid = 'public.messages'::regclass;
