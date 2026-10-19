-- Testnotiz 18.10., #5: Anzahl Stufen am Treppensteiger.
--
-- Neuer Cardio-Wert "stufenanzahl" (Spalte gleichen Namens): wie viele
-- Treppenstufen der Satz gestiegen ist. Getrennt von "stufe", dem
-- Widerstandslevel des Geraets. Nur der Katalog-Typ stair_climber bietet ihn
-- an; eigene Modelle behalten ihre Liste.

alter table public.equipment_models
  drop constraint equipment_models_cardio_werte_bekannt,
  add constraint equipment_models_cardio_werte_bekannt
    check (cardio_werte <@ array['zeit','strecke','stufe','stufenanzahl','kmh','steigung','watt','frequenz','kcal']::text[]);

alter table public.workout_sets
  add column stufenanzahl int constraint workout_sets_stufenanzahl_check check (stufenanzahl between 1 and 10000);

-- Kraft ODER Cardio, nie gemischt, nie leer -- wie 0054, mit der neuen Spalte.
alter table public.workout_sets drop constraint workout_sets_art;
alter table public.workout_sets add constraint workout_sets_art check (
  (load is not null and volume is not null
    and dauer_s is null and strecke_m is null and stufe is null and stufenanzahl is null and kmh is null
    and steigung_pct is null and watt is null and kcal is null and frequenz is null)
  or (load is null and volume is null and secondary_load is null
    and num_nonnulls(dauer_s, strecke_m, stufe, stufenanzahl, kmh, steigung_pct, watt, kcal, frequenz) >= 1));

-- Das Modell erbt die Liste vom Katalog-Typ (catalog:import haelt die Datei danach gleich).
update public.equipment_models
  set cardio_werte = array['zeit','stufe','stufenanzahl','kcal']
  where catalog_key = 'stair_climber';
