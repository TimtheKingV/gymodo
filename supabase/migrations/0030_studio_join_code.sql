-- Acht Zeichen aus einem Alphabet ohne 0/O und 1/I, damit niemand den Code
-- am Tresen verwechselt. Keine SECURITY DEFINER noetig -- reine Berechnung,
-- keine Tabelle beteiligt, dieselbe Einstufung wie is_valid_setting_choices
-- aus 0017.
create or replace function public.generate_join_code()
returns text
language plpgsql
volatile
as $$
declare
  alphabet  text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  ergebnis  text := '';
begin
  for i in 1..8 loop
    ergebnis := ergebnis || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return ergebnis;
end;
$$;

-- Ein duenner Wrapper um random(), Postgres' pro Backend deterministischen
-- PRNG -- ueber PostgREST direkt aufrufbar liesse sich dessen Ausgabe
-- wiederholt abtasten. service_role bleibt bewusst aussen vor: der
-- DEFAULT unten wertet mit den Rechten der einfuegenden Rolle aus, und
-- Studios entstehen ausschliesslich per Service-Role (Onboarding ist
-- admin-only, siehe Plan). SECURITY DEFINER-Funktionen wie
-- regenerate_studio_join_code laufen ohnehin als Funktionsbesitzer, nicht
-- als Aufrufer, und sind von diesem Revoke unberuehrt.
revoke all on function public.generate_join_code() from public, anon, authenticated;

-- Ein volatiler Default wird bei ADD COLUMN je Zeile neu ausgewertet, auch
-- fuer bereits bestehende Studios -- jedes bekommt also einen eigenen Code,
-- nicht denselben. Bei 33^8 moeglichen Codes ist eine Kollision unter den
-- wenigen Studios dieses Systems praktisch ausgeschlossen; die Unique-
-- Constraint darunter macht sie trotzdem unmoeglich statt nur unwahrscheinlich.
alter table public.studios
  add column join_code text not null default public.generate_join_code(),
  add column join_code_active boolean not null default true;

alter table public.studios
  add constraint studios_join_code_unique unique (join_code);

comment on column public.studios.join_code is
  'Wer diesen Code eingibt, wird Mitglied. studios_select (0001) laesst jedes Mitglied ihn lesen -- das ist bewusst so: der Code macht ohnehin die Runde, sobald er einmal weitergegeben ist. Nur regenerate_studio_join_code und set_studio_join_code_active duerfen ihn aendern, und die pruefen is_studio_staff.';

-- Der Beitritt per Code laeuft wie 0023 ueber eine Funktion, nicht ueber
-- eine Insert-Policy: ein Insert-Recht auf studio_memberships waere breiter
-- als noetig -- es erlaubte, sich in ein beliebiges Studio einzutragen,
-- statt nur in das, dessen Code man kennt.
create or replace function public.join_studio_by_code(p_code text)
returns table (studio_id uuid, joined boolean)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user   uuid := auth.uid();
  v_studio uuid;
  v_neu    boolean;
begin
  if v_user is null then
    return;
  end if;

  -- Unbekannt und gesperrt antworten identisch: leer. Sonst waere die
  -- Funktion ein Orakel, mit dem sich gueltige Codes erraten liessen.
  select s.id into v_studio
    from public.studios s
   where s.join_code = upper(trim(p_code))
     and s.join_code_active;

  if v_studio is null then
    return;
  end if;

  -- do nothing, nicht do update: wie in 0023 faellt eine Trainerin, die den
  -- Code ihres eigenen Studios eintippt, dabei nicht auf member zurueck.
  insert into public.studio_memberships (studio_id, user_id, role)
  values (v_studio, v_user, 'member')
  on conflict on constraint studio_memberships_studio_id_user_id_key do nothing;

  v_neu := found;

  return query select v_studio as studio_id, v_neu as joined;
end;
$$;

revoke all on function public.join_studio_by_code(text)
  from public, anon, authenticated, service_role;
grant execute on function public.join_studio_by_code(text) to authenticated;

-- Staff-only. "Erneuern" ist immer auch ein Entsperren, sonst muesste eine
-- Trainerin zwei Schritte gehen, um einen kompromittierten Code zu ersetzen.
create or replace function public.regenerate_studio_join_code(p_studio_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_code    text;
  v_versuch int := 0;
begin
  if not public.is_studio_staff(p_studio_id) then
    raise exception 'Nur Trainer und Inhaber duerfen den Code erneuern.';
  end if;

  loop
    v_code := public.generate_join_code();
    begin
      update public.studios
         set join_code = v_code, join_code_active = true
       where id = p_studio_id;
      exit;
    exception when unique_violation then
      v_versuch := v_versuch + 1;
      if v_versuch >= 5 then
        raise exception 'Konnte keinen eindeutigen Code erzeugen.';
      end if;
    end;
  end loop;

  return v_code;
end;
$$;

revoke all on function public.regenerate_studio_join_code(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.regenerate_studio_join_code(uuid) to authenticated;

create or replace function public.set_studio_join_code_active(p_studio_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_studio_staff(p_studio_id) then
    raise exception 'Nur Trainer und Inhaber duerfen den Code sperren oder entsperren.';
  end if;

  update public.studios
     set join_code_active = p_active
   where id = p_studio_id;
end;
$$;

revoke all on function public.set_studio_join_code_active(uuid, boolean)
  from public, anon, authenticated, service_role;
grant execute on function public.set_studio_join_code_active(uuid, boolean) to authenticated;
