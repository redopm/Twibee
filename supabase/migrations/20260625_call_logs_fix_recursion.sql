DROP POLICY IF EXISTS "Participants can read call_participants" ON call_participants;

CREATE POLICY "Anyone can read call_participants" ON call_participants
FOR SELECT USING (true);
