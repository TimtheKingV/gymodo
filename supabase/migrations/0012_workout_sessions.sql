-- Trainingseinheiten.
--
-- Die id kommt vom Client und hat deshalb bewusst KEINEN Default: der
-- Schreibvorgang ist ein PUT mit clientseitig erzeugter UUID, wodurch
-- Idempotenz strukturell entsteht statt als Zusatzmechanismus (Spec 6.3).
-- Ein Insert ohne id soll auffallen, nicht stillschweigend eine zweite
-- Session anlegen.
--
-- Eine Session entsteht implizit mit dem ersten gespeicherten Satz (Spec
-- 5.2); es gibt keinen Startknopf und keinen eigenen Endpoint dafuer.

create type public.session_completed_reason as enum ('manual', 'auto');

create table public.workout_sessions (
  id                uuid primary key,
  studio_id         uuid not null references public.studios (id) on delete cascade,
  user_id           uuid not null references auth.users (id) on delete cascade,
  started_at        timestamptz not null default now(),
  completed_at      timestamptz,
  completed_reason  public.session_completed_reason,
  created_at        timestamptz not null default now(),
  -- Abschlusszeitpunkt und Grund gehoeren zusammen. Ohne diese Regel gaebe
  -- es beendete Sessions ohne Grund und Gruende ohne Zeitpunkt, und der
  -- traege Autoabschluss (Spec 5.2) liesse sich nicht mehr von einem
  -- manuellen unterscheiden.
  constraint workout_sessions_completion_consistent
    check ((completed_at is null) = (completed_reason is null)),
  constraint workout_sessions_completed_after_start
    check (completed_at is null or completed_at >= started_at)
);

-- Der Verlaufspfad des Home-Tabs (Spec 7.5).
create index on public.workout_sessions (studio_id, user_id, started_at desc);
create index on public.workout_sessions (user_id);

alter table public.workout_sessions enable row level security;
alter table public.workout_sessions force row level security;

-- Sichtbar sind die eigenen Sessions; Trainer und Betreiber sehen die ihres
-- Studios (Spec 7.6).
create policy workout_sessions_select on public.workout_sessions
  for select to authenticated
  using (
    public.is_studio_member(workout_sessions.studio_id)
    and (
      workout_sessions.user_id = (select auth.uid())
      or public.is_studio_staff(workout_sessions.studio_id)
    )
  );

-- Schreiben darf ausschliesslich das Mitglied selbst -- auch ein Trainer
-- legt keine Session fuer jemanden an.
create policy workout_sessions_insert on public.workout_sessions
  for insert to authenticated
  with check (
    workout_sessions.user_id = (select auth.uid())
    and public.is_studio_member(workout_sessions.studio_id)
  );

-- Update traegt genau einen Zweck: das Beenden der eigenen Session.
create policy workout_sessions_update on public.workout_sessions
  for update to authenticated
  using (
    workout_sessions.user_id = (select auth.uid())
    and public.is_studio_member(workout_sessions.studio_id)
  )
  with check (
    workout_sessions.user_id = (select auth.uid())
    and public.is_studio_member(workout_sessions.studio_id)
  );

-- Kein Delete fuer irgendjemanden: Historie wird nicht geloescht
-- (Regelwerk Spec Abschnitt 10). Es gibt deshalb bewusst keine
-- Delete-Policy -- ohne sie greift RLS und der Loeschversuch trifft null
-- Zeilen.
