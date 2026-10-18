# Satztakt für alle Befestigungsarten Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Wiederholungszahl am Satzende liegt bei Kurzhantel, Stapel und Langhantel höchstens um 1 neben der Wahrheit (Blindprüfung gepoolt ≥ 90 %), ohne Kurzhantel und klare Stapel-Sätze zu verschlechtern.

**Architecture:** `Satztakt` (Kette sich gleichender Abschnitte) bekommt ein Profil je Befestigungsart (`TaktProfil`), `kurzhantel` behält seine heutigen Werte. Ein Rückfall schätzt aus Dauer und Takt, wenn die Kette versagt. Der `ZaehlerKoordinator` ruft `Satztakt` für alle Arten mit Profil auf. Alles wird offline gegen die Aufnahmen gemessen (`swift test`), mit fester Aufteilung in Abstimmung und Blindprüfung.

**Tech Stack:** Swift 6 / Swift Testing / SwiftPM (`apps/ios-member/Packages/Sensorik`), Python 3 (Werkbank `tools/sensorik-sim`, nur zum Probieren), xcodegen.

**Spec:** `docs/superpowers/specs/2026-10-18-satztakt-alle-befestigungsarten-design.md`

## Global Constraints

- Eigener Worktree unter `.claude/worktrees/` von `origin/master`; `.env` und `apps/ios-member/Config.xcconfig` hineinkopieren. Die Aufnahmen vom 18.10. (`data/sensoraufnahmen/2026-10-18-*`, `saetze-2026-10-18.csv`) liegen unversioniert im Hauptverzeichnis und müssen in den Worktree kopiert werden.
- Nur eine Session baut iOS zur selben Zeit: vor jedem `xcodebuild` `pgrep -lx xcodebuild`. Simulator per ID: `-destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707'`.
- Nach Änderungen an `project.yml` oder Dateien im App-/Test-Target: `cd apps/ios-member && xcodegen generate` und `project.pbxproj` mit committen.
- Commits deutsch mit ae/oe/ue, Form `feat(sensorik): …` / `fix(…)` / `test(…)` / `docs(…)`, ein Commit je Schritt. Trailer exakt: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` und `Claude-Session: https://claude.ai/code/session_0184T485mKrkh2scF9YGThFn`. Nach jedem Commit `git log -1 --format=%B` prüfen.
- Swift-Kommentare ASCII (ae/oe/ue/ss), sie nennen einen Grund. Tests mit Swift Testing (`@Test`, `#expect`, `#require`). Markdown mit echten Umlauten.
- `Satztakt` bleibt rein: keine Uhr, kein Zufall.
- Ziel ±1 (kein Gütetor): |gezählt − wahr| ≤ 1; Verdopplung und Verpassen zählen gleich.
- Aufteilung (fest): je Art die Aufnahmen mit `fuerZaehler == true`, nach Ordnername sortiert; Index 0, 2, 4, … = `abstimmen`, Index 1, 3, 5, … = `blind`. Kurzhantel-Sätze vom 16.10. sind bereits früher abgestimmt und zählen nicht zur Blindprüfung (nur zum Regressionsschutz).
- Je Art höchstens 3 abgestimmte Parameter, der Rest geteilt. Die Blindprüfung wird erst nach dem Einfrieren der Parameter (Task 5 und 6, jeweils Schritt „Einfrieren“) ausgewertet und nur einmal.
- Rechenzeit: höchstens eine Takt-Auswertung zugleich, abseits des Main Actors; keine neue Last gegenüber heute.
- Nicht pushen, bis Tim es sagt.

## Review Focus

1. Satz kürzer als `mindestDauer` (5 s) oder Ruhe: `Satztakt.auswerten` und der Rückfall liefern `nil`, nichts stürzt, `ergebnis()` fällt auf die Live-Zahl zurück (Task 4, 6).
2. Satz mit Pause mittendrin (Kniebeuge 2, `2026-10-18-1658-03`): die Kette reißt in zwei Hälften; die Zahl soll die Summe beider Hälften treffen, nicht nur die längere (Task 4).
3. Sehr langer Satz (> 3 Minuten, > 9 000 Messwerte): Auswertung bleibt unter 2 s im Release-Build und `satzMesswerte` wächst nicht unbegrenzt (Task 6).
4. Rate 100 Hz statt 50 (Diagnose-Umschaltung): Profilgrenzen rechnen in Sekunden, nicht in Abtastwerten (Task 3).
5. Art ohne Takt-Profil (`hebelarm`, `kabelgriff`, `koerper`): bleibt bei der Live-Zahl, kein Absturz, keine neue `algo`-Kennung (Task 6).

---

### Task 1: Aufnahmen vom 18.10. einlesen

**Files:**
- Create: `tools/sensorik-sim/eintragen.py`
- Modify: `data/sensoraufnahmen/korrekturen.json`, `data/sensoraufnahmen/README.md`
- Add (unverändert aus dem Hauptverzeichnis): `data/sensoraufnahmen/2026-10-18-*/`
- Test: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/AufnahmenTests.swift`

**Interfaces:**
- Produces: In `korrekturen.json` ein Eintrag je Ordner `2026-10-18-HHMM-NN`: `was`, `befestigung`, `befestigungsart` (aus `aufnahme.json`), `repsWahr` (aus `saetze-2026-10-18.csv`, Spalte `reps_wahr`, zugeordnet über `set_id` = `kontext.setId` in `aufnahme.json`), `fuerZaehler: true` für die 36 Sätze mit `abschluss == gesichert` und Wahrheit, sonst `false` mit `grund`.

- [ ] **Step 1: Failing test** `heute18OktoberIstEingetragen` in `AufnahmenTests.swift`: lädt `Korrekturen.laden()`, erwartet für jeden Ordner `2026-10-18-*` mit `messwerte.csv` einen Eintrag, genau 36 Einträge mit `fuerZaehler == true`, und dass `2026-10-18-1702-01` (`repsWahr` 25) die Art `langhantel` hat.
- [ ] **Step 2:** `swift test --package-path apps/ios-member/Packages/Sensorik --filter heute18OktoberIstEingetragen` → FAIL (Einträge fehlen).
- [ ] **Step 3: `tools/sensorik-sim/eintragen.py`** (Standardbibliothek, `python3 -I`) schreibt die Einträge in `korrekturen.json` (bestehende Einträge unverändert, Einrückung 2, UTF-8 mit Umlauten). `was` = Übungsname aus `kontext.exerciseName`; für `1702-01` zusätzlich `grund`: „in der App als Langhantelrudern Satz 3 geführt, laut Testnotiz 18.10. High-Bar-Kniebeuge Satz 3“. Abgebrochene Aufnahmen: `fuerZaehler: false`, `grund`: „abgebrochen, kein Satz“.
- [ ] **Step 4:** Skript laufen lassen, Test erneut → PASS.
- [ ] **Step 5:** README-Abschnitt „Stand 18. Oktober 2026“ ergänzen (36 echte Sätze, Geräte, Hinweis Hintergrund-App Latzug 2/3 und Pause Kniebeuge 2). Alle Ordner `2026-10-18-*` mit `git add` aufnehmen.
- [ ] **Step 6:** `swift test --package-path apps/ios-member/Packages/Sensorik` (komplett grün, der Gütebericht wird neu geschrieben) und committen: `docs(sensorik): Aufnahmen vom 18.10. mit Wahrheit eingetragen`.

---

### Task 2: Messlatte — Takt-Lauf, Aufteilung, Bericht

**Files:**
- Create: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/TaktBericht.swift`, `.../TaktBerichtTests.swift`
- Modify: `.../AufnahmeLauf.swift`
- Output: `data/sensoraufnahmen/taktbericht.md`

**Interfaces:**
- Produces in `AufnahmeLauf`: `static func takt(ordner: URL, art: Befestigungsart) throws -> Int?` (Zahl aus `Satztakt` auf dem ganzen Satz, `nil` ohne Ergebnis).
- Produces: `enum Gruppe { case abstimmen, blind, frueherAbgestimmt }`; `struct TaktZeile { ordner, art, wahr, gezaehlt: Int?, gruppe: Gruppe }`; `TaktBericht.zeilen() throws -> [TaktZeile]` (nur `fuerZaehler`; `frueherAbgestimmt` für `kurzhantel` aus `2026-10-16-*`; Aufteilungsregel aus Global Constraints); `TaktBericht.quote(_ zeilen: [TaktZeile]) -> (n: Int, exakt: Double, einsGenau: Double)` (`nil` zählt als falsch); `TaktBericht.markdown(_ zeilen: [TaktZeile]) -> String` (Tabelle je Art × Gruppe, gepoolt und je Art, plus Liste der Sätze außerhalb ±1).

- [ ] **Step 1: Failing tests** in `TaktBerichtTests.swift`: `aufteilungAbwechselndNachOrdnername` (synthetische Namen a, b, c, d, e → abstimmen, blind, abstimmen, blind, abstimmen), `quoteZaehltNilAlsFalsch` (wahr 10 / gezählt 9, 11, 12, nil → einsGenau 0,5), `kurzhantelVom16OktoberIstFruehAbgestimmt`.
- [ ] **Step 2:** Tests laufen lassen → FAIL.
- [ ] **Step 3:** `AufnahmeLauf.takt` und `TaktBericht` implementieren; der Bericht schreibt `taktbericht.md` über einen Test `berichtSchreiben` (wie `GueteberichtTests.berichtSchreibenUndFreigegebeneArtenPruefen`).
- [ ] **Step 4:** Tests → PASS. Baseline: `taktbericht.md` mit dem heutigen `Satztakt` (nur `kurzhantel`-Parameter, alle Arten) erzeugen, committen: `test(sensorik): Messlatte fuer Satztakt, Aufteilung und Baseline`. Die Baseline-Zahlen stehen oben in der Datei; spätere Aufgaben vergleichen dagegen.

---

### Task 3: `TaktProfil` je Befestigungsart

**Files:**
- Create: `apps/ios-member/Packages/Sensorik/Sources/Sensorik/TaktProfil.swift`
- Modify: `.../Satztakt.swift`
- Test: `.../SatztaktTests.swift`

**Interfaces:**
- Produces: `public struct TaktProfil: Sendable, Equatable { public let taktMin, taktMax, kappFaktor, kandidatAnteil, gleichheitMin, abstandMin, abstandMax, mindestDauer: Double; public static func fuer(_ art: Befestigungsart) -> TaktProfil? }`. `fuer(.kurzhantel)` hat exakt die heutigen Werte (1,2 / 3,0 / 1,5 / 0,85 / 0,9 / 0,75 / 1,3 / 5,0); `stapel` und `langhantel` starten mit denselben Werten; `hebelarm`, `kabelgriff`, `koerper` → `nil`.
- Produces: `Satztakt.auswerten(_ messwerte: [SensorMesswert], rateHz: Double = 50, profil: TaktProfil = .fuer(.kurzhantel)!) -> Ergebnis?` und `Satztakt.algo(fuer art: Befestigungsart) -> String` (`kurzhantel` → `"kurzhantel/takt2"`, sonst `"\(art.rawValue)/takt1"`). `Satztakt.algo` (ohne Argument) bleibt als `kurzhantel/takt2`.

- [ ] **Step 1: Failing tests:** `kurzhantelProfilHatDieHeutigenWerte` (alle acht Werte), `artenOhneProfilHabenKeins` (`hebelarm` → `nil`), `profilgrenzenRechnenInSekunden` (derselbe synthetische Satz bei 50 und 100 Hz ergibt dieselbe Zahl; Review Focus 4).
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3:** Die privaten Konstanten in `Satztakt` durch `profil.*` ersetzen; Dauer-Konstanten (`tiefpassHz`, `langsamS`) bleiben. Alle bestehenden `SatztaktTests` laufen unverändert und bleiben grün (Regressionsschutz Kurzhantel).
- [ ] **Step 4:** `swift test --package-path apps/ios-member/Packages/Sensorik` → PASS; `taktbericht.md` neu erzeugen, `kurzhantel`-Zeilen identisch zur Baseline.
- [ ] **Step 5:** Commit `refactor(sensorik): Satztakt mit Profil je Befestigungsart, Kurzhantel unveraendert`.

---

### Task 4: Rückfall bei fehlender oder zu kleiner Kette

**Files:**
- Modify: `.../Satztakt.swift`
- Test: `.../SatztaktTests.swift`

**Interfaces:**
- Consumes: `TaktProfil`, `Ergebnis`.
- Produces: `Satztakt.auswerten` liefert bei fehlender Kette oder einer Kette, die offensichtlich zu klein ist (Dauer der Kette < 50 % der Zeit, in der die Takt-Hüllkurve über 60 % ihres Spitzenwerts liegt), ein `Ergebnis` mit `anzahl = round(Aktivdauer / takt)` und `guete` unter 0,5. `Ergebnis.guete < 0.5` ist das Zeichen für „unsicher“ (`signalSchwach`). Die genaue Schwelle stellt der Bauende nach Messung an der Abstimmungsgruppe ein.

- [ ] **Step 1: Failing tests:** `schraegbankSaetzeBekommenEineZahl` (Argumente `2026-10-18-1608-01`, `1611-02`, `1614-02`; erwartet `Satztakt.auswerten` ≠ `nil` und `anzahl > 2`, mit `profil: .fuer(.kurzhantel)!`), `pauseImSatzZaehltBeideHaelften` (`2026-10-18-1658-03`, wahr 30, `abs(anzahl − 30) <= 3` als Mindestanforderung für die Summe beider Hälften; Review Focus 2), `ruheGibtWeiterNichts` (bestehender Test bleibt), `zuKurzGibtNichts` (bleibt; Review Focus 1).
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3:** Rückfall in `Satztakt.auswerten` einbauen; `Ergebnis.guete` trägt die Sicherheit.
- [ ] **Step 4:** Alle `SatztaktTests` und `taktbericht.md`: `kurzhantel`-Zeilen aus 16.10. nicht schlechter als Baseline (Zahl der Sätze innerhalb ±1 gleich oder höher).
- [ ] **Step 5:** Commit `feat(sensorik): Satztakt schaetzt aus Aktivdauer, wenn die Kette versagt`.

---

### Task 5: Stapel abstimmen

**Files:**
- Modify: `.../TaktProfil.swift`
- Test: `.../TaktBerichtTests.swift`

**Interfaces:**
- Consumes: `TaktBericht.zeilen/quote`, `TaktProfil.fuer(.stapel)`.

- [ ] **Step 1: Failing test** `stapelAbstimmungImZiel`: `quote` der Gruppe `abstimmen` für `stapel` hat `einsGenau >= 0.9`. Aktueller Stand laut Baseline steht in `taktbericht.md`.
- [ ] **Step 2:** → FAIL (erwartet; Baseline zeigt die Lücke).
- [ ] **Step 3:** Parameter von `TaktProfil.fuer(.stapel)` an der Gruppe `abstimmen` einstellen. Ausgangspunkte aus der Auswertung vom 18.10.: Takt 1,2–1,4 s bei Adduktoren/Abduktoren (`taktMin` unter 1,2 prüfen), Rand-Verluste bei Beinpresse und Abduktoren (zuerst `gleichheitMin` und `abstandMin/Max`). Höchstens 3 Parameter ändern.
- [ ] **Step 4: Einfrieren:** Parameter in `TaktProfil.swift` mit Kommentar (Datum, Gruppe, ohne Blindsätze). Erst danach `stapel` der Gruppe `blind` auswerten, Zahlen in `taktbericht.md`. Kein weiteres Abstimmen nach diesem Blick.
- [ ] **Step 5:** Test `stapelBlindEinsGenau` dokumentiert den erreichten Wert als Untergrenze (`>=` erreichter Wert abgerundet auf ganze Prozent), nicht als Ziel; zweiter Test `klareStapelSaetzeBleibenGut` (Bauchbeugen `1632-01`, `1634-01`, `1635-01`, Kabelrudern `1708-01`, `1709-01`, Latzug `1626-01`: je ±1).
- [ ] **Step 6:** Alle Tests grün, Commit `feat(sensorik): Satztakt-Profil fuer Stapel, Abstimmung und Blindwert im Bericht`.

---

### Task 6: Langhantel abstimmen

**Files:**
- Modify: `.../TaktProfil.swift`
- Test: `.../TaktBerichtTests.swift`

- [ ] **Step 1: Failing test** `langhantelAbstimmungImZiel` wie in Task 5 für `langhantel` (Rudern, Kniebeuge, Bankdrücken).
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3:** Abstimmen an der Gruppe `abstimmen`, Ausgangspunkte: Rudern Satz 1 (11 von 30, Rückfall greift nicht), Kniebeuge 25/30 und 26/28 (Ränder), Bankdrücken (langsam, Takt 2,6–2,8 s bei 5,4 s/Wdh, `taktMax` und Rückfall). Höchstens 3 Parameter.
- [ ] **Step 4: Einfrieren** und danach einmal die Gruppe `blind` auswerten, wie Task 5. Wird ±1 bei Bankdrücken nicht erreicht, steht das im Bericht; der Zähler liefert die Schätzung mit `guete < 0,5` (Task 4).
- [ ] **Step 5:** Gepoolte Auswertung: Test `gepooltBlindImZiel` (`quote` über alle `blind`-Zeilen aller Arten) wird als `withKnownIssue` markiert, falls < 0,9, sonst als normaler Test.
- [ ] **Step 6:** Commit `feat(sensorik): Satztakt-Profil fuer Langhantel, gepoolte Blindpruefung im Bericht`.

---

### Task 7: Koordinator ruft Satztakt für alle Arten mit Profil

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/Sensor/ZaehlerKoordinator.swift`
- Test: die vorhandenen Koordinator-Tests (`grep -rl ZaehlerKoordinator apps/ios-member/FitnessMemberTests`, z. B. `SensorAufnahmeKoordinatorTests.swift`)

**Interfaces:**
- Consumes: `TaktProfil.fuer(_:)`, `Satztakt.auswerten(_:rateHz:profil:)`, `Satztakt.algo(fuer:)`.

- [ ] **Step 1: Failing tests:** `stapelSatzEndetMitTaktZahl` (Aufnahme `2026-10-18-1642-01` als Eingang → `ergebnis().gezaehlt` innerhalb ±1 von 20 und `repEvents.algo == "stapel/takt1"`), `hebelarmBleibtBeiDerLiveZahl` (Review Focus 5), `langerSatzBleibtSchnell` (synthetisch 10 000 Messwerte → Auswertung < 2 s im Release; Review Focus 3).
- [ ] **Step 2:** → FAIL (`xcodebuild test`, ein Build zugleich).
- [ ] **Step 3:** Die drei Stellen `art == .kurzhantel` (Zeilen 72 und 166 in `ZaehlerKoordinator.swift`, Kommentar zu `satzMesswerte`) durch `TaktProfil.fuer(art) != nil` ersetzen; `RepEvents.algo` aus `Satztakt.algo(fuer: art)`. `satzMesswerte` wird nur für Arten mit Profil gesammelt; Obergrenze für die Länge (z. B. letzte 4 Minuten), damit der Speicher nicht unbegrenzt wächst.
- [ ] **Step 4: Hintergrund-Sätze:** Aufnahmen `2026-10-18-1628-01` und `1630-01` durch `AufnahmeLauf.zaehlen` und durch den Koordinator spielen. Warum liefert die Live-Zahl dort nichts (Spec: Pakete sind da)? Ist es ein Fehler im Hintergrund-Pfad, beheben und mit einem Test pinnen; sonst im Bericht als „kein Fehler, Satzende-Zahl deckt es ab“ festhalten.
- [ ] **Step 5:** `swift test` und `xcodebuild test -scheme FitnessMember -destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707'` grün.
- [ ] **Step 6:** Commit `feat(ios): Satzende-Zahl per Takt auch fuer Stapel und Langhantel`.

---

### Task 8: Bericht und Abschluss

**Files:**
- Modify: `data/sensoraufnahmen/README.md`, `data/sensoraufnahmen/taktbericht.md`, `tools/sensorik-sim/README.md`

- [ ] **Step 1:** `taktbericht.md` mit den endgültigen Zahlen je Art × Gruppe (gepoolt und je Art), der Liste der Sätze außerhalb ±1 und dem Satz „Gilt für diese Person, diese Geräte, diesen Tag; Beinpresse/Waden/Kniebeuge haben 2–4 Sätze, die Blindprüfung ist dort nur ein Hinweis“.
- [ ] **Step 2:** README-Abschnitt „Stand 18.10.“ ergänzen (Ergebnis, was nicht erreicht wurde, was als Nächstes neue Aufnahmen bräuchte).
- [ ] **Step 3:** Voller Lauf: `swift test --package-path apps/ios-member/Packages/Sensorik`, `xcodebuild test …` wie oben.
- [ ] **Step 4:** Commit `docs(sensorik): Bericht Satztakt fuer alle Befestigungsarten`.
