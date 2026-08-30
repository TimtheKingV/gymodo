create table public.instruction_assets (
  id                           uuid primary key default gen_random_uuid(),
  equipment_model_exercise_id  uuid not null references public.equipment_model_exercises (id) on delete cascade,
  kind                         text not null check (kind = 'video'),
  storage_path                 text not null check (length(trim(storage_path)) > 0),
  duration_s                   integer not null check (duration_s > 0 and duration_s <= 45),
  created_at                   timestamptz not null default now()
);

create index on public.instruction_assets (equipment_model_exercise_id);

alter table public.instruction_assets enable row level security;
alter table public.instruction_assets force row level security;

create policy instruction_assets_select on public.instruction_assets
  for select to authenticated
  using (
    exists (
      select 1
      from public.equipment_model_exercises eme
      join public.equipment_models em on em.id = eme.equipment_model_id
      where eme.id = instruction_assets.equipment_model_exercise_id
        and public.is_studio_member(em.studio_id)
    )
  );

create policy instruction_assets_insert on public.instruction_assets
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.equipment_model_exercises eme
      join public.equipment_models em on em.id = eme.equipment_model_id
      where eme.id = instruction_assets.equipment_model_exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy instruction_assets_update on public.instruction_assets
  for update to authenticated
  using (
    exists (
      select 1
      from public.equipment_model_exercises eme
      join public.equipment_models em on em.id = eme.equipment_model_id
      where eme.id = instruction_assets.equipment_model_exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  )
  with check (
    exists (
      select 1
      from public.equipment_model_exercises eme
      join public.equipment_models em on em.id = eme.equipment_model_id
      where eme.id = instruction_assets.equipment_model_exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy instruction_assets_delete on public.instruction_assets
  for delete to authenticated
  using (
    exists (
      select 1
      from public.equipment_model_exercises eme
      join public.equipment_models em on em.id = eme.equipment_model_id
      where eme.id = instruction_assets.equipment_model_exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );
