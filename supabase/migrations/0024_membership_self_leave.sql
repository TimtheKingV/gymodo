-- Wer mit einem Tap beitritt, muss mit einem Tap gehen koennen. Das ist die
-- Kehrseite von 0023: ohne Rueckweg waere ein versehentlicher Scan eine
-- Mitgliedschaft, die nur das Studio wieder aufloesen kann.
--
-- Die Einschraenkung auf 'member' haelt die Regel, dass sich niemand selbst
-- die letzte Inhaberrolle entzieht, ohne dafuer zaehlen zu muessen. Trainer
-- und Inhaber werden weiterhin unter Leute -> Mitarbeiter entfernt.
create policy memberships_delete_own_membership on public.studio_memberships
  for delete to authenticated
  using (user_id = auth.uid() and role = 'member');
