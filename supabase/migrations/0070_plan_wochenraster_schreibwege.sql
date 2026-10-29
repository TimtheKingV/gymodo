-- Schreibwege tragen das Wochenraster (Spec Wochenplan-Tab, Task 3).
--
-- training_plans.wochenraster (0069) haelt das Raster fest, das der Generator beim
-- Erzeugen berechnet hat; Plaene sind stabil (F14), gelesen wird es nie neu gerechnet.
-- Mitglieder duerfen training_plans nicht direkt schreiben, deshalb muessen die
-- Funktionen es mitfuehren:
-- * create_training_plan: neuer letzter Parameter p_wochenraster mit Default '[]'; ein Aufruf
--   mit den sechs alten Argumenten funktioniert weiter, die Migration darf vor dem Deploy laufen.
-- * swap_training_plan_position: die neue aktive Version uebernimmt das Raster des
--   Vorgaengers, sonst Rest wie 0066.

drop function public.create_training_plan(uuid, text, jsonb, text, jsonb, text[]);

create function public.create_training_plan(
  p_studio_id     uuid,
  p_regel_version text,
  p_eingabe       jsonb,
  p_struktur      text,
  p_einheiten     jsonb,
  p_gruende       text[],
  p_wochenraster  jsonb default '[]'::jsonb
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
  if not public.is_catalog_studio(p_studio_id) then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
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
    (user_id, studio_id, version, status, regel_version, eingabe, struktur, einheiten, gruende, wochenraster)
  values
    (v_user, p_studio_id, v_version, 'vorschlag', p_regel_version, p_eingabe, p_struktur, p_einheiten, p_gruende,
     p_wochenraster)
  returning * into v_plan;

  return v_plan;
end;
$$;

revoke all on function public.create_training_plan(uuid, text, jsonb, text, jsonb, text[], jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.create_training_plan(uuid, text, jsonb, text, jsonb, text[], jsonb) to authenticated;

create or replace function public.swap_training_plan_position(
  p_plan_id      uuid,
  p_einheit_key  text,
  p_position_key text,
  p_exercise_id  uuid,
  p_model_id     uuid,
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

  if not found or v_plan.status <> 'aktiv' or not public.is_catalog_studio(v_plan.studio_id) then
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

  -- Katalogmodell und Uebung daran (Modelle normaler Studios abgelehnt).
  perform public.training_plan_pruefen(
    v_plan.studio_id,
    jsonb_build_array(jsonb_build_object('positionen', jsonb_build_array(
      jsonb_build_object('modelId', p_model_id, 'exerciseId', p_exercise_id)))));

  select areas into v_areas from public.training_limits where user_id = v_user;
  if v_areas is not null and exists (
    select 1 from unnest(v_bereiche) b(bereich) where v_areas ->> b.bereich = 'meiden'
  ) then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  v_patch := jsonb_build_object(
    'exerciseId', p_exercise_id,
    'modelId', p_model_id,
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
                        case when p.value ->> 'key' = p_position_key then (p.value - 'machineId') || v_patch
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
    (user_id, studio_id, version, status, regel_version, eingabe, struktur, einheiten, gruende, wochenraster, accepted_at)
  values
    (v_user, v_plan.studio_id, v_version, 'aktiv', v_plan.regel_version, v_plan.eingabe,
     v_plan.struktur, v_einheiten, v_plan.gruende, v_plan.wochenraster, now())
  returning * into v_plan;

  return v_plan;
end;
$$;

revoke all on function public.swap_training_plan_position(uuid, text, text, uuid, uuid, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.swap_training_plan_position(uuid, text, text, uuid, uuid, jsonb) to authenticated;
