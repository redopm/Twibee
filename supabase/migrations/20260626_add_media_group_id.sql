-- Migration to support WhatsApp-style multi-media batching
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS media_group_id UUID NULL,
ADD COLUMN IF NOT EXISTS order_index INT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_messages_media_group_id ON messages(media_group_id);
