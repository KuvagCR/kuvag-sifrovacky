-- Apply together with the frontend release that calls this RPC.
BEGIN;

CREATE OR REPLACE FUNCTION public.record_navigation_use_v1(
 p_session_token uuid,
 p_navigation_station_id bigint,
 p_confirm boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
 ses public.game_sessions%ROWTYPE;
 nav_st public.stations%ROWTYPE;
 next_st public.stations%ROWTYPE;
 previous_st public.stations%ROWTYPE;
 charge_st public.stations%ROWTYPE;
 pr public.station_progress%ROWTYPE;
 charged boolean;
BEGIN
 SELECT * INTO ses
 FROM public.game_sessions
 WHERE session_token=p_session_token AND NOT is_finished
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

 SELECT * INTO nav_st
 FROM public.stations
 WHERE id=p_navigation_station_id AND game_id=ses.game_id;
 IF NOT FOUND OR nullif(btrim(nav_st.navigation_target),'') IS NULL THEN
  RAISE EXCEPTION 'NO_NAVIGATION_TARGET';
 END IF;

 SELECT s.* INTO next_st
 FROM public.stations s
 WHERE s.game_id=ses.game_id
 AND NOT EXISTS (
  SELECT 1 FROM public.station_progress p
  WHERE p.session_id=ses.id AND p.station_id=s.id AND p.answer_verified
 )
 AND (s.game_id<>1 OR s.station_order<>4)
 ORDER BY s.station_order,s.id
 LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'GAME_ALREADY_COMPLETED'; END IF;

 IF ses.game_id=1 AND nav_st.station_order=4 THEN
  IF next_st.station_order<>5 THEN RAISE EXCEPTION 'WRONG_STATION_ORDER'; END IF;
  SELECT s.* INTO previous_st
  FROM public.stations s
  JOIN public.station_progress p ON p.station_id=s.id
  WHERE p.session_id=ses.id AND p.answer_verified AND s.game_id=ses.game_id
  AND s.station_order<>4
  ORDER BY s.station_order DESC,s.id DESC
  LIMIT 1;
  IF NOT FOUND OR previous_st.station_order<>3 THEN
   RAISE EXCEPTION 'WRONG_STATION_ORDER';
  END IF;
  charge_st:=previous_st;
 ELSIF nav_st.id=next_st.id THEN
  charge_st:=next_st;
 ELSE
  SELECT s.* INTO previous_st
  FROM public.stations s
  JOIN public.station_progress p ON p.station_id=s.id
  WHERE p.session_id=ses.id AND p.answer_verified AND s.game_id=ses.game_id
  AND (s.game_id<>1 OR s.station_order<>4)
  ORDER BY s.station_order DESC,s.id DESC
  LIMIT 1;
  IF NOT FOUND OR previous_st.id<>nav_st.id THEN
   RAISE EXCEPTION 'WRONG_STATION_ORDER';
  END IF;
  charge_st:=previous_st;
 END IF;

 SELECT * INTO pr
 FROM public.station_progress
 WHERE session_id=ses.id AND station_id=charge_st.id
 FOR UPDATE;
  IF NOT FOUND THEN
   IF charge_st.id<>next_st.id THEN RAISE EXCEPTION 'INVALID_STATION_PROGRESS'; END IF;
   IF NOT coalesce(p_confirm,false) THEN
    RETURN jsonb_build_object(
     'navigationTarget',nav_st.navigation_target,
     'navigationUsed',false,
     'requiresConfirmation',true,
     'charged',false
    );
   END IF;
   INSERT INTO public.station_progress(
    session_id,station_id,hints_used,wrong_attempts,answer_history,hints_history,started_at
   ) VALUES(ses.id,charge_st.id,0,0,'[]'::jsonb,'[]'::jsonb,now())
   ON CONFLICT(session_id,station_id) DO NOTHING;
   SELECT * INTO pr
   FROM public.station_progress
   WHERE session_id=ses.id AND station_id=charge_st.id
   FOR UPDATE;
   IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_STATION_PROGRESS'; END IF;
  END IF;

 charged:=NOT coalesce(pr.navigation_used,false);
 IF charged AND NOT coalesce(p_confirm,false) THEN
  RETURN jsonb_build_object(
   'navigationTarget',nav_st.navigation_target,
   'navigationUsed',false,
   'requiresConfirmation',true,
   'charged',false
  );
 END IF;
 IF charged THEN
  UPDATE public.station_progress SET navigation_used=true WHERE id=pr.id;
 END IF;
 RETURN jsonb_build_object(
  'navigationTarget',nav_st.navigation_target,
  'navigationUsed',true,
  'requiresConfirmation',false,
  'charged',charged
 );
END;
$$;

REVOKE ALL ON FUNCTION public.record_navigation_use_v1(uuid,bigint,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_navigation_use_v1(uuid,bigint,boolean) TO anon,authenticated;

COMMIT;
