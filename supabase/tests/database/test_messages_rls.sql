BEGIN;
SELECT plan(4);

-- Insert dummy data
INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-000000000001', 'user1@test.com'),
  ('00000000-0000-0000-0000-000000000002', 'user2@test.com'),
  ('00000000-0000-0000-0000-000000000003', 'user3@test.com');

INSERT INTO profiles (id, phone_number, name) VALUES
  ('00000000-0000-0000-0000-000000000001', '+1111111111', 'User 1'),
  ('00000000-0000-0000-0000-000000000002', '+2222222222', 'User 2'),
  ('00000000-0000-0000-0000-000000000003', '+3333333333', 'User 3');

INSERT INTO chats (id, is_group, created_by) VALUES
  ('chat-1', false, '00000000-0000-0000-0000-000000000001');

INSERT INTO chat_participants (chat_id, user_id) VALUES
  ('chat-1', '00000000-0000-0000-0000-000000000001'),
  ('chat-1', '00000000-0000-0000-0000-000000000002');

INSERT INTO messages (id, chat_id, sender_id, text_content) VALUES
  ('msg-1', 'chat-1', '00000000-0000-0000-0000-000000000001', 'Hello User 2!');


-- TEST 1: User 1 (Participant) can select the message
SELECT set_config('role', 'authenticated', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}', true);

SELECT results_eq(
  'SELECT id FROM messages WHERE id = ''msg-1''',
  ARRAY['msg-1'],
  'Participants should be able to view messages in their chat'
);

-- TEST 2: User 3 (Non-Participant) cannot select the message
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000003", "role": "authenticated"}', true);

SELECT is_empty(
  'SELECT id FROM messages WHERE id = ''msg-1''',
  'Non-participants should NOT be able to view messages'
);

-- TEST 3: User 1 (Participant) can insert a message
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}', true);

SELECT lives_ok(
  $$INSERT INTO messages (id, chat_id, sender_id, text_content) VALUES ('msg-2', 'chat-1', '00000000-0000-0000-0000-000000000001', 'Test insertion')$$
  , 'Participants should be able to insert messages'
);

-- TEST 4: User 3 (Non-Participant) cannot insert a message
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000003", "role": "authenticated"}', true);

SELECT throws_ok(
  $$INSERT INTO messages (id, chat_id, sender_id, text_content) VALUES ('msg-3', 'chat-1', '00000000-0000-0000-0000-000000000003', 'Hacked message')$$
  , 'new row violates row-level security policy for table "messages"'
  , 'Non-participants should NOT be able to insert messages into chats they do not belong to'
);

SELECT * FROM finish();
ROLLBACK;
