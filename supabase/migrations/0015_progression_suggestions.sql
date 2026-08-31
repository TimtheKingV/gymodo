-- Ausgelieferte Gewichtsvorschlaege.
--
-- Blueprint 16.8.2 verlangt, dass ein Vorschlag nachvollziehbar bleibt:
-- Algorithmusversion, Eingaben, Ergebnis und Begruendungscode. Deshalb wird
-- jeder ausgelieferte Vorschlag festgehalten, nicht nur der angenommene --
-- "Vorschlag und bestaetigter Wert getrennt speichern" (Spec Abschnitt 10).
-- Der bestaetigte Wert steht in workout_sets und wird hiervon nie beruehrt.
--
-- Anfuegend wie member_machine_calibrations: kein Update, kein Delete. Ein
-- nachtraeglich geaenderter Vorschlag waere als Beleg wertlos.
--
-- ABWEICHUNGEN von Spec 7.1, beide der Klarheit halber:
--   `result` heisst hier `result_weight_kg` -- es ist ein Gewicht und darf
--   null sein (beim Erstkontakt gibt es bewusst keinen Vorschlag).
--   `reason_code` ist text, kein Enum: die Codes gehoeren zur
--   Algorithmusversion und aendern sich mit ihr. Ein Enum zwaenge jede
--   Regelaenderung in eine Migration und machte alte Zeilen ungueltig.

create table public.progression_suggestions (
  id                uuid primary key default gen_random_uuid(),
  studio_id         uuid not null references public.studios (id) on delete cascade,
  user_id           uuid not null references auth.users (id) on delete cascade,
  machine_id        uuid not null references public.machines (id) on delete restrict,
  exercise_id       uuid not null references public.exercises (id) on delete restrict,
  algo_version      text not null check (length(trim(algo_version)) > 0),
  inputs            jsonb not null,
  result_weight_kg  numeric(6, 2) check (result_weight_kg >= 0),
  reason_code       text not null check (length(trim(reason_code)) > 0),
  created_at        timestamptz not null default now(),
  constraint progression_suggestions_inputs_is_object
    check (jsonb_typeof(inputs) = 'object')
);

create index on public.progression_suggestions (
  studio_id, user_id, machine_id, exercise_id, created_at desc
);
create index on public.progression_suggestions (machine_id);
create index on public.progression_suggestions (exercise_id);
create index on public.progression_suggestions (user_id);

alter table public.progression_suggestions enable row level security;
alter table public.progression_suggestions force row level security;

create policy progression_suggestions_select
  on public.progression_suggestions
  for select to authenticated
  using (
    public.is_studio_member(progression_suggestions.studio_id)
    and (
      progression_suggestions.user_id = (select auth.uid())
      or public.is_studio_staff(progression_suggestions.studio_id)
    )
  );

-- Studio-Konsistenz wie in 0007, 0013 und 0014: aeussere Spalten MUESSEN
-- qualifiziert werden, sonst prueft die Bedingung stillschweigend nichts.
create policy progression_suggestions_insert
  on public.progression_suggestions
  for insert to authenticated
  with check (
    progression_suggestions.user_id = (select auth.uid())
    and public.is_studio_member(progression_suggestions.studio_id)
    and exists (
      select 1 from public.machines m
      where m.id = progression_suggestions.machine_id
        and m.studio_id = progression_suggestions.studio_id
    )
    and exists (
      select 1 from public.exercises e
      where e.id = progression_suggestions.exercise_id
        and e.studio_id = progression_suggestions.studio_id
    )
  );

-- Kein Update, kein Delete.
