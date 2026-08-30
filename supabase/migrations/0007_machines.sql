create type public.machine_status as enum ('active', 'inactive');

create table public.machines (
  id                  uuid primary key default gen_random_uuid(),
  studio_id           uuid not null references public.studios (id) on delete cascade,
  equipment_model_id  uuid not null references public.equipment_models (id) on delete restrict,
  label               text not null check (length(trim(label)) > 0),
  location_note       text,
  status              public.machine_status not null default 'active',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index on public.machines (studio_id);
create index on public.machines (equipment_model_id);

alter table public.machines enable row level security;
alter table public.machines force row level security;

create policy machines_select on public.machines
  for select to authenticated
  using (public.is_studio_member(studio_id));

-- Wie equipment_model_exercises: die Policy erzwingt zugleich, dass das
-- referenzierte Geraetemodell demselben Studio gehoert wie die Instanz.
--
-- WICHTIG: Die Spalten der machines-Zeile MUESSEN hier mit dem Tabellennamen
-- qualifiziert werden (machines.studio_id, nicht studio_id). Unqualifiziert
-- loest PostgreSQL den Namen gegen die INNERE Tabelle der Unterabfrage auf --
-- equipment_models hat ebenfalls eine Spalte studio_id, sodass aus
-- "em.studio_id = studio_id" ein wirkungsloses "em.studio_id = em.studio_id"
-- wuerde und die Studio-Pruefung stillschweigend nichts pruefte.
create policy machines_insert on public.machines
  for insert to authenticated
  with check (
    public.is_studio_staff(machines.studio_id)
    and exists (
      select 1 from public.equipment_models em
      where em.id = machines.equipment_model_id
        and em.studio_id = machines.studio_id
    )
  );

create policy machines_update on public.machines
  for update to authenticated
  using (public.is_studio_staff(machines.studio_id))
  with check (
    public.is_studio_staff(machines.studio_id)
    and exists (
      select 1 from public.equipment_models em
      where em.id = machines.equipment_model_id
        and em.studio_id = machines.studio_id
    )
  );

create policy machines_delete on public.machines
  for delete to authenticated
  using (public.is_studio_staff(machines.studio_id));
