-- machine_tags hatte bis hierher nur eine Select-Policy. Tags liessen sich
-- weder anlegen noch zuweisen noch sperren, ohne direkt an der Datenbank zu
-- sitzen -- das war der offene Punkt 2 aus dem Geraetekatalog-Plan und der
-- Grund, warum ein Studio sich nicht ohne Entwicklerhilfe einrichten liess.
--
-- WICHTIG, wie schon in 0007_machines.sql: die Spalten der machine_tags-Zeile
-- MUESSEN mit dem Tabellennamen qualifiziert werden. machines fuehrt ebenfalls
-- eine Spalte studio_id, sodass aus einem unqualifizierten
-- "m.studio_id = studio_id" ein wirkungsloses "m.studio_id = m.studio_id"
-- wuerde -- die Studio-Pruefung liefe still ins Leere und ein Tag koennte auf
-- ein Geraet eines fremden Studios zeigen.
--
-- machine_id bleibt bewusst nullbar: ein Tag wird auf Vorrat gedruckt und
-- erst spaeter zugewiesen. Der Check-Constraint aus 0008 sorgt dafuer, dass
-- 'active' und machine_id nur gemeinsam auftreten.
create policy machine_tags_insert on public.machine_tags
  for insert to authenticated
  with check (
    public.is_studio_staff(machine_tags.studio_id)
    and (
      machine_tags.machine_id is null
      or exists (
        select 1 from public.machines m
        where m.id = machine_tags.machine_id
          and m.studio_id = machine_tags.studio_id
      )
    )
  );

-- using prueft die alte Zeile, with check die neue. Beide zusammen verhindern,
-- dass ein Tag aus dem eigenen Studio herausgeschrieben wird: das Umhaengen
-- auf ein fremdes studio_id scheitert an with check, das Aendern eines fremden
-- Tags schon an using.
create policy machine_tags_update on public.machine_tags
  for update to authenticated
  using (public.is_studio_staff(machine_tags.studio_id))
  with check (
    public.is_studio_staff(machine_tags.studio_id)
    and (
      machine_tags.machine_id is null
      or exists (
        select 1 from public.machines m
        where m.id = machine_tags.machine_id
          and m.studio_id = machine_tags.studio_id
      )
    )
  );

-- Bewusst KEINE Delete-Policy. Ein Tag klebt physisch an einem Geraet; wer ihn
-- loescht, verliert die Zuordnungshistorie und macht den Fremdschluessel aus
-- 0008 (on delete restrict) wirkungslos. Der vorgesehene Weg ist
-- status = 'revoked', nicht Loeschen.
