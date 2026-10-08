-- Administrace: spusť v Supabase SQL Editoru.
-- Po vytvoření účtu v Authentication > Users přidej jeho UUID do public.game_admins.
CREATE TABLE IF NOT EXISTS public.game_admins (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.game_admins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.game_admins FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS public.game_photo_reviews (
 object_name text PRIMARY KEY,
 approved boolean NOT NULL DEFAULT false,
 reviewed_at timestamptz,
 reviewed_by uuid REFERENCES auth.users(id)
);
ALTER TABLE public.game_photo_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.game_photo_reviews FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.is_game_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT EXISTS(SELECT 1 FROM public.game_admins WHERE user_id=auth.uid());
$$;
REVOKE ALL ON FUNCTION public.is_game_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_game_admin() TO authenticated;

CREATE OR REPLACE FUNCTION public.game_admin_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NOT public.is_game_admin() THEN RAISE EXCEPTION 'ACCESS_DENIED'; END IF;
 RETURN jsonb_build_object(
  'totalRatings',(SELECT count(*) FROM public.game_feedback),
  'averageRating',(SELECT round(avg(rating)::numeric,1) FROM public.game_feedback),
  'ratings',(SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',f.id,'gameId',f.game_id,'playerType',f.player_type,
    'rating',f.rating,'comment',f.comment,'employeeAnswer',f.employee_answer,
    'createdAt',f.created_at) ORDER BY f.created_at DESC),'[]'::jsonb)
    FROM (SELECT * FROM public.game_feedback ORDER BY created_at DESC LIMIT 300) f),
  'photos',(SELECT coalesce(jsonb_agg(jsonb_build_object(
    'name',o.name,'createdAt',o.created_at,
    'approved',coalesce(r.approved,false)) ORDER BY o.created_at DESC),'[]'::jsonb)
    FROM storage.objects o LEFT JOIN public.game_photo_reviews r ON r.object_name=o.name
    WHERE o.bucket_id='kuvag-game-photos'),
  'finishedSessions',(SELECT count(*) FROM public.game_sessions WHERE is_finished=true)
 );
END;$$;
REVOKE ALL ON FUNCTION public.game_admin_overview() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.game_admin_overview() TO authenticated;

CREATE OR REPLACE FUNCTION public.game_admin_approve_photo(p_name text,p_approved boolean)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NOT public.is_game_admin() THEN RAISE EXCEPTION 'ACCESS_DENIED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='kuvag-game-photos' AND name=p_name) THEN RETURN false; END IF;
 INSERT INTO public.game_photo_reviews(object_name,approved,reviewed_at,reviewed_by)
 VALUES(p_name,p_approved,now(),auth.uid())
 ON CONFLICT(object_name) DO UPDATE SET approved=excluded.approved,reviewed_at=now(),reviewed_by=auth.uid();
 RETURN true;
END;$$;
REVOKE ALL ON FUNCTION public.game_admin_approve_photo(text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.game_admin_approve_photo(text,boolean) TO authenticated;

DROP POLICY IF EXISTS "Game admins read private photos" ON storage.objects;
CREATE POLICY "Game admins read private photos"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id='kuvag-game-photos' AND public.is_game_admin());

-- PŘÍKLAD po vytvoření admin účtu (dosaď skutečné UUID z Authentication > Users):
-- INSERT INTO public.game_admins(user_id) VALUES ('SEM-VLOZ-UUID-UZIVATELE');
