-- Apply in Supabase SQL Editor before deploying the matching app.js.
-- Keeps testing without employee code; enforces code for KUVAG sessions.
-- IMPORTANT: review other direct table write permissions and add rate limiting before public launch.
BEGIN;
CREATE OR REPLACE FUNCTION public.start_game_session_secure(
 p_game_id bigint, p_player_name text, p_player_type text,
 p_session_token uuid, p_show_in_leaderboard boolean DEFAULT false,
 p_employee_code text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public'
AS $$
DECLARE v_visibility text;
BEGIN
 SELECT visibility INTO v_visibility FROM public.games WHERE id=p_game_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'GAME_NOT_FOUND'; END IF;
 IF v_visibility='test' THEN
   IF p_player_type IS DISTINCT FROM 'test' THEN RAISE EXCEPTION 'TEST_ONLY'; END IF;
 ELSIF v_visibility='kuvag' THEN
   IF p_player_type IS DISTINCT FROM 'kuvag' THEN RAISE EXCEPTION 'EMPLOYEE_ONLY'; END IF;
 ELSIF v_visibility='public' THEN
   IF p_player_type NOT IN ('public','kuvag') THEN RAISE EXCEPTION 'INVALID_PLAYER_TYPE'; END IF;
 ELSE
   RAISE EXCEPTION 'GAME_NOT_AVAILABLE';
 END IF;
 IF p_player_type='kuvag' AND NOT coalesce(public.verify_employee_code(p_employee_code),false) THEN
   RAISE EXCEPTION 'INVALID_EMPLOYEE_CODE';
 END IF;
 PERFORM public.start_game_session(p_game_id,p_player_name,p_player_type,p_session_token,p_show_in_leaderboard);
END;
$$;
REVOKE ALL ON FUNCTION public.start_game_session(bigint,text,text,uuid,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.start_game_session_secure(bigint,text,text,uuid,boolean,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_game_session_secure(bigint,text,text,uuid,boolean,text) TO anon, authenticated;
COMMIT;
