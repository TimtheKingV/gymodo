-- Die Datenschutzgrenze, Spec 2026-08-31-trainerportal-struktur-design.md
-- Abschnitt 4 und Entscheidung 7.
--
-- Das Portal sieht Mitgliedschaft und Anwesenheit, aber keine
-- Trainingsdaten -- je Mitglied nichts. Bis hier gaben vier Policies
-- Trainern und Inhabern Leserecht auf die Trainingsdaten jedes Mitglieds
-- ihres Studios (0012 bis 0015, jeweils "or public.is_studio_staff(...)").
-- Alle vier verlieren diese Klausel.
--
-- Die Mitgliedschaftspruefung bleibt neben der Eigentuemerpruefung stehen,
-- obwohl sie fuer die eigenen Zeilen redundant aussieht: wer aus einem
-- Studio austritt (0024), verliert damit auch den Blick auf seine dortige
-- Historie. Das ist die bestehende Regel aus 0012, und dieser Schnitt
-- aendert sie nicht.
--
-- Ab hier ist studio_overview (0034) die einzige Stelle, an der
-- Trainingsdaten fuer Personal ueberhaupt noch erreichbar sind -- und sie
-- gibt ausschliesslich Summen heraus.
--
-- Fuer M3 zurueckzunehmen: Trainerbetreuung braucht den Verlauf. Der Weg
-- dorthin ist eine ausdrueckliche Freigabe durch das Mitglied, nicht die
-- pauschale Rolle.

drop policy workout_sessions_select on public.workout_sessions;
create policy workout_sessions_select on public.workout_sessions
  for select to authenticated
  using (
    public.is_studio_member(workout_sessions.studio_id)
    and workout_sessions.user_id = (select auth.uid())
  );

drop policy workout_sets_select on public.workout_sets;
create policy workout_sets_select on public.workout_sets
  for select to authenticated
  using (
    public.is_studio_member(workout_sets.studio_id)
    and workout_sets.user_id = (select auth.uid())
  );

drop policy member_machine_calibrations_select on public.member_machine_calibrations;
create policy member_machine_calibrations_select
  on public.member_machine_calibrations
  for select to authenticated
  using (
    public.is_studio_member(member_machine_calibrations.studio_id)
    and member_machine_calibrations.user_id = (select auth.uid())
  );

drop policy progression_suggestions_select on public.progression_suggestions;
create policy progression_suggestions_select
  on public.progression_suggestions
  for select to authenticated
  using (
    public.is_studio_member(progression_suggestions.studio_id)
    and progression_suggestions.user_id = (select auth.uid())
  );
