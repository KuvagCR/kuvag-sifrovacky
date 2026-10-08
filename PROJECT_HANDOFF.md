# KUVAG Šifrovačky — předání projektu
Aktualizováno: 8. 10. 2026. Interní pracovní dokument. Stav funkčnosti ověřit v aktuálním kódu a databázi; body označené jako hotové vycházejí z dosavadního testování uživatelkou.

## 1. Účel a priority
Vlastní mobilní webová platforma KUVAG CR pro venkovní šifrovací hry v Nepomuku a okolí. První ostrá hra je **primárně pro zaměstnance KUVAGu**, cílové spuštění **do konce října 2026**, bez uspěchání kvality. Po úspěchu lze nabídnout hru veřejnosti / městu Nepomuk, ovšem bez předběžného slibu bezplatné licence či převodu platformy. Potenciál 1–2 dalších her ročně (jaro/podzim). Provoz a doplňky mají být pokud možno **bezplatné**. Žádné placené API či nástroj bez výslovného souhlasu.

**Aktuální hlavní priorita:** dokončit stabilní první hru, ověřit historické podklady a otestovat trasu. Nové marketingové či administrativní funkce nesmějí ohrozit říjnový termín.

## 2. Odkazy a infrastruktura
- Soukromý GitHub: https://github.com/KuvagCR/kuvag-sifrovacky (větev main).
- Aplikace: https://kuvag-sifrovacky.kuvag-cr.workers.dev
- Demo: https://kuvag-sifrovacky.kuvag-cr.workers.dev/?game=1
- Administrace: https://kuvag-sifrovacky.kuvag-cr.workers.dev/admin.html
- Hosting: Cloudflare, automatické nasazení z GitHubu.
- Backend: Supabase, projekt `kuvag-sifrovacky`, oblast EU (Irsko).
- Frontend: statický HTML/CSS/JavaScript; hlavní soubory `index.html`, `style.css`, `app.js`, `admin.html`, `admin.css`, `admin.js`. Logo `logo bez pozadí.png` je schválené a neměnit za generované.
- Přístupové údaje, hesla, servisní klíče a soukromé tokeny **nikdy nevkládat do dokumentace ani commitu**. Při předání firemnímu účtu zvlášť ověřit správu vlastnictví a přístupů.

## 3. Datový model — ověřit vůči aktuálnímu schématu
- `games`: id, title, description, intro_text, finish_text, visibility, status, estimated_minutes, is_active, publish_at, created_at.
- `stations`: id, game_id, station_order, title, task_text, correct_answer, accepted_answers, hint_1, hint_2, story_text, success_text, image_url.
- `game_sessions`: id, game_id, player_name, player_type, is_test_run, started_at, finished_at, hints_used, wrong_attempts, total_points, is_finished, session_token.
- `station_progress`: session_id, station_id, completed_at, hints_used, wrong_attempts; unikátní dvojice session_id/station_id. **Pozdější změny mohou obsahovat časy začátku, záznamy pokusů a navigace; ověřit aktuální schéma.**
- `admin_users`: přístup administrátorů.
- Supabase Storage: `station-images` pro obrázky stanovišť.
- RLS a security-definer RPC: zejména `get_game_info`, `get_game_stations`, `normalize_game_answer`, `check_station_answer`, `save_station_progress`, `finish_game_session`, `get_player_ranking`, `verify_employee_code`. Před úpravou vždy načíst aktuální SQL definice a oprávnění.

## 4. Herní pravidla a funkce
- Mobilní web, bez instalace. Více her a publika: test / KUVAG / veřejnost.
- Testovací režim se nesmí započítávat do ostrého žebříčku a statistik.
- Stanoviště v pořadí; zadání, příběh, odpovědi, dvě nápovědy, vyhodnocení, postup.
- Bodování: výchozí **100 bodů na stanoviště**, chybná odpověď **−5**. Původní nápovědy v kódu mohly mít **−10 / −20**; v novější debatě padlo **−5 / −10**. **Neberte diskutované hodnoty jako potvrzenou implementaci — ověřte aktuální kód a sjednoťte nastavení před ostrým spuštěním.**
- Orientační mapa města **bez stanovišť a bez vyznačené trasy**, zdarma — uživatelka potvrdila jako hotové.
- Tlačítko navigace za **−30 bodů**, předem potvrdit, odečíst maximálně jednou na stanoviště — uživatelka potvrdila jako hotové. **Zbývá napojení konkrétních cílů/souřadnic dalších stanovišť přes administraci**.
- Detail hráče a měření času jednotlivých stanovišť uživatelka potvrdila jako hotové; při převzetí ověřit, že logování funguje i pro chyby, nápovědy a obnovení.
- Výsledky, souhrny, statistiky stanovišť, CSV export, žebříček KUVAG/veřejnost a administrace her/stanovišť existují; finální regresní test stále potřeba.
- Odpovědi normalizovat (mezery, velikost písmen, diakritika); alternativy oddělené středníkem.
- Demo: 1) Ztracené jméno → POMUK, 2) Založení kláštera → 1144 (uživatelka ověřila na fyzické tabuli; bez jejího souhlasu neměnit), 3) Nejstarší svědek / Dům U Lípy → U LÍPY.

## 5. Backlog (nepočítá se vkládání historických textů, odpovědí, šifer a nápověd)
### P0 — před spuštěním zaměstnanecké hry
- [ ] Spolehlivě obnovit rozehranou hru po zavření/obnovení stránky, včetně bodů a penalizací.
- [ ] Napojit navigaci na **konkrétní cíle dalších stanovišť** (souřadnice spravovatelné v administraci, bez placeného navigačního API).
- [ ] Ověřit zabezpečení startu, postupu, bodů, odpovědí, nápověd a navigačních penalizací; klient nesmí určovat důvěryhodné výsledné skóre.
- [ ] Oddělit testovací průchody a žebříček, vyčistit testovací výsledky bez ztráty potřebných dat.
- [ ] Kompletní mobilní/terénní test, včetně slabého signálu, přerušení, restartu a správné navigace.
- [ ] Historická kontrola, stabilní fyzické indicie na místech, práva k použitým fotkám; nahradit cizí hotlinkovaný úvodní obrázek.
- [ ] Pilot s lidmi, kteří neznají řešení; opravit zjištěné nedostatky.

### P1 — ideálně při prvním spuštění, podle času
- [ ] Závěrečné dobrovolné hodnocení: 1–5 hvězd; doporučení 0–10; účast v další hře ano/ne; co bavilo; co změnit; odkud se o hře dozvěděli.
- [ ] Ukládání hodnocení a dashboard v administraci (průměr, NPS, zájem, kanály, komentáře).
- [ ] Dobrovolné nahrání **fotografií** ze hry po dokončení (bez videa), správa v administraci, přiměřené limity souborů, souhlas s konkrétním zveřejněním; pozor i na práva osob vyobrazených na fotkách.
- [ ] Navigace v detailu hráče a statistikách (použití, podíl hráčů).
- [ ] Rozšířit export o detailní průchod, časy a navigaci.

### P2 — veřejná verze / další rozvoj
- [ ] Veřejné zakončení „Děkujeme, že jste hráli s KUVAGem“ a dobrovolný odkaz „Poznej KUVAG“.
- [ ] Samostatná landing page „Poznej KUVAG“: co vyrábíme → lidé → prostředí → benefity → kariéra → možnost kontaktu.
- [ ] Bezplatné, transparentní měření cesty hra → landing page → kariéra → zájem o práci; skutečné nástupy spojovat jen zákonným, interně odsouhlaseným postupem. GDPR/informační povinnosti a souhlasy řešit před sběrem osobních údajů.
- [ ] Duplikování her v administraci.
- [ ] Průběžná dokumentace projektu pro případnou HR soutěž: skutečné metriky, fotky se souhlasy, zpětná vazba, publicita, náborový dopad.
- [ ] Písemně domluvit případnou spolupráci s městem, použití městských fotek a zdrojů, odborný kredit historikovi a zachování dobrovolného odkazu na KUVAG.
- [ ] Případně role dalších administrátorů / městského partnera jen pro statistiky; zálohy a předání firemních účtů.

## 6. Historie a scénář
První hra: Nepomuk, kompaktní pěší trasa, přibližně 12–15 stanovišť / cca 90–120 min (upřesnit terénním testem). Základní místa: náměstí/kašna, spořitelna a zajímavé domy, kostel sv. Jana Nepomuckého, sv. Jakuba, fara/arciděkanství, Svatojánské muzeum, Dům U Růže, Zelený důl, kaplička/Šlépěje sv. Vojtěcha, Vyskočilka, Zelenohorská pošta, návrat na náměstí. Více úkolů může být na jednom místě. **Žádné QR štítky či nové značky na historických objektech**. Hráči dostanou obyčejnou mapu, ale ne seznam označených bodů. Historii odlišovat od pověstí. Neodhadovat fyzické detaily bez fotografií nebo ověření na místě.

Pracovní rámec „Po stopách ztraceného Nepomuku“: současné město → starý Pomuk → Jan Nepomucký → Vojtěchovy pověsti → historické cesty → finální šifra. Název není definitivní.

Historik: schůzka v pátek 9. 10. 2026. Očekává se odborná konzultace a podklady v následujících dnech, nikoli hotový scénář na schůzce. Historik může pomoci s fakty, trasou, prameny, mapami/fotkami, pověstmi a pozdější kontrolou. Všechny materiály používat jen s příslušným oprávněním. Případné město/Mikroregion je až druhá fáze, po dohodě s vedením KUVAGu.

Další náměty: popraviště/kat („Poslední rozsudek“), zaniklý klášter („Ztracené opatství“), Klášter–Červený most–Helenka, Šternberský dvůr / knížecí cesta, B-24 za 2. světové války, poustevna Na Skalici, železnice a Dvorec, rodinná přírodní hra. Nepoužité detaily první trasy uchovat pro budoucí hry.

## 7. Odborné a právní hranice
- Vlastnictví a oprávnění k platformě řešit firemně. Projekt vznikal v pracovní době pro KUVAG.
- Formulace „ve spolupráci s městem“ sama **není licencí** k fotografiím. Ověřit, zda město může udělit oprávnění pro webovou aplikaci, úpravy a prezentaci; doložit písemně a uvést autora podle podmínek.
- Dobrovolné odkazy na firmu v případné městské hře předem transparentně odsouhlasit; nepodmiňovat hraní návštěvou kariérního webu.
- U hráčských fotografií řešit licenci, dobrovolnost, konkrétní účely použití, soukromí vyobrazených osob a mazání.
- Firemní/neziskové předplatné AI nepovažovat za zaměnitelné; neukládat firemní data do neautorizovaného účtu bez schválení.

## 8. Jak s uživatelkou spolupracovat
Komunikovat **česky**, jednoduše, přátelsky, věcně. Uživatelka je HR, nikoli programátorka. Dává přednost tomu, aby asistent **přímo upravoval GitHub**, pokud má příslušný přístup, místo posílání dlouhého kódu k ručnímu vkládání. Při zásazích do Supabase dávat jeden jasný krok, vyčkat „mám“ a pokračovat. Nevydávat hypotézy za ověřený stav. Před úpravami načíst aktuální soubory a schéma; po změně otestovat. Neměnit schválené logo, vzhled ani již ověřený obsah bez domluvy. Bezplacený provoz je zásadní. Nenechat nové nápady ohrozit říjnové spuštění.

## 9. První kroky nového asistenta
1. Získat schválený přístup k repozitáři, načíst aktuální `app.js`, `admin.js`, HTML/CSS a případné SQL migrace.
2. Ověřit aktuální databázové schéma/RLS/RPC proti výše uvedenému popisu. Nepředpokládat, že starší SQL je aktuální.
3. S uživatelkou potvrdit prioritu P0 a plán na říjen; nepřepisovat hotovou mapu/navigaci/detail hráče.
4. Zabezpečit zálohu kódu a DB schématu bez tajných údajů.
5. Postupovat v malých testovatelných změnách, vysvětlit konkrétní výsledek každého kroku.
