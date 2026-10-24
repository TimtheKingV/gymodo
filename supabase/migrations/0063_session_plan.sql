-- Session traegt Planeinheit und Status je Position (Trainingsplan Etappe 3,
-- Task 4).
--
-- Die App schickt mit jedem Satz-PUT eine Momentaufnahme des Plans der
-- laufenden Einheit: welche Planeinheit, ein Stand-Zaehler und je Position
-- der Status (offen/erledigt/optional/getauscht) samt Ersatzuebung. Der
-- Server haelt sie je Session fest, damit spaetere Tasks daraus "Einheit
-- zaehlt", den Zaehler und die naechste Einheit ableiten -- serverseitig,
-- nicht aus einer Behauptung der App (F15).
--
-- * workout_sessions bekommt plan_id, plan_einheit_key und plan_stand.
--   Die Bindung an die Planeinheit wird einmal gesetzt und bleibt; plan_stand
--   ist monoton: die App sendet nach der Reserve-Frage aeltere Satz-Rumpfe
--   erneut, und deren Momentaufnahme darf eine neuere nie ueberschreiben.
-- * session_plan_status haelt den Status je Position. Nur lesbar fuer das
--   Mitglied; geschrieben wird ausschliesslich ueber record_session_plan,
--   die Session, Plan, Schluessel und Ersatzuebung selbst prueft.
-- * Ein Trigger verhindert, dass das Mitglied die Plan-Spalten ueber die
--   Update-Policy von workout_sessions (0047) direkt setzt -- sonst liesse
--   sich eine Session an einen fremden Plan binden oder plan_stand so hoch
--   setzen, dass keine Momentaufnahme mehr greift.
--
-- Additiv: alte Apps senden kein plan, ihre Sessions behalten null/null/0.

alter table public.workout_sessions
  add column plan_id uuid references public.training_plans (id),
  add column plan_einheit_key text,
  add column plan_stand int not null default 0,
  -- Eine halbe Bindung (Plan ohne Einheit oder umgekehrt) liesse sich
  -- spaeter keiner Einheit zuordnen.
  add constraint workout_sessions_plan_consistent
    check ((plan_id is null) = (plan_einheit_key is null)),
  add constraint workout_sessions_plan_stand_check
    check (plan_stand >= 0);

comment on column public.workout_sessions.plan_stand is
  'Hoechster uebernommener Stand der Plan-Momentaufnahme; nur record_session_plan erhoeht ihn.';

-- Fuer "Einheiten je Plan" der Folgetasks; die meisten Sessions haben keinen Plan.
create index workout_sessions_plan_id on public.workout_sessions (plan_id) where plan_id is not null;

-- user_id steht in der Zeile, damit die Select-Policy ohne Join auf
-- workout_sessions auskommt. on delete cascade an der Session: loescht das
-- Mitglied eine Einheit (0044), gehen die Statuszeilen mit -- wie die Saetze.
-- exercise_id ist die ERSATZ-Uebung der Position (null ohne Tausch);
-- restrict wie workout_sets.exercise_id (0013), damit ein Tausch nicht
-- stillschweigend seine Uebung verliert.
create table public.session_plan_status (
  session_id   uuid not null references public.workout_sessions (id) on delete cascade,
  position_key text not null,
  user_id      uuid not null references auth.users (id) on delete cascade,
  status       text not null check (status in ('offen', 'erledigt', 'optional', 'getauscht')),
  exercise_id  uuid references public.exercises (id) on delete restrict,
  primary key (session_id, position_key)
);

create index on public.session_plan_status (user_id);

alter table public.session_plan_status enable row level security;
alter table public.session_plan_status force  row level security;

-- Nur das Mitglied selbst; keine Insert-/Update-/Delete-Policy, geschrieben
-- wird nur ueber record_session_plan (SECURITY DEFINER).
create policy session_plan_status_select_own on public.session_plan_status
  for select to authenticated
  using (user_id = (select auth.uid()));

-- Die Plan-Spalten aendert nur record_session_plan. Die Funktion laeuft als
-- Eigentuemer, dort ist current_user nicht authenticated; jeder direkte
-- Schreibversuch des Mitglieds ueber PostgREST dagegen schon.
create function public.workout_sessions_plan_schuetzen()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if current_user in ('authenticated', 'anon') then
    if tg_op = 'INSERT' then
      if new.plan_id is not null or new.plan_einheit_key is not null or new.plan_stand <> 0 then
        raise exception 'plan_nur_ueber_satz' using errcode = '42501';
      end if;
    elsif new.plan_id is distinct from old.plan_id
       or new.plan_einheit_key is distinct from old.plan_einheit_key
       or new.plan_stand is distinct from old.plan_stand then
      raise exception 'plan_nur_ueber_satz' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.workout_sessions_plan_schuetzen()
  from public, anon, authenticated, service_role;

create trigger workout_sessions_plan_schuetzen
  before insert or update on public.workout_sessions
  for each row execute function public.workout_sessions_plan_schuetzen();

-- Uebernimmt die Momentaufnahme des Plans fuer eine Session.
--
-- Der Nutzer kommt nur aus auth.uid(). Fremd und unbekannt antworten gleich
-- (plan_ungueltig), damit die Antwort nichts verraet. Reihenfolge:
--
-- 1. Session des Aufrufers, FOR UPDATE: serialisiert gleichzeitige PUTs
--    derselben Session; ohne die Sperre saehen zwei Aufrufe denselben alten
--    plan_stand und der aeltere koennte den neueren ueberschreiben.
-- 2. Plan des Aufrufers im Studio DER SESSION und aktiv oder ersetzt. Ein
--    Plan eines anderen Studios wuerde dort Einheiten gutschreiben, die hier
--    trainiert wurden, und liesse das Loeschen jenes Studios am FK
--    workout_sessions.plan_id scheitern. Vorschlag/verworfen war nie der
--    Plan, nach dem trainiert wird; ersetzt muss gehen, weil ein dauerhafter
--    Tausch (0062) waehrend der Einheit eine neue Version anlegt.
-- 3. Ist die Session schon gebunden, muss die Einheit dieselbe sein, und ein
--    anderer Plan nur eine NEUERE Version derselben Reihe (Nutzer + Studio
--    sind durch 2. schon gleich) -- sonst stuenden Zeilen einer Einheit B an
--    einer Session der Einheit A. Die Bindung selbst bleibt die erste.
-- 4. Ist p_stand nicht groesser als plan_stand, passiert still nichts --
--    vor der Schluesselpruefung, damit ein veraltetes erneutes Senden
--    ignoriert wird statt zu scheitern.
-- 5. Jeder key ist eine Position DIESER Einheit, hoechstens einmal (sonst
--    raete die Funktion, welcher Status gilt); Status gueltig; getauscht nur
--    mit Ersatzuebung, und eine Ersatzuebung muss existieren. Alles vor dem
--    Schreiben, damit nichts halb uebernommen wird.
create function public.record_session_plan(
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
     and studio_id = v_session.studio_id
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
