-- Gespeicherte Trainingsplaene, Trainingsplan-Spec Etappe 2 (F14: Plaene sind stabil).
--
-- Ein Plan wird einmal erzeugt und dann nur noch gelesen -- nie beim Lesen
-- neu berechnet. Deshalb steht alles in der Zeile, was der Generator benutzt
-- hat: eingabe (Ziel, Tage, Minuten, Fokus, Erfahrung, Beschwerden -- ohne
-- die Kandidatenliste, die verwendeten Uebungen und Geraete stehen ja in
-- einheiten), die regel_version und das Ergebnis.
--
-- Versionen je (Mitglied, Studio): ein neuer Vorschlag verwirft den alten
-- ('verworfen'), ein angenommener Vorschlag ersetzt den aktiven Plan
-- ('ersetzt'). Genau ein aktiver Plan je Paar, erzwungen vom Teilindex --
-- nicht von der Fachschicht, sonst koennten zwei gleichzeitige Annahmen
-- zwei aktive Plaene hinterlassen.
--
-- RLS wie member_goals (0043): nur das Mitglied selbst. Keine
-- Delete-Policy: historische Versionen bleiben. Insert zusaetzlich nur fuer
-- Studios, in denen der Aufrufer Mitglied ist, damit niemand Plaene fuer
-- fremde Studios anlegt.

create table public.training_plans (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  studio_id    uuid not null references public.studios (id) on delete cascade,
  version      int  not null check (version >= 1),
  status       text not null check (status in ('vorschlag', 'aktiv', 'ersetzt', 'verworfen')),
  regel_version text not null,
  eingabe      jsonb not null check (jsonb_typeof(eingabe) = 'object'),
  struktur     text not null,
  einheiten    jsonb not null check (jsonb_typeof(einheiten) = 'array'),
  gruende      text[] not null,
  created_at   timestamptz not null default now(),
  accepted_at  timestamptz,
  unique (user_id, studio_id, version)
);

create unique index training_plans_one_active
  on public.training_plans (user_id, studio_id)
  where status = 'aktiv';

-- Hoechstens ein offener Vorschlag je Paar: zwei gleichzeitige Erzeugungen
-- koennten sonst beide den alten verwerfen und je einen neuen einfuegen.
create unique index training_plans_one_vorschlag
  on public.training_plans (user_id, studio_id)
  where status = 'vorschlag';

alter table public.training_plans enable row level security;
alter table public.training_plans force  row level security;

create policy training_plans_select_own on public.training_plans
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy training_plans_insert_own on public.training_plans
  for insert to authenticated
  with check (user_id = (select auth.uid()) and public.is_studio_member(studio_id));

create policy training_plans_update_own on public.training_plans
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- SECURITY INVOKER, ausdruecklich: die Policies oben reichen. Die Funktion
-- buendelt nur Ersetzen und Annehmen in einer Transaktion. FOR UPDATE
-- serialisiert gleichzeitige Annahmen desselben Vorschlags: die zweite
-- wartet und sieht danach 'aktiv' statt 'vorschlag' -- also Fehler statt
-- eines zweiten Wechsels.
create or replace function public.accept_training_plan(p_plan_id uuid)
returns public.training_plans
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_plan public.training_plans;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select * into v_plan
    from public.training_plans
   where id = p_plan_id and user_id = v_user
     for update;

  if not found or v_plan.status <> 'vorschlag' then
    raise exception 'plan_nicht_annehmbar' using errcode = 'P0001';
  end if;

  update public.training_plans
     set status = 'ersetzt'
   where user_id = v_user and studio_id = v_plan.studio_id and status = 'aktiv';

  update public.training_plans
     set status = 'aktiv', accepted_at = now()
   where id = p_plan_id
  returning * into v_plan;

  return v_plan;
end;
$$;

revoke all on function public.accept_training_plan(uuid) from public;
grant execute on function public.accept_training_plan(uuid) to authenticated;
