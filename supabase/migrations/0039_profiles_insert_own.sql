-- profiles traegt display_name seit 0001, aber es gibt weder eine
-- Insert-Policy noch einen Trigger, der die Zeile anlegt -- fuer kein
-- Mitglied existiert eine (0035_kurse.sql haelt das ausdruecklich fest).
--
-- Kein SECURITY DEFINER-Trigger auf auth.users: der deckte nur
-- Neuregistrierungen ab, und jedes Bestandsmitglied braeuchte trotzdem
-- den Schreibweg aus dem Profil. Ein Mechanismus, der zwei Wege ersetzt,
-- ist besser als ein zweiter neben ihnen.
create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = auth.uid());
