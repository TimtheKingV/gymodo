-- Bestaetigte Saetze.
--
-- Wie workout_sessions ohne Default auf der id: der Schreibvorgang ist ein
-- PUT mit clientseitig erzeugter UUID, derselbe PUT zweimal gesendet ergibt
-- denselben Satz (Spec 6.3).
--
-- `user_id` liegt hier redundant neben `session_id`. Das ist Absicht: der
-- Historienpfad fragt nach (studio, user, machine, exercise, performed_at)
-- und soll ohne Join auf workout_sessions auskommen (Spec 7.5). Die
-- Insert-Policy erzwingt, dass beide zusammenpassen.

create type public.problem_reason as enum (
  'schmerz',
  'geraet_passt_nicht',
  'zu_schwer',
  'sonstiges'
);

create table public.workout_sets (
  id              uuid primary key,
  studio_id       uuid not null references public.studios (id) on delete cascade,
  user_id         uuid not null references auth.users (id) on delete cascade,
  session_id      uuid not null references public.workout_sessions (id) on delete cascade,
  machine_id      uuid not null references public.machines (id) on delete restrict,
  exercise_id     uuid not null references public.exercises (id) on delete restrict,
  -- Laufende Nummer INNERHALB des Blocks (session, machine, exercise), nicht
  -- innerhalb der Session. Nur so traegt Zirkeltraining ohne Sonderlogik
  -- (Spec 7.1).
  set_index       int not null check (set_index >= 1),
  weight_kg       numeric(6, 2) not null check (weight_kg >= 0),
  reps            int not null check (reps > 0 and reps <= 1000),
  rir             numeric(3, 1) check (rir >= 0 and rir <= 10),
  problem_flag    boolean not null default false,
  problem_reason  public.problem_reason,
  performed_at    timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  -- Eine Ursache ohne gesetztes Kennzeichen waere eine Meldung, die keine
  -- Auswertung je findet.
  constraint workout_sets_problem_consistent
    check (problem_reason is null or problem_flag),
  -- Blockstruktur: zweimal Satz 2 im selben Block gibt es nicht.
  constraint workout_sets_unique_index_per_block
    unique (session_id, machine_id, exercise_id, set_index)
);

-- Der Historienpfad (Spec 7.5).
create index on public.workout_sets (
  studio_id, user_id, machine_id, exercise_id, performed_at desc
);
create index on public.workout_sets (session_id);
create index on public.workout_sets (machine_id);
create index on public.workout_sets (exercise_id);
create index on public.workout_sets (user_id);

alter table public.workout_sets enable row level security;
alter table public.workout_sets force row level security;

create policy workout_sets_select on public.workout_sets
  for select to authenticated
  using (
    public.is_studio_member(workout_sets.studio_id)
    and (
      workout_sets.user_id = (select auth.uid())
      or public.is_studio_staff(workout_sets.studio_id)
    )
  );

-- Die Studio- und Nutzerkonsistenz lebt in der Policy, nicht im Schema.
--
-- WICHTIG, wie in 0007: die Spalten der workout_sets-Zeile MUESSEN mit dem
-- Tabellennamen qualifiziert werden. Unqualifiziert loest PostgreSQL
-- `studio_id` gegen die INNERE Tabelle auf -- machines, exercises und
-- workout_sessions haben alle eine Spalte studio_id -- und aus
-- "m.studio_id = studio_id" wuerde ein wirkungsloses
-- "m.studio_id = m.studio_id".
create policy workout_sets_insert on public.workout_sets
  for insert to authenticated
  with check (
    workout_sets.user_id = (select auth.uid())
    and public.is_studio_member(workout_sets.studio_id)
    and exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_sets.session_id
        and ws.studio_id = workout_sets.studio_id
        and ws.user_id = workout_sets.user_id
    )
    and exists (
      select 1 from public.machines m
      where m.id = workout_sets.machine_id
        and m.studio_id = workout_sets.studio_id
    )
    and exists (
      select 1 from public.exercises e
      where e.id = workout_sets.exercise_id
        and e.studio_id = workout_sets.studio_id
    )
  );

-- Update existiert allein fuer die Idempotenz des PUT: derselbe Satz noch
-- einmal geschickt aktualisiert seine eigene Zeile, statt eine zweite
-- anzulegen. Die Konsistenzpruefungen gelten dabei unveraendert weiter.
create policy workout_sets_update on public.workout_sets
  for update to authenticated
  using (
    workout_sets.user_id = (select auth.uid())
    and public.is_studio_member(workout_sets.studio_id)
  )
  with check (
    workout_sets.user_id = (select auth.uid())
    and public.is_studio_member(workout_sets.studio_id)
    and exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_sets.session_id
        and ws.studio_id = workout_sets.studio_id
        and ws.user_id = workout_sets.user_id
    )
    and exists (
      select 1 from public.machines m
      where m.id = workout_sets.machine_id
        and m.studio_id = workout_sets.studio_id
    )
    and exists (
      select 1 from public.exercises e
      where e.id = workout_sets.exercise_id
        and e.studio_id = workout_sets.studio_id
    )
  );

-- Kein Delete: Historie wird nicht geloescht.
