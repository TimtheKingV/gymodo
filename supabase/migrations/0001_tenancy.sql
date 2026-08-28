create extension if not exists pgcrypto;

create table public.studios (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (length(trim(name)) > 0),
  timezone    text not null default 'Europe/Berlin',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create type public.studio_role as enum ('owner', 'trainer', 'member');

create table public.studio_memberships (
  id          uuid primary key default gen_random_uuid(),
  studio_id   uuid not null references public.studios (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  role        public.studio_role not null,
  created_at  timestamptz not null default now(),
  unique (studio_id, user_id)
);

create index on public.studio_memberships (user_id);
create index on public.studio_memberships (studio_id);

-- SECURITY DEFINER, damit die Policy auf studio_memberships nicht rekursiv
-- dieselbe Tabelle unter RLS abfragt. Diese Funktion ist die einzige Stelle,
-- an der RLS umgangen wird — deshalb hat sie ein festes search_path und
-- liefert ausschliesslich einen Boolean zurueck, niemals Daten.
create or replace function public.is_studio_member(p_studio_id uuid)
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
  );
$$;

revoke all on function public.is_studio_member(uuid) from public;
grant execute on function public.is_studio_member(uuid) to authenticated;

alter table public.studios             enable row level security;
alter table public.studios             force  row level security;
alter table public.profiles            enable row level security;
alter table public.profiles            force  row level security;
alter table public.studio_memberships  enable row level security;
alter table public.studio_memberships  force  row level security;

create policy studios_select on public.studios
  for select to authenticated
  using (public.is_studio_member(id));

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = auth.uid());

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy memberships_select_own on public.studio_memberships
  for select to authenticated
  using (user_id = auth.uid());
