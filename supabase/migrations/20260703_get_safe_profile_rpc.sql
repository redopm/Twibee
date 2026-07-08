
-- 20260703_get_safe_profile_rpc.sql
CREATE OR REPLACE FUNCTION get_safe_profile(target_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS \$\$
DECLARE
  profile_row RECORD;
  is_photo_visible BOOLEAN;
  is_about_visible BOOLEAN;
BEGIN
  SELECT id, name, phone_number, avatar_url, about, public_key
  INTO profile_row
  FROM public.profiles
  WHERE id = target_user_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  is_photo_visible := can_view_target_status(target_user_id, 'privacy_profile_photo');
  is_about_visible := can_view_target_status(target_user_id, 'privacy_about');

  RETURN json_build_object(
    'id', profile_row.id,
    'name', profile_row.name,
    'phone_number', profile_row.phone_number,
    'public_key', profile_row.public_key,
    'avatar_url', CASE WHEN is_photo_visible THEN profile_row.avatar_url ELSE NULL END,
    'about', CASE WHEN is_about_visible THEN profile_row.about ELSE NULL END
  );
END;
\$\$;

CREATE OR REPLACE FUNCTION get_safe_profiles()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS \$\$
DECLARE
  rec RECORD;
  result JSON[] := ARRAY[]::JSON[];
BEGIN
  FOR rec IN
    SELECT id, name, phone_number, avatar_url, about
    FROM public.profiles
    WHERE id != auth.uid()
  LOOP
    result := array_append(result, json_build_object(
      'id', rec.id,
      'name', rec.name,
      'phone_number', rec.phone_number,
      'avatar_url', CASE WHEN can_view_target_status(rec.id, 'privacy_profile_photo') THEN rec.avatar_url ELSE NULL END,
      'about', CASE WHEN can_view_target_status(rec.id, 'privacy_about') THEN rec.about ELSE NULL END
    ));
  END LOOP;
  RETURN array_to_json(result);
END;
\$\$;
