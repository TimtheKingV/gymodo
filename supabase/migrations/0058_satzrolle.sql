-- Trainingsplan-Spec 2026-10-21, Abschnitt 7: Satzrolle.
--
-- Ein leichter Aufwaermsatz vor den Arbeitssaetzen macht einen Block
-- uneinheitlich: die Progressionsregel findet keinen gemeinsamen
-- Ausgangswert und schlaegt gar nichts vor. Kuenftig lesen Vorschlag,
-- Fortschritt und die spaetere Muskelbilanz nur Arbeitssaetze.
--
-- text mit Check statt Enum, wie volume_source (0049): eine weitere Rolle
-- ist dann eine Zeile im Check statt eines ALTER TYPE. Alle bestehenden
-- Saetze werden ueber den Default zu Arbeitssaetzen -- so wurden sie bisher
-- auch gerechnet. Kein eigener Grant: workout_sets hat keine Spaltenrechte.
alter table public.workout_sets
  add column set_role text not null default 'arbeit'
    constraint workout_sets_set_role_check
    check (set_role in ('arbeit', 'aufwaermen'));

comment on column public.workout_sets.set_role is
  'arbeit (Default, auch fuer alle Altdaten) oder aufwaermen. Progression und Auswertungen lesen nur arbeit.';
