-- Wochenplan ohne feste Tage (Spec 2026-11-11, Abschnitt 6): das Mitglied legt
-- fest, wie oft pro Woche, nicht an welchem Tag.
--
-- training_profiles bekommt drei Zaehler: Krafttrainings je Woche (null =
-- noch keine Angabe, der Server leitet das Wochenziel dann ab), Cardio-
-- Einheiten je Woche und die Minuten, die eine Cardio-Einheit zaehlen soll.
-- Die Tagesspalten (kurs_tage, cardio_tage, kraft_tage) und wochenraster
-- bleiben unveraendert, die alte App auf Prod schreibt sie weiter.
--
-- cardio_checks bekommt eine id, damit ein Tag mehrere Haken haben kann, und
-- optional die Minuten des Hakens. Der Primaerschluessel (user_id, day) faellt
-- weg; ein Index auf (user_id, day) haelt die Wochenabfrage schnell.

alter table public.training_profiles
  add column kraft_pro_woche  smallint,
  add column cardio_pro_woche smallint not null default 0,
  add column cardio_minuten   smallint not null default 30,
  add constraint training_profiles_kraft_pro_woche_bereich  check (kraft_pro_woche  between 1 and 7),
  add constraint training_profiles_cardio_pro_woche_bereich check (cardio_pro_woche between 0 and 7),
  add constraint training_profiles_cardio_minuten_bereich   check (cardio_minuten   between 10 and 180);

-- Bestehende Profile uebernehmen ihre bisherigen Tage als Zaehler. Die Anweisungen
-- zwischen den Markern liest der Integrationstest und fuehrt sie erneut aus; sie
-- fassen nur Zeilen an, die noch keinen Wert haben.
-- befuellen:start
-- Kraft: Anzahl der Wunsch-Krafttage, sonst die Kraft-Eintraege im Wochenraster
-- des aktiven Plans (bei mehreren Studios der groesste Wert), sonst null.
update public.training_profiles p
set kraft_pro_woche = nullif(
  least(
    7,
    coalesce(
      nullif(cardinality(p.kraft_tage), 0),
      (select max(k.n)
         from (select (select count(*)
                         from jsonb_array_elements(tp.wochenraster) e
                        where e ->> 'art' = 'kraft') as n
                 from public.training_plans tp
                where tp.user_id = p.user_id
                  and tp.status = 'aktiv') k),
      0)),
  0)
where p.kraft_pro_woche is null;

-- Cardio: Anzahl der festen Cardio-Tage; cardio_minuten bleibt beim Default 30.
update public.training_profiles p
set cardio_pro_woche = cardinality(p.cardio_tage)
where p.cardio_pro_woche = 0
  and cardinality(p.cardio_tage) > 0;
-- befuellen:end

alter table public.cardio_checks
  add column id uuid not null default gen_random_uuid(),
  drop constraint cardio_checks_pkey,
  add primary key (id),
  add column minuten smallint check (minuten between 1 and 600);

create index cardio_checks_user_day_idx on public.cardio_checks (user_id, day);

comment on column public.cardio_checks.minuten is
  'Dauer des Cardio-Hakens in Minuten; null = ohne Angabe (alter Haken pro Tag).';

-- Rechte wie in 0071: das Mitglied liest, setzt und nimmt zurueck, kein Update.
-- Neue Spalten erben die Tabellenrechte, daran aendert sich nichts.
