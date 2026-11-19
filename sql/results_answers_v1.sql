BEGIN;

UPDATE public.stations SET title='Knárovka – Deset stop starého písaře'
WHERE game_id=1 AND station_order=6;
UPDATE public.stations SET title='Zelenohorská pošta – Tři znamení'
WHERE game_id=1 AND station_order=7;
UPDATE public.stations SET title='Tajemství domovního znamení'
WHERE game_id=1 AND station_order=8;

DROP FUNCTION IF EXISTS public.game_action_v2(uuid,bigint,text,text);
CREATE FUNCTION public.game_action_v2(
 p_session_token uuid,
 p_station_id bigint,
 p_action text,
 p_answer text DEFAULT NULL,
 p_submitted_answer text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
 ses public.game_sessions%ROWTYPE;
 st public.stations%ROWTYPE;
 pr public.station_progress%ROWTYPE;
 nxt bigint;
 correct boolean;
 h integer;
 w integer;
 used boolean;
 answer text;
 submitted text;
BEGIN
 SELECT * INTO ses FROM public.game_sessions
 WHERE session_token=p_session_token AND NOT is_finished FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

 SELECT * INTO st FROM public.stations
 WHERE id=p_station_id AND game_id=ses.game_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_STATION'; END IF;
 IF ses.game_id=1 AND st.station_order=4 THEN RAISE EXCEPTION 'INVALID_STATION'; END IF;

 SELECT s.id INTO nxt FROM public.stations s
 WHERE s.game_id=ses.game_id
 AND NOT EXISTS (
  SELECT 1 FROM public.station_progress p
  WHERE p.session_id=ses.id AND p.station_id=s.id AND p.answer_verified
 )
 AND (s.game_id<>1 OR s.station_order<>4)
 ORDER BY s.station_order,s.id LIMIT 1;
 IF nxt IS DISTINCT FROM p_station_id THEN RAISE EXCEPTION 'WRONG_STATION_ORDER'; END IF;

 INSERT INTO public.station_progress(
  session_id,station_id,hints_used,wrong_attempts,answer_history,hints_history,started_at
 ) VALUES(ses.id,st.id,0,0,'[]'::jsonb,'[]'::jsonb,now())
 ON CONFLICT(session_id,station_id) DO NOTHING;
 SELECT * INTO pr FROM public.station_progress
 WHERE session_id=ses.id AND station_id=st.id FOR UPDATE;

 h:=greatest(pr.hints_used,0);
 w:=greatest(pr.wrong_attempts,0);
 used:=pr.navigation_used;
 submitted:=coalesce(nullif(btrim(p_submitted_answer),''),p_answer);

 IF p_action='answer' THEN
  IF nullif(btrim(coalesce(p_answer,'')),'') IS NULL THEN RAISE EXCEPTION 'EMPTY_ANSWER'; END IF;
  correct:=public.normalize_game_answer(p_answer)=public.normalize_game_answer(st.correct_answer);
  IF NOT correct AND st.accepted_answers IS NOT NULL THEN
   SELECT EXISTS(
    SELECT 1 FROM unnest(string_to_array(st.accepted_answers,';')) a(v)
    WHERE public.normalize_game_answer(a.v)=public.normalize_game_answer(p_answer)
   ) INTO correct;
  END IF;
  IF correct THEN
   UPDATE public.station_progress SET answer_verified=true,completed_at=now(),finished_at=now(),
    answer_history=coalesce(answer_history,'[]'::jsonb)
     ||jsonb_build_array(jsonb_build_object('at',now(),'answer',submitted,'correct',true))
   WHERE id=pr.id;
  ELSE
   w:=w+1;
   UPDATE public.station_progress SET wrong_attempts=w,
    answer_history=coalesce(answer_history,'[]'::jsonb)
     ||jsonb_build_array(jsonb_build_object('at',now(),'answer',submitted,'correct',false))
   WHERE id=pr.id;
  END IF;
  RETURN jsonb_build_object('correct',correct,'hints',h,'wrong',w,'navigationUsed',used);
 ELSIF p_action='hint' THEN
  IF h>=2 THEN RETURN jsonb_build_object('hint',null,'hints',h,'wrong',w); END IF;
  answer:=CASE WHEN h=0 THEN st.hint_1 ELSE st.hint_2 END;
  IF nullif(answer,'') IS NULL THEN RETURN jsonb_build_object('hint',null,'hints',h,'wrong',w); END IF;
  h:=h+1;
  UPDATE public.station_progress SET hints_used=h,
   hints_history=coalesce(hints_history,'[]'::jsonb)
    ||jsonb_build_array(jsonb_build_object('at',now(),'hint',h))
  WHERE id=pr.id;
  RETURN jsonb_build_object('hint',answer,'hints',h,'wrong',w);
 ELSIF p_action='navigation' THEN
  IF nullif(st.navigation_target,'') IS NULL THEN RAISE EXCEPTION 'NO_NAVIGATION_TARGET'; END IF;
  IF NOT used THEN UPDATE public.station_progress SET navigation_used=true WHERE id=pr.id; END IF;
  RETURN jsonb_build_object('navigationTarget',st.navigation_target,'navigationUsed',true,'hints',h,'wrong',w);
 END IF;
 RAISE EXCEPTION 'INVALID_ACTION';
END;
$$;
REVOKE ALL ON FUNCTION public.game_action_v2(uuid,bigint,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.game_action_v2(uuid,bigint,text,text,text) TO anon,authenticated;

DROP FUNCTION IF EXISTS public.record_multistage_action(uuid,bigint,text,integer,integer);
CREATE FUNCTION public.record_multistage_action(
 p_session_token uuid,
 p_station_id bigint,
 p_action text,
 p_stage integer,
 p_target_count integer,
 p_answer text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
 ses public.game_sessions%ROWTYPE;
 st public.stations%ROWTYPE;
 pr public.station_progress%ROWTYPE;
 next_id bigint;
 stage_hints integer[];
 stage_wrongs integer[];
 current_count integer;
BEGIN
 SELECT * INTO ses FROM public.game_sessions
 WHERE session_token=p_session_token AND NOT is_finished FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

 SELECT * INTO st FROM public.stations
 WHERE id=p_station_id AND game_id=ses.game_id;
 IF NOT FOUND OR ses.game_id<>1 OR st.station_order<>2 THEN RAISE EXCEPTION 'INVALID_STATION'; END IF;
 IF p_stage IS NULL OR p_stage NOT BETWEEN 1 AND 3 THEN RAISE EXCEPTION 'INVALID_STAGE'; END IF;
 IF p_action IS NULL OR p_action NOT IN ('hint','wrong','correct') THEN RAISE EXCEPTION 'INVALID_ACTION'; END IF;
 IF p_target_count IS NULL THEN RAISE EXCEPTION 'INVALID_COUNT'; END IF;
 IF p_action='correct' AND (
  p_stage>2 OR p_target_count<>1 OR nullif(btrim(coalesce(p_answer,'')),'') IS NULL
 ) THEN RAISE EXCEPTION 'INVALID_CORRECT_ANSWER'; END IF;

 SELECT s.id INTO next_id FROM public.stations s
 WHERE s.game_id=ses.game_id
 AND NOT EXISTS (
  SELECT 1 FROM public.station_progress p
  WHERE p.session_id=ses.id AND p.station_id=s.id AND p.answer_verified
 )
 AND (s.game_id<>1 OR s.station_order<>4)
 ORDER BY s.station_order,s.id LIMIT 1;
 IF next_id IS DISTINCT FROM p_station_id THEN RAISE EXCEPTION 'WRONG_STATION_ORDER'; END IF;

 IF p_action='hint' AND p_target_count NOT BETWEEN 1 AND 2 THEN RAISE EXCEPTION 'INVALID_HINT_COUNT'; END IF;
 IF p_action='wrong' AND (p_target_count<1 OR p_target_count>1000) THEN RAISE EXCEPTION 'INVALID_WRONG_COUNT'; END IF;
 IF p_action='correct' AND public.normalize_game_answer(p_answer)
  <>(CASE p_stage WHEN 1 THEN 'BERANEK' ELSE 'UPROSTRED' END)
 THEN RAISE EXCEPTION 'INVALID_CORRECT_ANSWER'; END IF;

 INSERT INTO public.station_progress(
  session_id,station_id,hints_used,wrong_attempts,answer_history,hints_history,started_at
 ) VALUES(ses.id,st.id,0,0,'[]'::jsonb,'[]'::jsonb,now())
 ON CONFLICT(session_id,station_id) DO NOTHING;
 SELECT * INTO pr FROM public.station_progress
 WHERE session_id=ses.id AND station_id=st.id FOR UPDATE;

 stage_hints:=coalesce(pr.stage_hint_counts,ARRAY[0,0,0]::integer[]);
 stage_wrongs:=coalesce(pr.stage_wrong_counts,ARRAY[0,0,0]::integer[]);

 IF p_action='hint' THEN
  current_count:=coalesce(stage_hints[p_stage],0);
  IF p_target_count>current_count THEN
   stage_hints[p_stage]:=p_target_count;
   UPDATE public.station_progress SET stage_hint_counts=stage_hints,
    hints_used=coalesce(hints_used,0)+p_target_count-current_count,
    hints_history=coalesce(hints_history,'[]'::jsonb)
     ||jsonb_build_array(jsonb_build_object('at',now(),'hint',p_target_count,'stage',p_stage))
   WHERE id=pr.id;
  END IF;
 ELSIF p_action='wrong' THEN
  current_count:=coalesce(stage_wrongs[p_stage],0);
  IF p_target_count>current_count THEN
   stage_wrongs[p_stage]:=p_target_count;
   UPDATE public.station_progress SET stage_wrong_counts=stage_wrongs,
    wrong_attempts=coalesce(wrong_attempts,0)+p_target_count-current_count,
    answer_history=coalesce(answer_history,'[]'::jsonb)
     ||jsonb_build_array(jsonb_build_object(
      'at',now(),'answer',nullif(btrim(p_answer),''),'correct',false,'stage',p_stage
     ))
   WHERE id=pr.id;
  END IF;
 ELSE
  IF NOT EXISTS(
   SELECT 1 FROM jsonb_array_elements(coalesce(pr.answer_history,'[]'::jsonb)) AS history(item)
   WHERE item->>'stage'=p_stage::text AND item->>'correct'='true'
  ) THEN
   UPDATE public.station_progress SET answer_history=coalesce(answer_history,'[]'::jsonb)
    ||jsonb_build_array(jsonb_build_object(
     'at',now(),'answer',nullif(btrim(p_answer),''),'correct',true,'stage',p_stage
    ))
   WHERE id=pr.id;
  END IF;
 END IF;

 SELECT * INTO pr FROM public.station_progress WHERE id=pr.id;
 RETURN jsonb_build_object(
  'stageHints',pr.stage_hint_counts,'stageWrongCounts',pr.stage_wrong_counts,
  'hints',pr.hints_used,'wrong',pr.wrong_attempts,'navigationUsed',pr.navigation_used
 );
END;
$$;
REVOKE ALL ON FUNCTION public.record_multistage_action(uuid,bigint,text,integer,integer,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_multistage_action(uuid,bigint,text,integer,integer,text) TO anon,authenticated;

COMMIT;
