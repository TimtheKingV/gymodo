# Ziele & Fortschritt — offene manuelle Abnahme

`xcodebuild` und `pnpm vitest` beweisen, dass der Code baut und die reinen
Ableitungen stimmen — Serienstand, Zielrechnung, Rundung, Zeitzonenregeln.
Sie beweisen nichts über das, was auf dem Bildschirm passiert, und nichts
über eine Cloud-Datenbank, gegen die dieser Zweig nie gelaufen ist. Diese
Datei liegt bewusst im Repository und nicht im Arbeitsverzeichnis, damit sie
das Löschen des Worktrees überlebt.

Gebaut wurden in diesem Bauabschnitt drei Migrationen (`0041`–`0043`), fünf
neue Routen plus zwei erweiterte (`/me/profile`, `/me/bootstrap`), ein
fünfstufiges Onboarding nach der Registrierung, der Block „Deine Ziele" auf
Home neben der Serie, ein Gewichtsverlauf mit Eintragen/Löschen und
Ziellinie, und ein Profil, in dem jede Angabe einzeln änderbar und
entfernbar ist.

## Testlauf, kalt

Alle vier Ebenen liefen kalt am 15. September, mit isoliertem
`-derivedDataPath`, danach gelöscht.

| Ebene | Ergebnis |
| --- | --- |
| Domänen-Unit (`packages/domain`) | 165/165 Tests grün (15 Dateien) |
| Integration (`pnpm vitest run`, Repo-Wurzel) | 632/635 Tests grün (53 Dateien); 3 Fehlschläge, alle vorbestehend |
| `pnpm typecheck` | sauber |
| iOS (`xcodebuild test`, iPhone 17 Pro Simulator) | 581/581 Tests grün (66 Suiten), genau die vier vorbestehenden Warnungen |

Die drei Fehlschläge sind namentlich:

- `tests/integration/domain-complete-session.test.ts` → `completeSession >
  beendet die eigene Session und haelt den Grund fest`
- `tests/integration/domain-complete-session.test.ts` → `completeSession >
  Idempotenz: ein zweiter Abschluss verschiebt den Zeitpunkt nicht`
- `tests/integration/api-workout-sets.test.ts` → `POST
  /api/v1/workout-sessions/{sessionId}/complete > beendet die eigene
  Session`

Alle drei an derselben Ursache: der Check-Constraint
`workout_sessions_completed_after_start` reagiert auf einen Uhrenversatz
zwischen Host und Docker, nicht auf diesen Bauabschnitt — vorbestehend,
unverändert von Aufgabe 1 bis 10. Kein Fehlschlag außerhalb dieser beiden
Dateien.

Die vier vorbestehenden iOS-Warnungen: `SupabaseAuthBackend.swift:17`
(veralteter Initialisierer), `QRScannerController.swift:1`
(`@preconcurrency`), `:58` und `:63` (Erfassung von `AVCaptureSession` in
einer `@Sendable`-Closure). `xcodegen generate` hat `project.pbxproj` nicht
verändert.

## Migrationen in die Cloud — offen

Die lokale Supabase-Instanz steht auf `0043`. Die Cloud-Datenbank wurde in
dieser Aufgabe **nicht** angefasst — kein `supabase db push`, kein
`--linked`-Befehl, kein MCP-Werkzeug gegen die entfernte Datenbank. Das ist
eine bewusste Grenze dieser Aufgabe, keine Auslassung: das Schreiben in eine
fremde Datenbank ist eine nach außen wirkende Handlung, für die diese
Aufgabe kein Mandat hat.

**Wichtig für die Reihenfolge:** der neue Bootstrap (`GET /me/bootstrap`)
liest Spalten und Tabellen, die es ohne `0041`–`0043` nicht gibt
(`profiles.sex`, `.age_band`, `.height_cm`, `.training_goal`,
`.onboarding_completed_at`, `body_measurements`, `member_goals`). Ein
Deploy des Web-Codes vor den Migrationen scheitert am Dekodieren oder wirft
serverseitig einen Postgres-Fehler. Migration **vor** Deploy, wie schon in
`2026-09-01-gesamtfahrplan.md` §4f.

Vor dem Deploy, in dieser Reihenfolge:

1. **`supabase migration list` gegen die Cloud.** Erst messen, nicht glauben
   (§7 desselben Dokuments: *ist die Datenbank hinten oder vorn?*). Erwartet:
   `0001`–`0040` auf beiden Seiten gleich, `0041`–`0043` nur auf der Platte.
   Steht dort etwas anderes — insbesondere Cloud-Einträge ohne
   Platten-Gegenstück —, ist die Reihenfolge dieser Liste hinfällig und die
   Lage neu zu beurteilen, bevor irgendetwas geschrieben wird.

2. **`--dry-run`, geprüft gegen die drei Dateien selbst.** Erwartet genau
   `0041`–`0043` und rein additiv, ohne eine einzige zerstörende Anweisung
   und ohne Berührung von `workout_*`:
   - **Fünf Enums:** `member_sex`, `age_band`, `training_goal` (`0041`),
     `goal_kind`, `goal_status` (`0043`)
   - **Zwei neue Tabellen:** `body_measurements` (`0042`), `member_goals`
     (`0043`) — dazu fünf neue, alle nullable Spalten an `profiles`
     (`0041`)
   - **Zwei Funktionen:** `is_valid_goal_value`, `set_member_goal` (beide
     `0043`)
   - **Sieben Policies:** vier auf `body_measurements`
     (select/insert/update/delete, `0042`), drei auf `member_goals`
     (select/insert/update, bewusst ohne delete — ein Ziel wird
     aufgegeben, nicht gelöscht, `0043`)
   - **Zwei Indizes:** der Teilindex `member_goals_one_active_per_kind`
     (genau ein aktives Ziel je Sorte) und ein Index auf
     `(user_id, created_at desc)` (beide `0043`) — `0041` und `0042`
     bringen keinen zusätzlichen Index, `0042` ausdrücklich mit Kommentar,
     weil der Unique-Constraint den Btree schon mitbringt

3. **Push.** Kommt die CLI von der Entwicklermaschine nicht an die
   Postgres-Strecke (§4d: `LegacyDbConfigLoginRoleNetworkError`, gesperrter
   Port 5432/6543 als naheliegende Erklärung), dann über den
   Supabase-MCP-Server und die Version anschließend von Hand normalisieren:
   `apply_migration` vergibt eigene Zeitstempel-Versionen
   (`20260915…` statt `0041`), die sonst dauerhaft als Drift gemeldet
   würden — danach auf `0041`–`0043` zurücksetzen, wie in §4d und §4f
   vorgemacht.

4. **`pnpm smoke:migrations`.** Erwartet `exit 0` und beide Seiten bei
   `0043`. Ein `exit 2` heißt „lief nicht" (z. B. derselbe
   Transportfehler wie unter Punkt 3) und ist von einem `exit 1`
   („Drift") zu unterscheiden.

Erst danach der Web-Deploy, danach der iOS-Build — dieselbe Reihenfolge, aus
demselben Grund, wie in `2026-09-09-home-profil-abnahme.md` Punkt 0
festgehalten.

## Die vierzehn Schritte

1. **Neues Konto registrieren.** Nach dem Code erscheint das Onboarding, vor
   jedem Studio. „Später" auf Schritt 1: Home ohne Ziele, Nachholkarte da;
   die App startet danach **ohne** Onboarding.
2. **Bestandskonto anmelden.** Das Onboarding erscheint genau einmal.
3. **Alle fünf Schritte ausfüllen.** Home zeigt „Ziel 3 Tage", die Zielzeile,
   die Gewichtskarte mit dem Eintrag von heute; Profil zeigt alle Werte.
   Zusätzlich zu prüfen: das RastRad auf Schritt 2 (Gewicht) und Schritt 5
   (Zielgewicht) sowie im Eintragen-Sheet — die Ziffern müssen sichtbar sein
   und sich scrollen lassen. Das konnte in diesem Bauabschnitt nicht per
   Render geprüft werden (Werkzeuggrenze: `ImageRenderer` zeichnet den
   Inhalt eines `ScrollView`/`List` nicht), nur der Akzentstrich war in den
   angesehenen Renderings zu sehen.
4. **Schritt 2 ohne Gewicht.** Schritt 5 fehlt; Home zeigt die Zeile
   „Gewicht eintragen" statt der Karte.
5. **Flugmodus auf „Los geht's".** Banner nennt, was gespeichert ist und was
   nicht; Flugmodus aus, „Erneut versuchen" holt nur das Fehlende nach; kein
   zweites `onboardingDone` (Serverlog).
   Onboarding: Profil gespeichert, Gewicht scheitert (z. B. Flugmodus nach
   dem ersten Schreibvorgang) — „Später" führt auf Home, dort steht die
   Nachholkarte oder die Karte.
6. **Wochenziel 3, zwei Trainingstage.** Zielzeile „2 von 3", zwei Striche
   gefüllt — **die Flamme zählt unverändert**, die Fußnote auch. Dritter
   Tag: „3 von 3 · Ziel erreicht", Flamme unverändert.
7. **Gewicht eintragen, dann denselben Tag noch einmal.** Ein Punkt, ersetzt.
   Verlauf zeigt ihn, Wischen löscht ihn.
8. **Zielgewicht erreichen.** Eintrag unter der Marke: Karte zeigt den
   Haken; Profil zeigt kein Zielgewicht mehr; „Neues Ziel setzen" öffnet das
   Sheet.
9. **Als Trainer im Portal:** Überblick unverändert, keine Spur von Gewicht
   oder Zielen.
10. **Studio verlassen, Home öffnen.** Gewichtskarte und Verlauf bleiben;
    Zielzeile fehlt (keine Woche ohne Zeitzone), Wochenziel steht weiter im
    Profil.
11. **Jede Angabe im Profil entfernen.** Danach steht „—", Home zeigt die
    Nachholkarte, wenn kein Ziel mehr aktiv ist.
    Eine Profilangabe übernehmen: das Sheet schließt, du bleibst im
    Profil-Tab, kein Ladebildschirm.
12. **Dynamic Type XXL** auf Onboarding 1 und 3, Home, Gewichtsverlauf,
    Profil. Zusätzlich zu prüfen: der Block „Deine Ziele" auf Home und die
    Profilzeilen setzen — wie der Rest von Home — feste Schriftgrößen statt
    skalierender; auf Clipping achten. Ebenso am rechten Rand des
    Gewichtsverlaufs: das rechte Datumslabel der x-Achse kann abgeschnitten
    sein (geerbter Achsen-Code aus `UebungsfortschrittView`).
13. **VoiceOver** auf dem Gewichtsverlauf: Kurve und Rohwerte erreichbar; die
    Zielzeile im Kalender wird als ein Satz gelesen.
14. **Reduce Motion:** Schrittwechsel und Sheet ohne Bewegung, nichts fehlt.

## Abweichungen von Artboard und Plan, bewusst

| Abweichung | Grund |
| --- | --- |
| Onboarding4-Einleitung ersetzt: nicht „Die Serie auf Home zählt gegen dieses Ziel." (Artboard, `gen.py:288`), sondern „Auf Home steht es als eigene Zeile unter deiner Serie." | Der Artboard-Satz widerspricht Spec §9 Punkt 5: die Serie hängt nicht am Wochenziel, beide laufen nebeneinander. `gen.py` und die Artboards wurden nicht selbständig geändert — die Entscheidung, ob der Generator angepasst wird, liegt beim Auftraggeber. |
| `updateProfile`s Rückgabewert ist `ProfilAntwort` (die sechs Profil-Felder), nicht der erweiterte Bootstrap-`Member` | `PUT /me/profile` liefert weiterhin das Profil, keine Ziele und kein `latestWeight` — eine Dekodierung als erweitertes `Member` würde an fehlenden Pflichtfeldern scheitern. |
| `tageProWoche` in `OnboardingAntworten` ist ein optionales `Int?`, nicht der angezeigte Standardwert 3 | Eine unveränderte Vorgabe ist keine Antwort — aber ein Mitglied, das auf Schritt 4 bewusst mit „Weiter" bei 3 bestätigt, hat eines gegeben. Der angezeigte Standard lebt nur in der Ansicht. |
| Der Wiederholungsversuch nach einem Fehlschlag merkt sich fehlgeschlagene Schreibvorgänge (`OnboardingSchreibvorgang`), nicht Bildschirme | `.koerper` hätte sowohl Größe (Profil-Schreibvorgang) als auch Gewicht (Messwert-Schreibvorgang) bedeuten können — bei Größe+Gewicht ohne weitere Angaben hätte ein bildschirmbasiertes Modell den fehlgeschlagenen Profil-Schreibvorgang beim Retry übersprungen und `onboardingDone` nie gesetzt. |
| Die Nachholkarte auf Home (Onboarding als Sheet) sendet kein zweites `onboardingDone` | Aus dieser Karte heraus ist das Onboarding serverseitig schon abgeschlossen; ein erneutes Setzen würde nur den Abschlusszeitpunkt überschreiben. |
| Der Messtag ist der Ortstag des Geräts (`TimeZone.current`), nicht die Studio-Zeitzone | Spec 3.2: „Der Client liefert den Ortstag" — Körperdaten hängen an der Person, nicht am Studio (0042-Kommentar). |
| Die Zeile „Ziel erreicht" lebt nur im Speicher (`VerlaufStore`) und ist nach einem Neustart weg | Der erreichte Zustand kommt aus der Antwort des Eintragens (`goalReached`), nicht aus einer eigenen Serverspalte; ein Neuladen zeigt wieder die Karte mit dem laufenden Abstand, nicht falsch, nur nicht mehr hervorgehoben. |
| Fünf Kommentare umformuliert, ohne Bewertungsvokabular, einer davon plan-vorgeschrieben | Die Regel „nirgends, auch nicht in Kommentaren" gilt streng, auch für Verneinungen. Betroffen: `Stammdaten.swift`, `Messwert.swift` (Dokumentationskommentar zu `MeasurementsResponse.Summary`), `packages/domain/src/measurements.ts` (dieser Wortlaut stand so im Plan), `OnboardingSchritte.swift` und `HomeZiele.swift` — alle fünf sagen jetzt nur noch, dass hier ein eingetragener Wert oder eine Differenz steht, ohne die Bewertungsbegriffe selbst zu nennen. |
