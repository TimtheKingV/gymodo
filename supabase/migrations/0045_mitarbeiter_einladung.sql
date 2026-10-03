-- Mitarbeiter einladen per Link (Testnotiz 25.09., #6 -- Moeglichkeit 2).
--
-- Bis hierher kam Personal nur auf einem Umweg ins Studio: Konto anlegen,
-- per Studio-Code als Mitglied beitreten, dann von einem Trainer
-- hochgestuft werden. Jetzt erzeugt ein Trainer oder Inhaber einen Link,
-- der fuer eine Person und sieben Tage gilt; wer ihn annimmt, ist Trainer.
--
-- Gespeichert wird nur der SHA-256 des Tokens, nie der Token selbst: eine
-- gelesene Zeile -- von Personal per RLS, in einem Backup, in einem Log --
-- ist dann kein benutzbarer Link. Derselbe Gedanke wie token_hash in 0026.
-- Der Token wird deshalb genau einmal gezeigt, beim Erzeugen.
--
-- Die Rolle ist fest "trainer". Inhaber entstehen weiterhin nur ueber das
-- Onboarding (setMembershipRole nimmt "owner" ebenso wenig an, 0031).

create table public.staff_invites (
  id          uuid primary key default gen_random_uuid(),
  studio_id   uuid not null references public.studios (id) on delete cascade,
  token_hash  text not null unique,
  role        text not null default 'trainer' check (role = 'trainer'),
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '7 days',
  accepted_by uuid references auth.users (id) on delete set null,
  accepted_at timestamptz,
  revoked_at  timestamptz
);

create index on public.staff_invites (studio_id);

alter table public.staff_invites enable row level security;

-- Lesen: Personal des Studios (die Liste der offenen Einladungen im
-- Portal). Schreiben: nur ueber die Funktionen unten -- keine Insert-,
-- Update- oder Delete-Policy, aus demselben Grund wie beim Studio-Code:
-- ein Schreibrecht auf die Tabelle waere breiter als die vier Handgriffe,
-- die es braucht.
create policy staff_invites_select_staff on public.staff_invites
  for select to authenticated
  using (public.is_studio_staff(studio_id));

-- Der Hash eines Tokens, an einer Stelle. sha256() ist seit Postgres 11
-- eingebaut, kein pgcrypto noetig.
create or replace function public.staff_invite_hash(p_token text)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(sha256(convert_to(trim(p_token), 'UTF8')), 'hex');
$$;

revoke all on function public.staff_invite_hash(text) from public, anon, authenticated;

create or replace function public.create_staff_invite(p_studio_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_token text;
begin
  if not public.is_studio_staff(p_studio_id) then
    raise exception 'Nur Trainer und Inhaber duerfen einladen.';
  end if;

  -- Zwei UUIDs v4 ohne Bindestriche: 64 Hex-Zeichen, 244 Zufallsbits aus
  -- gen_random_uuid() (eingebaut seit Postgres 13, kryptografisch
  -- zufaellig). Genug, dass sich ein gueltiger Link nicht erraten laesst.
  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');

  insert into public.staff_invites (studio_id, token_hash, created_by)
  values (p_studio_id, public.staff_invite_hash(v_token), auth.uid());

  return v_token;
end;
$$;

revoke all on function public.create_staff_invite(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.create_staff_invite(uuid) to authenticated;

-- Was die Einladungsseite vor der Anmeldung zeigen darf: der Name des
-- Studios und bis wann der Link gilt. Deshalb auch fuer anon.
--
-- Unbekannt, abgelaufen, benutzt und zurueckgezogen antworten identisch:
-- leer. Eine unterschiedliche Antwort machte gueltige Links erratbar.
create or replace function public.staff_invite_info(p_token text)
returns table (studio_name text, expires_at timestamptz)
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select s.name, i.expires_at
    from public.staff_invites i
    join public.studios s on s.id = i.studio_id
   where i.token_hash = public.staff_invite_hash(p_token)
     and i.accepted_at is null
     and i.revoked_at is null
     and i.expires_at > now();
$$;

revoke all on function public.staff_invite_info(text)
  from public, anon, authenticated, service_role;
grant execute on function public.staff_invite_info(text) to anon, authenticated;

create or replace function public.accept_staff_invite(p_token text)
returns table (studio_id uuid)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
-- Der Rueckgabewert heisst studio_id wie die Spalten -- ohne diese Zeile
-- waere jede unqualifizierte Erwaehnung mehrdeutig.
#variable_conflict use_column
declare
  v_user   uuid := auth.uid();
  v_invite public.staff_invites%rowtype;
begin
  if v_user is null then
    return;
  end if;

  -- for update: zwei Konten, die denselben Link im selben Moment annehmen,
  -- laufen hintereinander -- das zweite findet accepted_at gesetzt.
  select * into v_invite
    from public.staff_invites i
   where i.token_hash = public.staff_invite_hash(p_token)
     and i.accepted_at is null
     and i.revoked_at is null
     and i.expires_at > now()
   for update;

  if not found then
    return;
  end if;

  -- Neu: Trainer. Schon Mitglied: hochgestuft. Schon Trainer oder Inhaber:
  -- unveraendert -- ein Inhaber, der den Link zum Ausprobieren oeffnet,
  -- darf dabei nicht zum Trainer werden.
  insert into public.studio_memberships as m (studio_id, user_id, role)
  values (v_invite.studio_id, v_user, 'trainer')
  on conflict on constraint studio_memberships_studio_id_user_id_key
  do update set role = 'trainer' where m.role = 'member';

  update public.staff_invites
     set accepted_at = now(), accepted_by = v_user
   where id = v_invite.id;

  return query select v_invite.studio_id;
end;
$$;

revoke all on function public.accept_staff_invite(text)
  from public, anon, authenticated, service_role;
grant execute on function public.accept_staff_invite(text) to authenticated;

create or replace function public.revoke_staff_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_studio uuid;
begin
  select i.studio_id into v_studio from public.staff_invites i where i.id = p_invite_id;

  -- Unbekannt und fremd antworten gleich.
  if v_studio is null or not public.is_studio_staff(v_studio) then
    raise exception 'Diese Einladung gibt es nicht.';
  end if;

  update public.staff_invites
     set revoked_at = now()
   where id = p_invite_id
     and accepted_at is null
     and revoked_at is null;
end;
$$;

revoke all on function public.revoke_staff_invite(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.revoke_staff_invite(uuid) to authenticated;
