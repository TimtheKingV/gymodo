-- Der Trainingsplan gehoert dem Katalog-Studio (Trainingsplan aus dem
-- Katalog, Task 1; Spec 2026-10-27).
--
-- Bisher: ein Plan je (Mitglied, Studio), Positionen nennen machineId (ein
-- Geraet des Studios). Jetzt: ein Plan je Mitglied, Eigentuemer ist das
-- Katalog-Studio (studios.is_catalog, 0047). Positionen nennen exerciseId und
-- modelId (ein equipment_models-Eintrag des Katalog-Studios, der die Uebung
-- traegt). Welches Geraet im eigenen Studio dazu passt, loest die App beim
-- Training auf; der Plan kennt keine Geraete mehr.
--
-- * training_plan_pruefen: p_studio_id muss das Katalog-Studio sein; jede
--   Position nennt modelId (ein Katalogmodell) und exerciseId (am Modell ueber
--   equipment_model_exercises), und keine machineId mehr. Vergleich weiter als
--   Text (kaputter Wert -> plan_ungueltig, kein Cast-Fehler 22P02).
-- * create_training_plan / accept_training_plan: Katalog-Studio ohne
--   Mitgliedschaft (dem Katalog tritt man nicht bei, 0047); jedes andere
--   Studio ist plan_ungueltig bzw. nicht annehmbar.
-- * swap_training_plan_position: p_model_id statt p_machine_id. Die alte
--   Fassung entfaellt (andere Parameternamen, gleiche Typen: neu anlegen
--   braucht drop). Sonst wie 0065, die Position verliert ein altes machineId.
-- * record_session_plan, set_plan_gewichte, init_plan_gewichte: der Plan
--   gehoert dem Katalog, die Session kann in jedem Studio laufen -- die
--   Bedingung studio_id = Studio der Session wird zu is_catalog_studio().
-- * Bestehende Plaene normaler Studios werden 'verworfen'. plan_gewichte und
--   Sessions bleiben unberuehrt (kein Datenverlust, die Plaene lassen sich
--   nur nicht mehr annehmen oder tauschen).
--
-- Die Policies training_plans_insert_own/_update_own gibt es seit 0062 nicht
-- mehr: geschrieben wird nur ueber die Funktionen. Sie werden hier bewusst
-- nicht wieder angelegt (das oeffnete den direkten Schreibweg erneut).

create or replace function public.training_plan_pruefen(p_studio_id uuid, p_einheiten jsonb)
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
  if not public.is_catalog_studio(p_studio_id) then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;
  if p_einheiten is null or jsonb_typeof(p_einheiten) <> 'array' then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  for v_einheit in select value from jsonb_array_elements(p_einheiten) loop
    if jsonb_typeof(v_einheit) <> 'object'
       or jsonb_typeof(v_einheit -> 'positionen') is distinct from 'array' then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;

    for v_pos in select value from jsonb_array_elements(v_einheit -> 'positionen') loop
      if jsonb_typeof(v_pos) <> 'object'
         or v_pos ? 'machineId'
         or not exists (
           select 1
             from public.equipment_models em
             join public.equipment_model_exercises eme on eme.equipment_model_id = em.id
            where em.studio_id = p_studio_id
              and em.id::text = v_pos ->> 'modelId'
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

create or replace function public.create_training_plan(
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

  if not found or v_plan.status <> 'vorschlag' or not public.is_catalog_studio(v_plan.studio_id) then
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

drop function public.swap_training_plan_position(uuid, text, text, uuid, uuid, jsonb);

create function public.swap_training_plan_position(
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

create or replace function public.record_session_plan(
  p_session_id  uuid,
  p_plan_id     uuid,
  p_einheit_key text,
  p_stand       int,
  p_positionen  jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user    uuid := auth.uid();
  v_session public.workout_sessions;
  v_plan    public.training_plans;
  v_einheit jsonb;
  v_pos     jsonb;
  v_keys    text[];
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_stand is null or p_stand < 1
     or p_positionen is null or jsonb_typeof(p_positionen) <> 'array' then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  select * into v_session
    from public.workout_sessions
   where id = p_session_id and user_id = v_user
     for update;
  if not found then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  select * into v_plan
    from public.training_plans
   where id = p_plan_id
     and user_id = v_user
     and public.is_catalog_studio(studio_id)
     and status in ('aktiv', 'ersetzt');
  if not found then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  if v_session.plan_id is not null then
    if p_einheit_key is distinct from v_session.plan_einheit_key then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;
    if p_plan_id <> v_session.plan_id and v_plan.version <= (
      select version from public.training_plans where id = v_session.plan_id
    ) then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;
  end if;

  -- Monoton: eine aeltere oder gleiche Momentaufnahme aendert nichts.
  if p_stand <= v_session.plan_stand then
    return;
  end if;

  select e.value into v_einheit
    from jsonb_array_elements(v_plan.einheiten) e(value)
   where e.value ->> 'key' = p_einheit_key
   limit 1;
  if v_einheit is null then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  select array_agg(p.value ->> 'key') into v_keys
    from jsonb_array_elements(v_einheit -> 'positionen') p(value);

  for v_pos in select value from jsonb_array_elements(p_positionen) loop
    if jsonb_typeof(v_pos) <> 'object'
       or not ((v_pos ->> 'key') = any (coalesce(v_keys, '{}')))
       or (v_pos ->> 'status') is null
       or (v_pos ->> 'status') not in ('offen', 'erledigt', 'optional', 'getauscht') then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;
    -- Erst Form pruefen, dann casten: ein kaputter Wert soll plan_ungueltig
    -- ergeben, keinen Cast-Fehler (22P02). Kein Textvergleich wie in 0062,
    -- weil die iOS-App UUIDs in Grossbuchstaben kodiert.
    if jsonb_typeof(v_pos -> 'exerciseId') = 'string' then
      if (v_pos ->> 'exerciseId') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
         or not exists (select 1 from public.exercises where id = (v_pos ->> 'exerciseId')::uuid) then
        raise exception 'plan_ungueltig' using errcode = 'P0001';
      end if;
    elsif coalesce(jsonb_typeof(v_pos -> 'exerciseId'), 'null') <> 'null' then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    elsif (v_pos ->> 'status') = 'getauscht' then
      -- Ein Tausch ohne Ersatzuebung sagt nicht, was trainiert wurde.
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;
  end loop;

  if (select count(*) from jsonb_array_elements(p_positionen))
     <> (select count(distinct value ->> 'key') from jsonb_array_elements(p_positionen)) then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  -- Die erste Bindung bleibt (siehe 3.).
  update public.workout_sessions
     set plan_id          = coalesce(plan_id, p_plan_id),
         plan_einheit_key = coalesce(plan_einheit_key, p_einheit_key),
         plan_stand       = p_stand
   where id = p_session_id;

  delete from public.session_plan_status where session_id = p_session_id;

  insert into public.session_plan_status (session_id, position_key, user_id, status, exercise_id)
  select p_session_id,
         value ->> 'key',
         v_user,
         value ->> 'status',
         case when jsonb_typeof(value -> 'exerciseId') = 'string'
              then (value ->> 'exerciseId')::uuid end
    from jsonb_array_elements(p_positionen);
end;
$$;

revoke all on function public.record_session_plan(uuid, uuid, text, int, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.record_session_plan(uuid, uuid, text, int, jsonb) to authenticated;

create or replace function public.set_plan_gewichte(
  p_session_id uuid,
  p_plan_id    uuid,
  p_zeilen     jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user    uuid := auth.uid();
  v_session public.workout_sessions;
  v_plan    public.training_plans;
  v_stand   timestamptz;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select * into v_session
    from public.workout_sessions
   where id = p_session_id and user_id = v_user
     for update;
  if not found then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  select * into v_plan
    from public.training_plans
   where id = p_plan_id
     and user_id = v_user
     and public.is_catalog_studio(studio_id)
     and status in ('aktiv', 'ersetzt');
  if not found then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  if v_session.completed_at is not null then
    v_stand := v_session.completed_at;
  else
    select coalesce(max(performed_at), v_session.started_at) into v_stand
      from public.workout_sets
     where session_id = p_session_id;
    -- Die Sperre aus 1. haelt nur die Session; ein Satz ohne Eintrag zaehlt
    -- ueber started_at (siehe sessions.ts).
    if v_stand is null or v_stand > now() - interval '4 hours' then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;
  end if;
  -- completed_at darf das Mitglied selbst setzen (0047); ein Abschluss in der
  -- Zukunft wuerde jeden echten spaeteren Stand blockieren. Eine Minute
  -- Spielraum: completeSession setzt completed_at mit der Uhr des
  -- App-Servers, und die darf der Datenbank etwas vorauslaufen.
  if v_stand > now() + interval '1 minute' then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  perform public.plan_gewichte_zeilen_pruefen(v_plan, p_zeilen);

  insert into public.plan_gewichte as pg
    (plan_id, einheit_key, position_key, user_id, load, secondary_load, grund, algo_version,
     stand_session_id, stand_completed_at)
  select p_plan_id,
         z.value ->> 'einheitKey',
         z.value ->> 'positionKey',
         v_user,
         (z.value ->> 'load')::numeric,
         (z.value ->> 'secondaryLoad')::numeric,
         z.value ->> 'grund',
         z.value ->> 'algoVersion',
         p_session_id,
         v_stand
    from jsonb_array_elements(p_zeilen) z
  on conflict (plan_id, einheit_key, position_key) do update
     set load               = excluded.load,
         secondary_load     = excluded.secondary_load,
         grund              = excluded.grund,
         algo_version       = excluded.algo_version,
         stand_session_id   = excluded.stand_session_id,
         stand_completed_at = excluded.stand_completed_at
   where pg.stand_completed_at is null
      or excluded.stand_completed_at > pg.stand_completed_at;

  update public.workout_sessions
     set gewichte_berechnet_at = now()
   where id = p_session_id;
end;
$$;

revoke all on function public.set_plan_gewichte(uuid, uuid, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.set_plan_gewichte(uuid, uuid, jsonb) to authenticated;

create or replace function public.init_plan_gewichte(
  p_plan_id uuid,
  p_zeilen  jsonb
)
returns void
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
   where id = p_plan_id
     and user_id = v_user
     and public.is_catalog_studio(studio_id)
     and status in ('aktiv', 'ersetzt')
     for update;
  if not found then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  perform public.plan_gewichte_zeilen_pruefen(v_plan, p_zeilen);

  insert into public.plan_gewichte
    (plan_id, einheit_key, position_key, user_id, load, secondary_load, grund, algo_version)
  select p_plan_id,
         z.value ->> 'einheitKey',
         z.value ->> 'positionKey',
         v_user,
         (z.value ->> 'load')::numeric,
         (z.value ->> 'secondaryLoad')::numeric,
         z.value ->> 'grund',
         z.value ->> 'algoVersion'
    from jsonb_array_elements(p_zeilen) z
  on conflict (plan_id, einheit_key, position_key) do nothing;
end;
$$;

revoke all on function public.init_plan_gewichte(uuid, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.init_plan_gewichte(uuid, jsonb) to authenticated;

-- Plaene normaler Studios gelten nicht mehr. Nur Vorschlag und aktiv: ersetzt
-- und verworfen sind schon erledigt. plan_gewichte bleibt, die Zeilen haengen
-- an der Plan-id.
update public.training_plans
   set status = 'verworfen'
 where studio_id not in (select id from public.studios where is_catalog)
   and status in ('vorschlag', 'aktiv');
