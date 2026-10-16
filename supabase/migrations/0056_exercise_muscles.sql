-- Muskelmodell in der Einweisung: die Muskeln einer Uebung.
--
-- Eine Liste von {key, name, role} (role: primary | secondary). Der
-- Katalog-Import schreibt sie (Spec Zusatzdaten), die API liefert sie aus.
-- Rein additiv: bestehende Uebungen bekommen eine leere Liste, aeltere
-- Apps kennen die Spalte nicht und lesen sie nicht.
alter table public.exercises
  add column muscles jsonb not null default '[]'
    constraint exercises_muscles_array
    check (jsonb_typeof(muscles) = 'array');
