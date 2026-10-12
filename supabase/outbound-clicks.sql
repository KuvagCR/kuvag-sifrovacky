-- Spusťte jednorázově v Supabase SQL Editoru (projekt hry).
-- Eviduje skutečné kliknutí na odkazy; pouze veřejná část hry volá RPC.
create table if not exists public.game_outbound_clicks (
  id bigint generated always as identity primary key,
  game_id integer not null,
  session_token text not null,
  destination text not null check (destination in ('novykuvag','kuvag','facebook','instagram')),
  clicked_at timestamptz not null default now()
);
create index if not exists game_outbound_clicks_game_destination_idx on public.game_outbound_clicks(game_id,destination,clicked_at);
alter table public.game_outbound_clicks enable row level security;
revoke all on public.game_outbound_clicks from anon, authenticated;
-- Veřejný klient nemůže číst ani přímo zapisovat statistiky.
create or replace function public.track_game_outbound_click(p_session_token text,p_destination text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_session_token is null or length(p_session_token)<16
     or p_destination not in ('novykuvag','kuvag','facebook','instagram') then
    return;
  end if;
  -- Identita a typ hráče se ověřují podle serverové relace.
  -- Pokud tabulka relací používá jiný název/sloupce, upravte následující SELECT.
  insert into public.game_outbound_clicks(game_id,session_token,destination)
  select s.game_id,p_session_token,p_destination
  from public.game_sessions s
  where s.session_token=p_session_token and s.player_type='public'
  limit 1;
end;
$$;
revoke all on function public.track_game_outbound_click(text,text) from public;
grant execute on function public.track_game_outbound_click(text,text) to anon, authenticated;
-- Přehled pro organizátora v SQL Editoru:
-- select game_id,destination,count(*) as kliknuti,
--        count(distinct session_token) as unikatni_hraci
-- from public.game_outbound_clicks
-- group by game_id,destination order by game_id,destination;
