# Gymtavo-Katalog Etappe 4: iOS — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Member-App braucht keinen Studio-Code mehr.
- Wer kein Studio hat, landet nach dem Onboarding im **Freien Training** und sieht dort alle Gymtavo-Gerätetypen.
- Im Studio stehen die Geräte des Studios mit ihren Gymtavo-Übungen. Hat das Studio keine Geräte, stehen dort alle Gymtavo-Typen.
- Trainiert wird an einem Gerät mit QR-Code oder an einem Gerätetyp ohne Gerät.
- Beitreten geht über Profil → Studios → „Studio beitreten“ (Scan oder Code) und über den Scan eines Gerätecodes aus einem fremden Studio: Die App tritt bei, wechselt das Studio und öffnet das Gerät.

**Architecture:** Der Kern ist eine **Station**, der Swift-Spiegel von `packages/domain/src/station.ts`.
- Eine Station ist ein Gerät aus `bootstrap.machines` oder ein Gerätetyp aus `bootstrap.catalog`, jeweils mit Ort (`studioId`, nil im Freien Training).
- `GeraetModel`, `GeraetRoute`, `LokalerBlock`, `Blockzeile` und die Geräteliste arbeiten mit der Station statt mit `BootstrapResponse.Machine`.
- Lokal wird über `Station.schluessel` verglichen (`geraet:<id>` / `typ:<id>`, wie auf dem Server). An die API geht `machineId` **oder** `equipmentModelId` plus `studioId`.
- Der aktive Ort (`Ort.studio(id)` / `Ort.freiesTraining`) ersetzt `activeStudioId: String?` als ausdrückliche Wahl. Er wird gespeichert.
- Kein neues Backend. Etappe 3 (PR #41) ist in `master` und ausgeliefert.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, XcodeGen (`apps/ios-member`).

**Quelle:**
- `docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md`, Abschnitte 6, 7 und 8.1
- Etappe-3-Plan: Ergebnis-Abschnitt „Für Etappe 4“
- Bestandsaufnahme der App vom 7. Oktober (Zeilenangaben unten aus diesem Stand)

**Voraussetzung:** Dieser Plan läuft **auf dem Mac mit Xcode**. In der Cloud-Umgebung gibt es kein Xcode, dort lassen sich Swift-Änderungen weder bauen noch testen.

## Global Constraints

- **Kommentare in Swift ohne Umlaute**, Nutzertexte mit Umlauten. Kommentare begründen, sie beschreiben nicht.
- **Design-Tokens aus `DesignSystem.swift`**, nie als Literal. Eine Akzentfläche pro Screen. Hit-Targets mindestens 44 pt.
- **Rückwärtskompatibel dekodieren.** `PendingSetWrite` (Datei `pending-writes.json`), `SessionFileStore`/`LokalerBlock` und `GespeicherterVerlauf` (Datei `verlauf.json`) liegen auf Geräten mit dem alten Format.
  - Neue Felder werden mit `decodeIfPresent` gelesen. `machineId` wird optional.
  - Jede Änderung an einem gespeicherten Typ bekommt einen Test, der das alte JSON dekodiert.
- **`machineId` am Typ weglassen, nicht `null` schicken.** Synthetisiertes `Encodable` lässt `nil`-Optionals weg, darauf verlässt sich `SetWrite`. Der Server weist `null` ab (Zod `.optional()`).
- **Eine Einheit gehört genau einem Ort.**
  - Die Einheit merkt sich beim ersten Satz ihren Ort.
  - Ein Satz am Typ trägt die `studioId` dieses Orts, im Freien Training keine.
  - Ein Ortswechsel bei offener Einheit wird nicht still vollzogen (Task 4).
- **Swift-Tests mit Swift Testing** als `struct`-Suite. Jede Ableitung bekommt ihren Test vor dem View, der sie benutzt (rot → grün).
- **Neue Swift-Dateien:** danach `xcodegen generate` in `apps/ios-member`. `Package.resolved` bleibt unangetastet.
- **Tests:** in `apps/ios-member`
  `xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath /tmp/dd-katalog test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED|Test run with"`
  - Einzelne Suite mit `-only-testing:FitnessMemberTests/<Suite>`.
  - Vorher `df -h /System/Volumes/Data` (mindestens 3 GB frei), danach `rm -rf /tmp/dd-katalog`.
  - Grün vor dem nächsten Task.
- **Ein Commit je Task**, deutsche Message (`feat(ios-member): …`), mit den Trailern der Session.
- **Sichtcheck nur gegen das lokale Backend** (`supabase start` + `pnpm --filter @fitretro/web dev`), nie gegen Produktion.

## Entscheidungen, die dieser Plan trifft

Diese Punkte stehen so nicht in der Spec. Tim prüft sie vor der Umsetzung.

1. **Ortswechsel bei offener Einheit:**
   - Wechselt das Mitglied im Profil das Studio oder auf Freies Training, während eine Einheit läuft, fragt die App: „Training in {Ort} beenden?“
   - Beim Bestätigen beendet sie die Einheit wie über „Training beenden“ und wechselt dann.
   - Beim Abbrechen bleibt alles, wie es war.
2. **Scan eines fremden Studios bei offener Einheit:**
   - Der Beitritt passiert immer, ein Mitglied wird man unabhängig vom Training.
   - Das Gerät öffnet sich nur, wenn keine Einheit an einem anderen Ort läuft. Sonst kommt derselbe Dialog wie unter 1.
3. **Erster Start:** Ohne gespeicherte Wahl ist das erste Studio aktiv, ohne Studio das Freie Training. Eine ausdrücklich gewählte Option „Freies Training“ bleibt erhalten, auch wenn Studios da sind.
4. **Wortlaut:**
   - Der Eintrag heißt „Freies Training“.
   - Untertitel in der Geräteliste: „Alle Gymtavo-Geräte“.
   - Der Kurse-Tab sagt im Freien Training: „Kurse gibt es in deinem Studio. Tritt einem Studio bei, um sie zu sehen.“ Darunter steht der Knopf „Studio beitreten“.

---

## Task 1: DTOs — Katalog lesen, `machineId` optional, alte Dateien weiter lesbar

**Files:**
- Modify:
  - `Networking/DTOs/BootstrapResponse.swift`
  - `Networking/DTOs/TagContextResponse.swift` (:90)
  - `Networking/DTOs/WorkoutSet.swift` (`SetWrite` :14-67, `RecordedSet` :70-85, `Blockvorschlag` :92-103)
  - `Networking/DTOs/SessionSummary.swift` (`Block` :63-85)
- Tests: `FitnessMemberTests/DTOTests.swift`

**Interfaces:**
```swift
// BootstrapResponse
struct Catalog: Decodable, Equatable, Sendable {
    let studioId: String
    let equipmentTypes: [EquipmentType]
    struct EquipmentType: Decodable, Equatable, Sendable {
        // dieselben Felder wie EquipmentModel, dazu
        let exercises: [Exercise]
    }
}
struct LastTypeSet: Decodable, Equatable, Sendable {
    let equipmentModelId, exerciseId: String; let load: Double; let secondaryLoad: Double?
    let volume: Int; let rir: Double?; let performedAt: String
}
var catalog: Catalog? = nil            // decodeIfPresent
var lastTypeSets: [LastTypeSet] = []   // decodeIfPresent ?? []
EquipmentModel.catalogModelId: String? // decodeIfPresent

// TagContextResponse
let machine: Machine?                  // null im Typ-Kontext

// SetWrite
var machineId: String?
var equipmentModelId: String?
var studioId: String?

// RecordedSet / Blockvorschlag / SessionSummary.Block
machineId: String?
equipmentModelId: String?              // decodeIfPresent: alte Caches haben ihn nicht
```

- [ ] **Rote Tests in `DTOTests`:**
  - Bootstrap ohne `catalog`/`lastTypeSets` (bisheriges JSON) dekodiert, Katalog `nil`, `[]`.
  - Bootstrap mit beiden Feldern dekodiert.
  - Typ-Kontext mit `"machine": null` dekodiert.
  - `SetWrite` am Typ kodiert **ohne** Schlüssel `machineId`, mit `equipmentModelId` und `studioId`. Im Freien Training fehlt auch `studioId`.
  - Altes `PendingSetWrite`-JSON mit `machineId` (und mit `weightKg`/`reps`) dekodiert weiter.
  - `SessionSummary` aus einem alten `verlauf.json`-Ausschnitt (ohne `equipmentModelId`) dekodiert.
  - Block mit `"machineId": null` dekodiert.
  - `CompletedSession` mit `vorschlaege[].machineId: null` dekodiert.
- [ ] Umsetzen:
  - `BootstrapResponse` bekommt ein eigenes `init(from:)`.
  - Der Memberwise-Init bleibt für die Tests erhalten, als ausdrücklicher Init mit Defaults für die neuen Felder.
  - `SetWrite.init(from:)` liest `machineId` mit `decodeIfPresent`.
- [ ] Die Kompilierfehler in den Nutzern von `machineId` (Bestandsaufnahme Abschnitt 7) **nicht** hier lösen. Wo der Compiler einen String braucht, bis Task 6 ein `?? ""` mit `// TODO Task 6` setzen. Grün, Commit `feat(ios-member): DTOs lesen den Gymtavo-Katalog, machineId wird optional`.

## Task 2: `Station` — Gerät oder Gerätetyp

**Files:** Create `Workout/Station.swift`, `FitnessMemberTests/StationTests.swift`.

**Interfaces:**
```swift
struct Station: Hashable, Sendable, Identifiable {
    enum Art: Hashable, Sendable { case geraet(machineId: String), typ(equipmentModelId: String) }
    let art: Art
    let studioId: String?              // nil = Freies Training
    let label: String                  // Geraetelabel bzw. Typname
    let equipmentModel: BootstrapResponse.EquipmentModel
    let exercises: [BootstrapResponse.Exercise]
    let tokenHashes: [String]          // leer am Typ
    let gesperrt: Bool                 // status != "active", am Typ false
    var id: String { schluessel }
    var schluessel: String             // "geraet:<id>" | "typ:<id>" -- wie station.ts
    var machineId: String? { ... }
    var equipmentModelId: String { equipmentModel.id }
}
extension Station {
    init(maschine: BootstrapResponse.Machine)
    init(typ: BootstrapResponse.Catalog.EquipmentType, studioId: String?)
    static func schluessel(machineId: String?, equipmentModelId: String) -> String
}
extension BootstrapResponse {
    func station(schluessel: String, studioId: String?) -> Station?
}
```
- [ ] Rote Tests:
  - Schlüssel wie auf dem Server.
  - Gerät gewinnt über den Typ.
  - Typ-Station ohne `machineId` und ohne Token.
  - `bootstrap.station(schluessel:)` findet Gerät und Typ und liefert für Unbekanntes `nil`.
- [ ] Umsetzen, `xcodegen generate`, grün, Commit `feat(ios-member): Station als Spiegel von station.ts`.

## Task 3: `CatalogStore` — Ort statt aktivem Studio, Beitritt wechselt

**Files:**
- Modify `Catalog/CatalogStore.swift` (:29, :76-122, :209-235)
- Tests: `CatalogStoreTests.swift`, alle `FakeBootstrapLoader`-Varianten (:5-57, :416-418, :629-631, :657-659)

**Interfaces:**
```swift
enum Ort: Equatable, Sendable, Codable { case studio(String), freiesTraining }
private(set) var ort: Ort                 // persistiert unter "aktiverOrt"; liest "activeStudioId" einmalig als Migration
var activeStudioId: String? { if case .studio(let id) = ort { id } else { nil } }  // bleibt fuer alle bisherigen Leser
func setOrt(_ ort: Ort)
func joinStudio(byCode:) async throws -> JoinResult   // wechselt danach auf .studio(result.studioId)
func joinStudio(byTag:) async throws -> JoinResult    // dito; liefert machineId fuer den Scanpfad
```

Regeln in `load()`:
- Ein gespeicherter `.studio(id)`, der nicht mehr in `studios` steht, fällt auf das erste Studio zurück. Ohne Studio fällt er auf `.freiesTraining`.
- `.freiesTraining` bleibt immer stehen.
- Ohne gespeicherte Wahl (erster Start): das erste Studio, ohne Studio `.freiesTraining`.

- [ ] Rote Tests:
  - Ohne Studio wird `.freiesTraining` gesetzt.
  - Die gewählte Option „Freies Training“ übersteht ein `load()` mit Studios.
  - Ein verlassenes Studio fällt zurück.
  - Ein alter Defaults-Eintrag `activeStudioId` wird übernommen.
  - `joinStudio(byCode:)` wechselt auf das neue Studio und setzt `studiohinweis(beigetreten: true)`.
  - `joinStudio(byTag:)` liefert `machineId` durch.
  - `reset()` löscht den Ort.
- [ ] Der Test :364 („ohne Studio … nach noStudio“) wird in Task 4 umgeschrieben, hier nur vorgemerkt.
- [ ] Grün, Commit `feat(ios-member): Ort statt aktivem Studio, Beitritt wechselt das Studio`.

## Task 4: Ortswechsel bei offener Einheit

**Files:**
- Modify `Workout/WorkoutSessionStore.swift`. Die Einheit merkt sich `ort: Ort` beim ersten Satz, gespeichert über `LokaleSession` mit `decodeIfPresent`.
- Create `Workout/Ortswechsel.swift`
- Tests: `WorkoutSessionStoreTests` / `OrtswechselTests`

**Interfaces:**
```swift
enum Ortswechsel {
    enum Ergebnis: Equatable { case sofort, erstBeenden(laufenderOrt: Ort) }
    static func pruefen(ziel: Ort, offeneEinheit: LokaleSession?) -> Ergebnis
}
```
- [ ] Rote Tests:
  - Ohne offene Einheit gilt `.sofort`.
  - Bei offener Einheit am selben Ort gilt `.sofort`.
  - Bei offener Einheit an einem anderen Ort gilt `.erstBeenden`.
  - Eine alte `LokaleSession` ohne `ort` gilt als am aktuellen Ort.
- [ ] Umsetzen. Den Dialog baut Task 7 (Profil) und Task 9 (Scan) ein. Grün, Commit.

## Task 5: Routing ohne Studio-Zwang, „Studio beitreten“ als eigener Screen

**Files:**
- Modify:
  - `Navigation/RootDestination.swift` (:10, :61-63)
  - `Navigation/RootView.swift` (:40-42)
  - `Catalog/CatalogLoadState.swift`
  - `Screens/Zugang/MemberRegistrierenView.swift` (:18)
- Create `Screens/Studios/StudioBeitretenView.swift`, herausgelöst aus `MemberKeinStudioView` (Scanner, Code-Feld, Fehlertexte :128-160)
- Delete `MemberKeinStudioView`. `MemberLadefehlerView` (:164) wandert in eine eigene Datei.
- Tests: `RootDestinationTests`, `CatalogStoreTests` :364

- [ ] Rote Tests:
  - `.loaded` führt nach dem Onboarding immer zu `.main`.
  - Das Onboarding gewinnt weiterhin.
  - Es gibt kein `.noStudio` mehr.
- [ ] `CatalogLoadState.loaded(hasStudio:)` wird `.loaded`. Die Zähler-Asserts in `CatalogStoreTests` (:76-91, 191, 273, 292-293, 308, 322, 360) ziehen nach.
- [ ] `StudioBeitretenView(beiErfolg:)`: Nach einem Beitritt schließt der Screen und zeigt den vorhandenen `studiohinweis`. Die Texte bleiben wie bisher.
- [ ] Registrierung: „Für dein Studio brauchst du ein Konto.“ → „Mit einem Konto speichert Gymtavo dein Training.“
- [ ] Grün, Commit `feat(ios-member): App ohne Studio-Zwang, Studio beitreten als eigener Screen`.

## Task 6: Lokale Blöcke und Sätze über Stationen

**Files:**
- Modify:
  - `Workout/LokaleSession.swift` (`LokalerBlock` :73-113)
  - `Workout/Trainingszusammenfassung.swift` (:10-25, :60)
  - `Workout/WorkoutSessionStore.swift` (:126-193)
  - `Screens/Training/TrainingTab.swift` (:30)
  - `Screens/Home/HomeZeilen.swift` (:277-279)
  - `Screens/Home/HomeSerieView.swift` (:559)
- Tests: `WorkoutSessionStoreTests`, `LokaleSessionTests`, `TrainingszusammenfassungTests`, `HomeZeilenTests`

**Interfaces:**
```swift
struct LokalerBlock { let stationSchluessel: String; let machineId: String?; let equipmentModelId: String?; ... } // id = "\(stationSchluessel):\(exerciseId)"
func satzSichern(station: Station, exerciseId: String, ...)  // statt machineId:
func naechsterSetIndex(station: Station, exerciseId: String) -> Int
```
`SetWrite` am Gerät: `machineId`. Am Typ: `equipmentModelId` plus `studioId` = Ort der Einheit, im Freien Training ohne.

- [ ] Rote Tests:
  - Eine alte `LokaleSession` (Blöcke nur mit `machineId`) dekodiert, und ihr Stationsschlüssel ist `geraet:<id>`.
  - Ein Satz am Typ in einer Studio-Einheit schreibt `equipmentModelId` und `studioId`, ohne `machineId`.
  - Im Freien Training schreibt er ohne `studioId`.
  - Zwei Typen ergeben zwei Blöcke.
  - Gerätezahlen (`geraeteAnzahl`, `verschiedeneGeraete`) zählen Stationen. Für Server-Blöcke gilt `machineId ?? "typ:" + equipmentModelId`.
- [ ] Die `TODO Task 6` aus Task 1 auflösen. Grün, Commit `feat(ios-member): lokale Bloecke und Saetze ueber Stationen`.

## Task 7: Profil → Studios — Freies Training, Beitreten, Wechsel mit Rückfrage

**Files:**
- Modify `Screens/Profil/MemberStudiosView.swift` (:8-67)
- Tests: neue Ableitung `StudiosListe` mit Test (Zeilen, Häkchen, Fußtext)

- [ ] Rote Tests (Ableitung):
  - Die erste Zeile ist immer „Freies Training“.
  - Danach kommen die Studios alphabetisch.
  - Das Häkchen folgt dem `ort`.
  - „Verlassen“ gibt es nur bei Studios.
- [ ] View:
  - Tap auf eine Zeile ruft `Ortswechsel.pruefen` auf. Bei `.erstBeenden` erscheint ein `confirmationDialog` „Training in {Ort} beenden?“; bestätigt wird über den Abschlusspfad aus `TrainingRootView.beenden()`, als Funktion in `WorkoutSessionStore` herausgezogen.
  - Darunter steht die Zeile „Studio beitreten“ → `StudioBeitretenView`.
  - Fußtext :43 neu: „Tippen wechselt. Ein Gerätecode aus einem anderen Studio macht dich dort zum Mitglied.“ Das stimmt nach Task 9 wirklich.
- [ ] Grün, Commit.

## Task 8: Geräteliste über Stationen

**Files:**
- Modify:
  - `Workout/GeraeteAuswahl.swift` (:14-194)
  - `Screens/Geraet/GeraeteAuswahlView.swift` (:15-483)
  - `Workout/GeraetEinstieg.swift` (:77-105)
- Tests: `GeraeteAuswahlTests`, `GeraetEinstiegTests`

**Regel (Spec 6):**
- `ort = .studio(id)` und das Studio hat Geräte: dessen Geräte als Stationen.
- `ort = .studio(id)` ohne Geräte: alle Katalogtypen mit `studioId = id`.
- `ort = .freiesTraining`: alle Katalogtypen mit `studioId = nil`.

**Interfaces:**
```swift
static func gruppen(bootstrap:, ort: Ort, suchtext:) -> Gruppen   // statt studioId:
struct Eintrag { let station: Station; ... }                       // id = station.schluessel
```
- „Zuletzt“ liest `lastSets` (Gerät) und `lastTypeSets` (Typ) über den Stationsschlüssel.
- `nichtScannbar` gilt nicht für Typen. Ein Typ ist kein Gerät ohne Sticker.

- [ ] Rote Tests:
  - Studio mit Geräten zeigt keine Katalogtypen.
  - Studio ohne Geräte zeigt alle Typen mit `studioId`.
  - Freies Training zeigt alle Typen ohne `studioId`.
  - „Zuletzt“ enthält einen freien Satz am Typ.
  - Die Suche findet einen Typ über eine Gymtavo-Übung.
  - Gymtavo-Übungen unter einem Studio-Gerät kommen aus `machines[].exercises`. Der Server mischt sie schon, die App mischt nichts.
  - `GeraetEinstiegRechner` zählt Besuche und letzte Übung je Station.
- [ ] View:
  - `beiAuswahl: (Station) -> Void`.
  - Untertitel im Freien Training: „Alle Gymtavo-Geräte“.
  - Fotos über `equipmentModel.id` wie bisher. Katalogfotos liegen im Gymtavo-Ordner, der für alle lesbar ist (0047).
  - Der Leerzustand „In diesem Studio ist noch kein Gerät eingetragen“ entfällt für Studios ohne Geräte, weil dort jetzt der Katalog steht.
- [ ] Grün, Commit.

## Task 9: Geräte-Screen, Route und Scan über Stationen

**Files:**
- Modify:
  - `Navigation/GeraetRoute.swift` (:7-20): `machineId` → `station: String`, also der Schlüssel, damit die Route `Hashable` bleibt
  - `Screens/Geraet/GeraetModel.swift`: `maschine` → `station`, alle `maschine.id`-Stellen aus der Bestandsaufnahme Abschnitt 6
  - `Workout/GeraetLoading.swift` (:9-14) plus `Networking/APIClient.swift`: `equipmentModelContext(modelId:studio:)` über `URLComponents`
  - `Screens/Training/TrainingRootView.swift` (:222, :420, :472-642)
  - `GeraetView.swift` (:171/198), `TrainingStartView.swift` (:55), `UebungWechselnSheet.swift` (:50), `ProblemSheet.swift` (:65), `GeraetErkanntView.swift` (:29)
  - Sensor: `SensorAufnahmeKoordinator.swift` (:185-246). Der Befestigungsschlüssel wird `station.schluessel`. Ein alter Schlüssel `sensor.befestigung.<machineId>` bleibt lesbar, weil `geraet:<id>` daraus abgeleitet wird.
- Tests: `GeraetKontextLadenTests`, `GeraetModelTests` (`FakeGeraetLoader` :1019-1065, `GeraetTestdaten` :1066 ff.), `APIClientTests`, neuer `ScanBeitrittTests`

**Kontext laden:**
- Mit Token: `tagContext`.
- An einem Gerät: `machineContext`.
- An einem Typ: `equipmentModelContext(modelId:, studio: station.studioId)`.

**Kalibrierung:** nur mit `machineId`. Am Typ blendet der Screen Kalibrieren und Einstellwerte-Merken aus (Spec 5.4). Die Einstellungen des Typs bleiben als Anzeige.

**Scan (`oeffneToken`, :563-597):**
1. Den Hash in `bootstrap.machines` suchen, wie bisher.
2. Nicht gefunden: `katalog.joinStudio(byTag:)`.
   - Fehler `.notFound`: bisheriger Text „Dieser Code ist nicht aktiv. Frag im Studio nach.“
   - Erfolg: `load()` ist erledigt, der Ort ist das neue Studio. Dann `Ortswechsel.pruefen`, gegebenenfalls Dialog.
   - Mit `machineId`: die Station suchen und navigieren.
   - Ohne `machineId` (Aushang): Liste des Studios zeigen, dazu den `studiohinweis`.
3. Gefunden, aber in einem anderen Studio als dem Ort: `Ortswechsel.pruefen`, dann `setOrt(.studio(maschine.studioId))` und öffnen. Die Fußzeile „Ein Scan … wechselt“ stimmt damit.
4. `PendingTagStore`-Eingänge laufen über denselben Pfad (:169-183).

- [ ] **Rote Tests:**
  - `GeraetKontextLaden`: Ein Typ geht über `equipmentModelContext` mit `studio`, ein Gerät über `machineContext`, ein Token über `tagContext`.
  - `GeraetModel` am Typ: kein Kalibrieren, Startwerte aus `lastTypeSets`, `satzSichern` schreibt ohne `machineId`.
  - `APIClientTests`: Die URL lautet `equipment-models/<id>/context?studio=<id>` bzw. ohne Query im Freien Training. Ein `machine: null` dekodiert.
  - `ScanBeitritt`: Das Entscheiden ist als reine Funktion herausgezogen (`ScanEntscheidung.fuer(token:bootstrap:ort:offeneEinheit:)` → `.oeffnen(Station)`, `.beitreten`, `.wechselnUndOeffnen(Ort, Station)`, `.erstBeenden(...)`). Getestet werden alle vier Fälle.
- [ ] Umsetzen, grün, Commit `feat(ios-member): Geraete-Screen, Route und Scan ueber Stationen, Beitritt per Geraetecode`.

## Task 10: Abschluss, Verlauf, Home und Kurse

**Files:**
- Modify:
  - `Screens/Training/TrainingAbschlussView.swift` (:229, :392-409): abgleichen über den Stationsschlüssel. Der Name kommt aus `block.machineLabel`, wenn die Station nicht im Bootstrap steht.
  - `TrainingRootView.blockZeile` (:420)
  - `SessionDetailView` (:163/187)
  - `HomeRootView` (:54-71, :219-240): Im Freien Training gibt es keine Kurse und keinen Studionamen. Der Kopf zeigt „Freies Training“.
  - `KurseWochenView` (:339-397, :741): Im Freien Training erscheint der Hinweis aus Entscheidung 4 mit Knopf → `StudioBeitretenView`.
- Tests: `TrainingAbschlussZeilenTests`, `HomeZeilenTests`, `KurseAnsichtTests`

- [ ] Rote Tests:
  - Ein Abschluss mit einem Vorschlag `machineId: nil` ordnet ihn dem Typ-Block zu.
  - Eine Home-Karte zählt freie Stationen mit.
  - Die Kurse-Ansicht liefert im Freien Training den Beitreten-Zustand.
- [ ] Umsetzen, grün, Commit.

## Task 11: Gesamtprüfung auf dem Mac

- [ ] Ganze Suite grün, ohne neue Warnungen.
- [ ] **Sichtcheck gegen das lokale Backend.** Fixtures per SQL: ein Gymtavo-Typ mit Übung und Video, ein Studio mit einem zugeordneten Gerät, ein Studio ohne Geräte. Durchspielen:
  1. Neues Konto ohne Studio: Nach dem Onboarding erscheint das Freie Training mit Gymtavo-Geräten. Satz am Typ, Training beenden, Vorschlag sichtbar, Verlauf mit Typname.
  2. Profil → Studio beitreten per Code. Das Studio wird aktiv, die Geräte des Studios mit ihren Gymtavo-Übungen erscheinen.
  3. Studio ohne Geräte: Die Gymtavo-Typen erscheinen. Ein Satz dort landet mit `studio_id` dieses Studios, das prüft man per SQL.
  4. Gerätecode eines fremden Studios scannen: Beitritt, Wechsel, Gerät offen.
  5. Bei offener Einheit auf Freies Training wechseln: Die Rückfrage kommt.
  6. App-Update über eine alte Installation mit offenen `pending-writes.json` und `verlauf.json`: Alles wird gelesen, nichts geht verloren.
- [ ] Plan abhaken, Ergebnis notieren, Push, PR.
