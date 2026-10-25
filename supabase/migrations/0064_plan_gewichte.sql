-- Zielgewichte je Planposition (Trainingsplan Etappe 4, Task 3).
--
-- Die Plan*struktur* (training_plans, 0061/0062) bleibt unveraendert und
-- versioniert; die Zielgewichte liegen als eigene Schicht darueber und
-- aendern sich nach jeder abgeschlossenen Einheit, ohne neue Planversion
-- (Spec G1).
--
-- * plan_gewichte: eine Zeile je (Plan-Version, Positionsschluessel). Nur
--   lesbar fuer das Mitglied selbst (force row level security, keine
--   Insert-/Update-/Delete-Policy). Geschrieben wird ausschliesslich ueber
--   set_plan_gewichte und init_plan_gewichte (SECURITY DEFINER, G10).
-- * Stand (G14): der Abschluss der Einheit, nicht das Gewicht.
--   stand_completed_at ist der Abschlusszeitpunkt der Session, die die Zeile
--   zuletzt geschrieben hat; stand_session_id nennt sie. Ein NEUERER
--   Abschluss ueberschreibt auch bei sinkendem Gewicht, ein aelterer, der
--   verspaetet eintrifft, und dieselbe Session erneut aendern nichts
--   ("nur hoeherer Stand gewinnt", wie plan_stand in 0063). Initialzeilen
--   (init_plan_gewichte) haben beides null und weichen jedem Abschluss.
-- * "Session abgeschlossen" und stand_completed_at spiegeln die Regel des
--   Servers (packages/domain sessions.ts, IDLE_HOURS_UNTIL_AUTO_COMPLETE = 4):
--     1. completed_at gesetzt (manuell beendet oder bereits automatisch
--        abgeschlossen)  ->  stand_completed_at = completed_at;
--     2. sonst gilt die Session als automatisch abgeschlossen, wenn die
--        letzte Aktivitaet (letzter Satz performed_at, ohne Saetze
--        started_at) laenger als 4 Stunden zurueckliegt  ->
--        stand_completed_at = diese letzte Aktivitaet. Das ist derselbe
--        Wert, den der Server beim spaeteren Schreiben des Autoabschlusses
--        als completed_at einsetzt; der Stand aendert sich dadurch nicht.
--     3. sonst: plan_ungueltig (Einheit laeuft noch).
-- * workout_sessions.gewichte_berechnet_at: setzt nur set_plan_gewichte
--   (Marke "Zielgewichte dieser Einheit sind berechnet"). Ein Trigger wie in
--   0063 verhindert, dass das Mitglied sie ueber die Update-Policy (0047)
--   direkt setzt.
--
-- zeilen-Format (jsonb-Array): { positionKey, load, secondaryLoad|null,
-- grund|null, algoVersion }.

alter table public.workout_sessions
  add column gewichte_berechnet_at timestamptz;

comment on column public.workout_sessions.gewichte_berechnet_at is
  'Zeitpunkt, zu dem die Zielgewichte nach dieser Einheit berechnet wurden; nur set_plan_gewichte setzt sie.';

create table public.plan_gewichte (
  plan_id              uuid not null references public.training_plans (id) on delete cascade,
  position_key         text not null,
  user_id              uuid not null references auth.users (id) on delete cascade,
  load                 numeric not null check (load >= 0),
  secondary_load       numeric check (secondary_load is null or secondary_load >= 0),
  grund                text,
  algo_version         text not null check (algo_version <> ''),
  -- Loescht das Mitglied die Einheit (0044), bleibt das Gewicht; der Stand
  -- (stand_completed_at) bleibt ebenfalls, damit keine aeltere Einheit ihn
  -- unterlaufen kann.
  stand_session_id     uuid references public.workout_sessions (id) on delete set null,
  stand_completed_at   timestamptz,
  primary key (plan_id, position_key)
);

create index on public.plan_gewichte (user_id);

alter table public.plan_gewichte enable row level security;
alter table public.plan_gewichte force  row level security;

create policy plan_gewichte_select_own on public.plan_gewichte
  for select to authenticated
  using (user_id = (select auth.uid()));

-- gewichte_berechnet_at schreibt nur set_plan_gewichte (laeuft als
-- Eigentuemer, dort ist current_user nicht authenticated).
create function public.workout_sessions_gewichte_schuetzen()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if current_user in ('authenticated', 'anon') then
    if tg_op = 'INSERT' then
      if new.gewichte_berechnet_at is not null then
        raise exception 'gewichte_nur_ueber_funktion' using errcode = '42501';
      end if;
    elsif new.gewichte_berechnet_at is distinct from old.gewichte_berechnet_at then
      raise exception 'gewichte_nur_ueber_funktion' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.workout_sessions_gewichte_schuetzen()
  from public, anon, authenticated, service_role;

create trigger workout_sessions_gewichte_schuetzen
  before insert or update on public.workout_sessions
  for each row execute function public.workout_sessions_gewichte_schuetzen();

-- Prueft p_zeilen gegen die Positionen des Plans und liefert sie normalisiert.
-- Alles vor dem Schreiben, damit nichts halb uebernommen wird. Kaputte Werte
-- ergeben plan_ungueltig, keinen Cast-Fehler.
create function public.plan_gewichte_zeilen_pruefen(p_plan public.training_plans, p_zeilen jsonb)
returns void
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_keys text[];
  v_z    jsonb;
begin
  if p_zeilen is null or jsonb_typeof(p_zeilen) <> 'array' then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  select array_agg(p.value ->> 'key') into v_keys
    from jsonb_array_elements(p_plan.einheiten) e(value),
         jsonb_array_elements(e.value -> 'positionen') p(value);

  for v_z in select value from jsonb_array_elements(p_zeilen) loop
    if jsonb_typeof(v_z) <> 'object'
       or jsonb_typeof(v_z -> 'positionKey') <> 'string'
       or not ((v_z ->> 'positionKey') = any (coalesce(v_keys, '{}')))
       or jsonb_typeof(v_z -> 'load') <> 'number'
       or (v_z ->> 'load')::numeric < 0
       or coalesce(jsonb_typeof(v_z -> 'secondaryLoad'), 'null') not in ('number', 'null')
       or (jsonb_typeof(v_z -> 'secondaryLoad') = 'number' and (v_z ->> 'secondaryLoad')::numeric < 0)
       or coalesce(jsonb_typeof(v_z -> 'grund'), 'null') not in ('string', 'null')
       or jsonb_typeof(v_z -> 'algoVersion') <> 'string'
       or (v_z ->> 'algoVersion') = '' then
      raise exception 'plan_ungueltig' using errcode = 'P0001';
    end if;
  end loop;

  if (select count(*) from jsonb_array_elements(p_zeilen))
     <> (select count(distinct value ->> 'positionKey') from jsonb_array_elements(p_zeilen)) then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;
end;
$$;

revoke all on function public.plan_gewichte_zeilen_pruefen(public.training_plans, jsonb)
  from public, anon, authenticated, service_role;

-- Schreibt die Zielgewichte nach einer abgeschlossenen Einheit.
--
-- Der Nutzer kommt nur aus auth.uid(). Fremd und unbekannt antworten gleich
-- (plan_ungueltig). Reihenfolge:
--
-- 1. Session des Aufrufers, FOR UPDATE: serialisiert gleichzeitige Aufrufe
--    derselben Session.
-- 2. Plan des Aufrufers im Studio DER SESSION, aktiv oder ersetzt (wie 0063).
-- 3. Session abgeschlossen (siehe Kopf) -> v_stand.
-- 4. Zeilen pruefen (Schluessel gehoeren zum Plan, Werte gueltig).
-- 5. Upsert; bestehende Zeilen aendern sich nur bei NEUEREM Stand. Das WHERE
--    am ON CONFLICT ist atomar, auch gegen Aufrufe anderer Sessions.
create function public.set_plan_gewichte(
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
     and studio_id = v_session.studio_id
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

  perform public.plan_gewichte_zeilen_pruefen(v_plan, p_zeilen);

  insert into public.plan_gewichte as pg
    (plan_id, position_key, user_id, load, secondary_load, grund, algo_version,
     stand_session_id, stand_completed_at)
  select p_plan_id,
         z.value ->> 'positionKey',
         v_user,
         (z.value ->> 'load')::numeric,
         (z.value ->> 'secondaryLoad')::numeric,
         z.value ->> 'grund',
         z.value ->> 'algoVersion',
         p_session_id,
         v_stand
    from jsonb_array_elements(p_zeilen) z
  on conflict (plan_id, position_key) do update
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

-- Legt Startwerte fuer Positionen an, die noch keine Zeile haben. Bestehende
-- Zeilen (auch aus einer Einheit) bleiben unberuehrt; der Stand bleibt leer,
-- damit jeder Abschluss die Startwerte ersetzt.
create function public.init_plan_gewichte(
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
     and status in ('aktiv', 'ersetzt')
     for update;
  if not found then
    raise exception 'plan_ungueltig' using errcode = 'P0001';
  end if;

  perform public.plan_gewichte_zeilen_pruefen(v_plan, p_zeilen);

  insert into public.plan_gewichte
    (plan_id, position_key, user_id, load, secondary_load, grund, algo_version)
  select p_plan_id,
         z.value ->> 'positionKey',
         v_user,
         (z.value ->> 'load')::numeric,
         (z.value ->> 'secondaryLoad')::numeric,
         z.value ->> 'grund',
         z.value ->> 'algoVersion'
    from jsonb_array_elements(p_zeilen) z
  on conflict (plan_id, position_key) do nothing;
end;
$$;

revoke all on function public.init_plan_gewichte(uuid, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.init_plan_gewichte(uuid, jsonb) to authenticated;
