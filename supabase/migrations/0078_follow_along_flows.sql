-- Follow-along-Flows: zeitgesteuerte Intervall-Workouts (Arbeit/Pause je Schritt).
-- flows und flow_steps sind Katalogdaten eines Studios: Mitglieder lesen, geschrieben
-- wird nur per service_role (Import). flow_runs schreibt das Mitglied selbst; die id
-- kommt vom Client, damit ein erneutes Senden idempotent ist (upsert ignoreDuplicates).

create table public.flows (
  id             uuid primary key default gen_random_uuid(),
  studio_id      uuid not null references public.studios (id) on delete cascade,
  key            text not null,
  titel          text not null,
  beschreibung   text,
  level          text check (level in ('einsteiger', 'mittel', 'fortgeschritten')),
  source_url     text,
  source_channel text,
  created_at     timestamptz not null default now(),
  unique (studio_id, key)
);

create table public.flow_steps (
  flow_id      uuid not null references public.flows (id) on delete cascade,
  position     int  not null check (position >= 1),
  name         text not null,
  beschreibung text,
  work_s       int  not null check (work_s > 0),
  rest_s       int  not null check (rest_s >= 0),
  is_warmup    boolean not null default false,
  primary key (flow_id, position)
);

create table public.flow_runs (
  id         uuid primary key,
  flow_id    uuid not null references public.flows (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  studio_id  uuid not null references public.studios (id),
  started_at timestamptz not null,
  ended_at   timestamptz not null,
  last_step  int  not null check (last_step >= 1),
  outcome    text not null check (outcome in ('finished', 'aborted')),
  constraint ended_after_start check (ended_at >= started_at)
);

create index flow_runs_user_idx on public.flow_runs (user_id, started_at desc);

alter table public.flows      enable row level security;
alter table public.flows      force  row level security;
alter table public.flow_steps enable row level security;
alter table public.flow_steps force  row level security;
alter table public.flow_runs  enable row level security;
alter table public.flow_runs  force  row level security;

create policy flows_select on public.flows
  for select to authenticated using (public.is_studio_member(studio_id));

create policy flow_steps_select on public.flow_steps
  for select to authenticated using (
    exists (
      select 1 from public.flows f
      where f.id = flow_steps.flow_id
        and public.is_studio_member(f.studio_id)
    )
  );

create policy flow_runs_select_own on public.flow_runs
  for select to authenticated using (user_id = (select auth.uid()));

create policy flow_runs_insert_own on public.flow_runs
  for insert to authenticated with check (
    user_id = (select auth.uid())
    and public.is_studio_member(studio_id)
    and exists (
      select 1 from public.flows f
      where f.id = flow_runs.flow_id
        and f.studio_id = flow_runs.studio_id
    )
  );

-- Rechte auf das Noetige beschraenken (Muster 0071).
revoke all on public.flows      from anon;
revoke all on public.flows      from public;
revoke all on public.flow_steps from anon;
revoke all on public.flow_steps from public;
revoke all on public.flow_runs  from anon;
revoke all on public.flow_runs  from public;
revoke all on public.flows      from authenticated;
revoke all on public.flow_steps from authenticated;
revoke all on public.flow_runs  from authenticated;
grant select on public.flows      to authenticated;
grant select on public.flow_steps to authenticated;
grant select, insert on public.flow_runs to authenticated;
