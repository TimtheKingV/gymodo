# Sub-Projekt 4 (Home & Profil) — offene manuelle Abnahme

`xcodebuild` beweist, dass der Code baut und die reinen Ableitungen stimmen;
es beweist nichts über das, was auf dem Bildschirm passiert, und nichts über
den Server gegen echtes Postgres. Diese Datei liegt bewusst im Repository und
nicht im Arbeitsverzeichnis, damit sie das Löschen des Worktrees überlebt.

Stand: 313 iOS-Tests in 46 Suiten, 130 Domänentests, `pnpm typecheck` sauber,
genau die vier vorbestehenden Warnungen aus Sub-Projekt 1
(`QRScannerController.swift` ×3, `SupabaseAuthBackend.swift` ×1).

Auf dieser Maschine ist Docker nicht installiert. Die lokale
Supabase-Instanz lief deshalb nie, Migration `0039_profiles_insert_own.sql`
wurde nie angewendet, und die in den Aufgaben 1–3 geschriebenen
Integrationstests (die Ergänzungen in `tests/integration/domain-sessions.test.ts`
und `domain-progress.test.ts`, sowie die komplett neue
`tests/integration/api-profil.test.ts`) sind kein einziges Mal gelaufen. Das
ist eine festgehaltene Entscheidung, kein Versehen — aber die Serverhälfte
dieses Sub-Projekts ist damit unbewiesen gegen echtes Postgres. Deshalb steht
das als erster Punkt vor den vierzehn manuellen Schritten.

## Vor den vierzehn Schritten

0. **Migration anwenden und die Integrationssuiten laufen lassen.** Auf einer
   Maschine mit lokalem Supabase: `0039_profiles_insert_own.sql` einspielen,
   dann `pnpm vitest run` im Repository-Wurzelverzeichnis, mit besonderem
   Augenmerk auf die Ergänzungen in `domain-sessions.test.ts` und
   `domain-progress.test.ts` sowie die komplette `api-profil.test.ts`. Erst
   danach ist die Serverhälfte dieses Sub-Projekts gegen echtes Postgres
   geprüft, nicht nur gelesen.

## Die vierzehn Schritte

1. **Erste Registrierung mit Vornamen, dann Home öffnen.** Der Gruß nennt den
   Vornamen, das Profil zeigt Name und Initialen.

2. **Bestandskonto ohne Namen.** Home grüßt **nicht**, das Profil zeigt nur
   die Mailadresse und keine Initialen. Dann über die Kopfkarte einen Namen
   setzen: beides erscheint.

3. **Registrierung mit Vornamen im Flugmodus abschließen.** Es geht ohne
   Namen weiter, keine Fehlermeldung, und das Profil bietet den Weg erneut
   an.

4. **Flugmodus, App neu starten, Home öffnen.** Verlauf, Kennzahlen und
   Fortschritt stehen aus dem Cache, darüber „Ohne Empfang. Stand: …". Dann
   Flugmodus aus und nach unten ziehen: der Satz verschwindet.

5. **Eine Einheit über vier Stunden offen liegen lassen**, dann Home öffnen.
   Sie erscheint mit „AUTO BEENDET" und **ohne Dauer**.

6. **Während einer laufenden Einheit Home öffnen.** Sie steht **nicht** unter
   „Letzte Trainings", die Kennzahl „Tage her" zeigt 0.

7. **Studio verlassen, Home öffnen.** „diese Woche" fehlt, „gesamt" und die
   Liste bleiben.

8. **Ein Diagramm mit einem einzigen Punkt.** Achse und Punkt sind sichtbar,
   die Kurve verschwindet nicht in einer Linie.

9. **Übungsfortschritt mit VoiceOver.** Die Rohwerteliste unter der Kurve ist
   erreichbar und liest Datum, Gewicht und Wiederholungen.

10. **Dynamic Type auf XXL** auf Home, Session-Detail und Profil. Nichts
    bricht ins Layout (§12: Abnahmebedingung).

11. **Resttimer auf 45 s stellen, Satz sichern.** Der Balken läuft 45 s,
    nicht 90.

12. **Vibration abschalten, Satz sichern.** Keine Haptik, die sichtbare
    Bestätigung bleibt. Dazu mehrfach zwischen zwei Übungen hin und her
    wechseln, ohne zu sichern: das Gerät bleibt stumm — der Auslöser ist ein
    Zähler gesicherter Sätze, nicht die Satznummer der gerade angezeigten
    Übung, und darf deshalb nicht schon beim bloßen Wechsel auf eine Übung
    mit mehr bereits gesicherten Sätzen vibrieren.

13. **RIR abschalten**, dann ein älteres Session-Detail öffnen: bereits
    erfasste RIR-Werte stehen weiterhin da — der Schalter regelt die
    Erfassung, nicht die Rückschau.

14. **Datenschutzzeile ohne konfigurierte Adresse.** `DATENSCHUTZ_URL` ist in
    diesem Stand nicht gesetzt — die Zeile im Profil unter „DEINE DATEN"
    muss deshalb vollständig fehlen, nicht nur ausgegraut oder ohne Ziel
    sein. Sobald irgendwann ein Wert hinterlegt ist: die Zeile erscheint und
    öffnet die hinterlegte Adresse.

## Bewusst offen — kein Versehen

- **Die Rohwerteliste im Fortschrittsdiagramm** (`UebungsfortschrittView.swift`)
  wiederholt den Parse-String `"\(tag)T12:00:00Z"` an drei Stellen (LineMark,
  PointMark, Datumsformatierung). Funktioniert an allen dreien identisch,
  gehört bei nächster Berührung der Datei in eine gemeinsame Hilfsfunktion.

- **Kein Test pinnt das Verhalten exakt an der 92-Tage-Grenze** des Fensters
  „3 Monate" (`Fortschrittsfenster.swift`). Die Fensterlogik selbst ist
  domänengetestet, aber ein Punkt, der genau auf der Grenze liegt, hat kein
  eigenes Testbeispiel.

- **Das Artboard hebt den jüngsten Punkt der Kurve mit einem größeren
  Symbol und einer gestrichelten Hilfslinie hervor; die Umsetzung zeichnet
  alle Punkte gleich** (`symbolSize(64)` für jeden `PointMark`). Kein
  funktionaler Unterschied, eine bewusst zurückgestellte Verfeinerung.

- **Die Achsenbeschriftung verlässt sich auf Swift Charts' Standard-Ziffernsatz
  statt auf ein explizites `.monospacedDigit()`.** Die direkte Beschriftung an
  den Endpunkten und die Rohwerteliste haben es, die Achse selbst nicht —
  auf einem Gerät kann das zu leicht springenden Achsenbreiten beim
  Fensterwechsel führen.

- **`SessionStore.signOut()` löscht den gemerkten Vornamen nicht.** Heute
  nachweislich folgenlos, weil ihn nur der Registrierungsablauf liest — ein
  abgemeldetes und neu registriertes Konto überschreibt ihn ohnehin. Wird
  erst relevant, sollte der Wert je an anderer Stelle gelesen werden.

- **Der Profil-Footer liest `CFBundleShortVersionString` direkt aus dem
  Bundle statt über `AppConfig`** (`ProfilRootView.swift`). Die drei
  Pflichtwerte und die optionale Datenschutz-URL laufen über `AppConfig`,
  die Versionsnummer nicht — inkonsequent, aber ohne Fehlerfall, weil der
  Schlüssel von iOS selbst garantiert gefüllt ist.

- **`profil.ts` reicht die rohe Postgres-Fehlermeldung in
  `DomainError("internal", error.message)` durch**, wovor der Kommentar in
  `respond.ts` ausdrücklich warnt („eine durchgereichte Datenbankmeldung
  verrät Tabellennamen, Spalten und manchmal fremde Werte"). Risiko hier
  gering, weil unter RLS in diesem Pfad nur `id` und `display_name`
  beschreibbar sind — trotzdem dieselbe Regel verletzt, die anderswo im
  Projekt gilt.
