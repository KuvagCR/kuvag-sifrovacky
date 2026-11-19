DO $$
BEGIN
 IF public.game_station_points_v2(2,0,ARRAY[0,0,0],0,false)<>100 THEN
  RAISE EXCEPTION 'No-hint multistage score mismatch';
 END IF;
 IF public.game_station_points_v2(2,1,ARRAY[1,0,0],0,false)<>90 THEN
  RAISE EXCEPTION 'First stage hint score mismatch';
 END IF;
 IF public.game_station_points_v2(2,6,ARRAY[2,2,2],0,false)<>10 THEN
  RAISE EXCEPTION 'Six multistage hints score mismatch';
 END IF;
 IF public.game_station_points_v2(2,3,ARRAY[1,1,1],2,true)<>30 THEN
  RAISE EXCEPTION 'Multistage hints, wrong attempts, and navigation score mismatch';
 END IF;
 IF public.game_station_points_v2(2,2,ARRAY[0,0,0],0,false)<>70 THEN
  RAISE EXCEPTION 'Legacy station hint score mismatch';
 END IF;
 IF public.game_station_points_v2(5,2,ARRAY[0,0,0],1,true)<>35 THEN
  RAISE EXCEPTION 'Ordinary station score mismatch';
 END IF;
END;
$$;
DO $$
DECLARE station_title text;
BEGIN
 SELECT title INTO station_title FROM public.stations WHERE game_id=1 AND station_order=6;
 IF station_title<>'Knárovka – Deset stop starého písaře' THEN
  RAISE EXCEPTION 'Knárovka result title mismatch';
 END IF;
 SELECT title INTO station_title FROM public.stations WHERE game_id=1 AND station_order=7;
 IF station_title<>'Zelenohorská pošta – Tři znamení' THEN
  RAISE EXCEPTION 'Zelenohorská pošta result title mismatch';
 END IF;
 SELECT title INTO station_title FROM public.stations WHERE game_id=1 AND station_order=8;
 IF station_title<>'Tajemství domovního znamení' THEN
  RAISE EXCEPTION 'Domovní znamení result title mismatch';
 END IF;
END;
$$;
