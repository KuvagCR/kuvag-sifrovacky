-- Security migration: apply ONLY with matching frontend release.
BEGIN;
ALTER TABLE public.station_progress ADD COLUMN IF NOT EXISTS navigation_used boolean NOT NULL DEFAULT false;
ALTER TABLE public.station_progress ADD COLUMN IF NOT EXISTS answer_verified boolean NOT NULL DEFAULT false;
ALTER TABLE public.station_progress ADD COLUMN IF NOT EXISTS stage_hint_counts integer[] NOT NULL DEFAULT ARRAY[0,0,0]::integer[];
ALTER TABLE public.station_progress ADD COLUMN IF NOT EXISTS stage_wrong_counts integer[] NOT NULL DEFAULT ARRAY[0,0,0]::integer[];
UPDATE public.stations
SET hint_1='Prohlédni si sochu stojící na vrcholu kašny.',
    hint_2='Jde o Ježíšovu matku – Pannu Marii.'
WHERE game_id=1 AND station_order=9;
UPDATE public.stations SET title='Knárovka – Deset stop starého písaře'
WHERE game_id=1 AND station_order=6;
UPDATE public.stations SET title='Zelenohorská pošta – Tři znamení'
WHERE game_id=1 AND station_order=7;
UPDATE public.stations SET title='Tajemství domovního znamení'
WHERE game_id=1 AND station_order=8;
-- Game 1's fourth station row is rendered only as a story transition in the
-- frontend, so it must not block the next playable station or game completion.
DROP FUNCTION IF EXISTS public.game_action_v2(uuid,bigint,text,text);
CREATE FUNCTION public.game_action_v2(p_session_token uuid,p_station_id bigint,p_action text,p_answer text DEFAULT NULL,p_submitted_answer text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE ses public.game_sessions%ROWTYPE; st public.stations%ROWTYPE; pr public.station_progress%ROWTYPE; nxt bigint; correct boolean; h integer; w integer; used boolean; answer text;
BEGIN
SELECT * INTO ses FROM public.game_sessions WHERE session_token=p_session_token AND NOT is_finished FOR UPDATE;
IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
SELECT * INTO st FROM public.stations WHERE id=p_station_id AND game_id=ses.game_id;
IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_STATION'; END IF;
IF ses.game_id=1 AND st.station_order=4 THEN RAISE EXCEPTION 'INVALID_STATION'; END IF;
SELECT s.id INTO nxt FROM public.stations s WHERE s.game_id=ses.game_id AND NOT EXISTS
 (SELECT 1 FROM public.station_progress p WHERE p.session_id=ses.id AND p.station_id=s.id AND p.answer_verified)
 AND (s.game_id<>1 OR s.station_order<>4)
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
 answer_history=coalesce(answer_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object('at',now(),'answer',coalesce(nullif(btrim(p_submitted_answer),''),p_answer),'correct',true)) WHERE id=pr.id;
 ELSE
 w:=w+1;UPDATE public.station_progress SET wrong_attempts=w,
 answer_history=coalesce(answer_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object('at',now(),'answer',coalesce(nullif(btrim(p_submitted_answer),''),p_answer),'correct',false)) WHERE id=pr.id; END IF;
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
DROP FUNCTION IF EXISTS public.record_multistage_action(uuid,bigint,text,integer,integer);
CREATE FUNCTION public.record_multistage_action(p_session_token uuid,p_station_id bigint,p_action text,p_stage integer,p_target_count integer,p_answer text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE ses public.game_sessions%ROWTYPE; st public.stations%ROWTYPE; pr public.station_progress%ROWTYPE;
 next_id bigint; stage_hints integer[]; stage_wrongs integer[]; current_count integer;
BEGIN
SELECT * INTO ses FROM public.game_sessions WHERE session_token=p_session_token AND NOT is_finished FOR UPDATE;
IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
SELECT * INTO st FROM public.stations WHERE id=p_station_id AND game_id=ses.game_id;
IF NOT FOUND OR ses.game_id<>1 OR st.station_order<>2 THEN RAISE EXCEPTION 'INVALID_STATION'; END IF;
IF p_stage IS NULL OR p_stage NOT BETWEEN 1 AND 3 THEN RAISE EXCEPTION 'INVALID_STAGE'; END IF;
IF p_action IS NULL OR p_action NOT IN ('hint','wrong','correct') THEN RAISE EXCEPTION 'INVALID_ACTION'; END IF;
IF p_target_count IS NULL THEN RAISE EXCEPTION 'INVALID_COUNT'; END IF;
IF p_action='correct' AND (p_stage>2 OR p_target_count<>1 OR nullif(btrim(coalesce(p_answer,'')),'') IS NULL) THEN RAISE EXCEPTION 'INVALID_CORRECT_ANSWER'; END IF;
SELECT s.id INTO next_id FROM public.stations s WHERE s.game_id=ses.game_id AND NOT EXISTS
 (SELECT 1 FROM public.station_progress p WHERE p.session_id=ses.id AND p.station_id=s.id AND p.answer_verified)
 AND (s.game_id<>1 OR s.station_order<>4)
 ORDER BY s.station_order,s.id LIMIT 1;
IF next_id IS DISTINCT FROM p_station_id THEN RAISE EXCEPTION 'WRONG_STATION_ORDER'; END IF;
IF p_action='hint' AND p_target_count NOT BETWEEN 1 AND 2 THEN RAISE EXCEPTION 'INVALID_HINT_COUNT'; END IF;
IF p_action='wrong' AND (p_target_count<1 OR p_target_count>1000) THEN RAISE EXCEPTION 'INVALID_WRONG_COUNT'; END IF;
IF p_action='correct' AND public.normalize_game_answer(p_answer)<>(CASE p_stage WHEN 1 THEN 'BERANEK' ELSE 'UPROSTRED' END) THEN RAISE EXCEPTION 'INVALID_CORRECT_ANSWER'; END IF;
INSERT INTO public.station_progress(session_id,station_id,hints_used,wrong_attempts,answer_history,hints_history,started_at)
 VALUES(ses.id,st.id,0,0,'[]'::jsonb,'[]'::jsonb,now()) ON CONFLICT(session_id,station_id) DO NOTHING;
SELECT * INTO pr FROM public.station_progress WHERE session_id=ses.id AND station_id=st.id FOR UPDATE;
stage_hints:=coalesce(pr.stage_hint_counts,ARRAY[0,0,0]::integer[]);
stage_wrongs:=coalesce(pr.stage_wrong_counts,ARRAY[0,0,0]::integer[]);
IF p_action='hint' THEN
 current_count:=coalesce(stage_hints[p_stage],0);
 IF p_target_count>current_count THEN
  stage_hints[p_stage]:=p_target_count;
  UPDATE public.station_progress SET stage_hint_counts=stage_hints,hints_used=coalesce(hints_used,0)+p_target_count-current_count,
   hints_history=coalesce(hints_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object('at',now(),'hint',p_target_count,'stage',p_stage))
  WHERE id=pr.id;
 END IF;
ELSIF p_action='wrong' THEN
 current_count:=coalesce(stage_wrongs[p_stage],0);
 IF p_target_count>current_count THEN
  stage_wrongs[p_stage]:=p_target_count;
  UPDATE public.station_progress SET stage_wrong_counts=stage_wrongs,wrong_attempts=coalesce(wrong_attempts,0)+p_target_count-current_count,
   answer_history=coalesce(answer_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object('at',now(),'answer',nullif(btrim(p_answer),''),'correct',false,'stage',p_stage))
  WHERE id=pr.id;
 END IF;
ELSE
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(pr.answer_history,'[]'::jsonb)) AS history(item)
   WHERE item->>'stage'=p_stage::text AND item->>'correct'='true') THEN
  UPDATE public.station_progress SET answer_history=coalesce(answer_history,'[]'::jsonb)
   ||jsonb_build_array(jsonb_build_object('at',now(),'answer',nullif(btrim(p_answer),''),'correct',true,'stage',p_stage))
  WHERE id=pr.id;
 END IF;
END IF;
SELECT * INTO pr FROM public.station_progress WHERE id=pr.id;
RETURN jsonb_build_object('stageHints',pr.stage_hint_counts,'stageWrongCounts',pr.stage_wrong_counts,
 'hints',pr.hints_used,'wrong',pr.wrong_attempts,'navigationUsed',pr.navigation_used);
END;$$;
REVOKE ALL ON FUNCTION public.record_multistage_action(uuid,bigint,text,integer,integer,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_multistage_action(uuid,bigint,text,integer,integer,text) TO anon,authenticated;
CREATE OR REPLACE FUNCTION public.game_station_points_v2(p_station_order integer,p_hints_used integer,p_stage_hint_counts integer[],p_wrong_attempts integer,p_navigation_used boolean)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO 'public' AS $$
SELECT greatest(0,100
 - CASE WHEN p_station_order=2 THEN
   (CASE WHEN coalesce(p_stage_hint_counts[1],0)>0 THEN 10 ELSE 0 END
    +CASE WHEN coalesce(p_stage_hint_counts[1],0)>1 THEN 20 ELSE 0 END
    +CASE WHEN coalesce(p_stage_hint_counts[2],0)>0 THEN 10 ELSE 0 END
    +CASE WHEN coalesce(p_stage_hint_counts[2],0)>1 THEN 20 ELSE 0 END
    +CASE WHEN coalesce(p_stage_hint_counts[3],0)>0 THEN 10 ELSE 0 END
    +CASE WHEN coalesce(p_stage_hint_counts[3],0)>1 THEN 20 ELSE 0 END
    +CASE WHEN greatest(coalesce(p_hints_used,0)-coalesce(p_stage_hint_counts[1],0)
      -coalesce(p_stage_hint_counts[2],0)-coalesce(p_stage_hint_counts[3],0),0)=0 THEN 0
      WHEN greatest(coalesce(p_hints_used,0)-coalesce(p_stage_hint_counts[1],0)
      -coalesce(p_stage_hint_counts[2],0)-coalesce(p_stage_hint_counts[3],0),0)=1 THEN 10 ELSE 30 END)
   WHEN coalesce(p_hints_used,0)=0 THEN 0 WHEN p_hints_used=1 THEN 10 ELSE 30 END
 - greatest(coalesce(p_wrong_attempts,0),0)*5
 - CASE WHEN coalesce(p_navigation_used,false) THEN 30 ELSE 0 END)
$$;
REVOKE ALL ON FUNCTION public.game_station_points_v2(integer,integer,integer[],integer,boolean) FROM PUBLIC;
CREATE OR REPLACE FUNCTION public.finish_game_session(p_session_token uuid,p_finished_at timestamptz,p_hints_used integer,p_wrong_attempts integer,p_total_points integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE ses public.game_sessions%ROWTYPE; total integer; completed integer;
BEGIN
SELECT * INTO ses FROM public.game_sessions WHERE session_token=p_session_token AND NOT is_finished FOR UPDATE;
IF NOT FOUND THEN RETURN; END IF;
SELECT count(*) INTO total FROM public.stations
WHERE game_id=ses.game_id AND (game_id<>1 OR station_order<>4);
SELECT count(*) INTO completed FROM public.station_progress p JOIN public.stations s ON s.id=p.station_id
WHERE p.session_id=ses.id AND s.game_id=ses.game_id AND p.answer_verified
AND (s.game_id<>1 OR s.station_order<>4);
IF total=0 OR completed<>total THEN RAISE EXCEPTION 'GAME_NOT_COMPLETED'; END IF;
UPDATE public.game_sessions SET finished_at=now(),current_station=total,is_finished=true,
 hints_used=(SELECT coalesce(sum(p.hints_used),0) FROM public.station_progress p
 JOIN public.stations s ON s.id=p.station_id WHERE p.session_id=ses.id
 AND s.game_id=ses.game_id AND (s.game_id<>1 OR s.station_order<>4)),
 wrong_attempts=(SELECT coalesce(sum(p.wrong_attempts),0) FROM public.station_progress p
 JOIN public.stations s ON s.id=p.station_id WHERE p.session_id=ses.id
 AND s.game_id=ses.game_id AND (s.game_id<>1 OR s.station_order<>4)),
 total_points=(SELECT coalesce(sum(public.game_station_points_v2(s.station_order,p.hints_used,
 p.stage_hint_counts,p.wrong_attempts,p.navigation_used)),0)
 FROM public.station_progress p JOIN public.stations s ON s.id=p.station_id
 WHERE p.session_id=ses.id AND p.answer_verified AND s.game_id=ses.game_id
 AND (s.game_id<>1 OR s.station_order<>4))
WHERE id=ses.id;
END;$$;
CREATE OR REPLACE FUNCTION public.get_game_state_v2(p_session_token uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE ses public.game_sessions%ROWTYPE; next_id bigint; next_order integer; progress jsonb; total_score integer;
BEGIN
 SELECT * INTO ses FROM public.game_sessions WHERE session_token=p_session_token;
 IF NOT FOUND THEN RETURN NULL; END IF;
 SELECT s.id,s.station_order INTO next_id,next_order FROM public.stations s
 WHERE s.game_id=ses.game_id AND NOT EXISTS
 (SELECT 1 FROM public.station_progress sp WHERE sp.session_id=ses.id AND sp.station_id=s.id AND sp.answer_verified)
 AND (s.game_id<>1 OR s.station_order<>4)
 ORDER BY s.station_order,s.id LIMIT 1;
 SELECT coalesce(jsonb_agg(jsonb_build_object('stationId',sp.station_id,'stationOrder',s.station_order,'hints',sp.hints_used,'wrong',sp.wrong_attempts,
 'stageHints',sp.stage_hint_counts,'stageWrongCounts',sp.stage_wrong_counts,
 'navigationUsed',sp.navigation_used,'completed',sp.answer_verified)),'[]'::jsonb)
 INTO progress FROM public.station_progress sp JOIN public.stations s ON s.id=sp.station_id
 WHERE sp.session_id=ses.id AND s.game_id=ses.game_id
 AND (s.game_id<>1 OR s.station_order<>4);
 SELECT coalesce(sum(public.game_station_points_v2(s.station_order,sp.hints_used,
 sp.stage_hint_counts,sp.wrong_attempts,sp.navigation_used)),0)
 INTO total_score FROM public.station_progress sp JOIN public.stations s ON s.id=sp.station_id
 WHERE sp.session_id=ses.id AND sp.answer_verified AND s.game_id=ses.game_id
 AND (s.game_id<>1 OR s.station_order<>4);
 RETURN jsonb_build_object('gameId',ses.game_id,'isFinished',ses.is_finished,'startedAt',ses.started_at,
 'nextStationId',next_id,'nextStationOrder',next_order,'progress',progress,'earnedPoints',total_score);
END;$$;
GRANT EXECUTE ON FUNCTION public.get_game_state_v2(uuid) TO anon,authenticated;
-- Block direct table writes from client roles (RLS policies should also be reviewed).
REVOKE INSERT,UPDATE,DELETE ON public.station_progress FROM PUBLIC,anon,authenticated;
-- NOTE: game_sessions direct UPDATE permissions must be audited against admin workflows before revocation.
REVOKE ALL ON FUNCTION public.save_station_progress(uuid,bigint,integer,integer) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.save_station_detail(uuid,bigint,integer,integer,timestamptz,timestamptz,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.check_station_answer(uuid,bigint,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.check_station_answer(bigint,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.game_action_v2(uuid,bigint,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.game_action_v2(uuid,bigint,text,text,text) TO anon,authenticated;
COMMIT;