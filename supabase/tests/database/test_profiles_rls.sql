BEGIN;
SELECT plan(3);

-- Insert dummy data
INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-000000000004', 'user4@test.com'),
  ('00000000-0000-0000-0000-000000000005', 'user5@test.com');

INSERT INTO profiles (id, phone_number, name) VALUES
  ('00000000-0000-0000-0000-000000000004', '+4444444444', 'User 4'),
  ('00000000-0000-0000-0000-000000000005', '+5555555555', 'User 5');

-- TEST 1: User 4 can select their own profile
SELECT set_config('role', 'authenticated', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000004", "role": "authenticated"}', true);

SELECT results_eq(
  'SELECT name FROM profiles WHERE id = ''00000000-0000-0000-0000-000000000004''',
  ARRAY['User 4'::text],
  'Users should be able to view their own profile'
);

-- TEST 2: User 4 can update their own profile
SELECT lives_ok(
  $$UPDATE profiles SET name = 'Updated User 4' WHERE id = '00000000-0000-0000-0000-000000000004'$$,
  'Users should be able to update their own profile'
);

-- TEST 3: User 4 cannot update User 5's profile
-- This typically shouldn't throw an error but affect 0 rows if RLS prevents it.
-- We can verify it by attempting an update and then checking if the name changed.
UPDATE profiles SET name = 'Hacked User 5' WHERE id = '00000000-0000-0000-0000-000000000005';

SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000005", "role": "authenticated"}', true);
SELECT results_eq(
  'SELECT name FROM profiles WHERE id = ''00000000-0000-0000-0000-000000000005''',
  ARRAY['User 5'::text],
  'Users should NOT be able to update other users profiles'
);

SELECT * FROM finish();
ROLLBACK;
