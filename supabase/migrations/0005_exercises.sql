create table public.exercises (
  id               uuid primary key default gen_random_uuid(),
  studio_id        uuid not null references public.studios (id) on delete cascade,
  name             text not null check (length(trim(name)) > 0),
  description      text,
  target_reps_min  integer not null check (target_reps_min > 0),
  target_reps_max  integer not null check (target_reps_max >= target_reps_min),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index on public.exercises (studio_id);

alter table public.exercises enable row level security;
alter table public.exercises force row level security;

create policy exercises_select on public.exercises
  for select to authenticated
  using (public.is_studio_member(studio_id));

create policy exercises_insert on public.exercises
  for insert to authenticated
  with check (public.is_studio_staff(studio_id));

create policy exercises_update on public.exercises
  for update to authenticated
  using (public.is_studio_staff(studio_id))
  with check (public.is_studio_staff(studio_id));

create policy exercises_delete on public.exercises
  for delete to authenticated
  using (public.is_studio_staff(studio_id));

create table public.equipment_model_exercises (
  id                  uuid primary key default gen_random_uuid(),
  equipment_model_id  uuid not null references public.equipment_models (id) on delete cascade,
  exercise_id         uuid not null references public.exercises (id) on delete cascade,
  sort_order          integer not null default 0,
  created_at          timestamptz not null default now(),
  unique (equipment_model_id, exercise_id)
);

create index on public.equipment_model_exercises (equipment_model_id);
create index on public.equipment_model_exercises (exercise_id);

alter table public.equipment_model_exercises enable row level security;
alter table public.equipment_model_exercises force row level security;

-- Verknuepfung ist nur gueltig, wenn Geraetemodell und Uebung demselben
-- Studio gehoeren -- der Join erzwingt das direkt in der Policy, nicht
-- nur per Anwendungscode.
create policy equipment_model_exercises_select on public.equipment_model_exercises
  for select to authenticated
  using (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e on e.studio_id = em.studio_id
      where em.id = equipment_model_exercises.equipment_model_id
        and e.id = equipment_model_exercises.exercise_id
        and public.is_studio_member(em.studio_id)
    )
  );

create policy equipment_model_exercises_insert on public.equipment_model_exercises
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e on e.studio_id = em.studio_id
      where em.id = equipment_model_exercises.equipment_model_id
        and e.id = equipment_model_exercises.exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy equipment_model_exercises_update on public.equipment_model_exercises
  for update to authenticated
  using (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e on e.studio_id = em.studio_id
      where em.id = equipment_model_exercises.equipment_model_id
        and e.id = equipment_model_exercises.exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  )
  with check (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e on e.studio_id = em.studio_id
      where em.id = equipment_model_exercises.equipment_model_id
        and e.id = equipment_model_exercises.exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy equipment_model_exercises_delete on public.equipment_model_exercises
  for delete to authenticated
  using (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e on e.studio_id = em.studio_id
      where em.id = equipment_model_exercises.equipment_model_id
        and e.id = equipment_model_exercises.exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );
