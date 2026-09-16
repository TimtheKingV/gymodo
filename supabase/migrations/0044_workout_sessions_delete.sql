-- Loeschen einer eigenen Einheit (Sammelstelle Punkt 19, Schnitt 4).
--
-- 0012 hatte bewusst keine Delete-Policy: "Historie wird nicht geloescht"
-- (M1-Spec Abschnitt 10). Das galt fuer Historie, die das System anlegt.
-- Seit Schnitt 4 beginnt eine Einheit mit einem Tap des Mitglieds, und ein
-- Fehlstart, ein Test oder eine Einheit, die jemand anders am Geraet
-- ausgeloest hat, sind keine Historie, sondern ein Irrtum. Loeschen statt
-- Verstecken: es sind die Daten des Mitglieds, und ein deleted_at, das jede
-- Abfrage mitfiltern muesste, waere die schlechtere Wahrheit.
--
-- Nur die eigenen Zeilen, ohne Mitgliedschaftsklausel -- anders als select
-- seit 0033: wer sein Studio verlassen hat, sieht die Einheiten dort nicht
-- mehr, darf sie aber weiterhin loeschen. Sie gehoeren ihm, nicht dem
-- Studio.
--
-- workout_sets haengt mit "on delete cascade" an der Session (0013) und geht
-- von selbst mit; referenzielle Aktionen laufen an RLS vorbei, eine eigene
-- Delete-Policy auf workout_sets braucht es dafuer nicht.
-- progression_suggestions traegt keine session_id (abschluss.ts) und bleibt
-- stehen: eine Rechnung ueber die Historie, keine Zeile der Einheit.
-- Serie (serie.ts), Fortschritt und studio_overview (0034) rechnen aus
-- denselben Zeilen und werden kleiner -- die ehrliche Folge, kein Fehler.

create policy workout_sessions_delete on public.workout_sessions
  for delete to authenticated
  using (workout_sessions.user_id = (select auth.uid()));
