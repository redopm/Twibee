BEGIN;
SELECT plan(4);

-- Insert dummy data
INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-000000000006', 'user6@test.com'),
  ('00000000-0000-0000-0000-000000000007', 'user7@test.com');

INSERT INTO profiles (id, phone_number, name) VALUES
  ('00000000-0000-0000-0000-000000000006', '+6666666666', 'User 6'),
  ('00000000-0000-0000-0000-000000000007', '+7777777777', 'User 7');

-- Set context to User 6
SELECT set_config('role', 'authenticated', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000006", "role": "authenticated"}', true);

-- TEST 1: User 6 can insert their own status
SELECT lives_ok(
  $$INSERT INTO statuses (id, user_id, media_type, expires_at) VALUES ('status-1', '00000000-0000-0000-0000-000000000006', 'text', NOW() + interval '24 hours')$$,
  'Users should be able to insert their own status'
);

-- TEST 2: User 6 cannot insert a status for User 7
SELECT throws_ok(
  $$INSERT INTO statuses (id, user_id, media_type, expires_at) VALUES ('status-2', '00000000-0000-0000-0000-000000000007', 'text', NOW() + interval '24 hours')$$,
  'new row violates row-level security policy for table "statuses"',
  'Users should NOT be able to insert a status for another user'
);

-- TEST 3: User 6 can view their own status
SELECT results_eq(
  'SELECT id FROM statuses WHERE id = ''status-1''',
  ARRAY['status-1'],
  'Users should be able to view their own unexpired status'
);

-- TEST 4: Delete the status and ensure they can't delete someone else's
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000007", "role": "authenticated"}', true);

DELETE FROM statuses WHERE id = 'status-1';

-- Ensure it was NOT deleted since User 7 tried to delete User 6's status
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000006", "role": "authenticated"}', true);
SELECT results_eq(
  'SELECT id FROM statuses WHERE id = ''status-1''',
  ARRAY['status-1'],
  'Users should NOT be able to delete another users status'
);

SELECT * FROM finish();
ROLLBACK;
