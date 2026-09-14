-- Ziele mit Geschichte, Spec Abschnitt 3.3.
--
-- Eine Tabelle statt zweier Spalten an profiles: ein Ziel hat einen
-- Anfang und ein Ende. "Zielgewicht 78 kg -- erreicht am 3. November" ist
-- der Moment, fuer den das Feature gebaut wird; zwei Spalten koennten ihn
-- nicht festhalten. Wer sein Wochenziel von 2 auf 3 hebt, schliesst das
-- alte ab, statt es zu verlieren.
--
-- Genau ein aktives Ziel je Sorte, erzwungen vom Teilindex -- nicht von
-- der Fachschicht. set_member_goal wechselt altes und neues in EINER
-- Transaktion, sonst gaebe es zwischen zwei Statements einen Augenblick
-- mit zwei aktiven oder keinem.
--
-- Wie body_measurements (0042): kein studio_id, keine Staff-Klausel, keine
-- Aggregatfunktion. Keine Delete-Policy: ein Ziel wird aufgegeben
-- ('dropped'), nicht geloescht -- die Geschichte bleibt beim Mitglied bis
-- zur M3-Loeschung. exercise_id ist fuer die vierte Sorte vorgesehen
-- (Uebungsziele, Runde 2) und in dieser Runde immer null.
--
-- Die Serie (serienstand in sessions.ts) haengt NICHT an weekly_days.
-- Sie zaehlt weiter Wochen mit mindestens einer Einheit; das Wochenziel
-- ist eine eigene Aussage daneben (Spec Abschnitt 9, Punkt 5).

create type public.goal_kind   as enum ('weekly_days', 'target_weight');
create type public.goal_status as enum ('active', 'reached', 'dropped');

-- IMMUTABLE und ohne Tabellenzugriff -- nur so darf sie in einem CHECK
-- stehen. search_path leer wie in 0040: der Rumpf braucht nichts aus
-- public.
create or replace function public.is_valid_goal_value(p_kind public.goal_kind, p_value numeric)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case p_kind
    when 'weekly_days'   then p_value = floor(p_value) and p_value between 1 and 7
    when 'target_weight' then p_value = round(p_value, 1) and p_value between 20 and 400
    else false
  end
$$;

create table public.member_goals (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  kind         public.goal_kind not null,
  target_value numeric(6,1) not null,
  exercise_id  uuid references public.exercises (id) on delete set null,
  status       public.goal_status not null default 'active',
  created_at   timestamptz not null default now(),
  reached_at   timestamptz,
  constraint member_goals_value_valid
    check (public.is_valid_goal_value(kind, target_value)),
  constraint member_goals_reached_at_only_when_reached
    check ((status = 'reached') = (reached_at is not null))
);

create unique index member_goals_one_active_per_kind
  on public.member_goals (user_id, kind)
  where status = 'active';

create index on public.member_goals (user_id, created_at desc);

alter table public.member_goals enable row level security;
alter table public.member_goals force  row level security;

create policy member_goals_select_own on public.member_goals
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy member_goals_insert_own on public.member_goals
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy member_goals_update_own on public.member_goals
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- SECURITY INVOKER, ausdruecklich: die Policies oben reichen, die
-- Funktion umgeht keine. Sie buendelt nur zwei Schreibvorgaenge in eine
-- Transaktion.
create or replace function public.set_member_goal(
  p_kind  public.goal_kind,
  p_value numeric
)
returns public.member_goals
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_neu  public.member_goals;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  update public.member_goals
     set status = 'dropped'
   where user_id = v_user and kind = p_kind and status = 'active';

  insert into public.member_goals (user_id, kind, target_value)
  values (v_user, p_kind, p_value)
  returning * into v_neu;

  return v_neu;
end;
$$;

revoke all on function public.set_member_goal(public.goal_kind, numeric) from public;
grant execute on function public.set_member_goal(public.goal_kind, numeric) to authenticated;
