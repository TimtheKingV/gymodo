-- Stammdaten am Profil, Spec 2026-09-13-ziele-und-fortschritt-design.md
-- Abschnitt 3.1.
--
-- Alle fuenf Spalten nullable: nichts davon ist Voraussetzung fuer
-- irgendeine Funktion, und ein Mitglied, das im Onboarding fuenfmal
-- "Spaeter" tippt, nutzt die App wie bisher.
--
-- Alter als SPANNE, nicht als Jahr oder Datum: sparsamer, und sie altert
-- nicht mit -- wer 35 wird, bleibt in 25_34, bis er es selbst aendert.
-- Ehrlicher als ein Alter, das die App aus einem Jahr rechnet.
--
-- Geschlecht wird gespeichert, aber in diesem Bauabschnitt von keiner
-- Funktion gelesen (Entscheidung vom 13. September: Grundlage fuer
-- spaetere Startgewicht-Vorschlaege und Trainingsplaene). "Keine Angabe"
-- ist null, kein vierter Wert.
--
-- Was hier NICHT passiert: keine neue Policy, kein Spaltenrecht fuer
-- Personal. profiles_select_own / _update_own / _insert_own (0001, 0039)
-- decken die Spalten -- die Zeile bleibt die eigene.

create type public.member_sex as enum ('female', 'male', 'diverse');
create type public.age_band as enum
  ('under_18', '18_24', '25_34', '35_44', '45_54', '55_64', '65_plus');
create type public.training_goal as enum
  ('lose_weight', 'build_muscle', 'stay_fit', 'get_stronger');

alter table public.profiles
  add column sex                     public.member_sex,
  add column age_band                public.age_band,
  add column height_cm               smallint,
  add column training_goal           public.training_goal,
  add column onboarding_completed_at timestamptz,
  add constraint profiles_height_range
    check (height_cm is null or height_cm between 100 and 250);

comment on column public.profiles.onboarding_completed_at is
  'Gesetzt beim Abschluss ODER beim Ueberspringen -- das Onboarding erscheint nie zweimal. Wird nie vom Client geliefert, nur ueber updateProfile({ onboardingDone: true }) auf now() gesetzt. Jedes Bestandskonto traegt null und sieht das Onboarding beim naechsten Start einmal; das sind bis M2 Entwicklerkonten und synthetische Daten.';
