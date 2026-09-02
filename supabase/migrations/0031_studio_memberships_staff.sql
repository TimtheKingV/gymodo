-- Lesen mit E-Mail-Adresse: eine SECURITY DEFINER-Funktion statt einer
-- Policy, weil auth.users ausserhalb der public-Policies liegt und
-- profiles (0001) nur die eigene Zeile freigibt. is_studio_staff(p_studio_id)
-- prueft den Aufrufer, nicht die Zeile -- deshalb steht der Aufruf einmal in
-- der where-Klausel und gilt fuer alle Zeilen gleich: ist der Aufrufer kein
-- Staff des Studios, liefert die Funktion leer, nie einen Fehler.
create or replace function public.list_studio_members(p_studio_id uuid)
returns table (
  user_id   uuid,
  email     text,
  role      public.studio_role,
  joined_at timestamptz
)
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select m.user_id, u.email, m.role, m.created_at
    from public.studio_memberships m
    join auth.users u on u.id = m.user_id
   where m.studio_id = p_studio_id
     and public.is_studio_staff(p_studio_id)
   order by m.created_at asc;
$$;

revoke all on function public.list_studio_members(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.list_studio_members(uuid) to authenticated;

-- UPDATE und DELETE reichen ihre eigene USING-Klausel allein nicht: Postgres
-- muss eine Zeile ueber eine SELECT-Policy sehen koennen, bevor es sie
-- ueberhaupt als Ziel fuer UPDATE/DELETE in Betracht zieht (siehe PostgreSQL-
-- Doku zu Row Security, Abschnitt "UPDATE/DELETE"; empirisch bestaetigt --
-- ohne diese Policy blieb is_studio_staff() zwar wahr, aber UPDATE traf 0
-- Zeilen bei einer fremden Zeile). memberships_select_own (0001) deckt nur
-- die eigene Zeile ab, das reicht Staff fuer fremde Zeilen nicht. Die
-- E-Mail-Adresse bleibt trotzdem exklusiv bei list_studio_members: diese
-- Policy liefert nur die Rohspalten aus public.studio_memberships.
create policy memberships_select_staff on public.studio_memberships
  for select to authenticated
  using (public.is_studio_staff(studio_id));

-- Rollenwechsel: role <> 'owner' auf beiden Seiten schliesst den Inhaber von
-- diesem Pfad aus. Damit ist "niemand kann sich selbst die letzte
-- Inhaberrolle entziehen" (Spec Abschnitt 2) durch die Policy erzwungen,
-- nicht durch eine Zaehlfunktion -- eine Inhaberzeile ist hier unerreichbar,
-- gleich wie viele es gibt.
create policy memberships_update_staff on public.studio_memberships
  for update to authenticated
  using (public.is_studio_staff(studio_id) and role <> 'owner')
  with check (public.is_studio_staff(studio_id) and role <> 'owner');

-- Entfernen: dieselbe Grenze. Ein Trainer entfernt ein Mitglied oder einen
-- anderen Trainer, nie einen Inhaber -- die Kehrseite von 0024, dort fuer
-- das eigene Konto, hier fuer fremde. "Fuer fremde" steht auch im
-- Bedingungstext: user_id <> auth.uid() schliesst die eigene Zeile aus, sonst
-- koennte sich ein Trainer ueber diesen Pfad selbst entfernen und damit
-- memberships_delete_own_membership (0024) unterlaufen, die genau das fuer
-- Trainer und Inhaber ausschliesst.
create policy memberships_delete_staff on public.studio_memberships
  for delete to authenticated
  using (public.is_studio_staff(studio_id) and role <> 'owner' and user_id <> auth.uid());
