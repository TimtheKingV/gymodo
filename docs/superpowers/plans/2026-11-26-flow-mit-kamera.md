# Flow mit Kamera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Flow „HIIT 20 Minuten“ läuft als geführtes Training: Pause mit Übungsvideo und Restzeit oben rechts, Arbeitsphase mit Kamerabild, Welle und gezählten Wiederholungen bei zählbaren Schritten, sonst Video und Uhr; alle 20 Schritte hängen an einer Katalogübung mit Video; eine Anleitung „Flow aus Video-Link“ liegt im Repo.

**Architecture:** `flow_steps` bekommt einen optionalen Verweis auf `exercises`; die App löst ihn über den Bootstrap auf und holt Video und Kameraangaben von der Übung. Die Zeitmaschine `FlowAblauf`/`FlowLauf` bleibt unverändert und ist die einzige Uhr. Daneben entsteht eine reine Zählmaschine `FlowZaehler` im Package `Koerperbild` (nutzt `Koerperlage`, `Erkennungspruefung`, `Sollwelle`) und in der App ein `FlowKameraModell`, das die `Bildquelle` passend zum `FlowZustand` startet und stoppt. `KameraSatzAblauf` und `GeraetModel` werden nicht angefasst.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, Swift Testing, XcodeGen; TypeScript, Vitest, Supabase/Postgres; Python (Videoserie außerhalb des Repos, Testprofile).

**Spec:** `docs/superpowers/specs/2026-11-26-flow-mit-kamera-design.md` (von Tim am 26.11.2026 freigegeben). Dazu lesen: `docs/superpowers/specs/2026-11-24-kamera-tempo-ablauf-design.md` Abschnitt 5 und 8, `docs/superpowers/plans/2026-11-26-follow-along-flows.md` (nach Task 0 im Zweig).

## Global Constraints

- Arbeitsbasis: Worktree `.claude/worktrees/flow-kamera`, Zweig `claude/flow-kamera` (von `claude/kamera-ablauf`). Der Kamera-Ablauf geht in diesem Zweig mit, **ein** gemeinsamer PR. Kein Push und kein PR ohne Tims Wort.
- Kein `git commit --amend`, kein Rebase. Tasks laufen nacheinander (App-Tasks teilen DerivedData).
- `Config.xcconfig` fehlt im Worktree: einmalig aus dem Hauptordner `apps/ios-member/Config.xcconfig` kopieren, nicht committen. Nach jeder Änderung an `project.yml` oder neuen Dateien: `cd apps/ios-member && xcodegen generate`.
- **Die Uhr des Flows wartet nie auf die Kamera.** `FlowAblauf.swift` und `FlowLauf.swift` werden nicht geändert; ihre Tests bleiben unverändert grün.
- Ein Kamerafehler bricht den Flow nie ab und verhindert nie `store.runAbschliessen`.
- Ein Flow ohne Verweise und ein Server ohne `exerciseId` verhalten sich wie heute (Ring).
- `FREIGESCHALTETE_PROFILE` bleibt `["ohne_kamera"]`. Kameraangaben der Flow-Übungen kommen nur im Debug-Build aus `KameraTestprofile.json`. Neue Katalogübungen bekommen **kein** `kamera`-Objekt.
- `GeraetModel.swift` und `KameraSatzAblauf.swift` werden nicht geändert.
- Kein Bild, kein Skelett, keine Wiederholungszahl wird gespeichert oder gesendet. `flow_runs` und `FlowRunEingabe` bleiben unverändert.
- Feste Werte (Spec): Aufstellen bestanden nach 1,0 s (`Erkennungspruefung.bestandenNach`), Profil dafür `ganzkoerper_stehend`; Kamera startet 5 s vor Ende der Pause; „nicht erkannt“ nach 3 s ohne Erkennung ab Beginn der Arbeitsphase oder nach mehr als 1,0 s Verlust; Tempo der neuen Kamera-Übungen 1 s senken / 0 halten / 1 s heben; Kostengrenze Videos 10 $; höchstens 3 Anläufe je Video.
- Texte wörtlich: „Stell das Handy so auf, dass du stehend und am Boden liegend ganz im Bild bist.“ · „Ohne Kamera starten“ · „Stell dich seitlich zur Kamera“ · „Schau zur Kamera“ · „Kamera sieht dich gerade nicht“ · „Als Nächstes“ · „SCHRITT n VON m“ · „PAUSE“. Farben und Schrift nur aus `DesignSystem`. Namen, Kommentare, Commits deutsch, im Code ae/oe/ue.
- Nichts auf Supabase-Prod, kein Katalog- oder Video-Import auf Prod ohne Tims ausdrückliches Ja für genau diesen Schritt (Task 10). OpenRouter-Schlüssel (`~/Documents/gymtavo/3D-Animationen/.env`) nie ausgeben.
- Keine Texte, Namen oder Bilder des Trainers in Katalog, Flow oder Videos; Beschreibungen in eigenen Worten.
- Tests: Package `cd apps/ios-member/Packages/Koerperbild && swift test --filter <Name>`. App `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/<Suite> 2>&1 | tail -30`. TypeScript `pnpm vitest run <Pfad>`, Integration `pnpm test:integration` (lokales Supabase), `pnpm typecheck`.

## Review Focus

1. **App geht während einer Kamera-Arbeitsphase in den Hintergrund und kommt in der übernächsten Pause zurück** – die Uhr steht richtig (Wanduhr), die Kamera ist aus, die bisher gezählten Zahlen bleiben, kein Absturz (Task 8).
2. **„Anhalten“ mitten in einem Kamera-Schritt, eine Minute später „Weiter“** – Zahl bleibt, Welle und Zählung setzen fort, es entstehen keine Wiederholungen aus der Pause (Task 7, Task 8).
3. **Kamera-Start scheitert oder liefert keine Bilder (Simulator ohne Abspieldaten, Kamera belegt)** – Hinweiszeile statt schwarzer Fläche, Flow läuft bis „Fertig“ und meldet den Lauf (Task 8).
4. **Zwei Kamera-Schritte direkt hintereinander mit verschiedenen Übungen** – der Zähler des zweiten beginnt bei 0 mit dessen Vorgabe; die Zahl des ersten steht im Fertig-Bildschirm (Task 8).
5. **Flow-Schritt verweist auf eine Übung, die der Bootstrap nicht (mehr) liefert, oder deren Video nicht geladen ist** – Ring wie heute, kein leerer Platz (Task 5, Task 6).

---

### Task 0: master hereinholen

**Files:** Merge `origin/master` → `claude/flow-kamera`; `apps/ios-member/FitnessMember.xcodeproj/project.pbxproj` neu erzeugt.

- [ ] **Step 1:** `git merge origin/master`. Erwartet: genau ein Konflikt in `project.pbxproj`.
- [ ] **Step 2:** Konflikt lösen durch Neuerzeugen: `git checkout --theirs apps/ios-member/FitnessMember.xcodeproj/project.pbxproj`, `Config.xcconfig` kopieren, `cd apps/ios-member && xcodegen generate`, Datei stagen. `project.yml` muss die Einträge beider Seiten enthalten (von Hand prüfen).
- [ ] **Step 3:** `pnpm install && pnpm typecheck && pnpm test`; `swift test` im Package `Koerperbild`; App-Tests ganz (`xcodebuild … test`). Erwartet: alles grün, darunter `FlowAblaufTests`, `FlowLaufTests`, `KameraAblaufModellTests`.
- [ ] **Step 4:** Merge-Commit `Merge origin/master (Flows) in claude/flow-kamera`.

### Task 1: Verweis Schritt → Übung in Datenbank, Domäne, API

**Files:**
- Create: `supabase/migrations/0080_flow_steps_uebung.sql`
- Modify: `packages/domain/src/flows.ts`, `packages/domain/src/flows.test.ts`
- Test: `tests/integration/db-flows.test.ts`, `tests/integration/api-flows.test.ts`

**Interfaces:**
- Produces: Spalte `public.flow_steps.exercise_id uuid null references public.exercises(id) on delete set null`; `FlowSchritt.exerciseId: string | null` in der Antwort von `GET /api/v1/me/flows`.

- [ ] **Step 1: Tests schreiben (rot).** `db-flows`: Schritt mit `exercise_id` einer Katalogübung einfügbar; Löschen der Übung setzt `exercise_id` auf null und lässt den Schritt stehen. `api-flows`: Flow mit einem verknüpften und einem unverknüpften Schritt liefert `exerciseId` gleich der Übungs-ID bzw. `null`.
- [ ] **Step 2:** `pnpm test:integration` → die neuen Tests scheitern (Spalte fehlt).
- [ ] **Step 3:** Migration schreiben (nur die Spalte, keine Policy, Kommentar zum Zweck). `listFlows`: `exercise_id` in den Select und in `SchrittZeile`, Abbildung auf `exerciseId`. `FlowSchritt`-Typ ergänzen.
- [ ] **Step 4:** Lokal `supabase db reset` (oder der im Flows-Plan genannte Weg), `pnpm test:integration`, `pnpm typecheck` → grün.
- [ ] **Step 5:** Commit `feat(flows): Flow-Schritt verweist optional auf eine Uebung (0080)`.

### Task 2: `uebung` in Flow-Datei und `flow:sql`

**Files:**
- Modify: `tools/flow-import/entwurf.ts`, `tools/flow-import/flow-sql.ts`
- Test: `tools/flow-import/entwurf.test.ts`, `tools/flow-import/flow-sql.test.ts`

**Interfaces:**
- Produces: `FlowSchritt.uebung?: string` (Katalogschlüssel, Muster `^[a-z0-9_]+$`). `flowZuSql(e: FlowEntwurf, studioId: string, katalogKeys?: ReadonlySet<string>): string`. `main()` lädt die Schlüssel aus `catalog/gymtavo.json` (`exercises[].key`) und übergibt sie.

- [ ] **Step 1: Tests (rot).**
  - `pruefeFlowEntwurf`: `uebung: "bw_pushup"` ist gültig; `uebung: ""` und `uebung: 5` werfen „Schritt 1: uebung muss ein Katalogschluessel sein.“
  - `flowZuSql` ohne `uebung` an irgendeinem Schritt erzeugt **zeichengleich** das SQL von heute (bestehender Erwartungstext bleibt).
  - Mit `uebung: "bw_pushup"`: die Insert-Zeile nennt die Spalte `exercise_id` und den Wert `(select id from public.exercises where studio_id = '00000000-0000-4000-8000-000000000001' and catalog_key = 'bw_pushup')`.
  - Mit `katalogKeys` ohne den Schlüssel: wirft „Unbekannte Katalogschluessel: 3 (bw_gibtsnicht).“
- [ ] **Step 2:** `pnpm vitest run tools/flow-import` → rot.
- [ ] **Step 3:** Umsetzen. Die Katalog-Studio-ID ist die Konstante `GYMTAVO_KATALOG_STUDIO = "00000000-0000-4000-8000-000000000001"`, unabhängig von `--studio`. Vorher in `supabase/migrations` prüfen, dass Katalogübungen so adressiert werden (`exercises.catalog_key`, Migration 0048); weicht es ab, die Unterabfrage anpassen und den Test mitziehen. Zusätzlich hinter den Inserts eine Sicherung im SQL: scheitert die Auflösung eines Schlüssels (Unterabfrage null), bricht die Transaktion mit `raise exception` ab.
- [ ] **Step 4:** Tests grün, `pnpm typecheck`.
- [ ] **Step 5:** Commit `feat(flow-import): Katalogschluessel je Schritt, flow:sql loest ihn auf`.

### Task 3: Katalog und Flow-Datei

**Files:**
- Modify: `catalog/gymtavo.json`, `tools/flow-import/flows/hiit-20-min.json`
- Create: `docs/flows/hiit-20-min-uebungen.md` (Liste für Tim)

**Interfaces:**
- Produces: 16 neue Übungen am Gerätetyp `bodyweight`, ohne `plan`, ohne `kamera`, ohne `video` (kommt in Task 4). Schlüssel und Zuordnung:

| Schritt | Schlüssel | neu | `volume_kind` |
|---|---|---|---|
| 1 High Kicks | `bw_high_kicks` | ja | seconds |
| 2 Slow Burpees | `bw_burpee_slow` | ja | reps |
| 3 Jumping Jacks | `bw_jumping_jack` | ja | reps |
| 4 Toe Touches + Jackknifes | `bw_toe_touch_jackknife` | ja | reps |
| 5 Mini Scissor Kicks | `bw_scissor_kicks` | ja | seconds |
| 6 Burpees mit Oberschenkel-Berührung | `bw_burpee_thigh_tap` | ja | reps |
| 7 Squat-Pulse | `bw_squat_pulse` | ja | reps |
| 8 Plank | `bw_plank` | nein | – |
| 9 Swimmer | `bw_swimmer` | ja | seconds |
| 10 Russian Twist | `bw_russian_twist` | nein | – |
| 11 Lunge + Kick | `bw_lunge_kick` | ja | reps |
| 12 Liegestütze | `bw_pushup` | nein | – |
| 13 Leg Drop & Pull | `bw_leg_drop_pull` | ja | reps |
| 14 Weitsprung mit Bodenberührung | `bw_broad_jump_touch` | ja | reps |
| 15 Squat mit Händen zum Boden | `bw_squat_floor_touch` | ja | reps |
| 16 Plank mit Knie zur Brust | `bw_mountain_climber` | nein | – |
| 17 Flutter Kicks | `bw_flutter_kicks` | ja | seconds |
| 18 Skater Jumps | `bw_skater_jump` | ja | reps |
| 19 Crunch-Halten | `bw_crunch_hold` | ja | seconds |
| 20 Burpees mit Streckung | `bw_burpee_jump` | ja | reps |

- [ ] **Step 1:** Vor dem Anlegen im Katalog nach jedem neuen Schlüssel und Namen suchen (auch ähnliche Namen); Treffer in die Liste für Tim aufnehmen statt doppelt anzulegen.
- [ ] **Step 2:** Die 16 Übungen nach dem Muster der vorhandenen `bw_*` anlegen: deutscher Name eindeutig im ganzen Katalog (wichtig für `KameraTestprofile`, das nach Namen schlüsselt), `description` in eigenen Worten (Ausgangspunkt: Texte aus `hiit-20-min.json`), `muscles`, `sources`, `review` wie dort üblich, `target_min`/`target_max` passend zu `volume_kind`. Am Gerätetyp `bodyweight` eintragen.
- [ ] **Step 3:** Katalogprüfung laufen lassen (`pnpm vitest run packages/domain/src/katalog-datei.test.ts` und der Trockenlauf von `catalog:import`, wie in `scripts/catalog-import.ts` beschrieben) → grün.
- [ ] **Step 4:** `hiit-20-min.json`: jedem der 20 Schritte `uebung` laut Tabelle geben. `pnpm --silent flow:sql tools/flow-import/flows/hiit-20-min.json --studio 00000000-0000-4000-8000-000000000001 > /dev/null` → Exit 0.
- [ ] **Step 5:** `docs/flows/hiit-20-min-uebungen.md` schreiben: Tabelle Schritt, Name, Schlüssel, neu/vorhanden, Kamera oder Uhr mit Grund (Spec Abschnitt 8), und ausdrücklich die Nähe zu `bw_v_up`, `bw_squat`, `bw_crunch`.
- [ ] **Step 6:** Commit `feat(katalog): 16 Koerpergewichtsuebungen fuer den HIIT-Flow`.
- [ ] **Step 7: HALT.** Tim sieht die Liste (Namen, Schlüssel, Dubletten). Änderungen einarbeiten, erst dann Task 4 und Task 10.

### Task 4: Videos erzeugen

Arbeitet im Ordner `~/Documents/gymtavo/3D-Animationen/ki-video-serie/` (kein Git; Protokoll in `progress.md` fortschreiben). Läuft neben Task 5–8.

**Files:**
- Modify (außerhalb): `uebungen.json`, `pakete.json`, `stand.json`, `progress.md`
- Create (Repo): `catalog/media/videos/<key>.mp4` für jede abgenommene Übung; `video`-Feld im Katalogeintrag

**Interfaces:**
- Consumes: Schlüssel aus Task 3. Zu erzeugen: alle 16 neuen plus `bw_plank`, `bw_russian_twist`, `bw_mountain_climber` (haben kein Video) = 19.
- Produces: Loops im Format der vorhandenen Katalogvideos (640×640, 24 Bilder/s); Dateiname und `video`-Feld wie bei `bw_pushup`.

- [ ] **Step 1:** Guthaben bei OpenRouter abfragen (über `api.py`, ohne den Schlüssel auszugeben). Unter 10 $: Tim sagen, nicht starten.
- [ ] **Step 2:** `progress.md` und `serie.py`/`beschreiben.py` lesen: Felder `szene`, `kamera`, `bewegung`, `pruefpunkte`, `ende`, Loop-Arten `wechsel` und `ganz`, `geraete: []` für Übungen ohne Gerät. Die 19 Einträge in `uebungen.json` schreiben. Kamerawinkel im Video: Kamera-Schritte in der Blickrichtung ihres Profils (seitlich: 2, 6, 7, 11, 12, 13, 15, 20; von vorn: 3), übrige so, dass die Bewegung am besten zu sehen ist. Abwechselnde Übungen (1, 16, 18) als `wechsel`, zusammengesetzte (2, 4, 6, 11, 14, 20) als `ganz`.
- [ ] **Step 3:** Ein neues Paket in `pakete.json`; `python3 serie.py erzeuge <keys>`. Startbilder groß gegen die Prüfpunkte prüfen, vor dem Video; Paare (Start/Umkehr) groß prüfen. Nach jedem Lauf Summe aus `kosten.json` für diese Runde bilden; bei 10 $ aufhören.
- [ ] **Step 4:** Prüfseite bauen (`pruefen.py`, wie bei den Paketen 1–10). **HALT:** Tim nimmt die Bewegung ab; Pfad als `open <pfad>` im bash-Block geben. Beanstandete mit `serie.py neu <key> "Notiz"`, höchstens 3 Anläufe; was dann nicht passt, bleibt ohne Video.
- [ ] **Step 5:** Abgenommene Loops nach `catalog/media/videos/` kopieren (Format wie in `docs/superpowers/plans/2026-11-23-ki-videos-einspielen.md` beschrieben umrechnen), `video`-Feld setzen, Katalogprüfung grün.
- [ ] **Step 6:** Commit `feat(katalog): Uebungsvideos fuer den HIIT-Flow`. Kosten und Besonderheiten für die Anleitung (Task 10) notieren.

### Task 5: App – Schritt auflösen und Ansicht bestimmen (reine Logik)

**Files:**
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/Flow.swift`
- Create: `apps/ios-member/FitnessMember/Flows/FlowUebungen.swift`
- Test: `apps/ios-member/FitnessMemberTests/FlowUebungenTests.swift`, `FlowDTOTests.swift`

**Interfaces:**
- Produces:
  - `FlowSchritt.exerciseId: String?` (fehlendes Feld dekodiert als nil).
  - `enum FlowSchrittAnsicht: Equatable { case ring; case video(exerciseId: String); case kamera(KameraStart) }`
  - `struct FlowUebungen { init(bootstrap: BootstrapResponse?, testprofile: Bool); func uebung(_ schritt: FlowSchritt) -> BootstrapResponse.Exercise?; func ansicht(_ schritt: FlowSchritt, mitKamera: Bool) -> FlowSchrittAnsicht; func hatKameraSchritt(_ flow: Flow) -> Bool }`
  - `extension Kameraprofil { var blickzeile: String? }` → „Stell dich seitlich zur Kamera“ für `ganzkoerperStehend`, `stuetzBoden`, `liegend`; „Schau zur Kamera“ für `oberkoerper`, `zugHaengend`; nil für `ohneKamera`.

- [ ] **Step 1: Tests (rot).**
  - DTO: JSON ohne `exerciseId` dekodiert, `exerciseId == nil`; mit Wert übernommen.
  - `uebung`: findet die Übung in `bootstrap.catalog.equipmentTypes[].exercises` und in `machines[].exercises`; unbekannte ID und `bootstrap == nil` → nil.
  - `ansicht`: Schritt ohne `exerciseId` → `.ring`; Übung nicht im Bootstrap → `.ring`; Übung ohne Kameraangaben → `.video(exerciseId:)`; Übung mit Kameraangaben und `mitKamera: true` → `.kamera(start)` mit `start.sollWiederholungen == nil`, `start.satzZiel == 1`; dieselbe mit `mitKamera: false` → `.video`; Profil `ohneKamera` → `.video`.
  - `testprofile: true` ergänzt Kameraangaben über `KameraTestprofile.ergaenzt` (nur `#if DEBUG`); `testprofile: false` nicht.
  - `blickzeile` für alle sechs Profile.
- [ ] **Step 2:** Suite `FlowUebungenTests` läuft rot.
- [ ] **Step 3:** Umsetzen. `KameraStart` entsteht über das vorhandene `Exercise.kameraStart(satzZiel:sollWiederholungen:)`.
- [ ] **Step 4:** Suiten `FlowUebungenTests`, `FlowDTOTests` grün.
- [ ] **Step 5:** Commit `feat(flows): Flow-Schritt loest Uebung, Video und Kameraangaben auf`.

### Task 6: App – Pause und Uhr-Schritt mit Video

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Flows/FlowVideoSchritt.swift`, `FlowZeitPille.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Flows/FlowLaufView.swift`, `FlowDetailView.swift` (reicht `FlowUebungen` und `UebungsVideoVorrat` durch)
- Test: `apps/ios-member/FitnessMemberTests/FlowAnzeigeTests.swift`

**Interfaces:**
- Consumes: `FlowUebungen`, `FlowSchrittAnsicht` (Task 5); `UebungsVideoVorrat.datei(exerciseId:ersatz:) async -> URL?`; `Schleifenvideo(asset:)`.
- Produces:
  - `FlowLaufView(flow:store:uebungen:videos:)`.
  - `struct FlowVideoSchritt: View { let ueberschrift: String; let zeile: String?; let name: String; let beschreibung: String?; let blickzeile: String?; let videoURL: URL?; let ringErsatz: FlowRing }` – zeigt das Video als Schleife, ohne `videoURL` den Ring.
  - `struct FlowZeitPille: View { let restS: Int }` oben rechts; `FlowAnzeige.uhrKurz(_ s: Int) -> String` („0:14“).

- [ ] **Step 1: Tests (rot).** `uhrKurz(14) == "0:14"`, `uhrKurz(75) == "1:15"`, `uhrKurz(0) == "0:00"`. Reine Funktion `FlowAnzeige.pausenzeile(ansicht:) -> String?`: `.kamera` mit Profil `stuetzBoden` → „Stell dich seitlich zur Kamera“, `.video` und `.ring` → nil.
- [ ] **Step 2:** Rot bestätigen.
- [ ] **Step 3:** Umsetzen nach Spec Abschnitt 6:
  - Countdown und Pause: `FlowVideoSchritt` mit Überschrift „GLEICH GEHT'S LOS“ bzw. „PAUSE“, Zeile „Als Nächstes“, Name und Beschreibung der **nächsten** Übung, Blickzeile, `FlowZeitPille` oben rechts.
  - Arbeit bei `.video`/`.ring`: `FlowVideoSchritt` mit „SCHRITT n VON m“, Video der laufenden Übung, darunter „Als Nächstes: …“, Zeit oben rechts. Bei `.ring` bleibt der große Ring wie heute.
  - Video-URLs je `exerciseId` einmal beim Erscheinen laden und für die nächste Übung vorhalten; lädt eines nicht, Ring.
  - `.kamera` zeigt in diesem Task noch dasselbe wie `.video` (Task 8 ersetzt es).
- [ ] **Step 4:** Tests grün; App im Simulator mit lokal eingespieltem Flow öffnen (Testaccount siehe Memory `reference_testaccount-member-app`), Pause und Arbeitsphase ansehen, Bildschirmfotos ablegen.
- [ ] **Step 5:** Commit `feat(flows): Pause und Arbeitsphase mit Uebungsvideo und Restzeit oben rechts`.

### Task 7: Package – `FlowZaehler`

**Files:**
- Create: `apps/ios-member/Packages/Koerperbild/Sources/Koerperbild/FlowZaehler.swift`
- Test: `apps/ios-member/Packages/Koerperbild/Tests/KoerperbildTests/FlowZaehlerTests.swift`

**Interfaces:**
- Consumes: `Koerperlage(vorgabe:gemerkterHub:)`, `.los(t:)`, `.unterbrechen()`, `.verarbeite(t:skelett:) -> Lage`, `.wiederholungen`; `Erkennungspruefung`; `Sollwelle`; `KameraSatzAblauf.Spurpunkt`.
- Produces:

```swift
public struct FlowZaehler: Sendable {
    public static let nichtErkanntNach: TimeInterval = 3
    public init(vorgabe: Kameravorgabe, tempo: Uebungstempo)
    /// Beginn der Arbeitsphase; vorherige Bilder duerfen schon ueber `bild` gekommen sein.
    public mutating func start(t: TimeInterval)
    public mutating func bild(t: TimeInterval, skelett: Skelett?)
    /// Anhalten und Fortsetzen der Flow-Uhr; angehaltene Zeit zaehlt nicht in Welle und Zaehlung.
    public mutating func anhalten(t: TimeInterval)
    public mutating func fortsetzen(t: TimeInterval)
    public var wiederholungen: Int { get }
    /// false: Hinweis "Kamera sieht dich gerade nicht".
    public var erkannt: Bool { get }
    public var welle: Sollwelle { get }
    public var sollzeit: TimeInterval { get }
    public var spur: [KameraSatzAblauf.Spurpunkt] { get }
}
```

- [ ] **Step 1: Tests (rot),** mit künstlichen Skelettfolgen wie in `KameraSatzAblaufTests` (Hilfen dort wiederverwenden):
  - 10 saubere Kniebeugen ab `start`, ohne Ruhe davor → `wiederholungen` 9 oder 10, nie mehr.
  - Bilder vor `start` zählen nicht.
  - Kein Skelett für 3,1 s ab `start` → `erkannt == false`; kommt es danach, `erkannt == true` und es wird gezählt.
  - 4 Wiederholungen, 2 s kein Skelett, 4 Wiederholungen → `wiederholungen >= 7`, während der Lücke `erkannt == false` nach mehr als 1,0 s, die Zahl sinkt zu keinem Zeitpunkt.
  - `anhalten` nach 3 Wiederholungen, 60 s Bilder mit Bewegung, `fortsetzen` → Zahl unverändert bis `fortsetzen`; `sollzeit` springt nicht um 60 s.
  - Hub unter 20° (winzige Bewegung) → 0 Wiederholungen, kein Absturz.
  - `sollzeit` wächst ab `start` mit der Zeit; `spur` enthält höchstens die letzten 6 s.
- [ ] **Step 2:** `swift test --filter FlowZaehlerTests` → rot.
- [ ] **Step 3:** Umsetzen. `los(t:)` beim `start`, wenn die Erkennung steht, sonst beim ersten Bild mit bestandener Erkennung; nach Verlust `unterbrechen()` und bei Rückkehr erneut `los`. Die Zahl wird über Unterbrechungen hinweg selbst aufsummiert. Die Welle ist eine reine Zeitvorgabe ab `start` und hält bei Verlust **nicht** an (anders als `KameraSatzAblauf`).
- [ ] **Step 4:** `swift test` im Package ganz → grün (bestehende Tests unverändert).
- [ ] **Step 5:** Commit `feat(koerperbild): FlowZaehler zaehlt Wiederholungen in einer festen Arbeitsphase`.

### Task 8: App – Aufstellen, Kamera-Phase, Fertig mit Zahlen

**Files:**
- Create: `apps/ios-member/FitnessMember/Flows/FlowKameraModell.swift`, `apps/ios-member/FitnessMember/Screens/Flows/FlowAufstellView.swift`, `FlowKameraSchritt.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Flows/FlowLaufView.swift`
- Test: `apps/ios-member/FitnessMemberTests/FlowKameraModellTests.swift`

**Interfaces:**
- Consumes: `FlowZaehler` (Task 7), `FlowUebungen`/`FlowSchrittAnsicht` (Task 5), `Bildquelle`, `Bildquellen.fuer(_:)`, `Kameraerlaubnis`, `KameraBildflaeche`, `Livebildziel`, `Wellenband`, `OhneKameraKnopf`.
- Produces:

```swift
@MainActor @Observable
final class FlowKameraModell {
    enum Start: Equatable { case aufstellen, erlaubnisFehlt, kameraFehlt, bereit, ohneKamera }
    static let vorlaufS = 5
    init(flow: Flow, uebungen: FlowUebungen,
         quelle: @escaping @MainActor (KameraStart) -> any Bildquelle = Bildquellen.fuer,
         erlaubnis: @escaping () -> Kameraerlaubnis = { .aktuell },
         anfragen: @escaping () async -> Kameraerlaubnis = Kameraerlaubnis.anfragen)
    private(set) var start: Start
    var mitKamera: Bool { get }                       // false nach "Ohne Kamera starten" oder ohne Erlaubnis
    private(set) var zaehler: FlowZaehler?             // nur waehrend eines Kamera-Schritts
    private(set) var letztesSkelett: Skelett?
    var ziel: Livebildziel { get }
    private(set) var hinweis: String?                  // "Kamera sieht dich gerade nicht"
    private(set) var gezaehlt: [Int: Int]              // Schritt-Index (0-basiert) -> Wiederholungen
    func aufstellenBeginnen() async                    // fragt Erlaubnis, startet Kamera, prueft ganzkoerper_stehend
    func ohneKameraStarten()
    /// Bei jedem Wechsel des Flow-Zustands und bei Anhalten/Weiter aufrufen.
    func folge(_ zustand: FlowZustand, pausiert: Bool) async
    func schliessen()                                  // Kamera aus, Idle-Timer unberuehrt
}
```

- [ ] **Step 1: Tests (rot),** mit einer Test-`Bildquelle`, die Skelette aus einer Liste liefert (Muster `KameraAblaufModellTests`):
  - Flow ohne Kamera-Schritt → `start == .bereit` sofort, keine Erlaubnisfrage, Quelle nie gestartet.
  - Erlaubnis verweigert → `.erlaubnisFehlt`; `ohneKameraStarten()` → `.ohneKamera`, `mitKamera == false`.
  - Aufstellen: 1,0 s sicher erkannte Pflichtgelenke von `ganzkoerper_stehend` → `.bereit`, Quelle gestoppt.
  - `folge(.pause(naechster: k, restS: 6))` mit Kamera-Schritt k → Quelle aus; `restS: 5` → Quelle läuft, `zaehler == nil`; `folge(.arbeit(schritt: k, …))` → `zaehler != nil`, zählt.
  - `folge(.pause(…))` nach dem Schritt → Quelle aus, `gezaehlt[k]` gesetzt, `zaehler == nil`.
  - Zwei Kamera-Schritte hintereinander mit verschiedenen Vorgaben → zweiter Zähler beginnt bei 0 mit der eigenen Vorgabe; `gezaehlt` hat beide Einträge. (Review Focus 4)
  - Quelle wirft beim Start oder meldet `beiFehler` → `hinweis` gesetzt, kein Wurf nach außen; beim nächsten Kamera-Schritt neuer Startversuch. (Review Focus 3)
  - `folge(…, pausiert: true)` → Zahl bleibt bei weiteren Bildern; `pausiert: false` → zählt weiter. (Review Focus 2)
  - Sprung von `.arbeit(schritt: k)` direkt zu `.pause(naechster: k + 2)` (Hintergrund) → Quelle aus, `gezaehlt[k]` gesetzt, kein Absturz. (Review Focus 1)
  - `folge(.fertig)` → Quelle aus; `mitKamera == false` → Quelle wird nie gestartet.
- [ ] **Step 2:** Suite `FlowKameraModellTests` rot.
- [ ] **Step 3:** Modell umsetzen. Ein Start-Zähler wie in `KameraAblaufModell` (`startNummer`) schützt vor Starts, die nach einem Stopp zurückkehren.
- [ ] **Step 4:** Ansichten:
  - `FlowAufstellView`: vor `lauf.starten()`, nur wenn `uebungen.hatKameraSchritt(flow)`. `KameraBildflaeche` mit Profil `ganzkoerperStehend`, der Aufstelltext, `OhneKameraKnopf` mit Titel „Ohne Kamera starten“; bei `.erlaubnisFehlt` Hinweis mit Weg in die Einstellungen (Baustein aus `UebungsvideoSchritt`), bei `.kameraFehlt` Hinweis und „Ohne Kamera starten“. Bei `.bereit`/`.ohneKamera` startet der Lauf.
  - `FlowKameraSchritt`: Arbeitsphase bei `.kamera`: `KameraBildflaeche` (dezent), `Wellenband(welle:tempo:sollzeit:spur:punkt:)` aus dem Zähler, Zahl groß „14 Wdh.“, Hinweiszeile, darüber „SCHRITT n VON m“ und `FlowZeitPille`, darunter Name und „Als Nächstes: …“. Kein Phasenwort, keine Takt-Pille.
  - `FlowLaufView`: ruft `folge` bei Phasenwechsel, jede Sekunde im Vorlauf-Fenster der Pause und bei Anhalten/Weiter; bei `scenePhase != .active` `schliessen()`, bei Rückkehr `folge` mit dem aktuellen Zustand. Abbrechen und Fertig rufen `schliessen()`; `abschliessen(_:)` bleibt unverändert und hängt nicht am Kamera-Modell.
  - Fertig: unter „n Schritte absolviert“ die Liste aus `gezaehlt` in Schrittfolge („Liegestütze 14“); leer → keine Liste.
- [ ] **Step 5:** Tests grün. Im Simulator mit `-kameraAbspielen <Repo-Wurzel>` und eingeschalteten Testprofilen einen Kamera-Schritt ansehen; ohne Abspieldaten prüfen, dass der Hinweis erscheint und der Flow bis „Fertig“ läuft. Bildschirmfotos ablegen.
- [ ] **Step 6:** Commit `feat(flows): Aufstellen vor dem Start, Kamera-Phase mit Welle und Zaehlung, Zahlen im Fertig-Bildschirm`.

### Task 9: Testprofile der Flow-Übungen und Prüfung gegen die Videos

Braucht die Videos aus Task 4.

**Files:**
- Create: `data/koerperbild/flow-zuordnung.json`
- Modify: `tools/kamera-zuordnung/testprofile.py`, `apps/ios-member/FitnessMember/Resources/KameraTestprofile.json` (erzeugt), `apps/ios-member/FitnessMemberTests/KameraTestprofileTests.swift`, Schaltertext in `Screens/Profil/ProfilRootView.swift`
- Create: `docs/flows/hiit-20-min-kamera-bericht.md`

**Interfaces:**
- Produces: `flow-zuordnung.json`, gleiche Form wie `zuordnung.json`, mit den neun Kamera-Schritten:

| Schlüssel | Profil | Signal | beginnt mit |
|---|---|---|---|
| `bw_jumping_jack` | `oberkoerper` | `schulter` | `heben` |
| `bw_squat_floor_touch`, `bw_squat_pulse`, `bw_lunge_kick` | `ganzkoerper_stehend` | `knie` | `senken` |
| `bw_burpee_slow`, `bw_burpee_thigh_tap`, `bw_burpee_jump` | `ganzkoerper_stehend` | `huefte` | `senken` |
| `bw_pushup` | `stuetz_boden` | `ellbogen` | `senken` |
| `bw_leg_drop_pull` | `liegend` | `huefte` | `senken` |

Seite `beide`, Tempo 1 / 0 / 1.

- [ ] **Step 1:** `testprofile.py`: liest zusätzlich `flow-zuordnung.json`; deren Einträge werden unabhängig vom Profil-Filter aufgenommen und überschreiben gleiche Schlüssel. Test in `KameraTestprofileTests`: „Liegestütz“ und „Jumping Jacks“ (bzw. die Namen aus Task 3) haben einen Eintrag mit dem Profil aus der Tabelle; die bisherigen Einträge bleiben.
- [ ] **Step 2:** Skelette der neun Videos vorrechnen (Werkzeug `loops-pruefen` mit `SKELETTE=<Ordner>`, siehe Plan `2026-11-24-kamera-tempo-kern-katalog.md`, Abschnitt „Stand nach der Umsetzung“), Ablage wie die vorhandenen Skelette, damit `AbspielQuelle` sie findet.
- [ ] **Step 3:** Package-Test `FlowZaehlerAbspielTests`: je Video `FlowZaehler` über die Skelettfolge (Start bei t = 0, Schleife so oft, bis 40 s erreicht sind), erwartete Zahl = Wiederholungen im Loop × Durchläufe, Toleranz ± 1 je Durchlauf. Ergebnis je Übung in `hiit-20-min-kamera-bericht.md` (gezählt, erwartet, erkannt-Anteil).
- [ ] **Step 4:** Übungen, die durchfallen: aus `flow-zuordnung.json` entfernen (Schritt läuft mit Uhr), im Bericht mit Grund vermerken. Kein Nachschärfen von `Koerperlage` in diesem Plan.
- [ ] **Step 5:** `python3 tools/kamera-zuordnung/testprofile.py`, Schaltertext im Profil um „Flow-Übungen“ ergänzen, App-Tests grün.
- [ ] **Step 6:** Commit `feat(kamera): Testprofile fuer die Flow-Uebungen, Bericht gegen die Videos`.

### Task 10: Anleitung, Prod, Gerätetest, PR

**Files:**
- Create: `docs/flows/flow-aus-video.md`

- [ ] **Step 1:** Anleitung schreiben, Abschnitte in dieser Reihenfolge, jeweils mit den echten Befehlen und dem, was beim HIIT-Flow passiert ist: (1) Link und Transkript (`flow:transkript`), (2) Entwurf und unsichere Schritte, (3) Abgleich mit dem Katalog: wie gesucht, wann „gleiche Übung“, wann neu, (4) neue Katalogübungen anlegen, (5) Videos: Beschreibung, Erzeugen, Prüfseite, Kosten je Übung, typische Fehler, (6) Kamera oder Uhr je Schritt: Regeln aus Spec Abschnitt 8 und Ergebnis des Berichts, (7) `uebung` in der Flow-Datei, `flow:sql`, (8) Einspielen und Freigaben in der richtigen Reihenfolge, (9) Probe in der App. Am Ende „Was schiefging oder Zeit gekostet hat“. Commit `docs(flows): Anleitung Flow aus Video-Link`.
- [ ] **Step 2:** Ganze Testläufe: `pnpm typecheck && pnpm test && pnpm test:integration`, `swift test` im Package, App-Tests ganz. Ausgabe im Bericht an Tim zitieren.
- [ ] **Step 3: HALT – Tim fragen,** ob gepusht und der PR geöffnet werden darf (ein PR: Kamera-Ablauf und Flow mit Kamera; Beschreibung nennt beide Pläne). Nach dem Öffnen `ccd_pr`-Status lesen.
- [ ] **Step 4: Prod, jeder Punkt einzeln mit Tims ausdrücklichem Ja, in dieser Reihenfolge:** (a) Migration 0080; (b) Merge des PR nach grüner CI → API-Deploy über Vercel, prüfen, dass `GET /me/flows` `exerciseId` liefert; (c) `catalog:import` für die 16 Übungen; (d) `catalog:import --nur-videos` für die neuen Videos; (e) Flow neu einspielen: `pnpm --silent flow:sql tools/flow-import/flows/hiit-20-min.json --studio 00000000-0000-4000-8000-000000000001`, SQL über den Supabase-Connector. Nach (e) per SQL zählen: 20 Schritte, 20 mit `exercise_id`.
- [ ] **Step 5:** Signierten Debug-Build aus Xcode auf Tims iPhone (Testprofile im Profil einschalten). Tim trainiert den Flow. Seine Beobachtungen je Schritt in `docs/flows/hiit-20-min-kamera-bericht.md` nachtragen (zählt / zählt nicht / Blickrichtung), und in die Anleitung, was daraus für den nächsten Flow folgt.
- [ ] **Step 6:** Memory `project_follow-along-flows` und `project_kamera-tempo-ablauf` auf den neuen Stand bringen.
