-- Rollenpruefung fuer Schreibrechte: Trainer und Owner duerfen den
-- Geraetekatalog pflegen, einfache Mitglieder nicht. Analog zu
-- is_studio_member aus M0, aber mit Rollenfilter.
create or replace function public.is_studio_staff(p_studio_id uuid)
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (
    select 1
    from public.studio_memberships m
    where m.studio_id = p_studio_id
      and m.user_id = auth.uid()
      and m.role in ('trainer', 'owner')
  );
$$;

revoke all on function public.is_studio_staff(uuid) from public;
grant execute on function public.is_studio_staff(uuid) to authenticated;

create table public.equipment_models (
  id             uuid primary key default gen_random_uuid(),
  studio_id      uuid not null references public.studios (id) on delete cascade,
  name           text not null check (length(trim(name)) > 0),
  manufacturer   text,
  photo_path     text,
  weight_step_kg numeric not null check (weight_step_kg > 0),
  min_weight_kg  numeric not null default 0 check (min_weight_kg >= 0),
  max_weight_kg  numeric check (max_weight_kg is null or max_weight_kg >= min_weight_kg),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index on public.equipment_models (studio_id);

alter table public.equipment_models enable row level security;
alter table public.equipment_models force row level security;

create policy equipment_models_select on public.equipment_models
  for select to authenticated
  using (public.is_studio_member(studio_id));

create policy equipment_models_insert on public.equipment_models
  for insert to authenticated
  with check (public.is_studio_staff(studio_id));

create policy equipment_models_update on public.equipment_models
  for update to authenticated
  using (public.is_studio_staff(studio_id))
  with check (public.is_studio_staff(studio_id));

create policy equipment_models_delete on public.equipment_models
  for delete to authenticated
  using (public.is_studio_staff(studio_id));

create table public.equipment_setting_definitions (
  id                  uuid primary key default gen_random_uuid(),
  equipment_model_id  uuid not null references public.equipment_models (id) on delete cascade,
  key                 text not null check (length(trim(key)) > 0),
  label               text not null check (length(trim(label)) > 0),
  kind                text not null check (kind in ('number', 'enum')),
  min_value           numeric,
  max_value           numeric,
  step_value          numeric,
  unit                text,
  sort_order          integer not null default 0,
  created_at          timestamptz not null default now(),
  unique (equipment_model_id, key)
);

create index on public.equipment_setting_definitions (equipment_model_id);

alter table public.equipment_setting_definitions enable row level security;
alter table public.equipment_setting_definitions force row level security;

create policy equipment_setting_definitions_select on public.equipment_setting_definitions
  for select to authenticated
  using (
    exists (
      select 1 from public.equipment_models em
      where em.id = equipment_setting_definitions.equipment_model_id
        and public.is_studio_member(em.studio_id)
    )
  );

create policy equipment_setting_definitions_insert on public.equipment_setting_definitions
  for insert to authenticated
  with check (
    exists (
      select 1 from public.equipment_models em
      where em.id = equipment_setting_definitions.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy equipment_setting_definitions_update on public.equipment_setting_definitions
  for update to authenticated
  using (
    exists (
      select 1 from public.equipment_models em
      where em.id = equipment_setting_definitions.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  )
  with check (
    exists (
      select 1 from public.equipment_models em
      where em.id = equipment_setting_definitions.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy equipment_setting_definitions_delete on public.equipment_setting_definitions
  for delete to authenticated
  using (
    exists (
      select 1 from public.equipment_models em
      where em.id = equipment_setting_definitions.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  );
