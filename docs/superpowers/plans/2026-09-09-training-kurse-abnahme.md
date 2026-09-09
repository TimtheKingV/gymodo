# Sub-Projekt 3 (Training & Kurse) — offene manuelle Abnahme

Alles in dieser Liste ist **übersetzt und getestet, aber nicht bedient**.
`xcodebuild` beweist, dass der Code baut und die reinen Ableitungen stimmen;
es beweist nichts über das, was auf dem Bildschirm passiert. Diese Datei liegt
bewusst im Repository und nicht im Arbeitsverzeichnis, damit sie das Löschen
des Worktrees überlebt.

Stand: 268 iOS-Tests in 41 Suiten, 119 Domänentests, `pnpm typecheck` sauber,
genau die vier vorbestehenden Warnungen aus Sub-Projekt 1.

## Die zehn Schritte

1. **Wochenplan über Mitternacht und über einen Kursbeginn hinweg liegen
   lassen.** Wochenstreifen, Überschrift und der Zustand der Zeile müssen ohne
   Zutun umschalten.

2. **Flugmodus an, Kurse-Tab öffnen, Flugmodus aus.** Die Offline-Karte muss von
   selbst verschwinden, und „Erneut versuchen" muss auch sofort funktionieren.

3. **App in den Hintergrund, zwei Minuten warten, zurück.** Der Screen lädt neu.
   Dieselbe Übung mit über fünf Minuten und ohne Netz: dann steht entweder die
   Offline-Karte oder der „Stand: …"-Hinweis — **nie eine nackte
   Belegungszahl**.

4. **Eine vergangene Kurszeile bei niedriger Helligkeit ansehen.** „VORBEI" und
   die Dauer müssen lesbar sein, die Zeile trotzdem erkennbar zurückgenommen.

5. **„Code stattdessen eingeben" im Beitritts-Scanner antippen.** Der Cursor muss
   im Studio-Code-Feld stehen und die Tastatur offen sein. *Das ist der einzige
   Punkt des ganzen Sub-Projekts, dessen Wirkung sich mit keinem Werkzeug
   nachweisen ließ.*

6. **„Meine Kurse" mit einer Anmeldung in zwei Wochen öffnen.** Sie muss unter
   „Später" auftauchen. Dazu: eine Einheit über Mitternacht beenden — der
   Abschluss muss „GESTERN · 23:40 – HEUTE 00:20" zeigen, nicht „HEUTE".

7. **Wochenplan laden, Flugmodus an, aus dem Hintergrund zurückkehren.** Der Plan
   bleibt **stehen**, die „12 von 16" verschwinden, und oben steht „Ohne
   Empfang. Stand: … Die freien Plätze lassen wir deshalb weg." Dann eine Zeile
   antippen: das Kursdetail zeigt denselben Satz und lässt die „Plätze"-Zeile
   weg.

8. **Ein Training beenden, während der Server einen Fehler liefert.** Unter
   „BEIM NÄCHSTEN MAL" muss der Servertext stehen — **nicht** „Vorschläge
   brauchen Empfang".

9. **Studio wechseln, während kein Netz da ist.** Der Wochenplan muss leer sein
   (Karte „Kein Empfang"), nicht der Plan des vorigen Studios, **und** „Meine
   Kurse" darf keine Anmeldung des vorigen Studios mehr zeigen. Danach mit Netz
   zurückwechseln: beide Screens füllen sich wieder.

10. **Auf einem Wartelistenplatz stehen, das Kursdetail öffnen, das Telefon
    sperren, nach zehn Minuten ohne Netz zurückkehren.** Es darf keine
    Platznummer dastehen, sondern „Du stehst auf der Warteliste."

## Bewusst offen — kein Versehen

- **Nachgerückt von der Warteliste.** Wer automatisch nachrückt, ist
  serverseitig von der Abmeldefrist ausgenommen (`promoted_at` in
  `cancel_course_booking`). Der Client kann das nicht erkennen: weder
  `CourseWeekSession` noch der Plattentyp tragen ein Feld dafür, und die
  Wochenplan-Abfrage liefert keines. Er wendet die Frist deshalb konservativ
  auf jede gebuchte Person an — „Abmelden" verschwindet dann, obwohl der Server
  es noch zuließe. Behebung braucht eine **Datenbankmigration** und gehört in
  eine eigene Aufgabe mit eigener Durchsicht. Es geht dabei nichts verloren und
  nichts Falsches wird behauptet; die Person muss sich ans Studio wenden.

- **Selbsttätig beendete Einheiten bekommen keine Vorschläge.** Ihr
  `completed_at` liegt außerhalb des Zeitfensters, mit dem die Vorschlagszeilen
  ihrer Einheit zugeordnet werden. Lieber kein Vorschlag als der einer fremden
  Einheit. Der Abschluss-Screen wird für eine ausgelaufene Einheit ohnehin nicht
  geöffnet — die geht über den Satz „automatisch beendet".

- **`InlineBanner` stellt denselben Fehler anders dar als die Fehlerkarte**
  (`textMuted` mit halbdeckender Kontur gegen `danger` mit voller). `InlineBanner`
  stammt aus Sub-Projekt 1 und wird von vielen Screens benutzt; eine Änderung
  dort ist nicht lokal und gehört in einen eigenen Durchgang durchs
  Designsystem.

- **Akzentzählung auf „Meine Kurse".** Bei drei bestätigten Anmeldungen stehen
  dort drei akzentgefüllte Kreise. Das Artboard hält es so, und der Akzent
  markiert hier eine Kategorie („deine bestätigten Plätze"), keine Hauptaktion.
  Bewusst gelassen — **aber die Zählweise darf beim nächsten Screen nicht als
  Vorbild für vier Akzentflächen gelten.**

- **`promotedUserId` in `apps/web/app/api/v1/course-sessions/[sessionId]/booking/route.ts`.**
  Der Server gibt die Kennung eines anderen Mitglieds heraus. Aus dem
  Swift-Client ist sie entfernt; der Serverstand gehört zu Phase 4.

- **Die vier Warnungen aus Sub-Projekt 1** (`QRScannerController.swift` ×3,
  `SupabaseAuthBackend.swift` ×1). Unverändert, eigener Zweig.
