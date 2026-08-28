create type public.tag_status as enum ('unassigned', 'active', 'revoked', 'replaced');

create table public.machine_tags (
  id          uuid primary key default gen_random_uuid(),
  studio_id   uuid not null references public.studios (id) on delete cascade,
  machine_id  uuid,
  token_hash  text not null check (token_hash ~ '^[0-9a-f]{64}$'),
  status      public.tag_status not null default 'unassigned',
  created_at  timestamptz not null default now(),
  revoked_at  timestamptz,
  constraint machine_tags_token_hash_key unique (token_hash)
);

create index on public.machine_tags (studio_id);

alter table public.machine_tags enable row level security;
alter table public.machine_tags force  row level security;

create policy machine_tags_select on public.machine_tags
  for select to authenticated
  using (public.is_studio_member(studio_id));
