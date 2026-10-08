# Serverové zabezpečení hry — kontrola 2026-10-08

## Zálohy
- GitHub: `backup-before-server-security-20261008` (kopie kódu před úpravami).
- Supabase: `game_backup.functions_20261008` (7 definic funkcí; potvrzeno výpisem uživatele).
- Pozor: záloha SQL definic **není** záloha tabulek ani jejich dat.

## Ověřené problémy
1. `check_station_answer(uuid,bigint,text)` pouze vrací boolean. Správnou odpověď **neukládá**.
2. `save_station_progress(uuid,bigint,int,int)` vloží dokončení bez důkazu správné odpovědi; bere nápovědy/chyby od klienta.
3. `save_station_detail` přepisuje historii a počty z klienta.
4. `finish_game_session` přepočítává body z `station_progress`, ale ignoruje navigaci.
5. `get_game_stations` vrací `navigation_target` všem klientům včetně neodemčených stanovišť.
6. Obnovení hry přes localStorage je pouze klientské, nikoli autoritativní.
7. Existuje i starší přetížení `check_station_answer(bigint,text)`; je třeba prověřit EXECUTE oprávnění.

## Bezpečný plán změny
- Migraci provést transakčně, bez DROP TABLE/CASCADE a bez mazání herních dat.
- Vytvořit serverový protokol akcí pro chybnou odpověď, nápovědu a navigaci (pouze jednou za stanoviště).
- Ověření správné odpovědi a záznam dokončení musí být jedna atomická operace; nevěřit `save_station_progress`.
- Před přepnutím frontend kódu ověřit RPC a jejich oprávnění.
- Změnit frontend tak, aby vyžadoval potvrzení zápisu na server a načítal autoritativní skóre.
- Po dokončení ověřit: špatná odpověď, dvě nápovědy, navigace -30, obnovení po refreshi, dokončení a žebříček.
- Staré záznamy ponechat beze změny; nelze zaručit jejich zpětnou validaci.

## Rollback
- Kód: vrátit GitHub branch/commit.
- SQL: obnovit konkrétní funkce z `game_backup.functions_20261008` až po kontrole závislostí a oprávnění.
- Rollback funkcí **nevrací** změny dat vzniklé během testů.
