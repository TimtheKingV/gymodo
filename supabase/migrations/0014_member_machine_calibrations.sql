-- Eigene Einstellwerte je Geraet und Uebung.
--
-- Das Mitglied ist Eigentuemer seiner Werte (Spec 7.1, Abweichung 4 vom
-- Blueprint): es kalibriert selbst, ein Trainer ist optional dabei. Der
-- gesamte Freigabemechanismus entfaellt damit.
--
-- Anfuegend, nie ueberschreibend: jede Aenderung legt eine neue Zeile an,
-- die neueste gewinnt. Deshalb gibt es weder Update- noch Delete-Policy.
--
-- ABWEICHUNG von Spec 7.1: die Spalte heisst `setting_values`, nicht
-- `values`. `values` ist in PostgreSQL ein reserviertes Wort und muesste
-- ueberall in Anfuehrungszeichen stehen -- eine Falle, die frueher oder
-- spaeter jemand uebersieht.

create type public.calibration_source as enum ('self', 'trainer_assisted');

create table public.member_machine_calibrations (
  id              uuid primary key default gen_random_uuid(),
  studio_id       uuid not null references public.studios (id) on delete cascade,
  user_id         uuid not null references auth.users (id) on delete cascade,
  machine_id      uuid not null references public.machines (id) on delete restrict,
  exercise_id     uuid not null references public.exercises (id) on delete restrict,
  setting_values  jsonb not null,
  -- JSONB nur mit schema_version und serverseitiger Validierung (Spec 7.4).
  schema_version  int not null check (schema_version >= 1),
  source          public.calibration_source not null default 'self',
  recorded_by     uuid references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  -- Ein Array oder ein blanker Skalar waere kein Satz von Einstellwerten.
  constraint member_machine_calibrations_values_is_object
    check (jsonb_typeof(setting_values) = 'object')
);

-- Der heisse Pfad: die neuesten Werte eines Mitglieds an einem Geraet
-- (Spec 7.5).
create index on public.member_machine_calibrations (
  studio_id, user_id, machine_id, exercise_id, created_at desc
);
create index on public.member_machine_calibrations (machine_id);
create index on public.member_machine_calibrations (exercise_id);
create index on public.member_machine_calibrations (user_id);
create index on public.member_machine_calibrations (recorded_by);

alter table public.member_machine_calibrations enable row level security;
alter table public.member_machine_calibrations force row level security;

create policy member_machine_calibrations_select
  on public.member_machine_calibrations
  for select to authenticated
  using (
    public.is_studio_member(member_machine_calibrations.studio_id)
    and (
      member_machine_calibrations.user_id = (select auth.uid())
      or public.is_studio_staff(member_machine_calibrations.studio_id)
    )
  );

-- Studio-Konsistenz wie in 0007 und 0013: die aeusseren Spalten MUESSEN
-- qualifiziert werden, sonst prueft die Bedingung stillschweigend nichts.
create policy member_machine_calibrations_insert
  on public.member_machine_calibrations
  for insert to authenticated
  with check (
    member_machine_calibrations.user_id = (select auth.uid())
    and public.is_studio_member(member_machine_calibrations.studio_id)
    and exists (
      select 1 from public.machines m
      where m.id = member_machine_calibrations.machine_id
        and m.studio_id = member_machine_calibrations.studio_id
    )
    and exists (
      select 1 from public.exercises e
      where e.id = member_machine_calibrations.exercise_id
        and e.studio_id = member_machine_calibrations.studio_id
    )
  );

-- Kein Update, kein Delete: eine Aenderung ist eine neue Zeile (Spec 5.4).
