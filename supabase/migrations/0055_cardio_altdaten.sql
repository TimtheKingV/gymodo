-- Testnotiz 14.10., 18:45 #7, Auslieferungsschritt 4 (Spec 8): alte
-- Cardio-Saetze tragen load/volume. Erst NACH der App mit Cardio-Werten
-- einspielen -- eine aeltere App liest load/volume als Pflichtfelder.
--
-- Seit Final-Review A speichert der Server Saetze einer alten App an einem
-- Cardio-Geraet weiter wie vor E2 (load/volume), und die Lesewege leiten
-- die Cardio-Werte daraus ab (cardioDesSatzes). Diese Funktion schreibt
-- genau diese Saetze um: Zeilen mit load an einem Geraet mit nicht-leerer,
-- vom Typ geerbter Liste. Sie ist wiederholbar und laesst sich nach dem
-- Auslaufen der alten App erneut aufrufen.
--
-- Regel wie altEingabeUmwandeln (cardio.ts): Sekunden -> dauer_s, Meter ->
-- strecke_m, die Belastung je Einheit in ihre Spalte, die Nebenbelastung
-- nur, wenn die Belastung die Spalte nicht schon belegt. Werte ausserhalb
-- der vererbten Liste des Geraets fallen weg. Jeder Wert wird gerundet und
-- in den Bereich seiner Spalte gekappt, damit krumme Altdaten keinen CHECK
-- reissen -- die Kappung steht IN jedem Zweig: GREATEST/LEAST ueberspringen
-- NULL und machten sonst aus "kein Wert" -10 % bzw. 0 /min. Bleibt nichts,
-- bleibt der Satz unveraendert (er verletzte sonst workout_sets_art).

create or replace function public.cardio_altdaten_umschreiben() returns void
  language sql
  set search_path = ''
  as $$
  with liste as (
    select m.id,
           m.load_unit,
           m.secondary_unit,
           case when cardinality(m.cardio_werte) > 0 then m.cardio_werte else coalesce(k.cardio_werte, '{}') end as werte
    from public.equipment_models m
    left join public.equipment_models k on k.id = m.catalog_model_id
  ),
  neu as (
    select s.id,
      case when e.volume_kind = 'seconds' and 'zeit' = any(l.werte)
        then least(greatest(round(s.volume)::int, 1), 86400) end as dauer_s,
      case when e.volume_kind = 'meters' and 'strecke' = any(l.werte)
        then least(greatest(round(s.volume)::int, 1), 200000) end as strecke_m,
      case when 'stufe' = any(l.werte) and l.load_unit = 'level'
             then least(greatest(round(s.load)::int, 0), 100)
           when 'stufe' = any(l.werte) and l.secondary_unit = 'level' and s.secondary_load is not null
             then least(greatest(round(s.secondary_load)::int, 0), 100) end as stufe,
      case when 'kmh' = any(l.werte) and l.load_unit = 'kmh'
             then least(greatest(round(s.load, 1), 0), 50)
           when 'kmh' = any(l.werte) and l.secondary_unit = 'kmh' and s.secondary_load is not null
             then least(greatest(round(s.secondary_load, 1), 0), 50) end as kmh,
      case when 'steigung' = any(l.werte) and l.load_unit = 'pct'
             then least(greatest(round(s.load, 1), -10), 40)
           when 'steigung' = any(l.werte) and l.secondary_unit = 'pct' and s.secondary_load is not null
             then least(greatest(round(s.secondary_load, 1), -10), 40) end as steigung_pct,
      case when 'watt' = any(l.werte) and l.load_unit = 'watt'
             then least(greatest(round(s.load)::int, 0), 3000)
           when 'watt' = any(l.werte) and l.secondary_unit = 'watt' and s.secondary_load is not null
             then least(greatest(round(s.secondary_load)::int, 0), 3000) end as watt,
      case when 'frequenz' = any(l.werte) and l.load_unit = 'rpm'
             then least(greatest(round(s.load)::int, 0), 300)
           when 'frequenz' = any(l.werte) and l.secondary_unit = 'rpm' and s.secondary_load is not null
             then least(greatest(round(s.secondary_load)::int, 0), 300) end as frequenz
    from public.workout_sets s
    join liste l on l.id = s.equipment_model_id
    join public.exercises e on e.id = s.exercise_id
    where cardinality(l.werte) > 0 and s.load is not null
  )
  update public.workout_sets s
     set dauer_s = n.dauer_s, strecke_m = n.strecke_m, stufe = n.stufe, kmh = n.kmh,
         steigung_pct = n.steigung_pct, watt = n.watt, frequenz = n.frequenz,
         load = null, volume = null, secondary_load = null,
         volume_source = 'eingegeben', volume_counted = null, rep_events = null
    from neu n
   where s.id = n.id
     and num_nonnulls(n.dauer_s, n.strecke_m, n.stufe, n.kmh, n.steigung_pct, n.watt, n.frequenz) >= 1;
  $$;

revoke execute on function public.cardio_altdaten_umschreiben() from public, anon, authenticated;

select public.cardio_altdaten_umschreiben();
