-- Belastung und Umfang statt Kilogramm und Wiederholungen.
--
-- Ein Laufband hat keinen Gewichtsstapel und ein Dauerlauf keine
-- Wiederholungen. Die Regel in progression.ts war schon einheitenfrei;
-- nur die Spaltennamen behaupteten Kilogramm. Ab hier: das Modell traegt
-- die Belastungseinheit, die Uebung die Umfangsart, der Satz zwei Zahlen
-- (Spec 2026-09-21-cardio-geraete-design, Abschnitt 4).
--
-- Alle Bestandsdaten sind Kraftdaten. Die Defaults ('kg', 'reps', 'kraft')
-- machen sie korrekt, ohne dass eine Zeile angefasst wird. Deshalb wird
-- umbenannt statt kopiert: vor dem Pilot gibt es keinen Fremdclient, der
-- die alten Namen braeuchte.
--
-- body_measurements.weight_kg bleibt: Koerpergewicht ist keine Belastung.

-- --------------------------------------------------------------------
-- Geraetemodell: was am Geraet gedreht wird, und in welcher Einheit.
-- --------------------------------------------------------------------

alter table public.equipment_models
  rename column weight_step_kg to load_step;
alter table public.equipment_models
  rename column min_weight_kg to load_min;
alter table public.equipment_models
  rename column max_weight_kg to load_max;

-- Belastung und Nebenbelastung teilen sich EINE Einheitenliste. Eine neue
-- Einheit ist ein Eintrag hier und eine Zeile im Formatierer
-- (packages/domain/src/belastung.ts), sonst nichts.
alter table public.equipment_models
  add column load_unit text not null default 'kg'
    constraint equipment_models_load_unit_check
    check (load_unit in ('kg', 'watt', 'level', 'kmh', 'pct', 'rpm'));

-- Optionale Nebenbelastung (Spec Abschnitt 3.1b): der zweite
-- Intensitaetsregler -- Neigung am Laufband, Trittfrequenz am Ergometer
-- mit Stufenanzeige. Die Regel steigert ihn nie, verlangt aber, dass er
-- gleich bleibt. Alle vier Spalten zusammen oder keine: eine Einheit ohne
-- Rastung haette kein Rad, eine Rastung ohne Einheit keinen Namen.
alter table public.equipment_models
  add column secondary_unit text
    constraint equipment_models_secondary_unit_check
    check (secondary_unit is null
           or secondary_unit in ('kg', 'watt', 'level', 'kmh', 'pct', 'rpm')),
  add column secondary_step numeric
    constraint equipment_models_secondary_step_check
    check (secondary_step is null or secondary_step > 0),
  add column secondary_min numeric
    constraint equipment_models_secondary_min_check
    check (secondary_min is null or secondary_min >= 0),
  add column secondary_max numeric,
  add constraint equipment_models_secondary_all_or_none
    check ((secondary_unit is null) = (secondary_step is null)
       and (secondary_unit is null) = (secondary_min is null)
       and (secondary_unit is null) = (secondary_max is null)),
  add constraint equipment_models_secondary_range
    check (secondary_max is null or secondary_max >= secondary_min);

-- Nur Anzeige: Gruppierung in der Geraetesuche, Filter im Portal, spaeter
-- eine Kennzahl. Keine Regel liest diese Spalte -- ein Waechter-Test in
-- packages/domain haelt sie aus progression, abschluss, workout und
-- machine-context fern (Spec Abschnitt 3.5). Nicht aus load_unit
-- abgeleitet: 'level' gibt es an hydraulischen Kraftmaschinen wie an
-- Crosstrainern, und ob ein Rudergeraet Cardio ist, weiss das Studio.
alter table public.equipment_models
  add column category text not null default 'kraft'
    constraint equipment_models_category_check
    check (category in ('kraft', 'cardio'));

-- --------------------------------------------------------------------
-- Uebung: was das Mitglied schaffen soll, und in welcher Einheit.
-- --------------------------------------------------------------------

alter table public.exercises
  rename column target_reps_min to target_min;
alter table public.exercises
  rename column target_reps_max to target_max;

-- Sekunden und Meter sind wie Wiederholungen ganze Zahlen; der Typ der
-- beiden Zielspalten bleibt integer. Die Constraints (> 0, max >= min)
-- gelten fuer alle drei Arten unveraendert.
alter table public.exercises
  add column volume_kind text not null default 'reps'
    constraint exercises_volume_kind_check
    check (volume_kind in ('reps', 'seconds', 'meters'));

-- --------------------------------------------------------------------
-- Satz: zwei Zahlen, deren Bedeutung an Modell und Uebung haengt.
-- --------------------------------------------------------------------

alter table public.workout_sets
  rename column weight_kg to load;
alter table public.workout_sets
  rename column reps to volume;

-- Die alte Grenze (1000) war eine Wiederholungsgrenze. Sekunden und Meter
-- brauchen mehr; die Grenze je Umfangsart prueft die Domain gegen die
-- Uebung (recordSet). Hier bleibt nur die Schranke gegen Unsinn.
alter table public.workout_sets
  drop constraint workout_sets_reps_check;
alter table public.workout_sets
  add constraint workout_sets_volume_check
    check (volume > 0 and volume <= 100000);

-- Ob secondary_load gesetzt sein MUSS, weiss nur das Modell; das prueft
-- die Domain beim Schreiben. Fuer Kraftgeraete bleibt die Spalte null.
alter table public.workout_sets
  add column secondary_load numeric(6, 2)
    constraint workout_sets_secondary_load_check
    check (secondary_load is null or secondary_load >= 0);

-- --------------------------------------------------------------------
-- Vorschlag: das Ergebnis ist eine Belastung, kein Gewicht.
-- --------------------------------------------------------------------

alter table public.progression_suggestions
  rename column result_weight_kg to result_load;

-- Der inputs-Datensatz aendert seine Schluessel mit Algorithmusversion
-- 2.0.0 (currentLoad, currentSecondaryLoad statt currentWeightKg). Alte
-- Zeilen behalten die alten Schluessel; dafuer gibt es algo_version.
-- Die Nebenbelastung des Vorschlags steht in inputs, nicht in einer
-- eigenen Spalte: sie wird nie gesteigert, nur mitgegeben.
