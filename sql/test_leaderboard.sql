-- Samostatný testovací žebříček; ostré výsledky zůstávají oddělené.
CREATE OR REPLACE FUNCTION public.get_test_game_leaderboard(p_game_id bigint,p_player_type text DEFAULT 'test')
RETURNS TABLE(player_rank bigint,player_name text,total_points integer,duration_seconds integer)
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
 SELECT row_number() OVER (ORDER BY gs.total_points DESC, EXTRACT(EPOCH FROM (gs.finished_at-gs.started_at)) ASC,gs.id ASC)::bigint,
 gs.player_name::text,gs.total_points::integer,
 greatest(0,EXTRACT(EPOCH FROM (gs.finished_at-gs.started_at))::integer)
 FROM public.game_sessions gs
 WHERE gs.game_id=p_game_id AND gs.player_type='test' AND gs.is_finished=true
 AND gs.show_in_leaderboard=true
 ORDER BY gs.total_points DESC,EXTRACT(EPOCH FROM (gs.finished_at-gs.started_at)) ASC,gs.id ASC LIMIT 15;
$$;
CREATE OR REPLACE FUNCTION public.get_test_player_ranking(p_session_token uuid)
RETURNS TABLE(player_rank bigint,total_players bigint)
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
 WITH target AS (SELECT game_id FROM public.game_sessions WHERE session_token=p_session_token AND player_type='test' AND is_finished=true),
 ranked AS (SELECT gs.session_token,row_number() OVER (ORDER BY gs.total_points DESC,EXTRACT(EPOCH FROM (gs.finished_at-gs.started_at)) ASC,gs.id ASC)::bigint AS pos
 FROM public.game_sessions gs JOIN target t ON t.game_id=gs.game_id
 WHERE gs.player_type='test' AND gs.is_finished=true AND gs.show_in_leaderboard=true)
 SELECT pos,(SELECT count(*) FROM ranked)::bigint FROM ranked WHERE session_token=p_session_token;
$$;
REVOKE ALL ON FUNCTION public.get_test_game_leaderboard(bigint,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_test_player_ranking(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_test_game_leaderboard(bigint,text) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_test_player_ranking(uuid) TO anon,authenticated;
