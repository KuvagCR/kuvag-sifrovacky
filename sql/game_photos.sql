-- Spustit jednou v Supabase SQL Editoru.
-- Soukromý bucket: fotografie nejsou veřejně čitelné.
INSERT INTO storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
VALUES ('kuvag-game-photos','kuvag-game-photos',false,8388608,ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE SET public=false,file_size_limit=8388608,allowed_mime_types=EXCLUDED.allowed_mime_types;

-- Povolit vložení pouze k dokončené herní relaci, nejpozději 24 hodin po dokončení.
CREATE OR REPLACE FUNCTION public.can_upload_game_photo(p_path text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,storage AS $$
DECLARE token_text text; photo_name text;
BEGIN
 token_text := split_part(p_path,'/',1);
 photo_name := split_part(p_path,'/',2);
 IF p_path !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$' THEN RETURN false; END IF;
 RETURN EXISTS (
  SELECT 1 FROM public.game_sessions gs
  WHERE gs.session_token=token_text::uuid
  AND gs.is_finished=true
  AND gs.finished_at > now()-interval '24 hours'
 );
END;$$;
REVOKE ALL ON FUNCTION public.can_upload_game_photo(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_upload_game_photo(text) TO anon,authenticated;

DROP POLICY IF EXISTS "Players upload completed game photos" ON storage.objects;
CREATE POLICY "Players upload completed game photos"
ON storage.objects FOR INSERT TO anon,authenticated
WITH CHECK (bucket_id='kuvag-game-photos' AND public.can_upload_game_photo(name));

-- Záměrně žádná veřejná SELECT/UPDATE/DELETE politika.
-- Fotografie může organizátor prohlížet v Supabase Storage v soukromém bucketu.
