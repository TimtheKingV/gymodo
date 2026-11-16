-- Einheit bearbeiten (P4, Testnotiz 10.11. #10): eine Einheit wird als Ganzes ersetzt
-- (Reihenfolge, Entfernen, Hinzufuegen, Tauschen, Werte) und als neue aktive Version
-- gespeichert. Wie order_training_plan_einheit (0073) und swap_training_plan_position (0070)
-- sperrt die Funktion je Nutzer und Studio, legt Version +1 an und setzt die alte auf
-- 'ersetzt'. Die Domain (baueEinheit) liefert vollstaendige Positionen; hier wird alles
-- noch einmal geprueft, weil der Client nie vertrauenswuerdig ist: Grenzen, Planmerkmale
-- der Uebung, Katalogmodell und gemiedene Bereiche. hauptmuskeln kommen immer aus
-- exercises.muscles (primaer), nie vom Client.

create function public.replace_training_plan_einheit(
  p_plan_id     uuid,
  p_einheit_key text,
  p_positionen  jsonb,
  p_minuten     numeric
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
  v_einheit   jsonb;
  v_neu       jsonb;
  v_einheiten jsonb;
  v_version   int;
  v_pos       jsonb;
  v_nr        int := 0;
  v_neue      jsonb := '[]'::jsonb;
  v_keys      text[] := '{}';
  v_ex_ids    uuid[] := '{}';
  v_ex        uuid;
  v_baustein  text;
  v_typ       text;
  v_bereiche  text[];
  v_muscles   jsonb;
  v_areas     jsonb;
  v_cardio    boolean;
  v_feld      text;
  v_saetze    numeric;
  v_wdh_von   numeric;
  v_wdh_bis   numeric;
  v_res_von   numeric;
  v_res_bis   numeric;
  v_pause     numeric;
  v_dauer     numeric;
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

  if p_positionen is null or jsonb_typeof(p_positionen) <> 'array'
     or jsonb_array_length(p_positionen) not between 1 and 20
     or p_minuten is null or p_minuten < 0 or p_minuten > 600 then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  select e.value into v_einheit
    from jsonb_array_elements(v_plan.einheiten) e(value)
   where e.value ->> 'key' = p_einheit_key
   limit 1;
  if v_einheit is null then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  select areas into v_areas from public.training_limits where user_id = v_user;

  for v_pos in select value from jsonb_array_elements(p_positionen) loop
    v_nr := v_nr + 1;

    if jsonb_typeof(v_pos) <> 'object' then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;
    -- Pflichtfelder: Texte, UUIDs und Aufwaermsatz; null im JSON zaehlt als fehlend.
    foreach v_feld in array array['key', 'baustein', 'rolle', 'exerciseId', 'modelId', 'typ'] loop
      if jsonb_typeof(v_pos -> v_feld) is distinct from 'string' or length(v_pos ->> v_feld) = 0 then
        raise exception 'plan_ungueltig' using errcode = 'P0001';
      end if;
    end loop;
    if jsonb_typeof(v_pos -> 'aufwaermsatz') is distinct from 'boolean'
       or v_pos ? 'machineId'
       or (v_pos ->> 'exerciseId') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or (v_pos ->> 'modelId') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;
    v_cardio := v_pos ->> 'baustein' = 'cardio';

    -- Zahlen: Typ pruefen, bevor gerechnet wird (kaputter Wert -> plan_ungueltig, kein Cast-Fehler).
    foreach v_feld in array array['saetze', 'pauseSek'] loop
      if jsonb_typeof(v_pos -> v_feld) is distinct from 'number'
         or (v_pos ->> v_feld)::numeric <> trunc((v_pos ->> v_feld)::numeric) then
        raise exception 'plan_ungueltig' using errcode = 'P0001';
      end if;
    end loop;
    v_saetze := (v_pos ->> 'saetze')::numeric;
    v_pause := (v_pos ->> 'pauseSek')::numeric;
    if v_saetze not between 1 and 10 or v_pause not between 0 and 600 then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;

    if v_cardio then
      if v_saetze <> 1 or v_pause <> 0
         or v_pos -> 'aufwaermsatz' <> 'false'::jsonb
         or jsonb_typeof(v_pos -> 'wdhVon') is distinct from 'null'
         or jsonb_typeof(v_pos -> 'wdhBis') is distinct from 'null'
         or jsonb_typeof(v_pos -> 'dauerMin') is distinct from 'number'
         or (v_pos ->> 'dauerMin')::numeric <> trunc((v_pos ->> 'dauerMin')::numeric)
         or (v_pos ->> 'dauerMin')::numeric not between 5 and 120 then
        raise exception 'plan_ungueltig' using errcode = 'P0001';
      end if;
      v_dauer := (v_pos ->> 'dauerMin')::numeric;
    end if;

    -- Reserve gilt auch fuer Cardio (der Generator schreibt sie, iOS dekodiert sie als Int).
    foreach v_feld in array array['reserveVon', 'reserveBis'] loop
      if jsonb_typeof(v_pos -> v_feld) is distinct from 'number'
         or (v_pos ->> v_feld)::numeric <> trunc((v_pos ->> v_feld)::numeric) then
        raise exception 'plan_ungueltig' using errcode = 'P0001';
      end if;
    end loop;
    v_res_von := (v_pos ->> 'reserveVon')::numeric;
    v_res_bis := (v_pos ->> 'reserveBis')::numeric;
    if not (v_res_von between 0 and v_res_bis and v_res_bis <= 10) then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;

    if not v_cardio then
      foreach v_feld in array array['wdhVon', 'wdhBis'] loop
        if jsonb_typeof(v_pos -> v_feld) is distinct from 'number'
           or (v_pos ->> v_feld)::numeric <> trunc((v_pos ->> v_feld)::numeric) then
          raise exception 'plan_ungueltig' using errcode = 'P0001';
        end if;
      end loop;
      v_wdh_von := (v_pos ->> 'wdhVon')::numeric;
      v_wdh_bis := (v_pos ->> 'wdhBis')::numeric;
      if not (v_wdh_von between 1 and 50 and v_wdh_bis between v_wdh_von and 50)
         or coalesce(jsonb_typeof(v_pos -> 'dauerMin'), 'null') <> 'null' then
        raise exception 'plan_ungueltig' using errcode = 'P0001';
      end if;
    end if;

    -- Schluessel und Uebungen je Einheit eindeutig.
    v_ex := (v_pos ->> 'exerciseId')::uuid;
    if (v_pos ->> 'key') = any (v_keys) or v_ex = any (v_ex_ids) then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;
    v_keys := v_keys || (v_pos ->> 'key');
    v_ex_ids := v_ex_ids || v_ex;

    -- Planmerkmale der Uebung aus dem Katalog; was der Client liefert, muss dazu passen.
    select plan_baustein, plan_typ, plan_bereiche, muscles
      into v_baustein, v_typ, v_bereiche, v_muscles
      from public.exercises
     where id = v_ex;
    if not found then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;
    if v_baustein is null or v_typ is null then
      raise exception 'uebung_ohne_planmerkmale' using errcode = 'P0001';
    end if;
    if v_baustein <> (v_pos ->> 'baustein') or v_typ <> (v_pos ->> 'typ') then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;

    -- Katalogmodell und Uebung daran (Modelle normaler Studios abgelehnt).
    -- Eigener Fehlercode, damit der Client "Gibt es an diesem Geraet nicht" zeigen kann.
    begin
      perform public.training_plan_pruefen(
        v_plan.studio_id,
        jsonb_build_array(jsonb_build_object('positionen', jsonb_build_array(
          jsonb_build_object('modelId', v_pos ->> 'modelId', 'exerciseId', v_pos ->> 'exerciseId')))));
    exception when raise_exception then
      raise exception 'modell_ungueltig' using errcode = 'P0001';
    end;

    -- Gemieden wird nur geprueft, was neu ist oder eine andere Uebung als vorher hat:
    -- eine spaeter gesetzte Beschwerde sperrt sonst jede Aenderung der Einheit.
    if v_areas is not null
       and not exists (
         select 1 from jsonb_array_elements(v_einheit -> 'positionen') o(value)
          where o.value ->> 'key' = v_pos ->> 'key'
            and o.value ->> 'exerciseId' = v_pos ->> 'exerciseId')
       and exists (
      select 1 from unnest(coalesce(v_bereiche, '{}')) b(bereich) where v_areas ->> b.bereich = 'meiden'
    ) then
      raise exception 'uebung_gemieden' using errcode = 'P0001';
    end if;

    -- Nur geprueft uebernommene Felder; hauptmuskeln immer aus der Uebung.
    v_neue := v_neue || jsonb_build_array(jsonb_build_object(
      'key', v_pos -> 'key',
      'baustein', v_pos -> 'baustein',
      'rolle', v_pos -> 'rolle',
      'exerciseId', v_pos -> 'exerciseId',
      'modelId', v_pos -> 'modelId',
      'typ', v_pos -> 'typ',
      'saetze', v_saetze::int,
      'wdhVon', case when v_cardio then null else v_wdh_von::int end,
      'wdhBis', case when v_cardio then null else v_wdh_bis::int end,
      'reserveVon', v_res_von::int,
      'reserveBis', v_res_bis::int,
      'pauseSek', v_pause::int,
      'aufwaermsatz', v_pos -> 'aufwaermsatz',
      'dauerMin', case when v_cardio then v_dauer::int else null end,
      'hauptmuskeln', coalesce((
        select jsonb_agg(m.value ->> 'key' order by m.nr)
          from jsonb_array_elements(coalesce(v_muscles, '[]'::jsonb)) with ordinality m(value, nr)
         where m.value ->> 'role' = 'primary'), '[]'::jsonb)));
  end loop;

  v_neu := jsonb_set(
    jsonb_set(v_einheit, '{positionen}', v_neue),
    '{geschaetzteMinuten}', to_jsonb(p_minuten));

  -- Die anderen Einheiten behalten ihre Reihenfolge (with ordinality).
  select jsonb_agg(
           case when e.value ->> 'key' = p_einheit_key then v_neu else e.value end
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

revoke all on function public.replace_training_plan_einheit(uuid, text, jsonb, numeric)
  from public, anon, authenticated, service_role;
grant execute on function public.replace_training_plan_einheit(uuid, text, jsonb, numeric) to authenticated;
