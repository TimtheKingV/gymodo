# Testnotizen 13.10. – Gewicht in der Pause, Knopfreihenfolge, Start-Drawer nach Übungswechsel

## Kontext

- **Quelle:** Testsitzung `~/Downloads/2026-10-13-1429/sitzung.md` mit 3 Screenshots, iPhone14,4, iOS 26.6.2, Stand `8261d6f`, 3 Notizen.
- **Inhalt:** Alle betreffen `GeraetView`:
  - #1: Das Gewicht im Drawer „Gewicht für den nächsten Satz“ soll auch beim Wegwischen gelten, nicht erst mit „Übernehmen“.
  - #2: In der Pause steht „Nächster Satz“ über „Nächste Übung“.
  - #3: Über „Weitere Übung an dem Gerät“ fehlt bei einer neuen Übung die Einweisung.

**Vorgehen:**
- Ablauf nach Skill `finetuning`, für iOS übertragen wie in `2026-10-12-testnotizen-member-app.md`.
- Worktree `.claude/worktrees/testnotizen-1310`, Branch `claude/testnotizen-1310-geraet` von `master`.
- Je Etappe zuerst ein roter Test (Swift Testing), dann die Umsetzung, dann ein Commit.
- Kommentare verweisen auf „(Testnotiz 13.10., #n)“.

### Rückfragen (beantwortet)

- **A, #1:** Das Rad schreibt bei jedem Einrasten direkt ins Modell. Wegwischen behält den Wert. Der Knopf schließt nur noch und heißt „Fertig“.
- **B, #3:** Nach der Wahl kommt derselbe Start-Drawer wie aus der Geräteliste. Bei einer neuen Übung: Einweisung → ggf. Einstellung → Startwerte → Countdown. Bei einer bekannten Übung: Startwerte → Countdown.

## Etappe 1 – Gewicht in der Pause gilt sofort (#1)

- **Ursache:** `GewichtAendernSheet` dreht einen eigenen `@State entwurf`. Ins Modell schreibt nur „Übernehmen“. Das war Absicht (Testnotiz 11.10., #12): Ein weggewischter Drawer sollte nichts verändern. Am iPhone wischt man den Drawer aber weg und erwartet, dass das Gewicht gilt.
- **Änderung:**
  - Das Rad bindet wie `WertZeile` über `Binding(get: modell.belastung, set: modell.belastungGewaehlt)`. Der Entwurf fällt weg.
  - Der Knopf heißt „Fertig“ und schließt nur.
  - Gestaltung: Er bleibt `PrimaryButton`. Er ist die einzige Aktion im Drawer, und an derselben Stelle stand vorher „Übernehmen“.
- **Test:** Das Schreiben selbst (`belastungGewaehlt`) gibt es schon. Den Charakterisierungstest dazu gibt es ebenfalls seit 11.10.: `einInDerPauseGewaehltesGewichtGiltFuerDenNaechstenSatz` hält fest, dass die Pause weiterläuft und der nächste Satz das neue Gewicht trägt. Kein neuer Test. Die Bindung im Drawer prüft der Sichtcheck.

## Etappe 2 – „Nächster Satz“ über „Nächste Übung“ (#2)

- **Ursache:** `PausenRad` stellt „Nächster Satz“ nach unten, damit der Daumen dort bleibt, wo „Satz N sichern“ lag (Testnotiz 06.10., #7).
- **Änderung:** Die beiden Knöpfe tauschen die Plätze. Der Kommentar nennt die neue Begründung: Der Satz kommt vor der Übung, so wie man liest.
- **Test:** keiner. Reine Reihenfolge fester Knöpfe, das prüft der Sichtcheck.

## Etappe 3 – Start-Drawer nach „Weitere Übung an dem Gerät“ (#3)

- **Ursache:** `UebungWechselnSheet` ruft nur `modell.uebungWechseln(zu:)`. Danach stehen sofort die Räder da. `UebungsstartSheet` (Einweisung, Einstellung, Startwerte, Countdown) hängt nur an der Wahl in `TrainingRootView`.
- **Änderung:**
  - `GeraetModel.uebungStarten(mit:)` übernimmt die Startwerte des Drawers und setzt die Phase auf `.bereit` (Countdown). `init` nutzt denselben Weg, damit beide Starts gleich sind.
  - `GeraetScreen` öffnet nach der Wahl, im `onDismiss` des Wechsel-Sheets, `UebungsstartSheet` mit demselben Modell. Zwei Sheets nacheinander gehen nur über `onDismiss`, wie bei der Abschlussfrage.
  - „Übung starten“ ruft `uebungStarten(mit:)`. Schließen lässt die Räder der neuen Übung stehen. Der Erstkontakt ist dann nicht erledigt und kommt beim nächsten Mal wieder.
  - Der Mitschnitt beginnt mit `uebungWechseln` und beginnt nach dem Countdown neu (`countdownBeenden`). Das ist derselbe Weg wie bei jedem Wechsel.
- **Test zuerst:** `GeraetModelTests`: Nach `uebungWechseln(zu: "e2")` und `uebungStarten(mit:)` ist die Phase `.bereit`, Belastung und Umfang stammen aus den Startwerten, und ein später Vorschlag ersetzt sie nicht.

## Geprüft

- **Reihenfolge der Commits:** Etappe 3 zuerst, weil ihr Test als einziger neu war. Danach 1 und 2.
- **Swift:** Der neue Test `nachDemWechselStartetDerDrawerMitCountdown` war vorab rot (`uebungStarten` fehlte) und ist danach grün. Volle Suite `xcodebuild test` grün, 1082 Tests in 110 Suites (vorher 1081). Simulator per id (`A2FB7461-…`), weil zwei „iPhone 17 Pro“ existieren.
- **Vitest und Typecheck:** Domain 332, Web 306 grün. `pnpm typecheck` grün. Kein TypeScript geändert.
- **Integration:** Das gemeinsame lokale Supabase stand bei 0051. Mit `supabase migration up --local` auf 0052 gebracht, danach 821 von 822 grün. Rot bleibt `api-workout-sets` (`workout_sessions_completed_after_start`). Das scheitert laut Notizen auch auf sauberem master und hat mit dem Diff nichts zu tun, der Branch ändert außerhalb von `apps/ios-member` nichts.
- **E2E und Produktionsbau:** nicht gelaufen, kein Web-Code geändert.
- **Am Gerät ansehen:**
  - #1: Drawer „Gewicht für den nächsten Satz“ drehen und wegwischen. Der nächste Satz muss das neue Gewicht tragen. „Fertig“ schließt nur.
  - #2: In der Pause steht „Nächster Satz“ oben, „Nächste Übung“ darunter.
  - #3: An der Ab-/Adduktorenmaschine nach „Übung abschließen“ → „Weitere Übung an dem Gerät“ eine nie trainierte Übung wählen. Erwartet: Einweisung, ggf. Einstellung, Startwerte, Countdown. Eine bekannte Übung zeigt nur die Startwerte und dann den Countdown. Schließen des Drawers lässt die Räder der neuen Übung stehen.
  - #3: Hinter dem Drawer zeigt die Seite schon die Räder der neuen Übung. Bei der Einweisung (volle Höhe) sieht man das nicht, bei den Startwerten allein schon.
