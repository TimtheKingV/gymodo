-- Der Ueberblick, Spec 2026-08-31-trainerportal-struktur-design.md
-- Abschnitt 4.
--
-- Seit 0033 kommt Personal an kein einzelnes Trainingsdatum mehr heran.
-- Diese Funktion ist die einzige Stelle, an der Trainingsdaten fuer
-- Personal ueberhaupt noch erreichbar sind -- und sie gibt ausschliesslich
-- Summen heraus, niemals Zeilen. Ihre Signatur ist damit die
-- Datenschutzgrenze in Code-Form: jede spaetere Erweiterung um eine
-- Aufschluesselung nach Person ist eine Entscheidung, keine Kleinigkeit.
--
-- Die Mindestzahl: Spec Abschnitt 4 haelt fest, dass Summen nicht
-- automatisch anonym sind -- wer montags allein da war, hat die 312 Saetze
-- an der Beinpresse gemacht. Unterhalb von fuenf aktiven Mitgliedern im
-- Zeitraum liefert die Funktion deshalb die vier Kennzahlen, aber keine
-- Aufschluesselung je Geraet. Die Schwelle reist im Rueckgabewert mit
-- ('min_members'), damit die Oberflaeche den Leer-Zustand begruenden kann
-- statt bloss leer zu sein.
--
-- jsonb statt einer Tabelle: der Ueberblick besteht aus vier Skalaren und
-- zwei Listen unterschiedlicher Gestalt. Als returns table waeren das drei
-- Funktionen -- und damit drei Stellen, an denen die Grenze spaeter
-- aufgeweicht werden koennte.

create or replace function public.studio_overview(
  p_studio_id uuid,
  p_days      int default 30
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
declare
  -- Die Mindestzahl aktiver Mitglieder, ab der es eine Aufschluesselung je
  -- Geraet gibt. Entschieden am 2. September 2026; Spec Abschnitt 4 liess
  -- den Wert offen und verlangte ihn "vor dem ersten echten Mitglied".
  k_mindestzahl constant int := 5;

  v_tage      int := least(greatest(coalesce(p_days, 30), 1), 365);
  v_von       timestamptz;
  v_aktive    int;
  v_saetze    int;
  v_probleme  int;
  v_geraete   jsonb := '[]'::jsonb;
  v_meldungen jsonb := '[]'::jsonb;
begin
  -- Leer, nicht Fehler -- wie list_studio_members (0031) und
  -- join_studio_by_code (0030). Eine unterschiedliche Antwort machte die
  -- Funktion zum Orakel darueber, welche Studios es gibt.
  if not public.is_studio_staff(p_studio_id) then
    return null;
  end if;

  v_von := now() - make_interval(days => v_tage);

  -- "Aktiv" heisst: hat im Zeitraum eine Einheit begonnen. Nicht "ist
  -- Mitglied" -- die Zahl soll sagen, ob das Studio benutzt wird, nicht
  -- wie lang die Kartei ist.
  select count(distinct s.user_id)::int
    into v_aktive
    from public.workout_sessions s
   where s.studio_id = p_studio_id
     and s.started_at >= v_von;

  select count(*)::int, count(*) filter (where w.problem_flag)::int
    into v_saetze, v_probleme
    from public.workout_sets w
   where w.studio_id = p_studio_id
     and w.performed_at >= v_von;

  if v_aktive >= k_mindestzahl then
    select coalesce(
             jsonb_agg(
               jsonb_build_object(
                 'machine_id', t.machine_id,
                 'label',      t.label,
                 'status',     t.status,
                 'sets',       t.saetze
               )
               order by t.saetze desc, t.label asc
             ),
             '[]'::jsonb
           )
      into v_geraete
      from (
        select w.machine_id,
               m.label,
               m.status::text as status,
               count(*)::int  as saetze
          from public.workout_sets w
          join public.machines m on m.id = w.machine_id
         where w.studio_id = p_studio_id
           and w.performed_at >= v_von
         group by w.machine_id, m.label, m.status
         order by count(*) desc, m.label asc
         limit 5
      ) t;

    select coalesce(
             jsonb_agg(
               jsonb_build_object(
                 'machine_id', t.machine_id,
                 'label',      t.label,
                 'reason',     t.reason,
                 'count',      t.anzahl
               )
               order by t.anzahl desc, t.label asc
             ),
             '[]'::jsonb
           )
      into v_meldungen
      from (
        select w.machine_id,
               m.label,
               w.problem_reason::text as reason,
               count(*)::int          as anzahl
          from public.workout_sets w
          join public.machines m on m.id = w.machine_id
         where w.studio_id = p_studio_id
           and w.performed_at >= v_von
           and w.problem_flag
         group by w.machine_id, m.label, w.problem_reason
         order by count(*) desc, m.label asc
         limit 5
      ) t;
  end if;

  return jsonb_build_object(
    'days',            v_tage,
    'active_members',  v_aktive,
    'sets',            v_saetze,
    'problem_reports', v_probleme,
    'min_members',     k_mindestzahl,
    'breakdown',       v_aktive >= k_mindestzahl,
    'top_machines',    v_geraete,
    'problems',        v_meldungen
  );
end;
$$;

comment on function public.studio_overview(uuid, int) is
  'Studioweite Summen fuer den Ueberblick. Liefert nie eine Zeile und nie einen Personenbezug -- die einzige Stelle, an der Trainingsdaten fuer Personal seit 0033 noch erreichbar sind. Unterhalb von fuenf aktiven Mitgliedern entfaellt die Aufschluesselung je Geraet (Spec Abschnitt 4). Wer kein Personal des Studios ist, bekommt NULL, keinen Fehler.';

revoke all on function public.studio_overview(uuid, int)
  from public, anon, authenticated, service_role;
grant execute on function public.studio_overview(uuid, int) to authenticated;
