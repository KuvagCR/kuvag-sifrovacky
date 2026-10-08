-- Security migration: apply ONLY with matching frontend release.
BEGIN;
ALTER TABLE public.station_progress ADD COLUMN IF NOT EXISTS navigation_used boolean NOT NULL DEFAULT false;
ALTER TABLE public.station_progress ADD COLUMN IF NOT EXISTS answer_verified boolean NOT NULL DEFAULT false;
CREATE OR REPLACE FUNCTION public.game_action_v2(p_session_token uuid,p_station_id bigint,p_action text,p_answer text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE ses public.game_sessions%ROWTYPE; st public.stations%ROWTYPE; pr public.station_progress%ROWTYPE; nxt bigint; correct boolean; h integer; w integer; used boolean; answer text;
BEGIN
SELECT * INTO ses FROM public.game_sessions WHERE session_token=p_session_token AND NOT is_finished FOR UPDATE;
IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
SELECT * INTO st FROM public.stations WHERE id=p_station_id AND game_id=ses.game_id;
IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_STATION'; END IF;
SELECT s.id INTO nxt FROM public.stations s WHERE s.game_id=ses.game_id AND NOT EXISTS
 (SELECT 1 FROM public.station_progress p WHERE p.session_id=ses.id AND p.station_id=s.id AND p.answer_verified)
 ORDER BY s.station_order,s.id LIMIT 1;
IF nxt IS DISTINCT FROM p_station_id THEN RAISE EXCEPTION 'WRONG_STATION_ORDER'; END IF;
INSERT INTO public.station_progress(session_id,station_id,hints_used,wrong_attempts,answer_history,hints_history,started_at)
 VALUES(ses.id,st.id,0,0,'[]'::jsonb,'[]'::jsonb,now()) ON CONFLICT(session_id,station_id) DO NOTHING;
SELECT * INTO pr FROM public.station_progress WHERE session_id=ses.id AND station_id=st.id FOR UPDATE;
h:=greatest(pr.hints_used,0);w:=greatest(pr.wrong_attempts,0);used:=pr.navigation_used;
IF p_action='answer' THEN
 IF nullif(btrim(coalesce(p_answer,'')),'') IS NULL THEN RAISE EXCEPTION 'EMPTY_ANSWER'; END IF;
 correct:=public.normalize_game_answer(p_answer)=public.normalize_game_answer(st.correct_answer);
 IF NOT correct AND st.accepted_answers IS NOT NULL THEN
 SELECT EXISTS(SELECT 1 FROM unnest(string_to_array(st.accepted_answers,';')) a(v)
 WHERE public.normalize_game_answer(a.v)=public.normalize_game_answer(p_answer)) INTO correct; END IF;
 IF correct THEN
 UPDATE public.station_progress SET answer_verified=true,completed_at=now(),finished_at=now(),
 answer_history=coalesce(answer_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object('at',now(),'correct',true)) WHERE id=pr.id;
 ELSE
 w:=w+1;UPDATE public.station_progress SET wrong_attempts=w,
 answer_history=coalesce(answer_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object('at',now(),'correct',false)) WHERE id=pr.id; END IF;
 RETURN jsonb_build_object('correct',correct,'hints',h,'wrong',w,'navigationUsed',used);
ELSIF p_action='hint' THEN
 IF h>=2 THEN RETURN jsonb_build_object('hint',null,'hints',h,'wrong',w); END IF;
 answer:=CASE WHEN h=0 THEN st.hint_1 ELSE st.hint_2 END;
 IF nullif(answer,'') IS NULL THEN RETURN jsonb_build_object('hint',null,'hints',h,'wrong',w); END IF;
 h:=h+1;UPDATE public.station_progress SET hints_used=h,
 hints_history=coalesce(hints_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object('at',now(),'hint',h)) WHERE id=pr.id;
 RETURN jsonb_build_object('hint',answer,'hints',h,'wrong',w);
ELSIF p_action='navigation' THEN
 IF nullif(st.navigation_target,'') IS NULL THEN RAISE EXCEPTION 'NO_NAVIGATION_TARGET'; END IF;
 IF NOT used THEN UPDATE public.station_progress SET navigation_used=true WHERE id=pr.id; END IF;
 RETURN jsonb_build_object('navigationTarget',st.navigation_target,'navigationUsed',true,'hints',h,'wrong',w);
END IF;
RAISE EXCEPTION 'INVALID_ACTION';
END;$$;
CREATE OR REPLACE FUNCTION public.finish_game_session(p_session_token uuid,p_finished_at timestamptz,p_hints_used integer,p_wrong_attempts integer,p_total_points integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE ses public.game_sessions%ROWTYPE; total integer; completed integer;
BEGIN
SELECT * INTO ses FROM public.game_sessions WHERE session_token=p_session_token AND NOT is_finished FOR UPDATE;
IF NOT FOUND THEN RETURN; END IF;
SELECT count(*) INTO total FROM public.stations WHERE game_id=ses.game_id;
SELECT count(*) INTO completed FROM public.station_progress p JOIN public.stations s ON s.id=p.station_id
 WHERE p.session_id=ses.id AND s.game_id=ses.game_id AND p.answer_verified;
IF total=0 OR completed<>total THEN RAISE EXCEPTION 'GAME_NOT_COMPLETED'; END IF;
UPDATE public.game_sessions SET finished_at=now(),current_station=total,is_finished=true,
 hints_used=(SELECT coalesce(sum(hints_used),0) FROM public.station_progress WHERE session_id=ses.id),
 wrong_attempts=(SELECT coalesce(sum(wrong_attempts),0) FROM public.station_progress WHERE session_id=ses.id),
 total_points=(SELECT coalesce(sum(greatest(0,100
 - CASE WHEN hints_used=0 THEN 0 WHEN hints_used=1 THEN 10 ELSE 30 END
 - greatest(wrong_attempts,0)*5 - CASE WHEN navigation_used THEN 30 ELSE 0 END)),0)
 FROM public.station_progress WHERE session_id=ses.id AND answer_verified)
WHERE id=ses.id;
END;$$;
-- Block direct table writes from client roles (RLS policies should also be reviewed).
REVOKE INSERT,UPDATE,DELETE ON public.station_progress FROM PUBLIC,anon,authenticated;
REVOKE UPDATE ON public.game_sessions FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.save_station_progress(uuid,bigint,integer,integer) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.save_station_detail(uuid,bigint,integer,integer,timestamptz,timestamptz,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.check_station_answer(uuid,bigint,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.check_station_answer(bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.game_action_v2(uuid,bigint,text,text) TO anon,authenticated;
COMMIT;