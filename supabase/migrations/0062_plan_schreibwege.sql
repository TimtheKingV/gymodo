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

-- Dauerhafter Tausch einer Planposition (Etappe 3, Task 3; Entscheidung Tim
-- 24.10.: sofort eine neue aktive Version, ohne Bestaetigungsschritt).
-- Nur fuer den eigenen AKTIVEN Plan und nur fuer Studio-Mitglieder; fremd,
-- nicht aktiv und ausgetreten antworten gleich (plan_nicht_annehmbar), damit
-- die Antwort nichts verraet. Die Uebung muss denselben plan_baustein haben
-- wie die Position, Geraet und Uebung muessen training_plan_pruefen bestehen,
-- und kein plan_bereiche-Eintrag darf in training_limits.areas "meiden" sein.
-- Kopiert wird der ganze Plan; nur exerciseId, machineId und hauptmuskeln
-- (primaere Muskeln der neuen Uebung) der einen Position aendern sich.
-- Sperrreihenfolge wie create_training_plan: erst Advisory-Sperre je (Nutzer,
-- Studio), dann FOR UPDATE auf die Zeile -- sonst Deadlock-Gefahr gegen eine
-- gleichzeitige Erzeugung. Die studio_id fuer die Sperre kommt aus einer
-- ungesperrten Vorab-Abfrage; der Besitz wird danach unter Sperre geprueft.
create function public.swap_training_plan_position(
  p_plan_id      uuid,
  p_einheit_key  text,
  p_position_key text,
  p_exercise_id  uuid,
  p_machine_id   uuid
)
returns public.training_plans
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user      uuid := auth.uid();
  v_studio    uuid;
  v_plan      public.training_plans;
  v_pos       jsonb;
  v_baustein  text;
  v_bereiche  text[];
  v_muscles   jsonb;
  v_areas     jsonb;
  v_einheiten jsonb;
  v_version   int;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select studio_id into v_studio
    from public.training_plans
   where id = p_plan_id and user_id = v_user;
  if not found then
    raise exception 'plan_nicht_annehmbar' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('training_plans:' || v_user::text || ':' || v_studio::text, 0));

  select * into v_plan
    from public.training_plans
   where id = p_plan_id and user_id = v_user
     for update;

  if not found or v_plan.status <> 'aktiv' or not public.is_studio_member(v_plan.studio_id) then
    raise exception 'plan_nicht_annehmbar' using errcode = 'P0001';
  end if;

  select p.value into v_pos
    from jsonb_array_elements(v_plan.einheiten) e(value),
         jsonb_array_elements(e.value -> 'positionen') p(value)
   where e.value ->> 'key' = p_einheit_key
     and p.value ->> 'key' = p_position_key
   limit 1;
  if v_pos is null then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  select plan_baustein, plan_bereiche, muscles
    into v_baustein, v_bereiche, v_muscles
    from public.exercises
   where id = p_exercise_id;
  if not found or v_baustein is distinct from (v_pos ->> 'baustein') then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  -- Geraet aktiv im Studio und Uebung daran (auch fuer fremde Studios abgelehnt).
  perform public.training_plan_pruefen(
    v_plan.studio_id,
    jsonb_build_array(jsonb_build_object('positionen', jsonb_build_array(
      jsonb_build_object('machineId', p_machine_id, 'exerciseId', p_exercise_id)))));

  select areas into v_areas from public.training_limits where user_id = v_user;
  if v_areas is not null and exists (
    select 1 from unnest(v_bereiche) b(bereich) where v_areas ->> b.bereich = 'meiden'
  ) then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  -- Reihenfolge der Einheiten und Positionen bleibt durch with ordinality erhalten.
  select jsonb_agg(
           case when e.value ->> 'key' = p_einheit_key then
             jsonb_set(e.value, '{positionen}', (
               select jsonb_agg(
                        case when p.value ->> 'key' = p_position_key then
                          p.value || jsonb_build_object(
                            'exerciseId', p_exercise_id,
                            'machineId', p_machine_id,
                            'hauptmuskeln', coalesce((
                              select jsonb_agg(m.value ->> 'key' order by m.nr)
                                from jsonb_array_elements(v_muscles) with ordinality m(value, nr)
                               where m.value ->> 'role' = 'primary'), '[]'::jsonb))
                        else p.value end
                        order by p.nr)
                 from jsonb_array_elements(e.value -> 'positionen') with ordinality p(value, nr)))
           else e.value end
           order by e.nr)
    into v_einheiten
    from jsonb_array_elements(v_plan.einheiten) with ordinality e(value, nr);

  select coalesce(max(version), 0) + 1 into v_version
    from public.training_plans
   where user_id = v_user and studio_id = v_plan.studio_id;

  update public.training_plans set status = 'ersetzt' where id = v_plan.id;

  insert into public.training_plans
    (user_id, studio_id, version, status, regel_version, eingabe, struktur, einheiten, gruende, accepted_at)
  values
    (v_user, v_plan.studio_id, v_version, 'aktiv', v_plan.regel_version, v_plan.eingabe,
     v_plan.struktur, v_einheiten, v_plan.gruende, now())
  returning * into v_plan;

  return v_plan;
end;
$$;

revoke all on function public.swap_training_plan_position(uuid, text, text, uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.swap_training_plan_position(uuid, text, text, uuid, uuid) to authenticated;
