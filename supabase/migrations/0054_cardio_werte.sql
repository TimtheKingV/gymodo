-- Testnotiz 14.10., 18:45 #7: Cardio-Werte (Spec 2026-10-15-cardio-werte-design).
--
-- Ein Cardio-Satz traegt bis zu acht beobachtete Werte statt Belastung und
-- Umfang. Welche, sagt das Geraet (cardio_werte, vom Katalog-Typ geerbt);
-- eine nicht-leere Liste macht ein Geraet zum Cardio-Geraet. Altdaten
-- bleiben hier unberuehrt -- 0055 schreibt sie um, erst nach der App.

create function public.ohne_dubletten(liste text[]) returns boolean
  language sql immutable
  as $$ select cardinality(liste) = (select count(distinct x) from unnest(liste) as x) $$;

alter table public.equipment_models
  add column cardio_werte text[] not null default '{}'
    constraint equipment_models_cardio_werte_bekannt
    check (cardio_werte <@ array['zeit','strecke','stufe','kmh','steigung','watt','frequenz','kcal']::text[])
    constraint equipment_models_cardio_werte_einmalig
    check (public.ohne_dubletten(cardio_werte));

alter table public.workout_sets
  alter column load drop not null,
  alter column volume drop not null,
  add column dauer_s int constraint workout_sets_dauer_s_check check (dauer_s between 1 and 86400),
  add column strecke_m int constraint workout_sets_strecke_m_check check (strecke_m between 1 and 200000),
  add column stufe int constraint workout_sets_stufe_check check (stufe between 0 and 100),
  add column kmh numeric(4, 1) constraint workout_sets_kmh_check check (kmh between 0 and 50),
  add column steigung_pct numeric(4, 1) constraint workout_sets_steigung_pct_check check (steigung_pct between -10 and 40),
  add column watt int constraint workout_sets_watt_check check (watt between 0 and 3000),
  add column kcal int constraint workout_sets_kcal_check check (kcal between 0 and 10000),
  add column frequenz int constraint workout_sets_frequenz_check check (frequenz between 0 and 300),
  -- Kraft ODER Cardio, nie gemischt, nie leer.
  add constraint workout_sets_art check (
    (load is not null and volume is not null
      and dauer_s is null and strecke_m is null and stufe is null and kmh is null
      and steigung_pct is null and watt is null and kcal is null and frequenz is null)
    or (load is null and volume is null and secondary_load is null
      and num_nonnulls(dauer_s, strecke_m, stufe, kmh, steigung_pct, watt, kcal, frequenz) >= 1));

-- 0049 verglich volume_counted mit volume; ein leeres volume machte den
-- Vergleich NULL, und ein CHECK laesst NULL durch.
alter table public.workout_sets drop constraint workout_sets_herkunft_consistent;
alter table public.workout_sets add constraint workout_sets_herkunft_consistent check (
  (volume_source = 'eingegeben' and volume_counted is null and rep_events is null)
  or (volume_source = 'gemessen' and volume is not null and volume_counted is not null
      and volume_counted = volume and rep_events is not null)
  or (volume_source = 'korrigiert' and volume is not null and volume_counted is not null
      and volume_counted <> volume and rep_events is not null));

-- Die Katalog-Typen (Spec 6). catalog:import haelt die Datei danach gleich.
update public.equipment_models set cardio_werte = array['zeit','strecke','kmh','steigung','kcal'] where catalog_key = 'treadmill';
update public.equipment_models set cardio_werte = array['zeit','strecke','stufe','watt','frequenz','kcal']
  where catalog_key in ('upright_bike', 'recumbent_bike', 'indoor_bike');
update public.equipment_models set cardio_werte = array['zeit','strecke','watt','kcal'] where catalog_key in ('airbike', 'ski_ergometer');
update public.equipment_models set cardio_werte = array['zeit','strecke','stufe','frequenz','kcal'] where catalog_key = 'elliptical';
update public.equipment_models set cardio_werte = array['zeit','strecke','watt','frequenz','kcal'] where catalog_key = 'rowing_ergometer';
update public.equipment_models set cardio_werte = array['zeit','stufe','kcal'] where catalog_key = 'stair_climber';

-- Eigene Cardio-Modelle ohne Typ (Spec 9): Zeit plus der Wert ihrer Einheit.
update public.equipment_models
  set cardio_werte = array['zeit'] || case load_unit
    when 'level' then array['stufe'] when 'kmh' then array['kmh'] when 'watt' then array['watt']
    when 'pct' then array['steigung'] when 'rpm' then array['frequenz'] else array[]::text[] end
  where category = 'cardio' and catalog_model_id is null and catalog_key is null;
