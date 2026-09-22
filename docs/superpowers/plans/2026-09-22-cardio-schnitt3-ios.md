# Cardio Schnitt 3: iOS — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Member-App liest die API aus Schnitt 1 (`load`, `volume`, `secondaryLoad`, `loadUnit`, `volumeKind`, `category`) und zeigt an einem Laufband Tempo in km/h, Neigung in % und Minuten; an einer Beinpresse sieht der Geräte-Screen Pixel für Pixel aus wie heute. Die Gerätesuche trennt Kraft und Cardio. Der Abschluss schreibt „+0,5 km/h bei 6,0 %".

**Architecture:** Kein neuer Screen. Ein Swift-Spiegel von `belastung.ts` (`Belastung.swift`: Einheiten, Umfangsarten, Formatierung) ist der einzige Ort, der Einheiten kennt; alles andere ist Umbenennung entlang derselben Nahtstellen wie in Schnitt 1. Die Nebenbelastung bekommt **kein drittes Rad**, sondern einen `Stepper44` unter den beiden Rädern: sie ändert sich selten, ein Stepper ist 44 pt hoch und trifft halbe Prozent, wo ein drittes Rad auf einem iPhone mini das Belastungsrad abschnitte. Das Umfangsrad zeigt Sekunden als „20:00" und Meter mit Tausenderpunkt; seine Spalte wird für diese Arten breiter.

**Tech Stack:** Swift 6 / SwiftUI / Swift Testing / XcodeGen (`apps/ios-member`). Keine Änderung an `packages/domain` oder `apps/web`.

**Quelle:** `docs/superpowers/specs/2026-09-21-cardio-geraete-design.md`, Abschnitte 3.1b, 5.3, 6, 8, 9. Vorbild für Aufbau und Ton: `2026-09-15-schnitt3-satzpfad.md`.

**Voraussetzung:** Dieser Schnitt läuft auf dem Mac mit Xcode, nicht in der Cloud. Der Branch `claude/cardio-geraete-logik-u5bceq` (PR #25) trägt Schnitt 1 und 2; dieser Schnitt baut darauf auf. Live gehen alle drei zusammen (Spec Abschnitt 14).

## Global Constraints

- **Kommentare in Swift ohne Umlaute** (ASCII). Nutzertexte tragen Umlaute.
- **Kommentare begründen, sie beschreiben nicht.** Jeder Kommentar, der durch die Umbenennung falsch wird („Gewicht", „Wiederholungen" als Datenwort), wird im selben Task umgeschrieben. Betroffen sind mindestens: `WertZeile` (Spaltenbreite „Wiederholungen sind hoechstens zweistellig"), `Rastwerte`, `GeraetModel.gewichtVomNutzer`, `Zahlformat` („Gewichte tragen immer eine Nachkommastelle"), `VorschlagsAnzeige`.
- **Körpergewicht bleibt Körpergewicht.** `Messwert.weightKg`, `Ziele`, `GewichtEintragenSheet`, `GewichtsverlaufView`, `HomeZiele`, `ZielSheet`, `ProfilZeilen`, `OnboardingSchreiber`, `VerlaufStore.messwerte` und `Zahlformat.gewicht*` bleiben unangetastet. Die Umbenennung gilt der Trainingsbelastung.
- **Kein Zweig „wenn Cardio" in der Logik.** Die Einheit ist ein Wert, den Formatierer und Räder lesen. `category` liest nur `GeraeteAuswahl` (Spec 3.5). Die einzige Regel, die an der Umfangsart hängt, ist das Satzziel (Task 6), und sie steht mit Begründung an genau einer Stelle.
- **Design-Tokens aus `DesignSystem.swift`**, nie als Literal. Eine Akzentfläche pro Screen. Hit-Targets nie unter 44 pt.
- **Die App misst nichts** (Spec 4.3). Das Mitglied liest Minuten, Tempo und Neigung von der Geräteanzeige ab, wie das Gewicht vom Stapel. Kein laufender Timer.
- **Swift-Tests mit Swift Testing** als `struct`-Suite. Jede Ableitung kommt mit ihrem Test vor dem View, der sie benutzt.
- **Neue Swift-Dateien:** danach `xcodegen generate` in `apps/ios-member`. `git status` vor jedem Commit, `Package.resolved` bleibt unangetastet.
- **iOS-Tests:** in `apps/ios-member`
  `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
  Einzelne Suite: `-only-testing:FitnessMemberTests/<Suite>`. Vor dem vollen Build `df -h /`. Grün vor dem nächsten Task.
- **Ein Commit je Task**, deutsche Message (`feat(ios-member): …`), Trailer:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  ```
- **Sichtcheck nur gegen das lokale Backend** (`supabase start` + `pnpm --filter @fitretro/web dev`), nie gegen Produktion. Die Produktion trägt Migration 0045 erst nach dem Merge.

---

## Task 1: `Belastung.swift` — der Spiegel von `belastung.ts`

**Files:**
- Create: `FitnessMember/Workout/Belastung.swift`
- Create: `FitnessMemberTests/BelastungTests.swift`
- Modify: `FitnessMember/DesignSystem/Zahlformat.swift` (nur Ergänzung)

**Interfaces:**
```swift
enum LoadUnit: String, Codable, Equatable, Sendable, CaseIterable { case kg, watt, level, kmh, pct, rpm }
enum VolumeKind: String, Codable, Equatable, Sendable { case reps, seconds, meters }
enum Kategorie: String, Codable, Equatable, Sendable { case kraft, cardio }

extension LoadUnit {
    /// "kg", "W", "Level", "km/h", "%", "U/min" -- das Wort neben dem Rad.
    var kurz: String
    /// 1 fuer kg, kmh, pct; 0 fuer watt, level, rpm -- wie NACHKOMMASTELLEN in belastung.ts.
    var nachkommastellen: Int
}

extension Zahlformat {
    static func belastung(_ wert: Double, _ einheit: LoadUnit) -> String        // "80,0", "120", "8,5"
    static func belastungMitEinheit(_ wert: Double, _ einheit: LoadUnit) -> String // "80,0 kg", "120 W", "Level 8", "8,5 km/h", "6,0 %", "85 U/min"
    static func belastungDelta(_ delta: Double, _ einheit: LoadUnit) -> String  // "+2,5 kg", "−10 W", "+1 Level"
    static func belastungGesprochen(_ wert: Double, _ einheit: LoadUnit) -> String // "80,0 Kilogramm", "120 Watt", "Level 8", "8,5 Kilometer pro Stunde", "6,0 Prozent", "85 Umdrehungen pro Minute"
    static func umfang(_ wert: Int, _ art: VolumeKind) -> String              // "12", "20:00", "2.000"
    static func umfangMitEinheit(_ wert: Int, _ art: VolumeKind) -> String    // "12 Wdh.", "20:00 min", "2.000 m"
    static func umfangGesprochen(_ wert: Int, _ art: VolumeKind) -> String    // "12 Wiederholungen", "20 Minuten", "2 Kilometer" / "750 Meter"
    static func korridor(_ min: Int, _ max: Int, _ art: VolumeKind) -> String // "8 – 12", "15 – 20 min", "2.000 – 5.000 m"
}
```
Die Strings entsprechen `formatLoad`/`formatVolume` in `belastung.ts` bis auf das Minuszeichen: iOS schreibt „−" (U+2212) wie heute in `GeraetModel.vorschlagText`. `gewicht`/`gewichtMitEinheit`/`gewichtGesprochen` bleiben für Körpergewicht bestehen; `belastung(_:.kg)` liefert dasselbe.

- [ ] **Step 1:** Tests zuerst, je Einheit und Art ein Fall, plus „20:00", „12:30", Tausenderpunkt, Gesprochenes.
- [ ] **Step 2:** Typen und Formatierer. Kopfkommentar: warum ein Ort (Spec 5.3), und dass eine neue Einheit hier je Funktion eine Zeile kostet.
- [ ] **Step 3:** `xcodegen generate`, Suite grün, Commit `feat(ios-member): Belastung.swift -- Einheiten, Umfangsarten und Formatierung`.

---

## Task 2: DTOs

**Files:**
- Modify: `Networking/DTOs/BootstrapResponse.swift`, `TagContextResponse.swift`, `WorkoutSet.swift`, `SessionSummary.swift`, `ExerciseProgress.swift`
- Modify: `FitnessMemberTests/DTOTests.swift` (JSON-Fixtures auf die neuen Namen; je ein Laufband-Fixture für Bootstrap und Tag-Kontext)

| Typ | Alt | Neu |
|---|---|---|
| `BootstrapResponse.EquipmentModel`, `TagContextResponse.EquipmentModel` | `weightStepKg/minWeightKg/maxWeightKg` | `loadUnit: LoadUnit`, `loadStep`, `loadMin`, `loadMax: Double?`, `secondaryUnit: LoadUnit?`, `secondaryStep/Min/Max: Double?`; Bootstrap zusätzlich `category: Kategorie` |
| `…Exercise` | `targetRepsMin/Max` | `volumeKind: VolumeKind`, `targetMin`, `targetMax` |
| `BootstrapResponse.LastSet` | `weightKg`, `reps` | `load`, `secondaryLoad: Double?`, `volume` |
| `TagContextResponse.HistoryEntry` | `weightKg`, `reps: [Int]` | `load`, `secondaryLoad: Double?`, `volume: [Int]` |
| `TagContextResponse.Suggestion` | `resultWeightKg`, `inputs.targetRepsMin/…/currentWeightKg` | `resultLoad`, `resultSecondaryLoad: Double?`, `inputs.targetMin/targetMax/loadStep/loadMin/loadMax/currentLoad/currentSecondaryLoad` |
| `SetWrite` | `weightKg`, `reps` | `load`, `volume`, `secondaryLoad: Double? = nil` |
| `RecordedSet` | `weightKg`, `reps` | `load`, `secondaryLoad: Double?`, `volume` |
| `Blockvorschlag` | `resultWeightKg`, `deltaKg` | `resultLoad`, `deltaLoad`, `secondaryLoad: Double?`, `loadUnit: LoadUnit`, `secondaryUnit: LoadUnit?` |
| `SessionSummary.Block` | — | `loadUnit`, `secondaryUnit: LoadUnit?`, `volumeKind`; `Set.weightKg/reps` → `load`, `secondaryLoad`, `volume` |
| `ExerciseProgress` | `firstWeightKg/currentWeightKg/changeKg`, `Point.topWeightKg/reps` | `firstLoad/currentLoad/changeLoad`, `loadUnit`, `volumeKind`, `Point.topLoad/volume` |

Die Enums dekodieren strikt: eine Einheit, die die App nicht kennt, ist ein Dekodierfehler und kein stilles „kg". Der Check-Constraint aus 0045 kennt genau diese sechs; eine siebte braucht ohnehin ein App-Update.

**Verlauf-Cache:** `VerlaufFileStore` schreibt `SessionSummary` und `ExerciseProgress` auf Platte. Ein Cache aus der alten Fassung dekodiert nicht mehr → wie bei `Serienstand` optional behandeln: Dekodierfehler heißt leerer Cache, der nächste Abruf füllt ihn. Kein `CodingKeys`-Fallback für Verlaufsdaten, die der Server ohnehin liefert.

- [ ] **Step 1:** DTOTests-Fixtures umschreiben; ein Laufband-Fixture (kmh/pct/seconds) für Bootstrap und Tag-Kontext; Test, dass ein alter Verlauf-Cache still verworfen wird.
- [ ] **Step 2:** DTOs umbenennen. Der Rumpf des `PendingWriteStore` bleibt: er speichert `SetWrite` als JSON, neue Sätze gehen als `load`/`volume`; alte gepufferte Sätze mit `weightKg`/`reps` nimmt der Server über den Alias an (Spec 5.1).
- [ ] **Step 3:** Commit `feat(ios-member): DTOs auf Belastung, Umfang und Kategorie`.

---

## Task 3: `LokaleSession`, `WorkoutSessionStore`, `Trainingszusammenfassung`

**Files:**
- Modify: `Workout/LokaleSession.swift`, `Workout/SessionFileStore.swift`, `Workout/WorkoutSessionStore.swift`, `Workout/Trainingszusammenfassung.swift`
- Modify: `FitnessMemberTests/WorkoutSessionStoreTests.swift`, `TrainingszusammenfassungTests.swift`, `PendingWriteStoreTests.swift`

- `LokalerSatz.weightKg/reps` → `load`, `secondaryLoad: Double?`, `volume`. **`SessionFileStore.load()` liest eine laufende Session aus der alten Fassung weiter:** eigener `init(from:)` mit Fallback von `weightKg`/`reps` auf `load`/`volume` (`secondaryLoad = nil`). Grund: das App-Update kann mitten in einer offenen Einheit kommen, und die geht sonst verloren. Test: eine Datei im alten Format lädt.
- `LokalerBlock` bekommt `loadUnit: LoadUnit`, `secondaryUnit: LoadUnit?`, `volumeKind: VolumeKind` — aus dem Bootstrap beim Anlegen des Blocks, damit TrainingLaeuft und Abschluss offline formatieren können. Fallback beim Lesen alter Dateien: `kg`, `nil`, `reps`.
- `satzSichern(machineId:exerciseId:load:secondaryLoad:volume:…)` und `SetWrite` entsprechend.
- `Trainingszusammenfassung.Blockzeile.gewichtKg` → `belastung: Double?` (nil bei uneinheitlichen Sätzen), plus `nebenbelastung: Double?`, `loadUnit`, `secondaryUnit`, `volumeKind`.

- [ ] Tests, Umbau, Commit `feat(ios-member): laufende Einheit mit Belastung, Nebenbelastung und Umfang`.

---

## Task 4: `Rastwerte` und `GeraetModel`

**Files:**
- Modify: `Workout/Rastwerte.swift`, `Screens/Geraet/GeraetModel.swift`
- Modify: `FitnessMemberTests/RastwerteTests.swift`, `GeraetModelTests.swift`, `GeraetKontextLadenTests.swift`, `GeraetEinstiegTests.swift`

**Rastwerte:**
```swift
static func belastung(min: Double, max: Double?, schritt: Double) -> [Double]   // vormals gewichte(...)
static func umfang(_ art: VolumeKind) -> [Int]   // reps 1...40 | seconds 30, 60, ... 5400 | meters 100, 200, ... 20000
```
`wiederholungen` entfällt; `maxRastenOhneObergrenze = 200` bleibt. Die Sekundenliste hat 180, die Meterliste 200 Einträge — dieselbe Größenordnung wie ein Gewichtsrad ohne Anschlag.

**GeraetModel:**
- `gewicht` → `belastung`, `wiederholungen` → `umfang`, neu `nebenbelastung: Double?` (nur gesetzt, wenn das Modell eine `secondaryUnit` hat; Vorbelegung: letzter Satz an diesem Gerät und dieser Übung, sonst `secondaryMin`).
- `gewichtsWerte` → `belastungsWerte`; neu `umfangsWerte: [Int]` aus `Rastwerte.umfang(aktiveUebung.volumeKind)`; `geklemmt` klemmt auf diese Liste.
- `loadUnit`, `secondaryUnit`, `volumeKind` als berechnete Eigenschaften aus `maschine.equipmentModel` und `aktiveUebung`.
- `kontextzeileGewicht` → `kontextzeileBelastung`: „Schritt 0,5 km/h · 0,0 – 20,0"; `kontextzeileWiederholungen` → `kontextzeileUmfang`: „Ziel 15 – 20 min" über `Zahlformat.korridor`.
- `vorschlagText`: „Vorschlag · +0,5 km/h" über `Zahlformat.belastungDelta`; `rueckblick.zuletzt`: „8,5 km/h · 6,0 % × 20:00 min" (Nebenbelastung nur, wenn vorhanden).
- `kontextUebernehmen`: `resultLoad` rastet auf `belastungsWerte`; `resultSecondaryLoad` setzt `nebenbelastung`, wenn das Mitglied sie nicht selbst angefasst hat (dieselbe `…VomNutzer`-Regel wie bei der Belastung).
- `letztesGewicht(fuer:)` → `letzteBelastung(fuer:)`.
- `satzSichern` übergibt `secondaryLoad: nebenbelastung`.

- [ ] Tests: Umfangslisten; Vorbelegung der Nebenbelastung (letzter Satz, sonst Minimum, nil ohne Nebenbelastung); Kontextzeilen je Einheit; Vorschlag übernimmt Belastung und Nebenbelastung, nicht aber eine vom Nutzer gesetzte.
- [ ] Commit `feat(ios-member): GeraetModel rechnet in Belastung und Umfang`.

---

## Task 5: `WertZeile` und `GeraetView`

**Files:**
- Modify: `Screens/Geraet/WertZeile.swift`, `Screens/Geraet/GeraetView.swift`, `Screens/Geraet/GeraetErkanntView.swift`, `Screens/Geraet/UebungWechselnSheet.swift`, `Screens/Geraet/RueckblickSheet.swift` (nur Texte)

- **Belastungsrad:** `werte: modell.belastungsWerte`, `text: { Zahlformat.belastung($0, modell.loadUnit) }`, `voWert: { Zahlformat.belastungGesprochen($0, modell.loadUnit) }`, Wort daneben `modell.loadUnit.kurz` statt „kg". `voLabel` „Belastung".
- **Umfangsrad:** `werte: modell.umfangsWerte.map(Double.init)`, `text: { Zahlformat.umfang(Int($0), modell.volumeKind) }`, Wort daneben „Wdh." / „min" / „m". Spaltenbreite: 104 pt bei `reps` (wie heute), 152 pt bei `seconds` und `meters` — „20:00" und „2.000" sind fünf Zeichen bei 44 pt Black monospaced. Der Kommentar zur Spaltenbreite wird entsprechend umgeschrieben.
- **Nebenbelastung:** unter den beiden Rädern, nur wenn `modell.secondaryUnit != nil`, eine Zeile `Stepper44` mit Beschriftung aus der Einheit („Neigung" für pct, „Trittfrequenz" für rpm, sonst `kurz`), Wert `Zahlformat.belastungMitEinheit`, Schritt `secondaryStep`, Grenzen `secondaryMin`/`secondaryMax`. Kein drittes Rad (siehe Architecture). Für ein Kraftgerät gibt es die Zeile nicht, und der Screen ist der heutige.
- `GeraetErkanntView` und `UebungWechselnSheet`: „Noch nie · Ziel 15 – 20 min" über `Zahlformat.korridor`.

- [ ] Sichtcheck auf iPhone 17 Pro und einem SE-Simulator (667 pt): Beinpresse unverändert; Laufband mit Stepper-Zeile passt ohne Scrollen bei Standard-Schriftgröße. Screenshots in den Commit-Text, nicht ins Repo.
- [ ] Commit `feat(ios-member): Geraete-Screen mit Einheit, Zeitrad und Nebenbelastung`.

---

## Task 6: Satzziel bei Zeit und Strecke

**Files:**
- Modify: `Screens/Geraet/GeraetModel.swift` (`satzZiel`), `FitnessMemberTests/GeraetModelTests.swift`

Das Satzziel aus `Einstellungen.satzZiel` (Vorgabe 3) entscheidet, wann nach dem Sichern statt der Pause die Wahl „Gerät abschließen / Weiterer Satz" kommt. An einem Laufband ist ein Satz die Einheit; nach 20 Minuten Dauerlauf eine 90-Sekunden-Pause zu starten wäre falsch. Deshalb: `satzZiel` ist 1, wenn `volumeKind != .reps`. Das ist die eine Stelle, an der die Umfangsart eine Regel trägt — mit diesem Kommentar.

- [ ] Test: Laufband-Übung → nach dem ersten Satz `phase == .entscheidung`; Beinpresse unverändert.
- [ ] Commit `feat(ios-member): ein Satz ist bei Zeit und Strecke die Einheit`.

---

## Task 7: Training-Tab und Abschluss

**Files:**
- Modify: `Screens/Training/TrainingRootView.swift`, `Screens/Training/TrainingAbschlussView.swift`
- Modify: `FitnessMemberTests/TrainingAbschlussZeilenTests.swift`, `TrainingTabTests.swift`

- Blockzeile: „1 Satz · 8,5 km/h · 6,0 %" statt „3 Sätze · 80,0 kg"; ohne Nebenbelastung entfällt der dritte Teil.
- `VorschlagsAnzeige(reasonCode:deltaLoad:loadUnit:secondaryLoad:secondaryUnit:)`: `.delta` trägt Einheit und Nebenbelastung; `text` „+0,5 km/h bei 6,0 %", „+2,5 kg"; `.halten` „Gewicht halten" bei kg, sonst „Belastung halten"; `gesprochen` über `belastungGesprochen`.

- [ ] Tests für die vier Einheiten und den Fall mit Nebenbelastung. Commit `feat(ios-member): Abschluss nennt Einheit und Nebenbelastung`.

---

## Task 8: Gerätesuche nach Kategorie

**Files:**
- Modify: `Workout/GeraeteAuswahl.swift`, `Screens/Geraet/GeraeteAuswahlView.swift`
- Modify: `FitnessMemberTests/GeraeteAuswahlTests.swift`

- `Eintrag` bekommt `kategorie: Kategorie` und `zuletzt` trägt `load` plus `loadUnit` statt `gewichtKg`.
- `Gruppen` bekommt `kraft: [Eintrag]` und `cardio: [Eintrag]` (statt `alle`) für den Fall ohne Suchtext; mit Suchtext bleibt die flache Trefferliste (`treffer`). Leere Gruppen entfallen in der Ansicht. Überschriften „KRAFT · A–Z", „CARDIO · A–Z".
- `zuletztText`: „vor 2 Tagen · 8,5 km/h".

- [ ] Tests: zwei Gruppen ohne Suchtext, leere Gruppe fehlt, Suche flach wie heute. Commit `feat(ios-member): Geraetesuche trennt Kraft und Cardio`.

---

## Task 9: Home und Verlauf

**Files:**
- Modify: `Screens/Home/SessionDetailView.swift`, `Screens/Home/UebungsfortschrittView.swift`, `Screens/Home/HomeRootView.swift` (Fortschrittskarte), `Verlauf/HomeZeilen.swift` (`veraenderung`), `Verlauf/VerlaufStore.swift` (nur Übungsfortschritt)
- Modify: `FitnessMemberTests/VerlaufStoreTests.swift`, `FortschrittsfensterTests.swift`, `HomeZieleTests.swift` (nur, wo Trainingsbelastung gemeint ist)

- Satzzeile im Session-Detail: „8,5 km/h · 6,0 % × 20:00 min"; VoiceOver über `belastungGesprochen`/`umfangGesprochen`.
- Übungsfortschritt: Achse und Punkte in `loadUnit`; `HomeZeilen.veraenderung(_:einheit:)` liefert „+0,5 km/h".
- **Nicht anfassen:** alles mit Körpergewicht (Gewichtsverlauf, Zielgewicht, Messwerte).

- [ ] Commit `feat(ios-member): Verlauf und Fortschritt in der Einheit des Geraets`.

---

## Task 10: Doku und Abnahme

- [ ] `docs/superpowers/specs/2026-08-30-designsystem.md` §7: Fußnote, dass die Rastung aus `load_step` kommt und das zweite Rad je Umfangsart liest. Kernflow-Spec Abschnitt 5 (Wertrad): Fußnote auf diesen Plan.
- [ ] Manuelle Abnahme gegen das lokale Backend mit einem Laufband (kmh, pct, Dauerlauf 15–20 min) und einer Beinpresse: Scan → Satz → Pause/Entscheidung → Abschluss → Home. Befund in `docs/superpowers/plans/…-cardio-schnitt3-abnahme.md` wie bei den vorigen Schnitten.
- [ ] Abschnitt „Stand" hier, Verweis in der Spec (Abschnitt 14: „(c) iOS, umgesetzt").

## Selbstprüfung

- [ ] `grep -rn "weightKg\|targetReps\|weightStepKg" FitnessMember FitnessMemberTests` trifft nur noch Körpergewicht (`Messwert`, `Ziele`, `Gewicht…`, `latestWeight`).
- [ ] Beinpresse: Screenshot vor/nach identisch.
- [ ] Alle Suiten grün auf iPhone 17 Pro.

## Was dieser Schnitt NICHT tut

- Kein laufender Timer, kein Puls, keine Distanz als Nebenwert (Spec Abschnitt 10).
- Keine Progression über die Nebenbelastung (offener Punkt 5 der Spec).
- Kein Filter in der Suche über die Gruppierung hinaus; die Kategorie-Kennzahl im Studio-Überblick bleibt offener Punkt 6.
