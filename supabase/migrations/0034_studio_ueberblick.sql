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
-- an der Beinpresse gemacht. Unterhalb von fuenf Personen im Zeitraum
-- verdeckt die Funktion deshalb alles, was Trainingsinhalt ist. Die
-- Schwelle reist im Rueckgabewert mit ('min_members'), damit die
-- Oberflaeche den Leer-Zustand begruenden kann statt bloss leer zu sein.
--
-- Drei Dinge daran sind bewusst so und nicht anders:
--
-- Erstens der kleinste Zeitraum. p_days ist nach unten auf sieben Tage
-- geklemmt, nicht auf einen. Die Funktion ist an authenticated vergeben,
-- also kann jeder Trainer sie per RPC mit einem Fenster aufrufen, das die
-- Oberflaeche nie benutzt. Bei p_days => 1 waere die Antwort an einem
-- ruhigen Tag der Trainingstag einer einzigen Person -- zuordenbar ueber
-- die Anwesenheit, die Personal legitim sieht. Und weil sich zwei Fenster
-- voneinander abziehen lassen, liesse sich aus N und N-1 jeder einzelne
-- Tag bis ein Jahr zurueck herausloesen. Sieben Tage sind die kleinste
-- Scheibe, die nicht auf einen einzelnen Besuch zeigt.
--
-- Zweitens gilt die Schwelle auch fuer die Skalare, nicht nur fuer die
-- Listen. Ein Monatsfenster in einem Studio mit einer einzigen erfassenden
-- Person verraet deren Satzzahl so sicher wie eine Rangliste. Unterhalb
-- der Schwelle kommen 'sets' und 'problem_reports' deshalb als JSON null
-- zurueck, nicht als Zahl. 'active_members' bleibt immer eine Zahl:
-- Abschnitt 4 zaehlt aktive Mitglieder ausdruecklich zum Sichtbaren, es
-- ist ein Kopfzaehlen und kein Trainingsinhalt -- und es ist die Zahl, mit
-- der die Oberflaeche erklaeren kann, warum der Rest fehlt.
--
-- Drittens zaehlt die Schwelle die Erfassenden, nicht die Aktiven. Eine
-- Einheit gilt als begonnen, sobald jemand ein Geraet antippt; gezaehlt
-- wird hier aber nur, was am Geraet bestaetigt wurde. Wer Saetze erfasst
-- hat, ist damit eine Teilmenge derer, die eine Einheit begonnen haben.
-- Fuenf Leute, die antippen und nichts bestaetigen, plus eine Person, die
-- trainiert, oeffneten sonst eine Rangliste, die vollstaendig dieser einen
-- Person gehoert. Ein k-anonymer Satz muss ueber genau die Zeilen gebildet
-- werden, aus denen die Kennzahl entsteht -- also ueber workout_sets.
-- v_aktive behaelt seine Bedeutung und bleibt das gemeldete
-- 'active_members'; die Schwelle haengt an v_erfassende.
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
  -- Die Mindestzahl erfassender Personen, ab der es Trainingsinhalt zu
  -- sehen gibt. Entschieden am 2. September 2026; Spec Abschnitt 4 liess
  -- den Wert offen und verlangte ihn "vor dem ersten echten Mitglied".
  k_mindestzahl constant int := 5;

  -- Der kleinste zulaessige Zeitraum. Siehe Kopf: ein Ein-Tages-Fenster
  -- waere ein Besuchsprotokoll, und die Differenz zweier Fenster ebenso.
  k_mindesttage constant int := 7;

  v_tage       int := least(greatest(coalesce(p_days, 30), k_mindesttage), 365);
  v_von        timestamptz;
  v_aktive     int;
  v_erfassende int;
  v_saetze     int;
  v_probleme   int;
  v_offen      boolean;
  v_geraete    jsonb := '[]'::jsonb;
  v_meldungen  jsonb := '[]'::jsonb;
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

  -- Alles Weitere entsteht aus workout_sets -- und aus derselben Abfrage
  -- kommt die Zahl, an der die Schwelle haengt. Beides zusammen, damit
  -- niemand spaeter das eine aendert und das andere stehen laesst.
  select count(*)::int,
         count(*) filter (where w.problem_flag)::int,
         count(distinct w.user_id)::int
    into v_saetze, v_probleme, v_erfassende
    from public.workout_sets w
   where w.studio_id = p_studio_id
     and w.performed_at >= v_von;

  v_offen := v_erfassende >= k_mindestzahl;

  if v_offen then
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

  -- case ohne else liefert SQL NULL und damit JSON null -- der Unterschied
  -- zu einer 0 ist der Punkt: verdeckt ist nicht dasselbe wie keins.
  return jsonb_build_object(
    'days',            v_tage,
    'active_members',  v_aktive,
    'sets',            case when v_offen then v_saetze end,
    'problem_reports', case when v_offen then v_probleme end,
    'min_members',     k_mindestzahl,
    'breakdown',       v_offen,
    'top_machines',    v_geraete,
    'problems',        v_meldungen
  );
end;
$$;

comment on function public.studio_overview(uuid, int) is
  'Studioweite Summen fuer den Ueberblick. Liefert nie eine Zeile und nie einen Personenbezug -- die einzige Stelle, an der Trainingsdaten fuer Personal seit 0033 noch erreichbar sind. Unterhalb von fuenf Personen mit erfassten Saetzen im Zeitraum entfallen die Aufschluesselung je Geraet und die Zahlen sets und problem_reports (JSON null); active_members bleibt sichtbar. Der Zeitraum ist nach unten auf sieben Tage geklemmt, damit kein einzelner Trainingstag herausloesbar ist. Wer kein Personal des Studios ist, bekommt NULL, keinen Fehler.';

revoke all on function public.studio_overview(uuid, int)
  from public, anon, authenticated, service_role;
grant execute on function public.studio_overview(uuid, int) to authenticated;
