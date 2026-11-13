-- Training-Flows (Entwurf 2b, E6): Reihenfolge und Loeschen von Positionen einer
-- Einheit in einem Aufruf. Die Liste p_position_keys ist die neue Reihenfolge der
-- Einheit; Schluessel, die fehlen, sind entfernt (mindestens eine bleibt). Wie der
-- dauerhafte Tausch (swap_training_plan_position, 0070) legt die Funktion sofort eine
-- neue aktive Version an und setzt die alte auf 'ersetzt'. Die Positionen bleiben
-- unveraendert; die geschaetzte Dauer der Einheit rechnet die Domain (p_minuten).

create function public.order_training_plan_einheit(
  p_plan_id       uuid,
  p_einheit_key   text,
  p_position_keys text[],
  p_minuten       numeric
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

  if p_position_keys is null or coalesce(array_length(p_position_keys, 1), 0) = 0
     or p_minuten is null or p_minuten < 0 or p_minuten > 600 then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;
  -- Ein null-Eintrag im Array waere kein Schluessel der Einheit.
  if exists (select 1 from unnest(p_position_keys) k(key) where k.key is null)
     or (select count(distinct k.key) from unnest(p_position_keys) k(key)) <> array_length(p_position_keys, 1) then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  select e.value into v_einheit
    from jsonb_array_elements(v_plan.einheiten) e(value)
   where e.value ->> 'key' = p_einheit_key
   limit 1;
  if v_einheit is null then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  -- Jeder Schluessel muss in der Einheit stehen.
  if exists (
    select 1 from unnest(p_position_keys) k(key)
     where not exists (
       select 1 from jsonb_array_elements(v_einheit -> 'positionen') p(value)
        where p.value ->> 'key' = k.key)
  ) then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  v_neu := jsonb_set(
    jsonb_set(v_einheit, '{positionen}', (
      select jsonb_agg(p.value order by k.nr)
        from unnest(p_position_keys) with ordinality k(key, nr)
        join jsonb_array_elements(v_einheit -> 'positionen') p(value) on p.value ->> 'key' = k.key)),
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

revoke all on function public.order_training_plan_einheit(uuid, text, text[], numeric)
  from public, anon, authenticated, service_role;
grant execute on function public.order_training_plan_einheit(uuid, text, text[], numeric) to authenticated;
