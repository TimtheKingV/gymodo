-- Trainingsprofil und Beschwerden, Trainingsplan-Spec Abschnitte 1 und 7.
--
-- Zwei Tabellen statt einer, weil Beschwerden Gesundheitsdaten sind
-- (DSGVO Art. 9): sie brauchen eine eigene, ausdrueckliche Einwilligung
-- (consent_at) und muessen einzeln widerrufbar sein. Widerruf heisst, die
-- Zeile zu loeschen -- deshalb gibt es hier eine Delete-Policy, anders als
-- bei member_goals (0043). Kein Freitext: areas hat nur feste Schluessel.
--
-- Wie member_goals: kein studio_id, keine Staff-Klausel; nur das
-- Mitglied selbst liest und schreibt. Die Wertelisten spiegeln
-- trainingsplan-typen.ts; die Fachschicht prueft zuerst, die Checks sind
-- das Netz darunter.

create table public.training_profiles (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  minutes    int  not null check (minutes in (30, 45, 60, 75, 90)),
  experience text not null check (experience in ('neu', 'unregelmaessig', 'regelmaessig')),
  focus      text[] not null default '{}',
  updated_at timestamptz not null default now(),
  constraint training_profiles_focus_max2 check (cardinality(focus) <= 2),
  constraint training_profiles_focus_values
    check (focus <@ array['brust', 'ruecken', 'schultern', 'arme', 'po', 'beine', 'bauch']::text[])
);

-- Ein CHECK darf keine Unterabfrage enthalten; deshalb prueft eine immutable
-- Funktion die Schluessel und Stufen von areas. Nur die fuenf Bereiche aus
-- trainingsplan-typen.ts und nur 'meiden'/'vorsichtig' -- so landet auch bei
-- einem direkten Schreibzugriff nichts Freies in den Gesundheitsdaten.
create function public.training_limits_areas_gueltig(a jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when jsonb_typeof(a) <> 'object' then false
    else coalesce(
      (select bool_and(
                e.key in ('knie', 'huefte', 'unterer_ruecken', 'schulter', 'ellenbogen_handgelenk')
                and jsonb_typeof(e.value) = 'string'
                and e.value #>> '{}' in ('meiden', 'vorsichtig'))
         from jsonb_each(a) as e),
      true)
  end
$$;

create table public.training_limits (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  consent_at timestamptz not null,
  areas      jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint training_limits_areas_object check (jsonb_typeof(areas) = 'object'),
  constraint training_limits_areas_werte check (public.training_limits_areas_gueltig(areas))
);

alter table public.training_profiles enable row level security;
alter table public.training_profiles force  row level security;
alter table public.training_limits   enable row level security;
alter table public.training_limits   force  row level security;

create policy training_profiles_select_own on public.training_profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy training_profiles_insert_own on public.training_profiles
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy training_profiles_update_own on public.training_profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy training_profiles_delete_own on public.training_profiles
  for delete to authenticated using (user_id = (select auth.uid()));

create policy training_limits_select_own on public.training_limits
  for select to authenticated using (user_id = (select auth.uid()));
create policy training_limits_insert_own on public.training_limits
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy training_limits_update_own on public.training_limits
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy training_limits_delete_own on public.training_limits
  for delete to authenticated using (user_id = (select auth.uid()));
