-- Gymtavo-Katalog und offener Zugang, Spec
-- 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 5.
--
-- Bis hier gehoerte jeder Inhalt genau einem Studio, und wer keines hatte,
-- kam nach dem Onboarding nicht weiter. Gymtavo pflegt jetzt eine eigene
-- Geraete- und Uebungsdatenbank, die jeder Angemeldete sieht. Sie lebt in
-- einem gewoehnlichen Studio mit Kennzeichen is_catalog -- nicht in einer
-- zweiten Tabellenwelt. So tragen Portal-Masken, Videoablage und
-- Satzpruefung den Katalog ohne doppelte Logik (Spec E6).

-- ---------------------------------------------------------------------
-- 1. Das Gymtavo-Studio und seine Waechter
-- ---------------------------------------------------------------------

-- Kein Spalten-Grant noetig: 0032 hat UPDATE auf studios fuer authenticated
-- auf name, timezone und cancellation_deadline_hours beschraenkt. Ein
-- Trainer kann sein Studio deshalb nicht selbst zum Katalog erklaeren.
alter table public.studios
  add column is_catalog boolean not null default false;

-- Hoechstens ein Katalog: zwei wuerden die Frage "welche Gymtavo-Uebung ist
-- Bankdruecken?" mehrdeutig machen, und der Fortschritt laeuft genau ueber
-- diese Identitaet zusammen (Spec E2).
create unique index studios_genau_ein_katalog
  on public.studios (is_catalog)
  where is_catalog;

-- SECURITY DEFINER wie is_studio_member (0001): die Funktion steht in
-- Policies anderer Tabellen und darf nicht von der RLS auf studios abhaengen.
-- Sie liefert ausschliesslich einen Boolean.
create or replace function public.is_catalog_studio(p_studio_id uuid)
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select coalesce(
    (select s.is_catalog from public.studios s where s.id = p_studio_id),
    false
  );
$$;

revoke all on function public.is_catalog_studio(uuid) from public, anon;
grant execute on function public.is_catalog_studio(uuid) to authenticated, service_role;

-- Feste id, damit Import (Etappe 2) und Tests das Studio ohne Suche finden.
-- Der Beitrittscode ist aus: dem Katalog tritt man nicht bei, man sieht ihn.
insert into public.studios (id, name, is_catalog, join_code_active)
values ('00000000-0000-4000-8000-000000000001', 'Gymtavo', true, false);

drop policy studios_select on public.studios;
create policy studios_select on public.studios
  for select to authenticated
  using (public.is_studio_member(studios.id) or studios.is_catalog);

-- Ein Waechter an der Tabelle statt Pruefungen in join_studio_by_tag,
-- join_studio_by_code und accept_staff_invite: er erreicht auch jeden
-- kuenftigen Beitrittsweg. Personal bleibt erlaubt -- das Gymtavo-Team
-- pflegt den Katalog spaeter im Portal und braucht dafuer Einladungen.
create or replace function public.gymtavo_keine_mitglieder()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.role = 'member' and public.is_catalog_studio(new.studio_id) then
    raise exception 'gymtavo_keine_mitglieder';
  end if;
  return new;
end;
$$;

revoke all on function public.gymtavo_keine_mitglieder() from public, anon, authenticated;

create trigger studio_memberships_gymtavo_keine_mitglieder
  before insert or update of role, studio_id on public.studio_memberships
  for each row execute function public.gymtavo_keine_mitglieder();

-- Der Katalog beschreibt Geraetetypen, keine Geraete an einem Ort. Ein
-- Geraet mit QR-Code im Gymtavo-Studio haette keinen Standort, und ein Scan
-- machte ueber join_studio_by_tag zum Mitglied -- genau das, was der Waechter
-- oben verbietet, nur auf einem zweiten Weg.
create or replace function public.gymtavo_ohne_geraete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.studio_id is not null and public.is_catalog_studio(new.studio_id) then
    raise exception 'gymtavo_ohne_geraete';
  end if;
  return new;
end;
$$;

revoke all on function public.gymtavo_ohne_geraete() from public, anon, authenticated;

create trigger machines_gymtavo_ohne_geraete
  before insert or update of studio_id on public.machines
  for each row execute function public.gymtavo_ohne_geraete();

create trigger machine_tags_gymtavo_ohne_geraete
  before insert or update of studio_id on public.machine_tags
  for each row execute function public.gymtavo_ohne_geraete();
