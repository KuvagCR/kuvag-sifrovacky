-- Hodnocení dokončené hry. Zaměstnanci KUVAG mají jednu doplňující otázku.
CREATE TABLE IF NOT EXISTS public.game_feedback (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 session_id bigint NOT NULL UNIQUE REFERENCES public.game_sessions(id) ON DELETE CASCADE,
 game_id bigint NOT NULL,
 player_type text NOT NULL,
 rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
 comment text,
 employee_answer text,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT feedback_comment_length CHECK (char_length(coalesce(comment,''))<=1000),
 CONSTRAINT feedback_employee_length CHECK (char_length(coalesce(employee_answer,''))<=1000)
);
ALTER TABLE public.game_feedback ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.game_feedback FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.submit_game_feedback(p_session_token uuid,p_rating integer,p_comment text DEFAULT NULL,p_employee_answer text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE ses public.game_sessions%ROWTYPE;
BEGIN
 SELECT * INTO ses FROM public.game_sessions
 WHERE session_token=p_session_token AND is_finished=true AND finished_at > now()-interval '7 days';
 IF NOT FOUND THEN RETURN false; END IF;
 IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 OR char_length(coalesce(p_comment,''))>1000 OR char_length(coalesce(p_employee_answer,''))>1000 THEN RETURN false; END IF;
 INSERT INTO public.game_feedback(session_id,game_id,player_type,rating,comment,employee_answer)
 VALUES(ses.id,ses.game_id,ses.player_type,p_rating,nullif(trim(p_comment),''),CASE WHEN ses.player_type='kuvag' THEN nullif(trim(p_employee_answer),'') ELSE NULL END)
 ON CONFLICT(session_id) DO UPDATE SET rating=excluded.rating,comment=excluded.comment,employee_answer=excluded.employee_answer,updated_at=now();
 RETURN true;
END;$$;
REVOKE ALL ON FUNCTION public.submit_game_feedback(uuid,integer,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_game_feedback(uuid,integer,text,text) TO anon,authenticated;
