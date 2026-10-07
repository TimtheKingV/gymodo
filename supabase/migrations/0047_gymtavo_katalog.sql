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

-- ---------------------------------------------------------------------
-- 2. Den Katalog liest jeder Angemeldete
-- ---------------------------------------------------------------------

-- Nur die Lesepolicies werden weiter. Geschrieben wird weiter mit
-- is_studio_staff -- fuer den Katalog heisst das: nur das Gymtavo-Team.

drop policy equipment_models_select on public.equipment_models;
create policy equipment_models_select on public.equipment_models
  for select to authenticated
  using (
    public.is_studio_member(equipment_models.studio_id)
    or public.is_catalog_studio(equipment_models.studio_id)
  );

drop policy equipment_setting_definitions_select on public.equipment_setting_definitions;
create policy equipment_setting_definitions_select on public.equipment_setting_definitions
  for select to authenticated
  using (
    exists (
      select 1 from public.equipment_models em
      where em.id = equipment_setting_definitions.equipment_model_id
        and (public.is_studio_member(em.studio_id) or public.is_catalog_studio(em.studio_id))
    )
  );

drop policy exercises_select on public.exercises;
create policy exercises_select on public.exercises
  for select to authenticated
  using (
    public.is_studio_member(exercises.studio_id)
    or public.is_catalog_studio(exercises.studio_id)
  );

drop policy instruction_assets_select on public.instruction_assets;
create policy instruction_assets_select on public.instruction_assets
  for select to authenticated
  using (
    exists (
      select 1
      from public.equipment_model_exercises eme
      join public.equipment_models em on em.id = eme.equipment_model_id
      where eme.id = instruction_assets.equipment_model_exercise_id
        and (public.is_studio_member(em.studio_id) or public.is_catalog_studio(em.studio_id))
    )
  );

-- Ohne diese Policy blieben die Videos trotz der Policy oben unsichtbar:
-- instruction_assets haengt an der Verknuepfung. Der Join auf dasselbe
-- Studio bleibt hier noch stehen; Abschnitt 3 lockert ihn fuer den Verweis.
drop policy equipment_model_exercises_select on public.equipment_model_exercises;
create policy equipment_model_exercises_select on public.equipment_model_exercises
  for select to authenticated
  using (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e on e.studio_id = em.studio_id
      where em.id = equipment_model_exercises.equipment_model_id
        and e.id = equipment_model_exercises.exercise_id
        and (public.is_studio_member(em.studio_id) or public.is_catalog_studio(em.studio_id))
    )
  );

-- Die Videos des Katalogs liegen unter dem Ordner des Gymtavo-Studios.
-- Ein Video, das ein Studio zu einer Gymtavo-Uebung ergaenzt, liegt dagegen
-- im Ordner des Studios und bleibt dessen Mitgliedern vorbehalten.
drop policy media_select on storage.objects;
create policy media_select on storage.objects
  for select to authenticated
  using (
    bucket_id in ('equipment-photos', 'instruction-videos')
    and (
      public.is_studio_member(public.storage_studio_id(name))
      or public.is_catalog_studio(public.storage_studio_id(name))
    )
  );

-- ---------------------------------------------------------------------
-- 3. Zuordnung zum Gymtavo-Typ und Verweis auf Gymtavo-Uebungen
-- ---------------------------------------------------------------------

-- Woher die App weiss, welche Gymtavo-Uebungen in einem Studio passen: das
-- Studio ordnet jedes seiner Modelle einem Gymtavo-Typ zu (Spec E1). Kein
-- Spalten-Grant noetig -- equipment_models hat keinen; die Grenze ist der
-- Trigger unten.
alter table public.equipment_models
  add column catalog_model_id uuid
    references public.equipment_models (id) on delete restrict;

create index on public.equipment_models (catalog_model_id);

-- SECURITY DEFINER, weil das Ziel in einem Studio liegen kann, das der
-- Aufrufer nicht lesen darf: die Antwort "ungueltig" soll fuer ein fremdes
-- Studio dieselbe sein wie fuer ein nicht existierendes Modell.
create or replace function public.equipment_models_zuordnung_pruefen()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.catalog_model_id is null then
    return new;
  end if;

  if public.is_catalog_studio(new.studio_id)
     or not exists (
       select 1 from public.equipment_models ziel
       where ziel.id = new.catalog_model_id
         and public.is_catalog_studio(ziel.studio_id)
     ) then
    raise exception 'gymtavo_zuordnung_ungueltig';
  end if;

  return new;
end;
$$;

revoke all on function public.equipment_models_zuordnung_pruefen() from public, anon, authenticated;

create trigger equipment_models_zuordnung_pruefen
  before insert or update of catalog_model_id, studio_id on public.equipment_models
  for each row execute function public.equipment_models_zuordnung_pruefen();

-- Verweis statt Kopie (Spec E2): ein Studio haengt Gymtavo-Uebungen direkt
-- an seine Modelle. Die Verknuepfung bleibt gueltig, wenn die Uebung im
-- Studio des Modells liegt ODER im Katalog -- nie in einem dritten Studio.
-- Ein Gymtavo-Modell bekommt damit nur Gymtavo-Uebungen: fuer es ist "im
-- Studio des Modells" und "im Katalog" dasselbe.
--
-- Videos, die ein Studio zu einer Gymtavo-Uebung ergaenzt, haengen an
-- dieser Studio-Verknuepfung und gehoeren damit dem Studio
-- (instruction_assets_* pruefen ueber em.studio_id).
drop policy equipment_model_exercises_select on public.equipment_model_exercises;
create policy equipment_model_exercises_select on public.equipment_model_exercises
  for select to authenticated
  using (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e
        on e.id = equipment_model_exercises.exercise_id
       and (e.studio_id = em.studio_id or public.is_catalog_studio(e.studio_id))
      where em.id = equipment_model_exercises.equipment_model_id
        and (public.is_studio_member(em.studio_id) or public.is_catalog_studio(em.studio_id))
    )
  );

drop policy equipment_model_exercises_insert on public.equipment_model_exercises;
create policy equipment_model_exercises_insert on public.equipment_model_exercises
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e
        on e.id = equipment_model_exercises.exercise_id
       and (e.studio_id = em.studio_id or public.is_catalog_studio(e.studio_id))
      where em.id = equipment_model_exercises.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  );

drop policy equipment_model_exercises_update on public.equipment_model_exercises;
create policy equipment_model_exercises_update on public.equipment_model_exercises
  for update to authenticated
  using (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e
        on e.id = equipment_model_exercises.exercise_id
       and (e.studio_id = em.studio_id or public.is_catalog_studio(e.studio_id))
      where em.id = equipment_model_exercises.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  )
  with check (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e
        on e.id = equipment_model_exercises.exercise_id
       and (e.studio_id = em.studio_id or public.is_catalog_studio(e.studio_id))
      where em.id = equipment_model_exercises.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  );

drop policy equipment_model_exercises_delete on public.equipment_model_exercises;
create policy equipment_model_exercises_delete on public.equipment_model_exercises
  for delete to authenticated
  using (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e
        on e.id = equipment_model_exercises.exercise_id
       and (e.studio_id = em.studio_id or public.is_catalog_studio(e.studio_id))
      where em.id = equipment_model_exercises.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  );
