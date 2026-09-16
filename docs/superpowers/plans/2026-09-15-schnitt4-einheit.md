# Schnitt 4: Was eine Einheit ist — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eine Einheit beginnt und endet dort, wo das Mitglied es sagt. Sie entsteht auf einem eigenen Screen „Training starten“ nach Geräte- und Übungswahl — mit dem Tap dort läuft die Uhr, und die Dauer enthält Einweisung und Einstellung. Der gemerkte Geräte­kontakt (`geraetBetreten`) verschwindet, weil die Einheit selbst jetzt den Anfang trägt. Eine Einheit ohne Satz wird verworfen und nie gemeldet: beim Ablauf der vier Stunden still, beim manuellen Beenden mit einem Satz im Fuß. Und eine Einheit, die es nicht hätte geben sollen, geht wieder weg — „Verwerfen“ auf dem Abschluss-Screen, „Training löschen“ im Session-Detail, mit Delete-Policy auf `workout_sessions` und geräumter Schreib-Warteschlange.

**Architecture:** Client plus eine Migration plus zwei kleine Server-Änderungen. Vier Ableitungen tragen den Umbau und bekommen ihren Test vor dem View: `WorkoutSessionStore.trainingStarten` (die Einheit entsteht ohne Satz; eine abgelaufene ohne Satz ist kein „automatisch beendet“, sondern nichts), `TrainingStart.ziel` (der Startscreen kommt nur, wenn kein Training läuft), `Trainingszusammenfassung` (die Dauer beginnt beim Start) und `EinheitVerwerfen.weg` (ob „Verwerfen“ den Server braucht oder die Warteschlange reicht). Der Server legt eine Einheit weiterhin erst mit dem ersten Satz an — deshalb liegt eine Einheit ohne Satz nie bei ihm, und „nie gemeldet“ ist strukturell, nicht Disziplin. Zwei Server-Änderungen: der Satz-PUT trägt den Beginn der Einheit mit (sonst zeigte Home die Zeit des ersten Satzes, die App die des Starts), und `DELETE /workout-sessions/{id}` mit der Delete-Policy aus Punkt 19. Entschieden am 15. September; Frage a) bis c) unten sind mit Empfehlung aufgenommen und vor Task 3 zu bestätigen.

**Tech Stack:** Swift 6 / SwiftUI / Swift Testing / XcodeGen (`apps/ios-member`). TypeScript / Zod / Vitest (`packages/domain`, `apps/web`, `tests/integration`). Eine SQL-Migration (`supabase/migrations/0044_…`).

**Quelle:** `docs/superpowers/plans/2026-09-12-ios-verbesserungen-aus-dem-betrieb.md`, „Stand“, Punkte 10 und 19, „Schnitt 4 — Was eine Einheit ist“, „Was wovon abhängt“ (15 hängt an 10; 19 an 10 und 20) und „Entschieden“ (Punkt 2: eine Einheit ohne Satz wird verworfen und nie gemeldet). Vorbild für Aufbau und Ton: `docs/superpowers/plans/2026-09-15-schnitt3-satzpfad.md` samt Nachträgen.

## Global Constraints

- **Branch und Reihenfolge.** `claude/ios-schnitt4-einheit` setzt auf `claude/ios-schnitt3-satzpfad` (PR #12) auf, nicht auf `master` — Schnitt 3 ist am 15. September noch nicht gemergt, und dieser Schnitt fasst `GeraetView`, `GeraetModel` und `TrainingRootView` an. Die Arbeit läuft im Worktree `.claude/worktrees/ios-schnitt4-einheit`; eine zweite Session (Fix „Gerät ohne Einstellwerte“, ändert `ErstkontaktFlow`) läuft parallel in einem eigenen Worktree. **Phase 2 beginnt erst, wenn PR #12 und dieser Fix gemergt sind**, und dann mit `git rebase master` — vorher kein Task 3, weil der Startscreen vor dem Dreischritt sitzt. Sichtchecks laufen nie gleichzeitig (ein SE-Simulator, eine Platte).
- **Kommentare in Swift ohne Umlaute** (ASCII). Nutzertexte tragen Umlaute.
- **Kommentare begründen, sie beschreiben nicht.** Wird durch den Umbau ein Kommentar falsch, wird er im selben Task umgeschrieben. Betroffen sind mindestens: `LokaleSession` („Entsteht implizit beim ersten Satz — es gibt keinen Startknopf“), `WorkoutSessionStore.geraetBetreten` (ganzer Block), `SessionFileStore.loadBeginn`, `GeraetErkanntScreen.task` („die Trainingsuhr laeuft ab hier“), `GeraetErkanntView` (Typkommentar „Ein Tap auf eine Uebung fuehrt direkt zum Satz“), `TrainingRootView.laufendKopf` („M1-Spec SS5.6: es gibt keinen Startknopf“), `TrainingTabTests.sessionOhneSatzZeigtUhrAberKeineZahlen` („der Fall kommt also nicht vor“), `Trainingszusammenfassung.init` („die gibt es zwar nicht, weil die Session mit dem ersten Satz entsteht“), `workout.ts recordSet` („es gibt keinen Startknopf und keinen Endpoint dafuer“) und der Test `legt die Session implizit an -- es gibt keinen Startknopf`.
- **Design-Tokens aus `DesignSystem.swift`**, nie als Literal: `bg`, `surface`, `surfaceRaised`, `line`, `text`, `textMuted`, `textFaint`, `accent`, `warn`, `danger`. Radien `card` 12, `neben` 14, `haupt` 16. Abstände 4/8/12/16/24/32/48. Ausnahme wie im Bestand: die horizontale Seitenkante 20.
- **Eine Akzentfläche pro Screen** (designsystem.md §2). „Training starten“ ist sie auf dem Startscreen; auf dem Abschluss bleibt es „Fertig“, „Training verwerfen“ ist ein Textknopf in `danger`; im Session-Detail ist „Training löschen“ ein `DangerOutlineButton` (Umriss, keine Fläche) und es gibt keine Akzentfläche.
- **Hit-Targets nie unter 44 pt** — und die Trefferfläche liegt im Label des Buttons, nicht in einem `.frame` um ihn: mit `PressButtonStyle` ist nur das gestylte Label tippbar (Vorlage `GeraetView.problemMelden`).
- **Die App misst nichts** (§10). Ohne Satz zeigt der laufende Zustand keine Zahlen (`TrainingTab.mitte` liefert `zahlen == nil`, das gilt schon); eine Einheit ohne Satz erzeugt keine Karte, keinen Serientag, keine Zeile beim Server.
- **Swift-Tests mit Swift Testing** (`import Testing`, `@Test`, `#expect`), als `struct`-Suite. Tests beweisen Ableitungen und Werte, nicht Sichtbarkeit und Höhe — die prüft der Sichtcheck (Task 9) mit Screenshots und Frames-Dump.
- **Reihenfolge:** Jede Ableitung kommt mit ihrem Test vor dem View, der sie benutzt (Task 1, 2, 4, 6 vor Task 3 und 7).
- **Neue Swift-Dateien:** `project.yml` zieht Verzeichnisse, nach dem Anlegen `xcodegen generate` in `apps/ios-member`. Danach `git status` vor jedem Commit, `Package.resolved` bleibt unangetastet.
- **iOS-Tests:** in `apps/ios-member`
  `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
  Einzelne Suite: `-only-testing:FitnessMemberTests/<Suite>`. **Vor jedem vollen Build `df -h /System/Volumes/Data`** — unter 3 GB frei zuerst `~/Library/Developer/Xcode/DerivedData/FitnessMember-*` löschen (am 15. September, 20 Uhr: 5,4 GB frei). Ein zusätzlicher Simulator kostet 1,6 GB, ein App-Build 0,4 GB. Bei voller Platte scheitern auch die Berichte der Subagenten; der Controller schreibt sie dann aus der Handback-Nachricht nach.
- **Server-Tests:** im Repo-Wurzelverzeichnis `pnpm typecheck`, `pnpm test`, `pnpm test:integration` (braucht das lokale Supabase in Docker und `.env`). Im Worktree vorher einmal `pnpm install`. Grün vor dem nächsten Task.
- **Ein Commit je Task**, deutsche Message im Stil der Historie mit ae/oe/ue. **Der Betreff steht wörtlich im Plan**; ein Subagent, der ihn abwandelt, wird korrigiert. Trailer genau so, wörtlich, und nach jedem Commit mit `git log -1 --format=%B` geprüft:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  ```
- **Nicht pushen.**
- **Sichtcheck nur gegen das lokale Backend**, nie gegen Produktion. `Config.xcconfig` bleibt unangetastet; die Umleitung geschieht über xcodebuild-Overrides (Task 9). Nicht auf den iPhone 17 Pro installieren — dort liegt die Entwickler-App mit Session; eigener SE-Simulator, danach löschen.
- **Was unterwegs auffällt und über den Schnitt hinausgeht:** notieren (Abschlussbericht, „Beim Sichtcheck gefunden, außerhalb dieses Schnitts“), nicht mitmachen.

---

## Task 1: Die Einheit beginnt mit „Training starten“ (Punkt 10, Store)

Heute entsteht die `LokaleSession` in `WorkoutSessionStore.satzSichern` mit dem ersten Satz; daneben merkt sich `geraetBetreten` den ersten Gerätekontakt in einer zweiten Datei (`trainingsbeginn.json`), damit die Uhr früher läuft als die Einheit. Mit Schnitt 4 fällt diese Zweiteilung: `trainingStarten(jetzt:)` legt die Einheit ohne Satz an, die Uhr hängt an ihrem `startedAt`, und der gemerkte Beginn samt Datei verschwindet.

Die Regel für Einheiten ohne Satz (Sammelstelle, Entschieden 2) wird hier zur Ableitung:

1. **Ablauf:** Eine Einheit ohne Satz läuft wie bisher vier Stunden nach ihrem Beginn aus (`aktiveSession` rechnet schon heute gegen `letzterSatzAm ?? startedAt`). `abgelaufeneSession()` liefert sie **nicht** — nur Einheiten mit Satz bekommen den Satz „automatisch beendet“ auf dem Tab. `ausgelaufeneQuittieren()` räumt beide.
2. **Beenden von Hand:** `beenden()` gibt die Kennung auch für eine leere Einheit zurück und räumt sie; ob daraus ein Abschluss oder ein Verwerfen wird, entscheidet `TrainingRootView` an `Trainingszusammenfassung` (Task 3).
3. **Nie gemeldet:** braucht keinen Code — der Server legt die Einheit erst mit dem ersten Satz-PUT an (`recordSet` upsertet `workout_sessions`), es gibt keinen Start-Endpoint. Das wird als Kommentar an `trainingStarten` festgehalten, damit niemand einen baut.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/WorkoutSessionStore.swift` (`gemerkterBeginn`, `init`, `abgelaufeneSession`, `ausgelaufeneQuittieren`, `beginnVerwerfen`, `geraetBetreten`, `trainingsbeginn`, `satzSichern`, `beenden`)
- Modify: `apps/ios-member/FitnessMember/Workout/LokaleSession.swift` (Typkommentar, neu `hatSaetze`)
- Modify: `apps/ios-member/FitnessMember/Workout/SessionFileStore.swift` (`beginnURL`, `loadBeginn`, `saveBeginn` entfallen; Altlast wegräumen)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift` (`geraetBetreten()` Z. 388 entfällt; `trainingsbeginn` Z. 211 bleibt)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetErkanntView.swift` (`GeraetErkanntScreen.body`, `.task`)
- Modify: `apps/ios-member/FitnessMemberTests/WorkoutSessionStoreTests.swift` (Abschnitt „Trainingsuhr“ wird „Start der Einheit“)
- Modify: `apps/ios-member/FitnessMemberTests/TrainingTabTests.swift` (nur der Kommentar in `sessionOhneSatzZeigtUhrAberKeineZahlen`)

**Interfaces:**
- Produces:
  - `WorkoutSessionStore.trainingStarten(jetzt: Date = Date()) -> LokaleSession` (`@discardableResult`) — legt eine leere Einheit an oder gibt die laufende zurück.
  - `WorkoutSessionStore.trainingsbeginn(jetzt:) -> Date?` — jetzt `aktiveSession(jetzt:)?.startedAt`, Signatur unverändert (`GeraetModel.trainingsbeginn` liest sie).
  - `WorkoutSessionStore.abgelaufeneSession(jetzt:)` — nur noch für Einheiten mit Satz.
  - `WorkoutSessionStore.ausgelaufeneQuittieren(jetzt: Date = Date())` — neuer Vorgabeparameter, räumt jede nicht mehr laufende Einheit.
  - `LokaleSession.hatSaetze: Bool`.
  - Entfällt: `geraetBetreten(jetzt:)`, `GeraetModel.geraetBetreten()`, `SessionFileStore.loadBeginn()/saveBeginn(_:)`.

- [x] **Step 1: Tests umschreiben** (`WorkoutSessionStoreTests.swift`). Der Abschnitt `// MARK: - Trainingsuhr` mit seinen acht Tests (`dieUhrLaeuftAbDemErstenGeraet…`, `dasZweiteGeraet…`, `dieSessionUebernimmtDenBeginn…`, `ohneGeraetekontakt…`, `einGemerkterBeginn…`, `beendenVerwirftDenBeginn`, `derBeginnUeberlebt…`, `ausgelaufeneQuittierenVerwirftAuchDenBeginn`) wird ersetzt durch:

```swift
// MARK: - Start der Einheit (Sammelstelle Punkt 10, Entschieden 2)

@Test func trainingStartenLegtEineLeereEinheitAn() {
    let (sut, _) = store()
    #expect(sut.aktiveSession(jetzt: start) == nil)

    let einheit = sut.trainingStarten(jetzt: start)

    // Die Einheit gibt es ab dem Tap -- ohne Satz, mit Uhr.
    #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(300)) == einheit)
    #expect(einheit.bloecke.isEmpty)
    #expect(einheit.startedAt == start)
    #expect(sut.trainingsbeginn(jetzt: start.addingTimeInterval(300)) == start)
}

@Test func einZweiterStartVerschiebtDenBeginnNicht() {
    let (sut, _) = store()
    let erste = sut.trainingStarten(jetzt: start)

    let zweite = sut.trainingStarten(jetzt: start.addingTimeInterval(900))

    #expect(zweite == erste)
    #expect(sut.trainingsbeginn(jetzt: start.addingTimeInterval(900)) == start)
}

@Test func derErsteSatzHaengtAnDerGestartetenEinheit() {
    let (sut, _) = store()
    let einheit = sut.trainingStarten(jetzt: start)

    let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                      problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(600))

    // Sonst spraenge die Uhr beim ersten Satz auf 00:00 zurueck, und
    // "seit 18:04" auf dem Training-Tab meinte den Satz statt den Start.
    #expect(geschrieben.sessionId == einheit.id)
    #expect(geschrieben.body.setIndex == 1)
    #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(600))?.startedAt == start)
}

@Test func eineLeereEinheitLaeuftNachVierStundenAus() {
    let (sut, _) = store()
    sut.trainingStarten(jetzt: start)

    #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(4 * 3600)) != nil)
    #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(4 * 3600 + 1)) == nil)
}

@Test func eineAbgelaufeneEinheitOhneSatzWirdStillVerworfen() {
    let (sut, _) = store()
    sut.trainingStarten(jetzt: start)
    let spaeter = start.addingTimeInterval(5 * 3600)

    // Kein "automatisch beendet" fuer ein Training, das nie stattfand.
    #expect(sut.abgelaufeneSession(jetzt: spaeter) == nil)

    sut.ausgelaufeneQuittieren(jetzt: spaeter)

    // Geraeumt ist sie trotzdem: der naechste Start ist eine neue Einheit.
    let neue = sut.trainingStarten(jetzt: spaeter)
    #expect(neue.startedAt == spaeter)
}

@Test func eineAbgelaufeneEinheitMitSatzWirdGemeldet() {
    let (sut, _) = store()
    sut.trainingStarten(jetzt: start)
    _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                        problemFlag: false, problemReason: nil, jetzt: start)
    let spaeter = start.addingTimeInterval(5 * 3600)

    #expect(sut.abgelaufeneSession(jetzt: spaeter)?.startedAt == start)

    sut.ausgelaufeneQuittieren(jetzt: spaeter)

    #expect(sut.abgelaufeneSession(jetzt: spaeter) == nil)
    #expect(sut.trainingsbeginn(jetzt: spaeter) == nil)
}

@Test func beendenRaeumtAuchEineLeereEinheit() {
    let (sut, _) = store()
    let einheit = sut.trainingStarten(jetzt: start)

    // Ob daraus ein Abschluss oder ein Verwerfen wird, entscheidet der
    // Training-Tab an der Zusammenfassung -- der Store raeumt nur.
    #expect(sut.beenden() == einheit.id)
    #expect(sut.aktiveSession(jetzt: start) == nil)
    #expect(sut.trainingsbeginn(jetzt: start) == nil)
}

@Test func derStartUeberlebtEinenProzessNeustart() {
    let verzeichnis = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    let ersterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
    let einheit = ersterLauf.trainingStarten(jetzt: start)

    let zweiterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))

    #expect(zweiterLauf.aktiveSession(jetzt: start.addingTimeInterval(60)) == einheit)
}
```

Der bestehende Test `derErsteSatzLegtDieSessionAn` bleibt — er beweist den Rückfallweg (Satz ohne vorherigen Start, etwa wenn die Einheit auf dem Satzpfad ausläuft). Sein Name bleibt, sein Kommentar wird: `// Rueckfall ohne Start: die Einheit laeuft auf dem Satzpfad aus, der naechste Satz legt eine neue an.`

In `TrainingTabTests.sessionOhneSatzZeigtUhrAberKeineZahlen` wird der Kommentar: `// Seit Schnitt 4 entsteht die Einheit mit "Training starten" -- vor dem ersten Satz steht die Uhr ohne Zahlen, nie "0 Saetze".`

- [x] **Step 2: Rot sehen.** `-only-testing:FitnessMemberTests/WorkoutSessionStoreTests`. Erwartet: Build-Fehler „value of type 'WorkoutSessionStore' has no member 'trainingStarten'“.

- [x] **Step 3: Store umbauen** (`WorkoutSessionStore.swift`). `gemerkterBeginn`, die Zeile `gemerkterBeginn = fileStore.loadBeginn()` im `init`, `beginnVerwerfen()` und `geraetBetreten(jetzt:)` entfallen. Dafür:

```swift
/// Das Mitglied hat "Training starten" gedrueckt -- ab hier gibt es die
/// Einheit, und mit ihr laeuft die Uhr (Sammelstelle Punkt 10, entschieden
/// 15. September; hebt M1-Spec SS5.6 auf).
///
/// Der Server erfaehrt davon nichts: er legt die Einheit weiterhin erst
/// mit dem ersten Satz an (recordSet upsertet workout_sessions), einen
/// Start-Endpoint gibt es nicht. Genau deshalb kann eine Einheit ohne
/// Satz nie bei ihm liegen -- "wird verworfen und nie gemeldet"
/// (Entschieden 2) ist Struktur, nicht Disziplin. Wer einen
/// Start-Endpoint baut, verliert das.
///
/// Idempotent: laeuft schon eine Einheit, bleibt sie. Der Startscreen
/// kommt zwar nur ohne laufendes Training (TrainingStart.ziel), aber ein
/// zweiter Tap darf die Uhr nicht zuruecksetzen.
@discardableResult
func trainingStarten(jetzt: Date = Date()) -> LokaleSession {
    if let laufende = aktiveSession(jetzt: jetzt) { return laufende }
    let session = LokaleSession(id: UUID(), startedAt: jetzt, bloecke: [])
    gespeicherteSession = session
    fileStore.save(session)
    return session
}

/// Woran die Trainingsuhr haengt: der Beginn der laufenden Einheit --
/// seit Schnitt 4 nichts daneben. Vorher lief hier ein gemerkter
/// Geraetekontakt der Einheit voraus, weil die erst mit dem ersten Satz
/// entstand; jetzt beginnt die Einheit selbst mit dem Tap.
func trainingsbeginn(jetzt: Date = Date()) -> Date? {
    aktiveSession(jetzt: jetzt)?.startedAt
}
```

`abgelaufeneSession` und `ausgelaufeneQuittieren` werden:

```swift
/// Die gespeicherte Einheit, sofern sie NICHT mehr laeuft UND einen Satz
/// hatte.
///
/// Vergessenes Beenden ist laut M1-Spec SS5.2 der Regelfall. Ohne diesen
/// Zugriff saehe das Mitglied am naechsten Tag einen leeren Tab und
/// wuesste nicht, ob sein Training angekommen ist.
///
/// Eine abgelaufene Einheit OHNE Satz gibt es hier nicht zu sehen: sie
/// wird still verworfen (Sammelstelle, Entschieden 2). "Automatisch
/// beendet" auf dem leeren Tab spraeche von einem Training, das nie
/// stattgefunden hat -- und beim Server liegt davon ohnehin nichts.
func abgelaufeneSession(jetzt: Date = Date()) -> LokaleSession? {
    guard let session = gespeicherteSession, session.hatSaetze,
          aktiveSession(jetzt: jetzt) == nil
    else { return nil }
    return session
}

/// Raeumt eine ausgelaufene Einheit weg -- mit Satz nach dem Satz auf dem
/// leeren Tab (abgelaufeneSession), ohne Satz still.
///
/// Kein separates Merker-Bool: das wuerde store-global gelten und damit
/// jede SPAETERE abgelaufene Einheit stumm halten, sobald einmal
/// quittiert wurde -- und einen Neustart nicht ueberleben. Die
/// Sessiondatei traegt nur die oertliche Sicht auf die laufende Einheit;
/// noch nicht gesendete Schreibvorgaenge liegen in PendingWriteStore.
/// Loeschen ist hier folgenlos fuer sie.
///
/// Selbstschutz: quittiert wird nur, was WIRKLICH ausgelaufen ist. Der
/// Name verspricht Selektivitaet -- ohne den Guard wuerde jeder Aufruf
/// zur falschen Zeit bedingungslos die laufende Einheit des Mitglieds
/// loeschen, Speicher und Datei. Der Schaden waere maximal unsymmetrisch:
/// falsch-negativ ist ein Satz zu viel auf dem leeren Tab, falsch-positiv
/// ist das Training des Mitglieds weg. Der Guard gehoert deshalb hier
/// hin, nicht nur in die Disziplin der Aufrufer.
func ausgelaufeneQuittieren(jetzt: Date = Date()) {
    guard gespeicherteSession != nil, aktiveSession(jetzt: jetzt) == nil else { return }
    gespeicherteSession = nil
    fileStore.save(nil)
}
```

In `satzSichern` wird der Kommentar über `var session` und die Zeile:

```swift
// Ohne laufende Einheit (sie ist auf dem Satzpfad ausgelaufen, oder ein
// Test sichert ohne Start) entsteht sie hier -- der Rueckfallweg, nicht
// der Regelfall: den setzt seit Schnitt 4 trainingStarten(jetzt:).
var session = aktiveSession(jetzt: jetzt)
    ?? LokaleSession(id: UUID(), startedAt: jetzt, bloecke: [])
```

In `beenden()` entfällt `beginnVerwerfen()`; der Kommentar wird: `/// Gibt die Kennung zurueck, damit der Aufrufer POST .../complete schicken kann -- oder, ohne Satz, gar nichts (TrainingRootView.beenden verwirft dann).` Der Typkommentar an `sessionPause` bleibt.

- [x] **Step 4: `LokaleSession`, `SessionFileStore`, `GeraetModel`, `GeraetErkanntScreen`.**

`LokaleSession.swift`, Typkommentar und neue Eigenschaft:

```swift
/// Die laufende Einheit. Entsteht seit Schnitt 4 mit dem Tap auf
/// "Training starten" (WorkoutSessionStore.trainingStarten) -- vorher
/// implizit mit dem ersten Satz (M1-Spec SS5.6, aufgehoben am
/// 15. September). Der Rueckfallweg ueber satzSichern bleibt.
struct LokaleSession: Codable, Equatable {
    let id: UUID
    let startedAt: Date
    var bloecke: [LokalerBlock]

    var letzterSatzAm: Date? {
        bloecke.flatMap(\.saetze).map(\.performedAt).max()
    }

    /// Ohne Satz ist eine Einheit ein Fehlstart, kein Training: sie wird
    /// verworfen, nicht abgeschlossen (Sammelstelle, Entschieden 2).
    var hatSaetze: Bool { bloecke.contains { !$0.saetze.isEmpty } }
}
```

`SessionFileStore.swift`: `beginnURL`, `loadBeginn`, `saveBeginn` und ihr Kommentar entfallen. Im `init` nach dem `createDirectory`:

```swift
// Altlast aus der Zeit vor Schnitt 4: der gemerkte Geraetekontakt lag in
// einer eigenen Datei, weil die Einheit erst mit dem ersten Satz entstand.
// Seit die Einheit mit "Training starten" beginnt, liest sie niemand mehr.
try? FileManager.default.removeItem(at: directory.appendingPathComponent("trainingsbeginn.json"))
```

`GeraetModel.swift`: `func geraetBetreten() { sessions.geraetBetreten() }` samt Kommentar (Z. 380–388) entfällt.

`GeraetErkanntView.swift`, `GeraetErkanntScreen.body`:

```swift
GeraetErkanntView(modell: modell, beiAuswahl: beiAuswahl)
    // Online zeigt das Geraetefoto den eigentlichen Nutzen bei zwei
    // baugleichen Stationen (designsystem.md SS8) -- der Offline-
    // Platzhalter in GeraetErkanntView bleibt unveraendert. Die
    // Trainingsuhr laeuft hier NICHT los: seit Schnitt 4 beginnt die
    // Einheit erst mit "Training starten" (TrainingStartView).
    .task { await modell.kontextLaden() }
```

- [x] **Step 5: Grün sehen.** `grep -rn "geraetBetreten\|gemerkterBeginn\|loadBeginn\|saveBeginn" apps/ios-member` — nichts mehr. Dann `xcodebuild test`, ganz.

- [x] **Step 6: Commit** — `feat(training): Die Einheit beginnt mit Training starten -- der gemerkte Geraetekontakt verschwindet`

---

## Task 2: Wann der Startscreen kommt — die Ableitung (Punkt 10, Frage a)

Frage a) aus der Sammelstelle, hier entschieden (Empfehlung, siehe „Offen“): **der Startscreen kommt nur, wenn kein Training läuft.** Mitten im Training kostet das nächste Gerät keinen Tap mehr als bisher (Scan → Übung → Satz), und der Zirkel über die Blockliste hat ohnehin immer ein laufendes Training. Das ist eine Regel mit drei Aufrufern in `TrainingRootView` (Übungswahl auf „Gerät erkannt“, `direktZumSatz` nach dem Scan, Blockliste) — sie gehört an einen Ort mit Test.

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/TrainingStart.swift`
- Create: `apps/ios-member/FitnessMemberTests/TrainingStartTests.swift`
- Modify: `apps/ios-member/FitnessMember/Navigation/GeraetRoute.swift` (neuer Fall `start`)

**Interfaces:**
- Produces:
  - `GeraetRoute.start(machineId: String, exerciseId: String, token: String?)`
  - `enum TrainingStart { static func ziel(machineId: String, exerciseId: String, token: String?, trainingLaeuft: Bool) -> GeraetRoute }`

- [x] **Step 1: Test schreiben** (`TrainingStartTests.swift`):

```swift
import Testing
@testable import FitnessMember

/// Wann zwischen Uebungswahl und Satzpfad der Screen "Training starten"
/// steht (Sammelstelle Punkt 10, Frage a).
struct TrainingStartTests {
    @Test func ohneLaufendesTrainingKommtDerStartscreen() {
        #expect(TrainingStart.ziel(machineId: "m1", exerciseId: "e1", token: "t", trainingLaeuft: false)
                == .start(machineId: "m1", exerciseId: "e1", token: "t"))
    }

    @Test func mittenImTrainingGehtEsDirektZumSatz() {
        // Das naechste Geraet kostet keinen Tap mehr als bisher.
        #expect(TrainingStart.ziel(machineId: "m1", exerciseId: "e1", token: nil, trainingLaeuft: true)
                == .geraet(machineId: "m1", exerciseId: "e1", token: nil))
    }
}
```

- [x] **Step 2: Rot sehen.** `xcodegen generate`, dann `-only-testing:FitnessMemberTests/TrainingStartTests`. Erwartet: „cannot find 'TrainingStart' in scope“.

- [x] **Step 3: Implementieren.** `GeraetRoute.swift`, zwischen `erkannt` und `geraet`:

```swift
/// "Training starten" -- nur ohne laufendes Training (TrainingStart.ziel).
/// Mit dem Tap dort entsteht die Einheit; der Fall wird dann durch
/// `geraet` ERSETZT, damit "Zurueck" vom Satzpfad nicht auf einen
/// Startknopf fuer ein Training fuehrt, das schon laeuft.
case start(machineId: String, exerciseId: String, token: String?)
```

`TrainingStart.swift`:

```swift
import Foundation

/// Wohin es nach der Wahl von Geraet und Uebung geht -- und wann der Screen
/// "Training starten" dazwischen steht (Sammelstelle Punkt 10, entschieden
/// 15. September).
///
/// Nur ohne laufendes Training. Mitten im Training kostet das naechste
/// Geraet keinen Tap mehr als bisher (Scan, Uebung, Satz); der Zirkel ueber
/// die Blockliste hat ohnehin immer ein laufendes Training. Drei Aufrufer
/// in TrainingRootView, eine Regel -- deshalb hier, mit Test.
enum TrainingStart {
    static func ziel(machineId: String, exerciseId: String, token: String?,
                     trainingLaeuft: Bool) -> GeraetRoute {
        trainingLaeuft
            ? .geraet(machineId: machineId, exerciseId: exerciseId, token: token)
            : .start(machineId: machineId, exerciseId: exerciseId, token: token)
    }
}
```

Der `switch` in `TrainingRootView.ziel(_:)` ist danach nicht mehr erschöpfend — für diesen Task dort einen Fall `case .start: EmptyView()` mit Kommentar `// Task 3 baut den Screen.` einfügen, damit der Build steht.

- [x] **Step 4: Grün sehen.** `xcodebuild test`, ganz. `git status`: `Package.resolved` unverändert, die zwei neuen Dateien und `project.pbxproj` dabei.

- [x] **Step 5: Commit** — `feat(training): TrainingStart entscheidet, wann der Startscreen kommt`

---

## Task 3: Der Screen „Training starten“ und die Texte (Punkt 10, View)

**Erst nach dem Rebase auf `master` mit PR #12 und dem Fix „Gerät ohne Einstellwerte“** (Global Constraints).

### Was der Screen zeigt

Kopfzeile (Ort · Einstiegsart, wie auf „Gerät erkannt“), Gerätename groß, die gewählte Übung, eine Karte, die sagt, was der Tap tut — und unten die eine Hauptaktion „Training starten“. Kein Gerätefoto (steht auf „Gerät erkannt“ davor; hier kostete es 204 pt, siehe Budget), kein Rückblick und kein Vorschlag (die stehen im Drawer des Satzpfads, Schnitt 3), keine Räder (die App misst nichts, und ein Rad vor dem Start wäre ein zweiter Satzpfad).

### Das Höhenbudget

Rahmen wie im Nachtrag von Schnitt 3 **gemessen** (SE 3. Gen., iOS 26.3, 15. September): Navigationsleiste 54 pt (Inhalt ab y 74), untere Safe Area 83 pt für die schwebende Tab-Leiste — dem Inhalt bleiben **510 pt**. Zeilenhöhen aus den SF-Metriken (11 pt Heavy 13,0 · 13 pt 15,3 · 15 pt 17,7 · 17 pt Semibold 20,0 · 32 pt Black 37,7).

| Element | pt |
| --- | ---: |
| oberes Padding | 24 |
| Kopfzeile (Label · Ort, Einstiegsart) | 13,0 |
| Abstand | 8 |
| Gerätename (32 pt Black, `lineLimit(1)`, `minimumScaleFactor(0.75)`) | 37,7 |
| Abstand | 4 |
| Übung (17 pt Semibold) | 20,0 |
| Abstand | 24 |
| Karte: Label 13,0 + 8 + drei Zeilen 15 pt mit `lineSpacing(3)` 59,1 + 2 × 16 Padding | 112,1 |
| **Inhalt** | **242,8** |
| Fuß im `safeAreaInset`: Knopf 64 + 24 | 88 |
| **Summe** | **330,8 von 510** |

179 pt Reserve; mit Gerätefoto (180 + 24) wären es −25. Der Screen scrollt nicht; die Karte bricht bei langem Text auf vier Zeilen um (+17,7) und bleibt im Budget. Der Sichtcheck (Task 9) misst nach.

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Training/TrainingStartView.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (`zeigeAusgelaufenHinweis`, `body` `.task(id:)` und `.onChange(of: sessions.aktiveSession() != nil)`, `fuss(laeuft:)`, `laufendeMitte` (`zirkelHinweis`), `laufendKopf` (Kommentar „seit“), `ziel(_:)`, `navigiere(zu:token:in:)`, `beenden()`)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetErkanntView.swift` (Typkommentar, `hinweis`)
- Modify: `apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift` (`leer`, Schritt 3, Z. 278)

**Interfaces:**
- Consumes: `WorkoutSessionStore.trainingStarten()` (Task 1), `TrainingStart.ziel(...)` und `GeraetRoute.start` (Task 2), `GeraetModel.maschine`, `.aktiveUebung`, `.einstiegsart`, `.uebungId` (Bestand).
- Produces: `TrainingStartView(modell: GeraetModel, beiStart: () -> Void)`; in `TrainingRootView` ein privates `enum TabHinweis { case ausgelaufen, verworfen }` an Stelle von `zeigeAusgelaufenHinweis: Bool`.

- [x] **Step 1: `TrainingStartView.swift`.**

```swift
import SwiftUI

/// "Training starten" -- der Screen zwischen Uebungswahl und Satzpfad, nur
/// ohne laufendes Training (TrainingStart.ziel). Mit dem Tap unten entsteht
/// die Einheit und die Uhr laeuft (Sammelstelle Punkt 10, entschieden
/// 15. September; hebt M1-Spec SS5.6 "es gibt keinen Startknopf" auf).
///
/// Kein Geraetefoto: es steht auf "Geraet erkannt" davor, und hier kostete
/// es 204 pt von 510 auf einem 667-pt-iPhone (Plan Schnitt 4, Task 3).
/// Kein Rueckblick, kein Vorschlag, keine Raeder: die gehoeren zum
/// Satzpfad, und "die App misst nichts" beginnt erst mit einem Satz.
struct TrainingStartView: View {
    let modell: GeraetModel
    let beiStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                kopfzeile
                geraetUndUebung
                    .padding(.top, DesignSystem.Spacing.s8)
                erklaerung
                    .padding(.top, DesignSystem.Spacing.s24)
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
        }
        // Der Inhalt ist 243 pt hoch, das kleinste iPhone laesst 510: die
        // Seite soll nicht federn wie eine, die mehr zu zeigen haette.
        .scrollBounceBehavior(.basedOnSize)
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            // Die eine Akzentflaeche des Screens (designsystem.md SS2), 64 pt
            // (SS4). Nie deaktiviert: sie haengt an nichts, was vom Netz
            // kommen koennte.
            PrimaryButton(title: "Training starten") { beiStart() }
                .padding(.horizontal, 20)
                .padding(.bottom, DesignSystem.Spacing.s24)
                .background(DesignSystem.Color.bg)
                .testnotizElement("training.starten", typ: "PrimaryButton")
        }
        .navigationBarTitleDisplayMode(.inline)
        .testnotizScreen(kontext: ["machineId": modell.maschine.id, "exerciseId": modell.uebungId])
    }

    /// Dieselbe Zeile wie auf "Geraet erkannt": wer ueber den Scan kommt,
    /// sieht "ERKANNT", wer ueber die Liste kommt, "AUSGEWAEHLT" -- die App
    /// weiss im zweiten Fall nicht, wo das Mitglied steht (designsystem.md
    /// SS10).
    private var kopfzeile: some View {
        HStack {
            Text([modell.maschine.label, modell.maschine.locationNote]
                .compactMap { $0 }.joined(separator: " · ").uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
            Spacer()
            Label(modell.einstiegsart.beschriftung, systemImage: modell.einstiegsart.symbol)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    private var geraetUndUebung: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            // Schrumpfen statt kuerzen, wie im Satzpfad (Schnitt 3): ein
            // abgeschnittener Name sagt nicht, an welchem Geraet man steht.
            Text(modell.maschine.equipmentModel.name.uppercased())
                .font(DesignSystem.Typography.geraetename)
                .tracking(-0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(DesignSystem.Color.text)
            Text(modell.aktiveUebung?.name ?? "")
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    /// Sagt, was der Tap tut und was ohne Satz passiert -- der eine Ort,
    /// an dem das Mitglied die Regel aus Entschieden 2 zu lesen bekommt.
    /// Kein textFaint: das ist tragende Information (designsystem.md SS2).
    private var erklaerung: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text("WAS JETZT PASSIERT")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            Text("Mit „Training starten“ läuft die Uhr — auch während Einweisung und Einstellung. Sicherst du keinen Satz, wird das Training verworfen und taucht nirgends auf.")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.text)
                .lineSpacing(3)
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        // Ein gesprochener Satz statt zweier Bruchstuecke; kein
        // Bedienelement darin, das dabei verschwinden koennte.
        .accessibilityElement(children: .combine)
    }
}
```

Kein `#Preview`: ein `GeraetModel` braucht Bootstrap, Loader und Store, und weder `GeraetView` noch `GeraetErkanntView` haben deshalb eine Preview — der Sichtcheck (Task 9) zeigt den Screen. `DesignSystem.Typography.geraetename`, `.uebungsname`, `.label`, `.fliesstext` sowie `Einstiegsart.beschriftung`/`.symbol` sind Bestand (`GeraetErkanntView`, `SessionDetailView`, `GeraetModel`).

- [x] **Step 2: `TrainingRootView` verdrahten.**

1. **`ziel(_:)`**, der Platzhalter aus Task 2 wird:

```swift
case .start(let machineId, let exerciseId, let token):
    if let modell = modell(machineId: machineId, exerciseId: exerciseId, token: token) {
        TrainingStartView(modell: modell) {
            sessions.trainingStarten()
            // ERSETZEN, nicht stapeln: "Zurueck" vom Satzpfad soll auf
            // "Geraet erkannt" fuehren, nicht auf einen Startknopf fuer ein
            // Training, das schon laeuft. Der Startscreen ist immer der
            // oberste Eintrag, wenn sein Knopf gedrueckt wird; der Guard
            // schuetzt nur vor einem Tap waehrend einer laufenden
            // Pop-Animation.
            let satzpfad = GeraetRoute.geraet(machineId: machineId, exerciseId: exerciseId, token: token)
            if case .start = pfad.last { pfad[pfad.count - 1] = satzpfad } else { pfad.append(satzpfad) }
        }
    }
```

2. **Übungswahl** in `case .erkannt`: `pfad.append(.geraet(machineId: machineId, exerciseId: uebungId, token: token))` wird
   `pfad.append(TrainingStart.ziel(machineId: machineId, exerciseId: uebungId, token: token, trainingLaeuft: sessions.aktiveSession() != nil))`.

3. **`navigiere(zu:token:in:)`**, Fall `.direktZumSatz`: dieselbe Ersetzung — `pfad.append(TrainingStart.ziel(machineId: maschine.id, exerciseId: uebung, token: token, trainingLaeuft: sessions.aktiveSession() != nil))`. Kommentar dazu: `// Auch der Direktweg beginnt ohne laufendes Training auf dem Startscreen -- sonst entstuende die Einheit fuer Stammgaeste weiter erst mit dem Satz.`

4. **`oeffne(_ block:)`** bleibt `.geraet` — Kommentar ergänzen: `// Kein TrainingStart.ziel: die Blockliste gibt es nur, solange ein Training laeuft.`

5. **Hinweis im Fuß.** `@State private var zeigeAusgelaufenHinweis = false` wird `@State private var hinweis: TabHinweis?`; der lange Kommentar davor bleibt inhaltlich, mit zwei Änderungen: „zeigeAusgelaufenHinweis“ heißt jetzt `hinweis`, und der Absatz zu `beenden()` wird „die beiden Zweige von `beenden()` (manuelles Beenden mit Satz setzt nil, ohne Satz `.verworfen`)“. Am Ende der Datei neben `UmschaltTick`:

```swift
/// Der Satz im Fuss ueber einer Einheit, die nicht mehr laeuft. Zwei
/// Faelle, ein Zustand: gleichzeitig gelten sie nie, und ein zweites Bool
/// haette zwei Banner uebereinander erlaubt.
private enum TabHinweis {
    /// Vier Stunden ohne Satz -- die Einheit MIT Saetzen ist beim Server
    /// (oder in der Warteschlange) und gilt als beendet.
    case ausgelaufen
    /// "Training beenden" ohne einen Satz: verworfen, nie gemeldet
    /// (Sammelstelle, Entschieden 2). Nie stumm -- der Tap hatte eine
    /// Wirkung, und die soll man lesen koennen.
    case verworfen

    var text: String {
        switch self {
        case .ausgelaufen: "Dein letztes Training wurde automatisch beendet."
        case .verworfen: "Kein Satz gesichert — das Training wurde verworfen."
        }
    }
}
```

   `fuss(laeuft:)`: `if zeigeAusgelaufenHinweis { InlineBanner(tone: .muted, message: "Dein letztes Training wurde automatisch beendet.") }` wird `if let hinweis { InlineBanner(tone: .muted, message: hinweis.text) }`.

   Das `.task(id: UmschaltTick(...))`:

```swift
.task(id: UmschaltTick(datum: context.date, wach: neuAuswerten)) {
    // Mit Satz bekommt die ausgelaufene Einheit den Satz im Fuss; ohne
    // Satz liefert abgelaufeneSession() nichts, und sie wird still
    // geraeumt (Entschieden 2). ausgelaufeneQuittieren() raeumt beide.
    if sessions.abgelaufeneSession() != nil { hinweis = .ausgelaufen }
    sessions.ausgelaufeneQuittieren()
}
```

   `.onChange(of: sessions.aktiveSession() != nil) { _, laeuft in if laeuft { hinweis = nil } }`.

   `beenden()`:

```swift
private func beenden() {
    guard let session = sessions.aktiveSession(),
          let zusammenfassung = Trainingszusammenfassung(session)
    else {
        // Ohne Satz gibt es keinen Abschluss und nichts, was der Server
        // wissen muesste: die Einheit wird verworfen (Entschieden 2). Das
        // trifft seit Schnitt 4 den Regelfall "Training starten, dann doch
        // nicht" -- und weiterhin den seltenen, dass die Einheit zwischen
        // Neuzeichnen und Tap ausgelaufen ist. sessions.beenden() raeumt
        // unbedingt, anders als ausgelaufeneQuittieren().
        hinweis = .verworfen
        sessions.beenden()
        return
    }
    // Der Satz im Fuss gehoert zu GENAU EINER frueheren Einheit (M1): mit
    // dem manuellen Beenden hier gilt er nicht mehr.
    hinweis = nil
    // Erst festhalten, dann beenden -- andersherum sind die Zahlen weg,
    // bevor der Screen sie zeigt.
    sessions.beenden()
    pfad.append(.abschluss(sessionId: session.id, zusammenfassung: zusammenfassung))
}
```

6. **`laufendeMitte`**: `zirkelHinweis` steht nur noch, wenn `!session.bloecke.isEmpty` — vor dem ersten Satz gibt es keinen Block, auf den man tippen könnte, und „Zweiter Durchgang?“ über einer leeren Liste wäre ein Rätsel. Kommentar am `if`: `// Vor dem ersten Satz (seit Schnitt 4 moeglich) gibt es keinen Block zum Antippen -- der Satz zum Zirkel waere ein Raetsel.`

7. **`laufendKopf`**, der Kommentar an `Text("seit …")` wird: `// Der Beginn ist seit Schnitt 4 der Tap auf "Training starten". Die Zeile bleibt: eine Uhr ohne Anker ("23:41 -- seit wann?") sagt nichts.`

- [x] **Step 3: Die zwei Texte.** Der dritte aus der Sammelstelle (`TrainingRootView.leerInhalt`, „Dein Training startet von selbst, sobald du den ersten Satz sicherst — es gibt keinen Startknopf“) existiert seit Schnitt 2 nicht mehr — im Fuß steht nur noch „Training starten“ über den Scanwegen, und das bleibt richtig. Im Abschlussbericht vermerken.

`GeraetErkanntView.swift`, Typkommentar:

```swift
/// "Was machst du heute?" -- die Uebungsliste eines erkannten Geraets.
///
/// Ein Tap auf eine Uebung waehlt sie; es gibt keinen Bestaetigungsknopf
/// (designsystem.md SS8). Ohne laufendes Training folgt "Training starten"
/// (TrainingStart.ziel, Schnitt 4), sonst direkt der Satzpfad.
```

`hinweis`: `"Ein Tap wählt die Übung. Läuft noch kein Training, kommt danach „Training starten“. Trainierst du hier immer dasselbe, überspringt gymodo diese Liste künftig."`

`HomeRootView.swift` Z. 278: `schritt(3, "Training starten, Sätze sichern", "Ein Tap startet die Uhr. Jeder Satz danach ist meistens nur ein Antippen.")`

- [x] **Step 4: `xcodegen generate`, `xcodebuild test`**, ganz. `grep -rn "zeigeAusgelaufenHinweis\|startet dabei von selbst\|landest direkt beim Satz" apps/ios-member` — nichts mehr. `git status`: `Package.resolved` unverändert.

- [x] **Step 5: Im Simulator (iPhone 17 Pro) einmal bauen und den Startscreen ansehen** — geht nur mit Backend; deshalb hier nur bauen, der Sichtcheck in Task 9 prüft.

- [x] **Step 6: Commit** — `feat(training): Screen Training starten nach Geraete- und Uebungswahl`

---

## Task 4: Die Dauer beginnt beim Start (Punkt 10, Zusammenfassung und Server-Beginn — Frage c)

Punkt 10: „Die Dauer wird ehrlicher. Sie enthält dann Einweisung und Einstellung.“ Das stimmt heute an keiner der zwei Stellen, die eine Dauer zeigen:

- **Abschluss-Screen:** `Trainingszusammenfassung.init` rechnet `von` und `dauerMinuten` ab dem ersten Satz, nicht ab `session.startedAt`.
- **Home-Karte und Serie:** `recordSet` upsertet `workout_sessions` ohne `started_at` — die Spalte bekommt ihren Default `now()`, also den Zeitpunkt, an dem der erste Satz-PUT **beim Server ankommt**. Nach einem Offline-Training ist das Stunden später. Der Client muss den Beginn mitschicken.

Das zweite ist eine Server-Änderung über „eine Migration“ hinaus (ein optionales Feld im Satz-PUT). Ohne sie zeigte die App „seit 18:04“ und Home „ab 18:12“ für dieselbe Einheit. **Empfehlung: mitnehmen** (Frage c unten); wird sie verneint, entfallen Step 3 bis 6 und der Commit-Betreff wird `feat(training): Die Dauer auf dem Abschluss-Screen beginnt beim Start`.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/Trainingszusammenfassung.swift` (`init`)
- Modify: `apps/ios-member/FitnessMemberTests/TrainingszusammenfassungTests.swift` (`rechnetDauerVomErstenBisZumLetztenSatz`)
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/WorkoutSet.swift` (`SetWrite`)
- Modify: `apps/ios-member/FitnessMember/Workout/WorkoutSessionStore.swift` (`satzSichern`, `body`)
- Modify: `apps/ios-member/FitnessMemberTests/WorkoutSessionStoreTests.swift` (neuer Test)
- Modify: `packages/domain/src/workout.ts` (`recordSetInputSchema`, `recordSet`)
- Create: `packages/domain/src/workout.test.ts`
- Modify: `tests/integration/domain-record-set.test.ts`

**Interfaces:**
- Produces:
  - `SetWrite.sessionStartedAt: String? = nil` (ISO 8601, wie `performedAt`).
  - Server: `sessionStartedAt` optional im Rumpf des Satz-PUT; wird nur beim Anlegen der Session übernommen.
  - `Trainingszusammenfassung.von == session.startedAt`.

- [x] **Step 1: Swift-Tests.** In `TrainingszusammenfassungTests.swift` wird `rechnetDauerVomErstenBisZumLetztenSatz`:

```swift
@Test func rechnetDauerVomStartBisZumLetztenSatz() throws {
    // Der erste Satz faellt zehn Minuten nach dem Start: Einweisung und
    // Einstellung gehoeren zum Training (Sammelstelle Punkt 10).
    let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
        LokalerBlock(machineId: "m1", exerciseId: "e1",
                     saetze: [satz(1, 80, 10), satz(2, 80, 47)]),
    ])

    let z = try #require(Trainingszusammenfassung(session))

    #expect(z.dauerMinuten == 47)
    #expect(z.von == start)
    #expect(z.bis == start.addingTimeInterval(47 * 60))
}
```

In `WorkoutSessionStoreTests.swift`, Abschnitt „Start der Einheit“:

```swift
@Test func derSatzTraegtDenBeginnDerEinheitZumServer() {
    let (sut, _) = store()
    sut.trainingStarten(jetzt: start)

    let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                      problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(600))

    // Sonst bekaeme die Session beim Server den Zeitpunkt des ersten PUT
    // als Beginn -- nach einem Offline-Training Stunden spaeter.
    #expect(geschrieben.body.sessionStartedAt == ISO8601DateFormatter().string(from: start))
}
```

- [x] **Step 2: Rot sehen.** `-only-testing:FitnessMemberTests/TrainingszusammenfassungTests -only-testing:FitnessMemberTests/WorkoutSessionStoreTests`. Erwartet: der Dauer-Test schlägt mit 37 statt 47 fehl; der Store-Test bricht am Build („no member 'sessionStartedAt'“).

- [x] **Step 3: Swift implementieren.** `Trainingszusammenfassung.init`:

```swift
/// nil fuer eine Einheit ohne Saetze -- die wird verworfen, nicht
/// abgeschlossen (Entschieden 2), und ein Abschluss ohne Inhalt waere eine
/// leere Statistik mit Nullen (SS5).
init?(_ session: LokaleSession) {
    let alle = session.bloecke.flatMap(\.saetze)
    guard let letzter = alle.map(\.performedAt).max() else { return nil }

    // Ab dem Start, nicht ab dem ersten Satz: seit Schnitt 4 hat das
    // Mitglied den Beginn selbst gesetzt, und Einweisung und Einstellung
    // gehoeren zum Training (Sammelstelle Punkt 10).
    von = session.startedAt
    bis = letzter
    dauerMinuten = Int(letzter.timeIntervalSince(session.startedAt) / 60)
    // geraeteAnzahl, satzAnzahl und bloecke bleiben, wie sie sind.
```

`SetWrite` bekommt als letztes Feld:

```swift
/// Der Beginn der Einheit, ISO 8601 wie performedAt. Der Server legt die
/// Session mit dem ersten Satz an und uebernimmt ihn dabei -- ohne ihn
/// staende dort die Ankunft des ersten PUT, nach einem Offline-Training
/// Stunden nach dem Start (Sammelstelle Punkt 10).
var sessionStartedAt: String? = nil
```

`satzSichern`, beim Bau von `body`: `sessionStartedAt: ISO8601DateFormatter().string(from: session.startedAt)` (denselben Formatter wie für `performedAt` einmal in eine lokale Konstante ziehen, statt ihn zweimal zu bauen).

- [x] **Step 4: Server-Test.** `packages/domain/src/workout.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { recordSetInputSchema } from "./workout.js";

const basis = {
  sessionId: "11111111-1111-4111-8111-111111111111",
  setId: "22222222-2222-4222-8222-222222222222",
  machineId: "33333333-3333-4333-8333-333333333333",
  exerciseId: "44444444-4444-4444-8444-444444444444",
  setIndex: 1,
  weightKg: 80,
  reps: 10,
};

describe("recordSetInputSchema", () => {
  it("nimmt den Beginn der Einheit an", () => {
    const ergebnis = recordSetInputSchema.safeParse({
      ...basis,
      sessionStartedAt: "2026-09-15T16:04:00.000Z",
      performedAt: "2026-09-15T16:14:00.000Z",
    });
    expect(ergebnis.success).toBe(true);
  });

  // Ein Beginn nach dem Satz waere eine negative Dauer auf Home.
  it("weist einen Beginn nach dem Satz ab", () => {
    const ergebnis = recordSetInputSchema.safeParse({
      ...basis,
      sessionStartedAt: "2026-09-15T16:20:00.000Z",
      performedAt: "2026-09-15T16:14:00.000Z",
    });
    expect(ergebnis.success).toBe(false);
  });
});
```

In `tests/integration/domain-record-set.test.ts` wird der Test `legt die Session implizit an -- es gibt keinen Startknopf` umbenannt in `legt die Session mit dem ersten Satz an -- einen Start-Endpoint gibt es nicht` (Inhalt unverändert), und dahinter:

```ts
it("uebernimmt den Beginn der Einheit vom Client, und nur beim ersten Satz", async () => {
  const client = await userClient(memberAEmail);
  const sessionId = newId();
  const beginn = "2026-09-15T16:04:00.000Z";

  await recordSet(client, payload({ sessionId, sessionStartedAt: beginn, performedAt: "2026-09-15T16:14:00.000Z" }));
  // Ein zweiter Satz mit anderem Beginn verschiebt nichts (ignoreDuplicates).
  await recordSet(client, payload({ sessionId, setIndex: 2, sessionStartedAt: "2026-09-15T16:30:00.000Z", performedAt: "2026-09-15T16:31:00.000Z" }));

  const admin = serviceClient();
  const { data } = await admin
    .from("workout_sessions")
    .select("started_at")
    .eq("id", sessionId)
    .single();
  expect(Date.parse(data!.started_at)).toBe(Date.parse(beginn));
});
```

Rot sehen: `pnpm --filter @fitretro/domain test` — „weist einen Beginn nach dem Satz ab“ schlägt fehl (unbekannte Felder werden von Zod verworfen, das Schema akzeptiert). Integrationstest: `started_at` ≠ `beginn`.

- [x] **Step 5: Server implementieren** (`workout.ts`). Im Schema nach `performedAt`:

```ts
    // Der Beginn der Einheit, vom Client gesetzt ("Training starten",
    // Schnitt 4). Nur beim Anlegen der Session uebernommen, siehe recordSet.
    sessionStartedAt: z.string().datetime().optional(),
```

und ein zweites `.refine`:

```ts
  .refine(
    (value) =>
      !value.sessionStartedAt ||
      !value.performedAt ||
      Date.parse(value.sessionStartedAt) <= Date.parse(value.performedAt),
    { path: ["sessionStartedAt"], message: "Der Beginn der Einheit liegt nach dem Satz." },
  );
```

Der Kommentar an `recordSet` wird: „Idempotent durch die clientseitig erzeugten UUIDs … Die Session entsteht dabei mit dem ersten Satz -- einen Start-Endpoint gibt es nicht, und deshalb liegt eine Einheit ohne Satz nie hier (Sammelstelle Schnitt 4, Entschieden 2). Ihren Beginn setzt der Client (Spec 5.2, seit Schnitt 4).“ Der Upsert:

```ts
  // `ignoreDuplicates` macht daraus ON CONFLICT DO NOTHING: ein zweiter Satz
  // in derselben Session verschiebt deren Startzeitpunkt nicht -- auch
  // nicht mit einem anderen sessionStartedAt.
  const { error: sessionError } = await client.from("workout_sessions").upsert(
    {
      id: input.sessionId,
      studio_id: studioId,
      user_id: userId,
      // Ohne den Wert griffe der Default now(): die Ankunft des ersten PUT,
      // nach einem Offline-Training Stunden nach dem Start.
      ...(input.sessionStartedAt ? { started_at: input.sessionStartedAt } : {}),
    },
    { onConflict: "id", ignoreDuplicates: true },
  );
```

- [x] **Step 6: Grün sehen.** `pnpm typecheck`, `pnpm test`, `pnpm test:integration`; `xcodebuild test`, ganz.

- [x] **Step 7: Commit** — `feat(training): Die Dauer beginnt beim Start -- Zusammenfassung und Server uebernehmen den Beginn`

---

## Task 5: Server — eine eigene Einheit lässt sich löschen (Punkt 19)

Migration, Domain-Funktion, Route, Tests. Die Sätze gehen per `on delete cascade` (0013) mit; referenzielle Aktionen laufen an RLS vorbei, `workout_sets` braucht dafür keine eigene Delete-Policy. `progression_suggestions` trägt keine `session_id` (siehe Kommentar in `abschluss.ts`) und bleibt stehen — sie ist eine Rechnung über die Historie, keine Zeile der Einheit.

Antwort auf eine unbekannte oder fremde Kennung: **204**, wie `deleteMeasurement` — RLS blendet fremde Zeilen aus, der Aufruf trifft null Zeilen, und „nicht gefunden“ verriete, dass es die Kennung gibt.

**Files:**
- Create: `supabase/migrations/0044_workout_sessions_delete.sql`
- Modify: `packages/domain/src/workout.ts` (neu `deleteSessionInputSchema`, `deleteSession`)
- Modify: `packages/domain/src/index.ts` (Export)
- Create: `apps/web/app/api/v1/workout-sessions/[sessionId]/route.ts`
- Modify: `tests/integration/rls-workout-sessions.test.ts` (Test Z. 216 wird umgekehrt, ein Negativtest dazu)
- Create: `tests/integration/api-workout-session-delete.test.ts`

**Interfaces:**
- Produces:
  - `DELETE /api/v1/workout-sessions/{sessionId}` → 204 (auch beim zweiten Aufruf und bei fremder Kennung), 401 ohne Bearer, 422 bei ungültiger UUID.
  - `deleteSession(client: SupabaseClient, rawInput: unknown): Promise<void>` mit `{ sessionId }`.
  - Policy `workout_sessions_delete`.

- [x] **Step 1: RLS-Tests.** In `rls-workout-sessions.test.ts` wird `Historie: auch die eigene Session laesst sich nicht loeschen` ersetzt durch zwei Tests:

```ts
  it("positiv: ein Mitglied loescht seine eigene Session, die Saetze gehen mit", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = newId();
    const { error: insertError } = await client
      .from("workout_sessions")
      .insert({ id: sessionId, studio_id: studioA, user_id: memberAId });
    if (insertError) throw insertError;
    const { error: setError } = await client.from("workout_sets").insert({
      id: newId(), studio_id: studioA, user_id: memberAId, session_id: sessionId,
      machine_id: machineA, exercise_id: exerciseA, set_index: 1, weight_kg: 80, reps: 10,
    });
    if (setError) throw setError;

    const { error } = await client.from("workout_sessions").delete().eq("id", sessionId);
    expect(error).toBeNull();

    const admin = serviceClient();
    const { data: sessions } = await admin.from("workout_sessions").select("id").eq("id", sessionId);
    const { data: sets } = await admin.from("workout_sets").select("id").eq("session_id", sessionId);
    expect(sessions).toHaveLength(0);
    // Cascade aus 0013 -- ohne eigene Delete-Policy auf workout_sets.
    expect(sets).toHaveLength(0);
  });

  it("negativ: die Session eines anderen Mitglieds laesst sich nicht loeschen", async () => {
    const a = await userClient(memberAEmail);
    const sessionId = newId();
    const { error: insertError } = await a
      .from("workout_sessions")
      .insert({ id: sessionId, studio_id: studioA, user_id: memberAId });
    if (insertError) throw insertError;

    const a2 = await userClient(memberA2Email);
    await a2.from("workout_sessions").delete().eq("id", sessionId);

    const admin = serviceClient();
    const { data } = await admin.from("workout_sessions").select("id").eq("id", sessionId);
    expect(data).toHaveLength(1);
  });
```

Das `beforeAll` dieser Datei legt bisher kein Gerät und keine Übung an. Oben bei den `let`-Deklarationen `let machineA: string;` und `let exerciseA: string;` ergänzen und im `beforeAll` hinter dem Mitgliedschafts-Insert:

```ts
  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Sessions-Kabelzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: machine, error: machineError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: model.id, label: "S1" })
    .select("id")
    .single();
  if (machineError) throw machineError;
  machineA = machine.id;

  const { data: exercise, error: exerciseError } = await admin
    .from("exercises")
    .insert({ studio_id: studioA, name: "Sessions-Latzug", target_reps_min: 8, target_reps_max: 12 })
    .select("id")
    .single();
  if (exerciseError) throw exerciseError;
  exerciseA = exercise.id;
```

- [x] **Step 2: API-Test** `tests/integration/api-workout-session-delete.test.ts`, nach dem Muster von `api-workout-sets.test.ts` (dasselbe `beforeAll`: Studio A und B, Mitglied A und A2, Gerät und Übung in A):

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { PUT } from "@/app/api/v1/workout-sessions/[sessionId]/sets/[setId]/route";
import { DELETE } from "@/app/api/v1/workout-sessions/[sessionId]/route";
import { accessTokenFor, createTestUser, serviceClient, uniqueEmail } from "./helpers/clients.js";

let studioA: string;
let memberAEmail: string;
let memberA2Email: string;
let machineA: string;
let exerciseA: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "API Loeschen Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioA = studio.id;

  memberAEmail = uniqueEmail("api-loeschen-a");
  memberA2Email = uniqueEmail("api-loeschen-a2");
  const memberAId = await createTestUser(memberAEmail);
  const memberA2Id = await createTestUser(memberA2Email);

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: memberAId, role: "member" },
      { studio_id: studioA, user_id: memberA2Id, role: "member" },
    ]);
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Beinpresse", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: machine, error: machineError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: model.id, label: "07" })
    .select("id")
    .single();
  if (machineError) throw machineError;
  machineA = machine.id;

  const { data: exercise, error: exerciseError } = await admin
    .from("exercises")
    .insert({ studio_id: studioA, name: "Beidbeinig", target_reps_min: 8, target_reps_max: 12 })
    .select("id")
    .single();
  if (exerciseError) throw exerciseError;
  exerciseA = exercise.id;
});

function deleteRequest(sessionId: string, bearer?: string): Request {
  return new Request(`http://localhost/api/v1/workout-sessions/${sessionId}`, {
    method: "DELETE",
    headers: bearer ? { authorization: `Bearer ${bearer}` } : {},
  });
}

function deleteContext(sessionId: string): { params: Promise<{ sessionId: string }> } {
  return { params: Promise.resolve({ sessionId }) };
}

async function einheitMitSatz(bearer: string): Promise<{ sessionId: string; setId: string }> {
  const sessionId = crypto.randomUUID();
  const setId = crypto.randomUUID();
  const response = await PUT(
    new Request(`http://localhost/api/v1/workout-sessions/${sessionId}/sets/${setId}`, {
      method: "PUT",
      headers: { "content-type": "application/json", authorization: `Bearer ${bearer}` },
      body: JSON.stringify({ machineId: machineA, exerciseId: exerciseA, setIndex: 1, weightKg: 80, reps: 10 }),
    }),
    { params: Promise.resolve({ sessionId, setId }) },
  );
  expect(response.status).toBe(200);
  return { sessionId, setId };
}

describe("DELETE /workout-sessions/{id}", () => {
  it("loescht die eigene Einheit samt Saetzen und antwortet 204", async () => {
    const bearer = await accessTokenFor(memberAEmail);
    const { sessionId, setId } = await einheitMitSatz(bearer);

    const response = await DELETE(deleteRequest(sessionId, bearer), deleteContext(sessionId));

    expect(response.status).toBe(204);
    const admin = serviceClient();
    expect((await admin.from("workout_sessions").select("id").eq("id", sessionId)).data).toHaveLength(0);
    expect((await admin.from("workout_sets").select("id").eq("id", setId)).data).toHaveLength(0);
  });

  it("antwortet auch beim zweiten Aufruf mit 204", async () => {
    const bearer = await accessTokenFor(memberAEmail);
    const { sessionId } = await einheitMitSatz(bearer);
    await DELETE(deleteRequest(sessionId, bearer), deleteContext(sessionId));

    const response = await DELETE(deleteRequest(sessionId, bearer), deleteContext(sessionId));

    expect(response.status).toBe(204);
  });

  it("laesst die Einheit eines anderen Mitglieds stehen -- und verraet sie nicht", async () => {
    const bearerA = await accessTokenFor(memberAEmail);
    const { sessionId } = await einheitMitSatz(bearerA);
    const bearerA2 = await accessTokenFor(memberA2Email);

    const response = await DELETE(deleteRequest(sessionId, bearerA2), deleteContext(sessionId));

    expect(response.status).toBe(204);
    const admin = serviceClient();
    expect((await admin.from("workout_sessions").select("id").eq("id", sessionId)).data).toHaveLength(1);
  });

  it("weist einen Aufruf ohne Anmeldung mit 401 ab", async () => {
    const response = await DELETE(deleteRequest(crypto.randomUUID()), deleteContext(crypto.randomUUID()));
    expect(response.status).toBe(401);
  });

  it("weist eine unbrauchbare Kennung mit 422 ab", async () => {
    const bearer = await accessTokenFor(memberAEmail);
    const response = await DELETE(deleteRequest("x", bearer), deleteContext("x"));
    expect(response.status).toBe(422);
  });
});
```

- [x] **Step 3: Rot sehen.** `pnpm test:integration -- rls-workout-sessions api-workout-session-delete`. Erwartet: der positive RLS-Test findet die Zeile noch (keine Policy); die API-Datei bricht am Import der Route.

- [x] **Step 4: Migration** `supabase/migrations/0044_workout_sessions_delete.sql`:

```sql
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
```

Lokal einspielen: `supabase db reset` in `apps/web` (oder wie die anderen Migrationen dieses Repos lokal eingespielt werden — `supabase migration up` prüfen), bevor die Integrationstests laufen.

- [x] **Step 5: Domain und Route.** `workout.ts`, ans Ende:

```ts
export const deleteSessionInputSchema = z.object({
  sessionId: z.string().uuid("Die Kennung der Einheit ist keine gueltige UUID."),
});

/**
 * Loescht eine eigene Einheit samt Saetzen (Cascade aus 0013) --
 * Sammelstelle Punkt 19.
 *
 * Idempotent wie deleteMeasurement: eine Einheit, die es nicht (mehr) gibt,
 * ist danach genau das. RLS blendet fremde aus, der Aufruf trifft dann null
 * Zeilen und antwortet trotzdem ohne Fehler -- "nicht gefunden" verriete,
 * dass es die Kennung gibt. Der zusaetzliche Filter auf user_id sagt das
 * auch dem Leser, nicht nur der Policy.
 */
export async function deleteSession(
  client: SupabaseClient,
  rawInput: unknown,
): Promise<void> {
  const parsed = deleteSessionInputSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }
  const userId = await requireUserId(client);

  const { error } = await client
    .from("workout_sessions")
    .delete()
    .eq("id", parsed.data.sessionId)
    .eq("user_id", userId);
  if (error) {
    throw new DomainError("internal", "Die Einheit konnte nicht geloescht werden.");
  }
}
```

`index.ts`: `deleteSession` neben `completeSession` und `recordSet` exportieren (die bestehende Export-Zeile für `workout.js` erweitern).

`apps/web/app/api/v1/workout-sessions/[sessionId]/route.ts`:

```ts
import { deleteSession } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ sessionId: string }> };

/**
 * Loescht eine eigene Einheit (Sammelstelle Punkt 19, Schnitt 4). Eine
 * Einheit, die es nicht (mehr) gibt, ist danach genau das -- kein 404,
 * deshalb antwortet auch ein zweiter Aufruf mit 204, und eine fremde
 * Kennung ebenso (RLS trifft null Zeilen, siehe deleteSession).
 */
export async function DELETE(request: Request, context: Context): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  const { sessionId } = await context.params;
  try {
    await deleteSession(client, { sessionId });
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}
```

- [x] **Step 6: Grün sehen.** `pnpm typecheck`, `pnpm test`, `pnpm test:integration` (ganz — `domain-sessions`, `studio-ueberblick` und die RLS-Tests dürfen nicht kippen).

- [x] **Step 7: Commit** — `feat(server): Eine eigene Einheit laesst sich loeschen -- Delete-Policy, Domain, Route`

---

## Task 6: Client — die Ableitungen fürs Verwerfen und Löschen (Punkt 19, Stores)

Drei Dinge müssen mit, wenn eine Einheit weggeht, und alle drei sind ohne View prüfbar:

1. **Warteschlange** (`CatalogStore.pendingWrites`): liegen für die Einheit noch ungesendete Sätze, legt der nächste Reconnect sie beim Server wieder an. `schreibvorgaengeVerwerfen(sessionId:)` nimmt sie raus, Speicher und Platte.
2. **Verlaufscache** (`VerlaufStore.sessions`): die Liste sofort ohne die Einheit; Gesamtzahl, Woche und Serie kommen mit dem nächsten Abruf vom Server — eine lokal heruntergezählte Serie wäre eine zweite Regel.
3. **Der Weg** (`EinheitVerwerfen.weg`): „Verwerfen“ auf dem Abschluss-Screen kommt oft im Keller. Hat kein Satz der Einheit den Server erreicht (alle liegen noch in der Warteschlange), kennt der Server die Einheit nicht (`recordSet` legt sie erst mit dem ersten Satz an) — die Warteschlange leeren genügt, offline. Liegt mindestens ein Satz beim Server, muss erst `DELETE` durch; **danach** die Warteschlange, sonst stünde nach einem Fehlschlag eine halbe Einheit beim Server, die niemand mehr löschen kann.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift` (neu `deleteSession(sessionId:)` neben `completeSession`)
- Modify: `apps/ios-member/FitnessMember/Catalog/CatalogStore.swift` (neu `schreibvorgaengeVerwerfen(sessionId:)`, `offeneSchreibvorgaenge(sessionId:)`)
- Modify: `apps/ios-member/FitnessMember/Verlauf/VerlaufStore.swift` (neu `einheitEntfernen(id:)`; `cacheMitMesswertenSchreiben` heißt `cacheSchreiben`)
- Create: `apps/ios-member/FitnessMember/Workout/EinheitVerwerfen.swift`
- Create: `apps/ios-member/FitnessMemberTests/EinheitVerwerfenTests.swift`
- Modify: `apps/ios-member/FitnessMemberTests/CatalogStoreTests.swift`, `apps/ios-member/FitnessMemberTests/VerlaufStoreTests.swift`

**Interfaces:**
- Produces:
  - `APIClient.deleteSession(sessionId: String) async throws(APIError)` — String, weil `SessionSummary.id` ein String ist und der Abschluss `sessionId.uuidString` reicht.
  - `CatalogStore.schreibvorgaengeVerwerfen(sessionId: UUID)`
  - `CatalogStore.offeneSchreibvorgaenge(sessionId: UUID) -> Int`
  - `VerlaufStore.einheitEntfernen(id: String)`
  - `enum EinheitVerwerfen { enum Weg: Equatable { case nurLokal, ueberDenServer }; static func weg(offeneSchreibvorgaenge: Int, satzAnzahl: Int) -> Weg }`

- [x] **Step 1: Tests.** `EinheitVerwerfenTests.swift`:

```swift
import Testing
@testable import FitnessMember

/// Ob "Verwerfen" den Server braucht -- oder die Warteschlange reicht.
struct EinheitVerwerfenTests {
    @Test func liegenAlleSaetzeNochInDerWarteschlangeReichtDieWarteschlange() {
        // Der Server legt die Einheit erst mit dem ersten Satz an: hat ihn
        // keiner erreicht, gibt es dort nichts zu loeschen -- und das geht
        // auch im Keller.
        #expect(EinheitVerwerfen.weg(offeneSchreibvorgaenge: 3, satzAnzahl: 3) == .nurLokal)
    }

    @Test func einGesendeterSatzVerlangtDenServer() {
        #expect(EinheitVerwerfen.weg(offeneSchreibvorgaenge: 2, satzAnzahl: 3) == .ueberDenServer)
        #expect(EinheitVerwerfen.weg(offeneSchreibvorgaenge: 0, satzAnzahl: 3) == .ueberDenServer)
    }
}
```

`CatalogStoreTests.swift`, hinter `flushKeepsFailed`:

```swift
@Test("schreibvorgaengeVerwerfen nimmt nur die Eintraege der einen Einheit -- Speicher und Platte")
func verwerfenNimmtNurDieEineEinheit() {
    let directory = tempDirectory()
    let store = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: PendingWriteStore(directory: directory))
    let a = UUID(), b = UUID()
    let body = SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil)
    let a1 = PendingSetWrite(sessionId: a, setId: UUID(), body: body)
    let a2 = PendingSetWrite(sessionId: a, setId: UUID(), body: body)
    let b1 = PendingSetWrite(sessionId: b, setId: UUID(), body: body)
    store.enqueue(a1); store.enqueue(a2); store.enqueue(b1)
    #expect(store.offeneSchreibvorgaenge(sessionId: a) == 2)

    store.schreibvorgaengeVerwerfen(sessionId: a)

    // Sonst legte der naechste Reconnect die verworfene Einheit wieder an.
    #expect(store.pendingWrites == [b1])
    #expect(PendingWriteStore(directory: directory).loadAll() == [b1])
    #expect(store.offeneSchreibvorgaenge(sessionId: a) == 0)
}
```

`VerlaufStoreTests.swift` (mit den Hilfen `store(_:verzeichnis:)` und `einheit(id:)` der Datei):

```swift
@Test func einheitEntfernenNimmtSieAusListeUndCache() async {
    let loader = FakeLoader()
    loader.antwort = SessionsResponse(sessions: [einheit(id: "s1"), einheit(id: "s2")], summary: leereKopfzeile)
    let verzeichnis = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let sut = store(loader, verzeichnis: verzeichnis)
    await sut.laden(studioId: nil)

    sut.einheitEntfernen(id: "s1")

    #expect(sut.sessions.map(\.id) == ["s2"])
    // Der Cache auch -- sonst staende die geloeschte Einheit beim naechsten
    // Kaltstart wieder da, bis der Abruf durch ist.
    #expect(store(loader, verzeichnis: verzeichnis).sessions.map(\.id) == ["s2"])
}
```

- [x] **Step 2: Rot sehen.** `xcodegen generate`, dann `-only-testing:FitnessMemberTests/EinheitVerwerfenTests -only-testing:FitnessMemberTests/CatalogStoreTests -only-testing:FitnessMemberTests/VerlaufStoreTests`. Erwartet: Build-Fehler an den drei neuen Namen.

- [x] **Step 3: Implementieren.** `EinheitVerwerfen.swift`:

```swift
import Foundation

/// Wie "Verwerfen" auf dem Abschluss-Screen die Einheit loswird
/// (Sammelstelle Punkt 19).
enum EinheitVerwerfen {
    enum Weg: Equatable {
        /// Kein Satz hat den Server erreicht -- er kennt die Einheit nicht
        /// (recordSet legt sie erst mit dem ersten Satz an). Die
        /// Warteschlange leeren genuegt, und das geht auch im Keller.
        case nurLokal
        /// Mindestens ein Satz liegt beim Server: erst DELETE, DANN die
        /// Warteschlange. Andersherum staende nach einem Fehlschlag eine
        /// halbe Einheit beim Server, die niemand mehr loeschen kann.
        case ueberDenServer
    }

    static func weg(offeneSchreibvorgaenge: Int, satzAnzahl: Int) -> Weg {
        offeneSchreibvorgaenge >= satzAnzahl ? .nurLokal : .ueberDenServer
    }
}
```

`CatalogStore.swift`, hinter `entferneAusPendingWrites`:

```swift
/// Die offenen Schreibvorgaenge einer verworfenen oder geloeschten Einheit
/// (Sammelstelle Punkt 19): blieben sie liegen, legte der naechste
/// Reconnect die Einheit beim Server wieder an. Speicher und Platte
/// zusammen, wie ueberall hier.
func schreibvorgaengeVerwerfen(sessionId: UUID) {
    pendingWrites.removeAll { $0.sessionId == sessionId }
    pendingWriteStore.save(pendingWrites)
}

/// Wie viele Saetze dieser Einheit den Server noch nicht erreicht haben --
/// EinheitVerwerfen.weg entscheidet daran, ob ein DELETE noetig ist.
func offeneSchreibvorgaenge(sessionId: UUID) -> Int {
    pendingWrites.filter { $0.sessionId == sessionId }.count
}
```

`VerlaufStore.swift`: `cacheMitMesswertenSchreiben()` wird `cacheSchreiben()` (drei Aufrufer: `messwertEintragen`, `messwertEntfernen`, neu `einheitEntfernen`), der Kommentar davor bleibt. Neu, hinter `messwertEntfernen`:

```swift
/// Nach dem Loeschen einer Einheit (Sammelstelle Punkt 19): die Liste
/// sofort ohne sie, die Kopfzeile erst mit dem naechsten Abruf --
/// Gesamtzahl, Woche und Serie rechnet der Server, und eine lokal
/// heruntergezaehlte Serie waere eine zweite Regel neben serie.ts.
func einheitEntfernen(id: String) {
    sessions.removeAll { $0.id == id }
    cacheSchreiben()
}
```

`APIClient.swift`, hinter `completeSession`:

```swift
/// Eine Einheit, die es nicht (mehr) gibt, ist danach genau das -- kein
/// Fehler, auch beim zweiten Aufruf (204, siehe Server-Route).
func deleteSession(sessionId: String) async throws(APIError) {
    try await executeNoContent(path: "workout-sessions/\(sessionId)", method: "DELETE")
}
```

- [x] **Step 4: Grün sehen.** `xcodebuild test`, ganz. `git status`: `Package.resolved` unverändert.

- [x] **Step 5: Commit** — `feat(verlauf): Ableitungen fuers Verwerfen und Loeschen -- Warteschlange, Verlaufscache, Weg`

---

## Task 7: „Verwerfen“ auf dem Abschluss-Screen, „Training löschen“ im Detail (Punkt 19, Views)

Zwei Wege, beide mit Rückfrage und ohne Rückgängig, nie als Wisch auf der Home-Karte (Sammelstelle). Löschen ist **nicht** optimistisch (Ruling aus dem Gewichtsverlauf): erst der Server, dann der lokale Stand; misslingt es, bleibt alles stehen und der Fehler steht über dem Knopf.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingAbschlussView.swift` (`safeAreaInset`, neu `verwerfen()`, Dialog)
- Modify: `apps/ios-member/FitnessMember/Screens/Home/SessionDetailView.swift` (`init` bekommt `apiClient`, `teilAbschnitt`, neu `loeschen(_:)`, Dialog)
- Modify: `apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift` (`navigationDestination`, `SessionDetailView(sessionId:apiClient:)`)

**Interfaces:**
- Consumes: `EinheitVerwerfen.weg`, `CatalogStore.offeneSchreibvorgaenge/schreibvorgaengeVerwerfen`, `VerlaufStore.einheitEntfernen`, `APIClient.deleteSession` (Task 6); `VerlaufStore.laden(studioId:)`, `CatalogStore.activeStudioId` (Bestand).
- Produces: `SessionDetailView(sessionId: String, apiClient: APIClient)`.

- [x] **Step 1: Abschluss-Screen.** In `TrainingAbschlussView`:

```swift
@Environment(VerlaufStore.self) private var verlauf
@State private var verwerfenGefragt = false
@State private var verwerfenFehler: String?
```

Der `safeAreaInset` wird:

```swift
.safeAreaInset(edge: .bottom) {
    VStack(spacing: DesignSystem.Spacing.s12) {
        if let verwerfenFehler {
            InlineBanner(tone: .danger, message: verwerfenFehler)
        }
        // Die eine Hauptaktion des Screens, 64pt (designsystem.md SS4).
        // Nie deaktiviert, nie stumm: sie haengt an nichts, was vom Netz
        // kommen koennte -- "Fertig" muss auch dann aus dem Screen
        // herausfuehren, wenn completeSession nie antwortet.
        PrimaryButton(title: "Fertig") { beiFertig() }
        // Die Nebenaktion (Sammelstelle Punkt 19): hier merkt man, dass
        // die Einheit ein Fehlstart war, nicht drei Tage spaeter im
        // Verlauf. Als Text in danger, kein zweiter Umriss neben der
        // Akzentflaeche (designsystem.md SS2). Der Rahmen steht im Label:
        // mit PressButtonStyle ist nur das Label tippbar
        // (GeraetView.problemMelden).
        Button { verwerfenGefragt = true } label: {
            Text("Training verwerfen")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(DesignSystem.Color.danger)
        .buttonStyle(PressButtonStyle())
        .accessibilityHint("Löscht diese Einheit nach einer Rückfrage")
        .testnotizElement("abschluss.verwerfen", typ: "Button")
    }
    .padding(.horizontal, 20)
    .padding(.bottom, DesignSystem.Spacing.s24)
    .background(DesignSystem.Color.bg)
}
.confirmationDialog("Dieses Training verwerfen?", isPresented: $verwerfenGefragt, titleVisibility: .visible) {
    Button("Verwerfen", role: .destructive) { Task { await verwerfen() } }
    Button("Abbrechen", role: .cancel) {}
} message: {
    Text("Sätze und Zeit dieser Einheit sind danach weg. Das lässt sich nicht rückgängig machen.")
}
```

Und in einer `// MARK: - Verwerfen`-Erweiterung:

```swift
/// Erst der Server, dann die Warteschlange, dann der Verlauf -- die
/// Reihenfolge begruendet EinheitVerwerfen.Weg. Der Fall .nurLokal kommt
/// ohne Netz aus; der andere sagt bei fehlendem Empfang, was jetzt gilt,
/// statt eine halbe Einheit stehen zu lassen.
private func verwerfen() async {
    verwerfenFehler = nil
    let weg = EinheitVerwerfen.weg(
        offeneSchreibvorgaenge: katalog.offeneSchreibvorgaenge(sessionId: sessionId),
        satzAnzahl: zusammenfassung.satzAnzahl)
    if weg == .ueberDenServer {
        do throws(APIError) {
            try await apiClient.deleteSession(sessionId: sessionId.uuidString)
        } catch {
            verwerfenFehler = error == .offline
                ? "Keine Verbindung. Zum Verwerfen brauchst du Empfang — bis dahin bleibt die Einheit gespeichert."
                : error.servertext
            return
        }
    }
    katalog.schreibvorgaengeVerwerfen(sessionId: sessionId)
    verlauf.einheitEntfernen(id: sessionId.uuidString)
    beiFertig()
}
```

Der laufende `completeSession`-Task braucht keine Behandlung: kommt seine Antwort nach dem DELETE, ist der Screen weg; läuft er nach dem DELETE erst los, antwortet der Server 404, und `ausfall` trifft einen Screen, den niemand mehr sieht.

- [x] **Step 2: Session-Detail.** `SessionDetailView` bekommt `let apiClient: APIClient`, dazu:

```swift
@Environment(CatalogStore.self) private var katalog
@Environment(\.dismiss) private var dismiss
/// Der Teil, fuer den die Rueckfrage offen ist -- wie
/// MemberStudiosView.studioPendingLeave.
@State private var zuLoeschen: SessionSummary?
@State private var loeschFehler: String?
```

In `teilAbschnitt(_:mitUeberschrift:)` unter dem `VStack` der Blöcke:

```swift
// Ein Knopf JE TEIL, nicht je Karte: beim Loeschen eines Teils einer
// zusammengefassten Karte geht nur dieser Teil, nicht der ganze Tag
// (Sammelstelle Punkt 19). Umriss in danger, keine Flaeche -- der Screen
// hat keine Akzentflaeche (designsystem.md SS2).
DangerOutlineButton(title: mitUeberschrift ? "Diesen Teil löschen" : "Training löschen") {
    zuLoeschen = teil
}
.testnotizElement("session.loeschen", typ: "DangerOutlineButton")
```

Über der `ForEach` der Teile, im äußeren `VStack` hinter `kopf(karte)`: `if let loeschFehler { InlineBanner(tone: .danger, message: loeschFehler) }`.

Am `ScrollView`:

```swift
.confirmationDialog(
    "Dieses Training löschen?",
    isPresented: Binding(get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }),
    titleVisibility: .visible,
    presenting: zuLoeschen
) { teil in
    Button("Löschen", role: .destructive) { Task { await loeschen(teil) } }
    Button("Abbrechen", role: .cancel) {}
} message: { _ in
    Text("Sätze und Zeit sind danach weg, Wochenzahl und Serie rechnen neu. Das lässt sich nicht rückgängig machen.")
}
```

Und:

```swift
// MARK: - Loeschen

private extension SessionDetailView {
    /// Nicht optimistisch, wie beim Gewicht: erst der Server, dann der
    /// lokale Stand. Misslingt der Aufruf, bleibt der Screen stehen und der
    /// Fehler steht oben, statt eine Einheit verschwinden zu lassen, die
    /// serverseitig noch existiert.
    ///
    /// Danach zurueck: die Karte, ueber die man kam, gibt es so nicht mehr
    /// -- und die Kopfzeile auf Home holt sich Woche und Serie mit dem
    /// Abruf, den `laden` hier anstoesst.
    func loeschen(_ teil: SessionSummary) async {
        loeschFehler = nil
        do throws(APIError) {
            try await apiClient.deleteSession(sessionId: teil.id)
        } catch {
            loeschFehler = error == .offline
                ? "Keine Verbindung. Das Training wurde nicht gelöscht."
                : error.servertext
            return
        }
        if let id = UUID(uuidString: teil.id) { katalog.schreibvorgaengeVerwerfen(sessionId: id) }
        verlauf.einheitEntfernen(id: teil.id)
        Task { await verlauf.laden(studioId: katalog.activeStudioId) }
        dismiss()
    }
}
```

`HomeRootView.swift`: `SessionDetailView(sessionId: id)` wird `SessionDetailView(sessionId: id, apiClient: apiClient)`.

- [x] **Step 3: `xcodebuild test`**, ganz (kein Test hängt an den Views; der Build muss stehen).

- [x] **Step 4: Commit** — `feat(verlauf): Verwerfen auf dem Abschluss-Screen, Loeschen im Session-Detail`

---

## Task 8: Doku nachziehen

Was der Umbau in Specs und Sammelstelle falsch macht. Specs werden nicht umgeschrieben — sie beschreiben ihren Stand —, sondern bekommen datierte Einschübe (Konvention seit Schnitt 3).

**Files:**
- Modify: `docs/superpowers/plans/2026-09-12-ios-verbesserungen-aus-dem-betrieb.md` („Stand“, Punkt 10, Punkt 19, „Schnitt 4“)
- Modify: `docs/superpowers/specs/2026-08-28-fitness-retrofit-m1-design.md` (§5.2 Z. 148, §5.6 Z. 208–212; §7.6 nennt kein Delete, dort nichts)
- Modify: `docs/superpowers/specs/2026-09-08-ios-training-kurse-design.md` (Z. 98 und Z. 196)
- Modify: `docs/superpowers/specs/2026-08-30-designsystem.md` (§8, Satz „Ein Tap auf eine Übung führt direkt zum Satz; es gibt keinen Bestätigungsknopf.“)

- [x] **Step 1: Sammelstelle.** Unter „Stand“ ein Spiegelstrich hinter dem zu „Gerät“:

> - **Einheit** (Schnitt 4): sie beginnt auf dem Screen „Training starten“ nach Geräte- und Übungswahl, nur wenn noch kein Training läuft (`TrainingStart.ziel`, `TrainingStartView`, `WorkoutSessionStore.trainingStarten`); der gemerkte Gerätekontakt (`geraetBetreten`) ist weg. Eine Einheit ohne Satz wird beim Ablauf still verworfen und beim manuellen Beenden mit dem Satz „Kein Satz gesichert — das Training wurde verworfen.“; beim Server liegt sie nie (`recordSet` legt die Session erst mit dem ersten Satz an, und der PUT trägt seit Schnitt 4 `sessionStartedAt`). Löschen: `DELETE /workout-sessions/{id}` (Migration 0044), „Training verwerfen“ auf dem Abschluss, „Training löschen“ je Teil im Session-Detail, Warteschlange und Verlaufscache räumen mit (`CatalogStore.schreibvorgaengeVerwerfen`, `VerlaufStore.einheitEntfernen`). Punkt 10 und 19 sind damit umgesetzt.

Bei Punkt 10 hinter „Für Schnitt 4 offen:“ die beiden Spiegelstriche durch „**Umgesetzt (Schnitt 4, 15. September):** der Screen kommt nur ohne laufendes Training; die Regel für leere Einheiten ist `abgelaufeneSession`/`trainingStarten` mit Test.“ ersetzen. Der Spiegelstrich „Drei Texte werden falsch“ bekommt den Zusatz „(der erste, `TrainingRootView.leerInhalt`, war seit Schnitt 2 schon weg)“. Bei Punkt 19 vor dem kursiven Schluss: „**Umgesetzt (Schnitt 4).**“ Unter „Schnitt 4“ die drei Spiegelstriche als erledigt markieren und den Satz ergänzen: „Zusätzlich zum Plan: der Satz-PUT trägt `sessionStartedAt`, damit Home dieselbe Dauer zeigt wie die App (Frage c des Plans).“

- [x] **Step 2: M1-Spec.** §5.2 hinter „Es gibt keinen Startknopf — der Training-Tab füllt sich einfach.“: „*(Seit Schnitt 4, 15. September, aufgehoben: die Einheit beginnt mit dem Tap auf „Training starten“ nach Geräte- und Übungswahl, wenn noch kein Training läuft; ihren Beginn setzt der Client mit dem ersten Satz-PUT. Siehe `docs/superpowers/plans/2026-09-15-schnitt4-einheit.md`.)*“ §5.6 hinter „Die Session entsteht implizit beim ersten gespeicherten Satz (siehe Abschnitt 7.2).“: „*(Seit Schnitt 4 aufgehoben: es gibt den Screen „Training starten“; serverseitig entsteht die Session weiterhin mit dem ersten Satz, deshalb liegt eine Einheit ohne Satz nie beim Server. Eine Einheit lässt sich seit Migration 0044 löschen.)*“

- [x] **Step 3: Training/Kurse-Spec.** Z. 98 hinter „Es gibt keinen Startknopf (M1-Spec §5.6), also weiß niemand, warum plötzlich ein Training läuft.“: „*(Seit Schnitt 4 gibt es ihn — „Training starten“ —, die Zeile „seit 18:04“ bleibt als Anker der Uhr.)*“ Z. 196, Spalte „warum“: „ohne Startknopf sonst unerklärlich *(seit Schnitt 4: Anker der Uhr)*“.

- [x] **Step 4: Designsystem §8.** Hinter „Ein Tap auf eine Übung führt direkt zum Satz; es gibt keinen Bestätigungsknopf.“: „*(Seit Schnitt 4: ohne laufendes Training folgt der Screen „Training starten“ — sein Knopf startet die Einheit, er bestätigt keine Übung. Mitten im Training führt der Tap weiterhin direkt zum Satz.)*“

- [x] **Step 5: Commit** — `docs: Sammelstelle, M1-Spec SS5.2/SS5.6 und Designsystem SS8 fuer Schnitt 4 nachgezogen`

---

## Task 9: Sichtcheck gegen das lokale Backend

Tests beweisen Ableitungen, nicht Sichtbarkeit und Höhe. Der Sichtcheck läuft auf dem SE-Simulator (667 pt, anzulegen, danach löschen) und für zwei Screens auch auf dem 17 Pro-Layout (eigener zweiter Simulator, **nicht** der vorhandene mit der Entwickler-App) — gegen das lokale Backend. Die Screenshots werden angesehen, nicht nur gemacht, und die Rahmen der Elemente kommen aus einem Frames-Dump, nicht aus Augenmaß.

**Aufbau (Lehren aus Schnitt 3):**
- `df -h /System/Volumes/Data` vor dem ersten Build; unter 3 GB frei `~/Library/Developer/Xcode/DerivedData/FitnessMember-*` löschen.
- Lokales Supabase in Docker (`docker ps`), Migration 0044 eingespielt; Web-API in `apps/web` mit `set -a; source ../../.env; set +a; pnpm dev` im Hintergrund.
- Build mit Overrides, `Config.xcconfig` bleibt unangetastet:
  `xcodebuild build -scheme FitnessMember -destination 'platform=iOS Simulator,id=<SE-UDID>' API_BASE_URL=http://127.0.0.1:3000/api/v1 SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_ANON_KEY=<aus .env>`. Danach die drei Werte in der `Info.plist` des Builds prüfen (`plutil -p`). **Nicht** `CODE_SIGNING_ALLOWED=NO`, sonst verliert der Login die Session (Keychain).
- Seed-Skript und XCUITest-Harness aus Schnitt 3 liegen im Scratchpad der alten Session (`/private/tmp/claude-501/-Users-timbuttner-Documents-fitness-app/102a4eb0-beb7-4477-8386-7edba0722ac0/scratchpad`: `seed.mjs`, `harness/`, `schritte.txt`, `sim-ids.env`); sie sind am 15. September, 20 Uhr, noch da. Ins eigene Scratchpad kopieren; wenn sie fehlen, neu bauen. `seed.mjs` legt Nutzer `schnitt3@example.test`, Studio „Schnitt-3-Studio“, Geräte mit und ohne Einstellwerte und letzte Sätze per Service-Key an — der Name bleibt, nur das Ziel `.env` muss auf `127.0.0.1` zeigen (das Skript bricht sonst ab). Die Kalibrierungszeile für Geräte ohne Einstellwerte ist nach Fix A nicht mehr nötig; prüfen, ob `seed.mjs` sie noch anlegt, und stehen lassen (schadet nicht).
- Harness-Regeln: `TEST_RUNNER_`-Umgebung kommt nicht an, die Schritte kommen über `schritte.txt` im Scratchpad; Taps über die Element-Koordinate (`tapc:<Label>`); jeder Lauf beginnt mit `launch`, sonst bleibt der Navigationsstapel vom letzten Lauf; Geräte unterhalb der Falz über das Suchfeld (`type:Gerät, Übung oder Platz:<Text>`); `frames` schreibt die Rahmen aller Elemente in den Bericht; `shot:<name>` macht den Screenshot mit `xcrun simctl io <udid> screenshot`.
- SE-Simulator: `xcrun simctl create "SE-Schnitt4" "iPhone SE (3rd generation)" <iOS-26.3-Runtime aus simctl list runtimes>`, am Ende `xcrun simctl delete SE-Schnitt4`. Für den 17-Pro-Vergleich ebenso `"Pro-Schnitt4"` mit „iPhone 17 Pro“, ebenfalls löschen.

- [x] **Step 1: Der Startscreen auf dem SE** — Gerät über die Suche wählen, Übung antippen: Kopfzeile, Gerätename (eine Zeile, geschrumpft bei „BEINPRESSE SITZEND“), Übung, die Karte „WAS JETZT PASSIERT“, „Training starten“ über der Tab-Leiste. Screenshot `se-start.png`, `frames`: der Knopf ist 64 pt hoch, sein Unterrand liegt über der Safe Area (y + Höhe ≤ 584), die Karte reicht nicht in den Knopf. Auf dem 17 Pro: `pro-start.png`, der Knopf sitzt über dem Home-Indikator.
- [x] **Step 2: Der Tap** — „Training starten“: der Satzpfad kommt, die Uhr im Kopf läuft ab 0:00 (Screenshot nach 5 s: `se-satzpfad-uhr.png`). „Zurück“ führt auf „Gerät erkannt“, nicht auf den Startscreen (`se-zurueck-erkannt.png`).
- [x] **Step 3: Training-Tab vor dem ersten Satz** — Tab „Training“: „TRAINING LÄUFT“ mit Uhr und „seit hh:mm“, keine Zahlen rechts, keine Blockliste, kein Zirkel-Satz, „Training beenden“ und die Scanwege im Fuß (`se-training-leer-laeuft.png`).
- [x] **Step 4: Beenden ohne Satz** — „Training beenden“: kein Abschluss-Screen, der Tab ist leer, im Fuß steht „Kein Satz gesichert — das Training wurde verworfen.“ (`se-verworfen.png`). Danach im Browser/`psql` gegen das lokale Supabase: `select count(*) from workout_sessions where user_id = '<id>'` — die Zahl ist nicht gestiegen.
- [x] **Step 5: Das nächste Gerät kommt ohne Startscreen** — Start, einen Satz sichern, „Gerät abschließen“, zweites Gerät über die Suche, Übung antippen: direkt der Satzpfad (`se-zweites-geraet.png`). Blockliste antippen: direkt der Satzpfad.
- [x] **Step 6: Direktweg** — an einem Gerät mit `visitCount ≥ 2` und genau einer genutzten Übung ohne laufendes Training: nach der Wahl aus der Liste kommt der Startscreen, nicht der Satzpfad (`se-direkt-start.png`). (Der Seed liefert dafür ein Gerät mit einem letzten Satz einer Übung und `visit_count` 2 — im Seed prüfen, sonst nachtragen.)
- [x] **Step 7: Dauer** — Start, 90 s warten, Satz, „Gerät abschließen“, „Training beenden“: der Abschluss zeigt „HEUTE · hh:mm – hh:mm“ ab dem Start und „2 MINUTEN“ (nicht 0) (`se-abschluss-dauer.png`). „Fertig“, Home neu laden: die Karte zeigt dieselbe Spanne „ab hh:mm“ des Starts, nicht des Satzes (`se-home-karte.png`).
- [x] **Step 8: Verwerfen auf dem Abschluss** — noch eine Einheit mit Satz, „Training beenden“: unter „Fertig“ steht „Training verwerfen“ in danger, 44 pt (`frames`); Tap → Rückfrage „Dieses Training verwerfen?“ (`se-verwerfen-dialog.png`); „Verwerfen“ → zurück auf dem leeren Tab; Home neu laden: die Einheit fehlt, die Wochenzahl ist um eins kleiner (`se-home-nach-verwerfen.png`). Dasselbe im **Flugmodus** mit einer Einheit, deren Satz nie rausging: Verwerfen gelingt ohne Fehlerbanner (`.nurLokal`), Flugmodus aus, kein Satz erscheint nach dem Reconnect. Und im Flugmodus mit einer Einheit, deren erster Satz schon draußen war: das Banner „Keine Verbindung. Zum Verwerfen brauchst du Empfang …“, die Einheit bleibt (`se-verwerfen-offline.png`).
- [x] **Step 9: Löschen im Detail** — Home, Karte antippen: unter den Blöcken „Training löschen“ (52 pt Umriss, `frames`); Rückfrage; „Löschen“ → zurück auf Home, die Karte ist weg, Serie und Wochenzahl rechnen neu nach dem Abruf (`se-detail-loeschen.png`, `se-home-nach-loeschen.png`). Eine zusammengefasste Karte (zwei Einheiten kurz nacheinander, Punkt 15): je Teil ein Knopf „Diesen Teil löschen“, nur der eine Teil geht (`se-detail-zwei-teile.png`).
- [x] **Step 10: Dynamic Type** `xcrun simctl ui <udid> content_size extra-extra-extra-large` auf dem SE: Startscreen und Abschluss dürfen scrollen, nichts überlappt, „Training starten“ und „Training verwerfen“ bleiben erreichbar (`se-start-xxxl.png`). Danach `content_size medium`.
- [x] **Step 11: VoiceOver-Beschriftungen** aus dem Accessibility-Baum (`frames` liefert Labels mit): der Startscreen liest Kopfzeile, Gerät, Übung, die Karte als einen Satz, „Training starten“; der Abschluss liest „Training verwerfen“ mit dem Hint.
- [x] **Step 12: Bericht** — Liste der Screenshots mit je einem Satz, was sie zeigen, plus die gemessenen Rahmen der drei Knöpfe; Abweichungen als Nachtrag-Commit `fix(training): Nachzuege aus dem Sichtcheck -- <was>` oder als Notiz unter „Beim Sichtcheck gefunden, außerhalb dieses Schnitts“. Beide Simulatoren löschen, Web-API beenden, Testnutzer und Studio per Service-Key wieder entfernen (der Seed räumt beim nächsten Lauf ohnehin).

---

## Selbstprüfung

`xcodebuild test` beweist die Ableitungen (`trainingStarten`, `abgelaufeneSession` ohne Satz, `TrainingStart.ziel`, `Trainingszusammenfassung.von`, `EinheitVerwerfen.weg`, `schreibvorgaengeVerwerfen`, `einheitEntfernen`), `pnpm test`/`pnpm test:integration` die Server-Seite (`sessionStartedAt`, Delete-Policy, Route), der Sichtcheck die Screens. Von Hand, am Gerät, im Studio:

- [ ] Gerät scannen, Übung antippen: „Training starten“ mit Ort, Gerät, Übung und der Karte, was passiert. Tap: der Satzpfad, die Uhr läuft ab jetzt. „Zurück“ führt auf „Gerät erkannt“, nicht auf den Startknopf.
- [ ] Training-Tab vor dem ersten Satz: „TRAINING LÄUFT“, Uhr, „seit hh:mm“, keine Zahlen, keine Liste, kein Zirkel-Satz.
- [ ] „Training beenden“ ohne Satz: kein Abschluss, Satz im Fuß „Kein Satz gesichert — das Training wurde verworfen.“, auf Home nichts, beim Server nichts.
- [ ] Vier Stunden nach einem Start ohne Satz: der Tab ist leer, **ohne** „automatisch beendet“. Mit Satz: wie bisher mit dem Satz.
- [ ] Zweites Gerät mitten im Training, Blockliste, Direktweg mitten im Training: kein Startscreen. Direktweg ohne laufendes Training: Startscreen.
- [ ] Abschluss-Screen: Zeitraum und Minuten ab dem Start, nicht ab dem ersten Satz. Home-Karte am nächsten Tag: „ab hh:mm“ ist die Startzeit.
- [ ] „Training verwerfen“ unter „Fertig“: Rückfrage, dann weg — Home, Wochenzahl, Serie ohne die Einheit. Im Keller ohne gesendeten Satz geht es; mit gesendetem Satz steht der Satz zum Empfang, und die Einheit bleibt, bis es Empfang gibt.
- [ ] Session-Detail: „Training löschen“ unter den Blöcken, Rückfrage, dann zurück auf Home ohne die Karte. Bei einer Karte aus zwei Teilen: je Teil ein Knopf, nur der eine Teil geht.
- [ ] Offline im Detail: „Keine Verbindung. Das Training wurde nicht gelöscht.“, die Einheit bleibt.
- [ ] Ein anderes Konto auf demselben Gerät sieht weder die Einheit noch kann es sie löschen (RLS).
- [ ] VoiceOver: Startscreen als vier Elemente plus Knopf; „Training verwerfen“ mit Hint; „Training löschen“ als Knopf.
- [ ] Dynamic Type größte Stufe: Startscreen und Abschluss scrollen, nichts überlappt, die Knöpfe bleiben erreichbar.

## Offen — vor der Umsetzung zu entscheiden

**a) Kommt der Startscreen nur, wenn noch kein Training läuft?** Geprüft: `TrainingRootView` hat drei Wege zum Satzpfad — Übungswahl auf „Gerät erkannt“, `direktZumSatz` nach dem Scan, und der Zirkel über die Blockliste. Die Blockliste gibt es nur bei laufendem Training. Bei den beiden anderen liefe ein Startscreen mitten im Training auf einen Knopf hinaus, der nichts tut (`trainingStarten` ist idempotent) und jeden Gerätewechsel einen Tap kostet — das widerspricht dem Interaktionsbudget (§9). **Empfehlung: ja, nur ohne laufendes Training**, als `TrainingStart.ziel` mit Test (Task 2). Der Plan setzt das voraus.

**b) Was passiert mit einer laufenden Einheit ohne Satz beim Ablauf der vier Stunden und beim Verlassen der App?** Geprüft: der Server legt `workout_sessions` ausschließlich in `recordSet` an (Upsert mit dem ersten Satz-PUT, `workout.ts`); es gibt keinen Start-Endpoint, und dieser Plan baut keinen. Eine Einheit ohne Satz existiert also nur in `laufende-session.json` — **lokal verwerfen reicht, der Server hat nichts zu vergessen.** Das ist auch der Grund, warum `trainingStarten` keinen Netzaufruf macht (Kommentar dort). Drei Fälle, Empfehlung:
- *Ablauf der vier Stunden:* still verwerfen, **ohne** „Dein letztes Training wurde automatisch beendet.“ — der Satz spräche von einem Training, das nie stattfand (Task 1, `abgelaufeneSession` nur mit Satz).
- *„Training beenden“ ohne Satz:* verwerfen, mit dem Satz „Kein Satz gesichert — das Training wurde verworfen.“ im Fuß (nie stumm, designsystem.md §5). Alternative wäre gar kein Satz; dann sähe der Tap wirkungslos aus.
- *Verlassen der App (Hintergrund, Kill):* **nichts** — die Einheit läuft weiter, bis ein Satz kommt, sie beendet wird oder die vier Stunden um sind. Ein Anruf zwischen Start und erstem Satz darf das Training nicht beenden, und die Vier-Stunden-Regel deckt den Fall „gestartet und gegangen“ ohne Sonderweg. Wer „beim Verlassen“ in der Sammelstelle als „beim Verlassen des Geräte-Screens“ liest: auch dann nichts — der Weg zurück auf den Tab und weiter zum nächsten Gerät ist der Normalfall.

**c) Der Beginn der Einheit beim Server (nicht in der Sammelstelle).** Geprüft: `recordSet` schickt kein `started_at`, die Spalte bekommt `now()` beim ersten PUT. Damit zeigte Home nach Schnitt 4 die Ankunft des ersten Satzes, die App die Startzeit — bei einem Offline-Training Stunden auseinander; Serie und Wochenzahl zählen nach `started_at`. Ein optionales `sessionStartedAt` im Satz-PUT behebt das mit einem Feld und einem Refine, ohne Migration (Task 4, Step 3–6). **Empfehlung: mitnehmen**, obwohl die Sammelstelle für Schnitt 4 nur „eine Migration“ vorsieht. Wird es verneint, entfallen die Server-Steps von Task 4 und der Commit-Betreff dort wird `feat(training): Die Dauer auf dem Abschluss-Screen beginnt beim Start`.

**d) Delete-Policy ohne Mitgliedschaftsklausel.** Die Sammelstelle sagt `user_id = auth.uid()` „wie bei select seit 0033“; 0033 prüft aber zusätzlich `is_studio_member`. Der Plan nimmt die reine Eigentumsklausel (Migration 0044, Kommentar begründet: wer sein Studio verlassen hat, darf seine Einheiten dort weiterhin löschen). Wer die Mitgliedschaft mitprüfen will: eine Zeile in 0044 und ein Negativtest („nach dem Austritt lässt sich die Einheit nicht mehr löschen“) mehr.

## Was dieser Schnitt NICHT tut

- **Übungsbilder** (Punkte 14 und 18, Schnitt 5), **Kurse als Einheit** (Punkt 20, Schnitt 6), **Rekorde und Grafik** (Punkte 2 und 9, Schnitt 7), **laufendes Training auf Home** (Punkt 21).
- **Punkt 15** (Trainings teilweise zusammenfassen) ist mit Schnitt 1 da; dieser Schnitt ändert daran nur, dass das Löschen je Teil geht.
- **Keinen Start-Endpoint.** Der Server legt die Einheit weiter mit dem ersten Satz an — das ist die Struktur hinter „nie gemeldet“ (Frage b). Wer ihn baut, braucht eine zweite Regel zum Aufräumen leerer Zeilen.
- **Keine Warteschlange fürs Löschen.** Ein DELETE, das offline scheitert, wird nicht gemerkt und später nachgeholt; der Screen sagt, dass Empfang fehlt, und die Einheit bleibt. Der eine Fall, der offline trotzdem geht (kein Satz je gesendet), ist `EinheitVerwerfen.weg`.
- **Kein Rückgängig**, kein Wisch auf der Home-Karte (Sammelstelle Punkt 19).
- **Kein `deleted_at`**: gelöscht ist gelöscht — Serie, Fortschritt, Studio-Überblick werden kleiner, das ist richtig so.
- **`progression_suggestions` bleiben stehen**, wenn ihre Einheit gelöscht wird: sie tragen keine `session_id`, sind eine Rechnung über die Historie und stören nichts. Falls Schnitt 7 (Rekorde) daran etwas ändern will, dort.
- **Der Dreischritt (`ErstkontaktFlow`)** bleibt, wie Fix A ihn hinterlässt; der Startscreen sitzt davor, nicht darin.
- **Dynamic Type der festen Schriften** und **die Wiederholungsspalte bei XXXL** (bekannter Altbefund) bleiben außen vor.
- **Die dunkle Statusleiste in „Gerät wählen“** und die wackeligen CI-E2E-Tests `trainerportal.spec.ts` und `leute.spec.ts` (auf `master` bekannt) sind nicht Teil dieses Schnitts — vor dem PR prüfen, welcher Test scheitert, bevor der Branch schuld ist.
