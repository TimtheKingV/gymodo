-- Tausch ueber die Typgrenze (Trainingsplan Etappe 4, Task 7; Uebergabe
-- Etappe 3, Punkt 2; Spec 2026-10-25 G20).
--
-- swap_training_plan_position (0062) kopierte typ, Wiederholungsbereich,
-- Reserve, Pause und Aufwaermsatz der ALTEN Position: wer eine
-- Mehrgelenkuebung gegen eine Isolationsuebung tauschte, trainierte sie mit
-- der Mehrgelenk-Vorgabe (8-12 Wdh., 150 s Pause, Aufwaermsatz) -- und die
-- Zielgewichte rechneten gegen diesen falschen Bereich.
--
-- Die Werte je Typ entstehen weiter nur in der Fachschicht (zielprofil und
-- pauseSekunden, ueber tauschVorgaben): sie gibt sie fuer BEIDE Typen in
-- p_vorgaben mit, {"mehrgelenk": {...}, "isolation": {...}}. Die Funktion
-- waehlt den Eintrag nach exercises.plan_typ der neuen Uebung -- den Typ
-- bestimmt also der Katalog, nicht der Aufrufer -- und prueft ihn auf
-- vernuenftige Werte (ganze Zahlen, 1 <= wdhVon <= wdhBis <= 50,
-- 0 <= reserveVon <= reserveBis <= 10, 0 <= pauseSek <= 600, aufwaermsatz
-- boolean, typ passend zum Schluessel). Ein Mitglied, das die Funktion
-- direkt aufruft, kann so keine unsinnigen Werte in seinen Plan schreiben;
-- die Regeln selbst stehen nicht ein zweites Mal in SQL.
--
-- Cardio laeuft ueber dauerMin, nicht ueber Saetze: eine Cardioposition
-- behaelt ihre Werte (wie der Generator: typ isolation, keine Wdh., Pause 0).
--
-- Die alte Signatur ohne p_vorgaben entfaellt, damit kein Weg mehr die Werte
-- der alten Position uebernimmt. Sonst unveraendert gegenueber 0062: Sperren,
-- Pruefungen, Fehlercodes, neue aktive Version.
--
-- Schluessel der Position bleiben gleich: plan_gewichte (0064) haengt an
-- (plan_id, einheit_key, position_key); die getauschte Position bekommt in der
-- Fachschicht Startwert bzw. Uebertragung (G9), nicht das alte Ziel.

drop function public.swap_training_plan_position(uuid, text, text, uuid, uuid);

create function public.swap_training_plan_position(
  p_plan_id      uuid,
  p_einheit_key  text,
  p_position_key text,
  p_exercise_id  uuid,
  p_machine_id   uuid,
  p_vorgaben     jsonb
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
  v_typ       text;
  v_bereiche  text[];
  v_muscles   jsonb;
  v_areas     jsonb;
  v_v         jsonb;
  v_feld      text;
  v_patch     jsonb;
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

  select plan_baustein, plan_typ, plan_bereiche, muscles
    into v_baustein, v_typ, v_bereiche, v_muscles
    from public.exercises
   where id = p_exercise_id;
  if not found or v_baustein is distinct from (v_pos ->> 'baustein') or v_typ is null then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  -- Vorgaben des Typs der neuen Uebung. Erst die JSON-Typen pruefen, dann
  -- rechnen: ein kaputter Wert soll plan_ungueltig ergeben, keinen Cast-Fehler.
  v_v := case when jsonb_typeof(p_vorgaben) = 'object' then p_vorgaben -> v_typ end;
  if v_v is null or jsonb_typeof(v_v) <> 'object'
     or v_v ->> 'typ' is distinct from v_typ
     or jsonb_typeof(v_v -> 'aufwaermsatz') is distinct from 'boolean' then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;
  foreach v_feld in array array['wdhVon', 'wdhBis', 'reserveVon', 'reserveBis', 'pauseSek'] loop
    if jsonb_typeof(v_v -> v_feld) is distinct from 'number'
       or (v_v ->> v_feld)::numeric <> trunc((v_v ->> v_feld)::numeric) then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;
  end loop;
  if not ((v_v ->> 'wdhVon')::numeric between 1 and (v_v ->> 'wdhBis')::numeric
          and (v_v ->> 'wdhBis')::numeric <= 50
          and (v_v ->> 'reserveVon')::numeric between 0 and (v_v ->> 'reserveBis')::numeric
          and (v_v ->> 'reserveBis')::numeric <= 10
          and (v_v ->> 'pauseSek')::numeric between 0 and 600) then
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

  v_patch := jsonb_build_object(
    'exerciseId', p_exercise_id,
    'machineId', p_machine_id,
    'hauptmuskeln', coalesce((
      select jsonb_agg(m.value ->> 'key' order by m.nr)
        from jsonb_array_elements(v_muscles) with ordinality m(value, nr)
       where m.value ->> 'role' = 'primary'), '[]'::jsonb));
  if v_pos ->> 'baustein' <> 'cardio' then
    v_patch := v_patch || jsonb_build_object(
      'typ', v_typ,
      'wdhVon', (v_v ->> 'wdhVon')::int,
      'wdhBis', (v_v ->> 'wdhBis')::int,
      'reserveVon', (v_v ->> 'reserveVon')::int,
      'reserveBis', (v_v ->> 'reserveBis')::int,
      'pauseSek', (v_v ->> 'pauseSek')::int,
      'aufwaermsatz', (v_v -> 'aufwaermsatz'));
  end if;

  -- Reihenfolge der Einheiten und Positionen bleibt durch with ordinality erhalten.
  select jsonb_agg(
           case when e.value ->> 'key' = p_einheit_key then
             jsonb_set(e.value, '{positionen}', (
               select jsonb_agg(
                        case when p.value ->> 'key' = p_position_key then p.value || v_patch
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

revoke all on function public.swap_training_plan_position(uuid, text, text, uuid, uuid, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.swap_training_plan_position(uuid, text, text, uuid, uuid, jsonb) to authenticated;
