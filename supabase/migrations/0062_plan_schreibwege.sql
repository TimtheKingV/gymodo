-- Plaene werden nur ueber gepruefte Funktionen geschrieben (Trainingsplan
-- Etappe 3, Task 2; Entscheidung Tim 24.10.).
--
-- Bis 0061 durfte das Mitglied training_plans per PostgREST direkt einfuegen
-- und aendern (Policies insert_own/update_own). Damit liessen sich beliebige
-- exerciseId/machineId in einheiten speichern -- etwa Geraete eines fremden
-- Studios (Uebergabe Etappe 3, Punkt 2). Ein Spaltenschutz (Update nur auf
-- status/accepted_at per Spalten-Grant) haette die Positionen beim Insert
-- trotzdem ungeprueft gelassen und braeche die Konvention "keine
-- Tabellen-Grants". Deshalb entfallen beide Policies; geschrieben wird nur
-- noch ueber SECURITY DEFINER-Funktionen, die als Eigentuemer an RLS vorbei
-- schreiben und vorher selbst pruefen:
--
-- * create_training_plan: Mitgliedschaft, jede Position gegen die aktiven
--   Geraete des Studios (training_plan_pruefen), dann alten Vorschlag
--   verwerfen, Version vergeben, einfuegen -- in einer Transaktion und je
--   (Mitglied, Studio) serialisiert (Punkt 5: vorher drei Einzelschritte aus
--   der Fachschicht).
-- * accept_training_plan: wie in 0061, jetzt SECURITY DEFINER (es gibt keine
--   Update-Policy mehr) und nur bei bestehender Mitgliedschaft (Punkt 4).
-- * Trigger nach dem Loeschen von training_limits: bereinigt die Plaene in
--   ALLEN Studios, auch in verlassenen (Punkt 3: die Update-Policy liess dort
--   nichts zu). Laeuft in derselben Transaktion wie der Widerruf.
--
-- Lesen bleibt bei training_plans_select_own.

drop policy training_plans_insert_own on public.training_plans;
drop policy training_plans_update_own on public.training_plans;

-- Jede Position muss ein aktives Geraet des Studios nennen und eine Uebung,
-- die an dessen Modell haengt -- direkt oder ueber den Gymtavo-Typ
-- (catalog_model_id). Das ist genau der Weg von ladeKandidaten, auch fuer
-- Cardio; jeder Plan des Generators besteht also. Vergleich als Text statt
-- Cast nach uuid: ein kaputter Wert soll plan_ungueltig ergeben, keinen
-- Cast-Fehler (22P02), den die Fachschicht nicht zuordnen kann.
-- Nicht an authenticated freigegeben: aufgerufen fuer ein beliebiges Studio
-- verriete sie, welche Geraete und Uebungen es dort gibt.
create function public.training_plan_pruefen(p_studio_id uuid, p_einheiten jsonb)
returns void
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_einheit jsonb;
  v_pos     jsonb;
begin
  if p_einheiten is null or jsonb_typeof(p_einheiten) <> 'array' then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  for v_einheit in select value from jsonb_array_elements(p_einheiten) loop
    if jsonb_typeof(v_einheit) <> 'object'
       or jsonb_typeof(v_einheit -> 'positionen') is distinct from 'array' then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;

    for v_pos in select value from jsonb_array_elements(v_einheit -> 'positionen') loop
      if jsonb_typeof(v_pos) <> 'object' or not exists (
        select 1
          from public.machines m
          join public.equipment_models em on em.id = m.equipment_model_id
          join public.equipment_model_exercises eme
            on eme.equipment_model_id = em.id
            or eme.equipment_model_id = em.catalog_model_id
         where m.studio_id = p_studio_id
           and m.status = 'active'
           and m.id::text = v_pos ->> 'machineId'
           and eme.exercise_id::text = v_pos ->> 'exerciseId'
      ) then
        raise exception 'plan_ungueltig' using errcode = 'P0001';
      end if;
    end loop;
  end loop;
end;
$$;

revoke all on function public.training_plan_pruefen(uuid, jsonb)
  from public, anon, authenticated, service_role;

-- Der Nutzer kommt nur aus auth.uid(), nie aus einem Parameter: niemand legt
-- Plaene fuer andere an. Die Advisory-Sperre je (Mitglied, Studio)
-- serialisiert gleichzeitige Erzeugungen; ohne sie saehen beide denselben
-- alten Vorschlag und dieselbe Hoechstversion, und eine scheiterte am
-- Teilindex training_plans_one_vorschlag. Geprueft wird vor dem Verwerfen,
-- damit ein ungueltiger Plan den alten Vorschlag stehen laesst.
create function public.create_training_plan(
  p_studio_id     uuid,
  p_regel_version text,
  p_eingabe       jsonb,
  p_struktur      text,
  p_einheiten     jsonb,
  p_gruende       text[]
)
returns public.training_plans
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user    uuid := auth.uid();
  v_version int;
  v_plan    public.training_plans;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.is_studio_member(p_studio_id) then
    raise exception 'kein_mitglied' using errcode = '42501';
  end if;

  perform public.training_plan_pruefen(p_studio_id, p_einheiten);

  perform pg_advisory_xact_lock(hashtextextended('training_plans:' || v_user::text || ':' || p_studio_id::text, 0));

  update public.training_plans
     set status = 'verworfen'
   where user_id = v_user and studio_id = p_studio_id and status = 'vorschlag';

  select coalesce(max(version), 0) + 1 into v_version
    from public.training_plans
   where user_id = v_user and studio_id = p_studio_id;

  insert into public.training_plans
    (user_id, studio_id, version, status, regel_version, eingabe, struktur, einheiten, gruende)
  values
    (v_user, p_studio_id, v_version, 'vorschlag', p_regel_version, p_eingabe, p_struktur, p_einheiten, p_gruende)
  returning * into v_plan;

  return v_plan;
end;
$$;

revoke all on function public.create_training_plan(uuid, text, jsonb, text, jsonb, text[])
  from public, anon, authenticated, service_role;
grant execute on function public.create_training_plan(uuid, text, jsonb, text, jsonb, text[]) to authenticated;

-- Wie 0061, aber SECURITY DEFINER (ohne Update-Policy schriebe die
-- Invoker-Fassung nichts) und nur fuer Mitglieder des Plan-Studios: wer
-- ausgetreten ist, nimmt keinen alten Vorschlag mehr an. Gleicher Fehler wie
-- fuer fremde oder verworfene Plaene, damit die Antwort nichts verraet.
-- FOR UPDATE serialisiert gleichzeitige Annahmen wie bisher.
create or replace function public.accept_training_plan(p_plan_id uuid)
returns public.training_plans
language plpgsql
security definer
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

  if not found or v_plan.status <> 'vorschlag' or not public.is_studio_member(v_plan.studio_id) then
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

revoke all on function public.accept_training_plan(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.accept_training_plan(uuid) to authenticated;

-- Widerruf der Beschwerden (DSGVO Art. 9): nach dem Loeschen von
-- training_limits darf keine Planzeile mehr verraten, dass es Beschwerden
-- gab -- weder das Flag noch die Gruende beschwerden_*. Alle Plaene des
-- Nutzers, unabhaengig von der Mitgliedschaft, darum SECURITY DEFINER. Die
-- Uebungen bleiben (F14: Plaene sind stabil). with ordinality haelt die
-- Reihenfolge der uebrigen Gruende.
create function public.training_limits_widerruf_bereinigen()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.training_plans p
     set eingabe = jsonb_set(p.eingabe, '{beschwerdenBeruecksichtigt}', 'false'::jsonb),
         gruende = array(
           select g.wert
             from unnest(p.gruende) with ordinality as g(wert, nr)
            where g.wert not like 'beschwerden\_%'
            order by g.nr)
   where p.user_id = old.user_id
     and (p.eingabe -> 'beschwerdenBeruecksichtigt' is distinct from 'false'::jsonb
          or exists (select 1 from unnest(p.gruende) as g(wert) where g.wert like 'beschwerden\_%'));
  return null;
end;
$$;

revoke all on function public.training_limits_widerruf_bereinigen()
  from public, anon, authenticated, service_role;

create trigger training_limits_widerruf
  after delete on public.training_limits
  for each row execute function public.training_limits_widerruf_bereinigen();
