-- Flows im Gymtavo-Katalog-Studio (Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md,
-- Abschnitt 5.2): Wie Geraete und Uebungen soll auch ein Flow, den Gymtavo pflegt, fuer jeden
-- Angemeldeten sichtbar sein -- auch fuer Nutzer ohne Studio. Das Katalog-Studio hat nie
-- Mitglieder (Waechter gymtavo_keine_mitglieder), die Lesepolicies aus 0078 liessen es deshalb
-- niemanden sehen.
--
-- Gelesen wird zusaetzlich, wenn das Studio des Flows das Katalog-Studio ist. Geschrieben
-- werden Flows weiterhin nur per service_role. Ein Lauf des Katalog-Flows tragt als studio_id
-- das Katalog-Studio (wie Saetze im freien Training); der Flow muss zum Studio des Laufs
-- gehoeren, damit niemand einen Lauf an ein fremdes Studio haengt.

drop policy flows_select on public.flows;
create policy flows_select on public.flows
  for select to authenticated using (
    public.is_studio_member(studio_id) or public.is_catalog_studio(studio_id)
  );

drop policy flow_steps_select on public.flow_steps;
create policy flow_steps_select on public.flow_steps
  for select to authenticated using (
    exists (
      select 1 from public.flows f
      where f.id = flow_steps.flow_id
        and (public.is_studio_member(f.studio_id) or public.is_catalog_studio(f.studio_id))
    )
  );

drop policy flow_runs_insert_own on public.flow_runs;
create policy flow_runs_insert_own on public.flow_runs
  for insert to authenticated with check (
    user_id = (select auth.uid())
    and (public.is_studio_member(studio_id) or public.is_catalog_studio(studio_id))
    and exists (
      select 1 from public.flows f
      where f.id = flow_runs.flow_id
        and f.studio_id = flow_runs.studio_id
    )
  );
