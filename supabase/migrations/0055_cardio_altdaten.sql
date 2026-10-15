-- Testnotiz 14.10., 18:45 #7, Auslieferungsschritt 4 (Spec 8): alte
-- Cardio-Saetze tragen load/volume. Erst NACH der App mit Cardio-Werten
-- einspielen -- eine aeltere App liest load/volume als Pflichtfelder.
--
-- Regel wie altEingabeUmwandeln (cardio.ts): Sekunden -> dauer_s, Meter ->
-- strecke_m, die Belastung je Einheit in ihre Spalte. Werte ausserhalb der
-- vererbten Liste des Geraets fallen weg. Jeder Wert wird in den Bereich
-- seiner Spalte gekappt, damit krumme Altdaten keinen CHECK reissen. Bleibt
-- nichts, bleibt der Satz unveraendert (er verletzte sonst workout_sets_art).

create function public.cardio_altdaten_umschreiben() returns void
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
      case when l.load_unit = 'level' and 'stufe' = any(l.werte)
        then least(greatest(round(s.load)::int, 0), 100) end as stufe,
      case when l.load_unit = 'kmh' and 'kmh' = any(l.werte)
        then least(greatest(round(s.load, 1), 0), 50) end as kmh,
      least(greatest(coalesce(
        case when l.load_unit = 'pct' and 'steigung' = any(l.werte) then round(s.load, 1) end,
        case when l.secondary_unit = 'pct' and 'steigung' = any(l.werte) then round(s.secondary_load, 1) end), -10), 40) as steigung_pct,
      case when l.load_unit = 'watt' and 'watt' = any(l.werte)
        then least(greatest(round(s.load)::int, 0), 3000) end as watt,
      least(greatest(coalesce(
        case when l.load_unit = 'rpm' and 'frequenz' = any(l.werte) then round(s.load)::int end,
        case when l.secondary_unit = 'rpm' and 'frequenz' = any(l.werte) then round(s.secondary_load)::int end), 0), 300) as frequenz
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
