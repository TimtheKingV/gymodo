-- Herkunft der Wiederholungszahl am Satz (Sensor-Spec B 6.1).
--
-- Seit Teilprojekt B darf der Bewegungssensor Wiederholungen zaehlen. Das
-- Mitglied bestaetigt die Zahl beim Sichern oder korrigiert sie am Rad;
-- gespeichert wird, woher sie kommt, was der Zaehler stand und je
-- Wiederholung ein paar Kennzahlen fuer Tempo (C) und Spiel (D).
--
-- Rein additiv: Bestand und alte Clients landen ueber den Default bei
-- 'eingegeben'. Keine neue Policy -- die Spalten gehoeren zur Zeile und
-- fallen unter dieselbe Sichtbarkeit und Loeschung.

alter table public.workout_sets
  add column volume_source text not null default 'eingegeben'
    constraint workout_sets_volume_source_check
    check (volume_source in ('eingegeben', 'gemessen', 'korrigiert')),
  -- Mindestens 1: der Zaehler schreibt erst nach der ersten gezaehlten
  -- Wiederholung ins Rad. Wer nichts gezaehlt bekam, hat 'eingegeben'.
  add column volume_counted int
    constraint workout_sets_volume_counted_check
    check (volume_counted is null or volume_counted between 1 and 1000),
  add column rep_events jsonb,
  -- Die einfache Konsistenz prueft die Datenbank selbst; was die Uebung
  -- wissen muss (nur bei volume_kind 'reps'), prueft recordSet.
  -- "is not null" steht ausdruecklich da: ein CHECK laesst NULL durch, und
  -- "NULL = volume" bzw. "NULL <> volume" ist NULL, nicht false.
  add constraint workout_sets_herkunft_consistent check (
    (volume_source = 'eingegeben' and volume_counted is null and rep_events is null)
    or (volume_source = 'gemessen' and volume_counted is not null
        and volume_counted = volume and rep_events is not null)
    or (volume_source = 'korrigiert' and volume_counted is not null
        and volume_counted <> volume and rep_events is not null));
